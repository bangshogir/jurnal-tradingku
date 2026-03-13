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
        ]);

        // Update the user's balance from MT5 whenever data is received
        if (isset($validated['balance']) && $validated['balance'] > 0) {
            $user->balance = $validated['balance'];
            $user->save();
        }

        // Handle Canceled Pending Orders
        if ($validated['type'] === 'pending_cancel') {
            TradingLog::where('user_id', $user->id)
                ->where('ticket_id', $validated['ticket_id'])
                ->delete();
            
            $msg = "🗑️ <b>PENDING CANCELED</b> 🗑️\n";
            $msg .= "🏷️ Pair: <b>{$validated['symbol']}</b>\n";
            $msg .= "🎫 Ticket: {$validated['ticket_id']}\n";
            \App\Services\TelegramService::sendMessage($msg);

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

            $msg = "";
            if ($type === 'deal_open') {
                $msg .= "🚨 <b>NEW ORDER OPENED</b> 🚨\n";
                $msg .= "🏷️ Pair: <b>{$symbol}</b>\n";
                $msg .= "⚖️ Lot: {$lot}\n";
                $msg .= "🎯 Entry: {$entry}\n";
                $msg .= "🛑 SL: {$sl} | 💰 TP: {$tp}\n";
            } elseif ($type === 'deal_close') {
                $msg .= "🏁 <b>TRADE CLOSED</b> 🏁\n";
                $msg .= "🏷️ Pair: <b>{$symbol}</b>\n";
                $msg .= "⚖️ Lot: {$lot}\n";
                $msg .= "🚪 Close Price: " . ($validated['close_price'] ?? 0) . "\n";
                
                $emoji = $profit >= 0 ? "🟩" : "🟥";
                $msg .= "💲 Profit/Loss: {$emoji} <b>$" . number_format($profit, 2) . "</b>\n";
                $msg .= "💼 Balance: $" . number_format($bal, 2) . "\n";
            } elseif ($type === 'pending_order') {
                $msg .= "⏳ <b>PENDING ORDER PLACED</b> ⏳\n";
                $msg .= "🏷️ Pair: <b>{$symbol}</b>\n";
                $msg .= "⚖️ Lot: {$lot}\n";
                $msg .= "🎯 Target Entry: {$entry}\n";
                $msg .= "🛑 SL: {$sl} | 💰 TP: {$tp}\n";
            }

            if ($msg !== "") {
                \App\Services\TelegramService::sendMessage($msg);
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
