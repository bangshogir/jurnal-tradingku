<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\TradingLog;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class TradingWebhookController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index()
    {
        //
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(Request $request)
    {
        // Authentication via Webhook Token
        $token = $request->header('X-Webhook-Token') ?? $request->bearerToken() ?? $request->input('token');
        
        if (empty($token)) {
            return response()->json(['message' => 'Unauthorized. No token provided.'], 401);
        }

        $user = User::where('webhook_token', $token)->first();

        if (!$user) {
            return response()->json(['message' => 'Unauthorized. Invalid token.'], 401);
        }

        // Validate incoming data
        $validated = $request->validate([
            'ticket_id'    => 'required|string',
            'symbol'       => 'required|string',
            'type'         => 'required|string',
            'entry_price'  => 'nullable|numeric',
            'close_price'  => 'nullable|numeric',
            'sl_price'     => 'nullable|numeric',
            'tp_price'     => 'nullable|numeric',
            'lot_size'     => 'nullable|numeric',
            'profit_loss'  => 'nullable|numeric',
            'swap'         => 'nullable|numeric',
            'commission'   => 'nullable|numeric',
            'magic_number' => 'nullable|string',
            'comment'      => 'nullable|string',
            'open_time'    => 'nullable|date',
            'close_time'   => 'nullable|date',
            'balance'      => 'nullable|numeric',   // MT5 AccountInfoDouble(ACCOUNT_BALANCE)
            'account_name' => 'nullable|string',
        ]);

        // Update the user's balance from MT5 whenever data is received
        if (isset($validated['balance']) && $validated['balance'] > 0) {
            $user->balance = $validated['balance'];
            $user->save();
        }

        // Handle Canceled Pending Orders
        if ($validated['type'] === 'pending_cancel') {
            $deleted = TradingLog::where('user_id', $user->id)
                ->where('ticket_id', $validated['ticket_id'])
                ->delete();
            
            // Determine target Telegram Chat ID based on Account Routing
            $targetChatId = $user->telegram_chat_id; // Fallback
            $accName = $validated['account_name'] ?? null;
            $accountLabel = '';

            if ($accName) {
                // EA sends "LoginNumber - ServerName". Extract numeric login part for matching.
                $accountLogin = trim(explode('-', $accName)[0]);

                $route = \App\Models\TelegramRouting::where('user_id', $user->id)
                    ->where(function($q) use ($accName, $accountLogin) {
                        $q->where('account_number', $accName)
                          ->orWhere('account_number', $accountLogin);
                    })->first();
                
                if ($route && !empty($route->telegram_chat_id)) {
                    $targetChatId = $route->telegram_chat_id;
                    $accountLabel = $route->description ? $route->description : "Acc: {$accountLogin}";
                } else {
                    $accountLabel = "Acc: {$accountLogin}";
                }
            }

            // Only notify once — when we actually deleted the record (first webhook to arrive)
            if ($deleted > 0 && !empty($targetChatId)) {
                $msg = "<b>[🗑️ PENDING CANCELED]</b>\n";
                if ($accountLabel) $msg .= "👤 {$accountLabel}\n";
                $msg .= "Pair: <b>{$validated['symbol']}</b>\n";
                $msg .= "Ticket: {$validated['ticket_id']}\n";
                \App\Services\TelegramService::sendMessage($msg, $targetChatId);
            }

            Log::info("Webhook received: Pending order cancelled for ticket: " . $validated['ticket_id']);
            return response()->json(['message' => 'Pending order cancelled successfully'], 200);
        }

        // Save or Update to Database (State Machine: Pending -> Open -> Closed)
        try {
            $log = TradingLog::updateOrCreate(
                [
                    'user_id' => $user->id,
                    'ticket_id' => $validated['ticket_id'], // MT5 Order Ticket / Position ID
                ],
                [
                    'symbol' => $validated['symbol'],
                    'type' => $validated['type'],
                    'entry_price' => $validated['entry_price'] ?? 0,
                    'close_price' => $validated['close_price'] ?? 0,
                    'sl_price' => $validated['sl_price'] ?? 0,
                    'tp_price' => $validated['tp_price'] ?? 0,
                    'lot_size' => $validated['lot_size'] ?? 0,
                    'profit_loss' => $validated['profit_loss'] ?? 0,
                    'open_time' => $validated['open_time'] ?? null,
                    'close_time' => $validated['close_time'] ?? null,
                    'swap' => $validated['swap'] ?? 0,
                    'commission' => $validated['commission'] ?? 0,
                    'magic_number' => $validated['magic_number'] ?? '',
                    'comment' => $validated['comment'] ?? '',
                ]
            );

            // TELEGRAM NOTIFICATION
            $type = $validated['type'];
            $symbol = $validated['symbol'];
            $entry = $validated['entry_price'] ?? 0;
            $sl = $validated['sl_price'] ?? 0;
            $tp = $validated['tp_price'] ?? 0;
            $lot = $validated['lot_size'] ?? 0;
            $profit = $validated['profit_loss'] ?? 0;
            $bal = $user->balance ?? 0;

            // Determine target Telegram Chat ID based on Account Routing
            $targetChatId = $user->telegram_chat_id; // Fallback
            $accName = $validated['account_name'] ?? null;
            $accountLabel = '';

            if ($accName) {
                // EA sends "LoginNumber - ServerName". Extract numeric login part for matching.
                $accountLogin = trim(explode('-', $accName)[0]);

                $route = \App\Models\TelegramRouting::where('user_id', $user->id)
                    ->where(function($q) use ($accName, $accountLogin) {
                        $q->where('account_number', $accName)
                          ->orWhere('account_number', $accountLogin);
                    })->first();
                
                if ($route && !empty($route->telegram_chat_id)) {
                    $targetChatId = $route->telegram_chat_id;
                    $accountLabel = $route->description ? $route->description : "Acc: {$accountLogin}";
                } else {
                    $accountLabel = "Acc: {$accountLogin}";
                }
            }

            $msg = "";
            $typeUpper = strtoupper($type);

            // Match based on MT4's actual typeStr payload
            if (in_array($type, ['buy', 'sell'])) {
                $msg .= "<b>[🟢 ORDER OPENED]</b>\n";
                if ($accountLabel) $msg .= "👤 {$accountLabel}\n";
                $msg .= "Pair: <b>{$symbol}</b>\n";
                $msg .= "Type: {$typeUpper}\n";
                $msg .= "Lot: {$lot}\n";
                $msg .= "Entry: {$entry}\n";
                $msg .= "SL: {$sl} | TP: {$tp}\n";
            } elseif (in_array($type, ['buy_closed', 'sell_closed'])) {
                $msg .= "<b>[🏁 TRADE CLOSED]</b>\n";
                if ($accountLabel) $msg .= "👤 {$accountLabel}\n";
                $msg .= "Pair: <b>{$symbol}</b>\n";
                $msg .= "Type: {$typeUpper}\n";
                $msg .= "Lot: {$lot}\n";
                $msg .= "Close Price: " . ($validated['close_price'] ?? 0) . "\n";
                
                $sign = $profit >= 0 ? "+" : "-";
                $absProfit = abs($profit);
                $msg .= "Profit/Loss: {$sign} <b>$" . number_format($absProfit, 2) . "</b>\n";
                $msg .= "Balance: $" . number_format($bal, 2) . "\n";
            } elseif (in_array($type, ['buy_limit', 'sell_limit', 'buy_stop', 'sell_stop'])) {
                $msg .= "<b>[⌛ PENDING ORDER]</b>\n";
                if ($accountLabel) $msg .= "👤 {$accountLabel}\n";
                $msg .= "Pair: <b>{$symbol}</b>\n";
                $msg .= "Type: {$typeUpper}\n";
                $msg .= "Lot: {$lot}\n";
                $msg .= "Target Entry: {$entry}\n";
                $msg .= "SL: {$sl} | TP: {$tp}\n";
            }

            // DEDUPLICATE: Notify only on a real state change:
            // - wasRecentlyCreated → brand-new ticket (true first insert)
            // - wasChanged('type') → status transitioned (e.g. buy_limit → buy, buy → buy_closed)
            // Repeated webhooks with identical data will silently skip the notification.
            $shouldNotify = $log->wasRecentlyCreated || $log->wasChanged('type');

            if ($msg !== "" && !empty($targetChatId) && $shouldNotify) {
                \App\Services\TelegramService::sendMessage($msg, $targetChatId);
            }
            
            Log::info("Webhook received and saved for ticket: " . $validated['ticket_id']);
            return response()->json(['message' => 'Success', 'data' => $log], 201);
            
        } catch (\Exception $e) {
            Log::error("Failed to save webhook data: " . $e->getMessage());
            return response()->json(['message' => 'Error saving data', 'error' => $e->getMessage()], 500);
        }
    }

    /**
     * Display the specified resource.
     */
    public function show(string $id)
    {
        //
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, string $id)
    {
        //
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(string $id)
    {
        //
    }
}
