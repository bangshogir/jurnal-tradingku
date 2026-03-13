<?php

namespace App\Http\Controllers;

use App\Models\TradingLog;
use Illuminate\Http\Request;

use Illuminate\Support\Facades\Auth;

class DashboardController extends Controller
{
    public function index(Request $request)
    {
        $filter = $request->query('filter', 'all');
        $dateFilter = $request->query('date_filter', 'all_time');

        // Reusable date filter closure
        $applyDateFilter = function ($q) use ($dateFilter) {
            if ($dateFilter === 'all_time') return;

            $now = \Carbon\Carbon::now();
            $q->where(function ($query) use ($now, $dateFilter) {
                if ($dateFilter === 'today') {
                    $query->whereDate('close_time', $now->toDateString())
                        ->orWhere(function ($sub) use ($now) {
                            $sub->whereNull('close_time')->whereDate('created_at', $now->toDateString());
                        });
                } elseif ($dateFilter === 'last_7_days') {
                    $query->where('close_time', '>=', $now->copy()->subDays(7))
                        ->orWhere(function ($sub) use ($now) {
                            $sub->whereNull('close_time')->where('created_at', '>=', $now->copy()->subDays(7));
                        });
                } elseif ($dateFilter === 'last_30_days') {
                    $query->where('close_time', '>=', $now->copy()->subDays(30))
                        ->orWhere(function ($sub) use ($now) {
                            $sub->whereNull('close_time')->where('created_at', '>=', $now->copy()->subDays(30));
                        });
                } elseif ($dateFilter === 'this_month') {
                    $query->whereMonth('close_time', $now->month)->whereYear('close_time', $now->year)
                        ->orWhere(function ($sub) use ($now) {
                            $sub->whereNull('close_time')->whereMonth('created_at', $now->month)->whereYear('created_at', $now->year);
                        });
                } elseif ($dateFilter === 'last_month') {
                    $lastMonth = $now->copy()->subMonth();
                    $query->whereMonth('close_time', $lastMonth->month)->whereYear('close_time', $lastMonth->year)
                        ->orWhere(function ($sub) use ($lastMonth) {
                            $sub->whereNull('close_time')->whereMonth('created_at', $lastMonth->month)->whereYear('created_at', $lastMonth->year);
                        });
                } elseif ($dateFilter === 'this_year') {
                    $query->whereYear('close_time', $now->year)
                        ->orWhere(function ($sub) use ($now) {
                            $sub->whereNull('close_time')->whereYear('created_at', $now->year);
                        });
                }
            });
        };

        $query = TradingLog::where('user_id', Auth::id());
        $applyDateFilter($query);

        if ($filter === 'completed') {
            $query->whereIn('type', ['buy_closed', 'sell_closed', 'other_closed']);
        } elseif ($filter === 'cancelled') {
            $query->where('type', 'pending_cancel');
        } else {
            // 'all' includes both completed and cancelled history
            $query->whereIn('type', ['buy_closed', 'sell_closed', 'other_closed', 'pending_cancel']);
        }

        // 1. Sort by newest date (close_time first, fallback created_at)
        // 2. Paginate
        $trades = $query->orderByRaw('COALESCE(close_time, created_at) DESC')->paginate(10)->withQueryString();

        // Calculate statistics based on all completed trades within the date filter
        $allTradesQuery = TradingLog::where('user_id', Auth::id())
            ->whereIn('type', ['buy_closed', 'sell_closed', 'other_closed']);
        $applyDateFilter($allTradesQuery);
        // Order by close_time or created_at for accurate drawdown calculation
        $allTrades = $allTradesQuery->orderByRaw('COALESCE(close_time, created_at) ASC')->get();

        $totalTrades = $allTrades->count();
        $totalProfit = $allTrades->sum('profit_loss');
        
        // Win / Loss statistics
        $winningTrades = $allTrades->where('profit_loss', '>', 0)->count();
        $losingTrades  = $allTrades->where('profit_loss', '<', 0)->count();
        $winRate       = $totalTrades > 0 ? round(($winningTrades / $totalTrades) * 100, 2) : 0;
        
        // Profit percentage (Profit Factor: Gross Profit / Gross Loss)
        $grossProfit = $allTrades->where('profit_loss', '>', 0)->sum('profit_loss');
        $grossLoss   = abs($allTrades->where('profit_loss', '<', 0)->sum('profit_loss'));
        $profitPct   = ($grossProfit + $grossLoss) > 0 
            ? round(($grossProfit / ($grossProfit + $grossLoss)) * 100, 2) 
            : 0;

        // Max Drawdown & All Time High
        $cumulative  = 0;
        $peak        = 0;
        $maxDrawdown = 0;
        $allTimeHigh = 0;
        foreach ($allTrades as $t) {
            $cumulative += $t->profit_loss;
            if ($cumulative > $peak) {
                $peak = $cumulative;
            }
            $drawdown    = $peak - $cumulative;
            $maxDrawdown = max($maxDrawdown, $drawdown);
            $allTimeHigh = max($allTimeHigh, $cumulative);
        }
        
        // Today calculations
        $todayStart = \Carbon\Carbon::today();
        
        // Trades closed today
        $todayTradesList = $allTrades->filter(function($trade) use ($todayStart) {
            $dateToUse = $trade->close_time ? $trade->close_time : $trade->created_at;
            return $dateToUse >= $todayStart;
        });
        
        $todayTradesCount = $todayTradesList->count();
        $todayProfit = $todayTradesList->sum('profit_loss');
        
        // Chart: daily P&L for last 30 days (based on closed trades for this user)
        $chartData = [];
        for ($i = 29; $i >= 0; $i--) {
            $day = \Carbon\Carbon::today()->subDays($i);
            $dayProfit = $allTrades->filter(function ($t) use ($day) {
                $date = $t->close_time ?? $t->created_at;
                return $date && \Carbon\Carbon::parse($date)->isSameDay($day);
            })->sum('profit_loss');
            $chartData[] = [
                'date'   => $day->format('d M'),
                'profit' => round($dayProfit, 2),
            ];
        }

        // Real balance from MT5
        $currentBalance = Auth::user()->balance;

        return view('dashboard', compact(
            'trades',
            'totalTrades',
            'totalProfit',
            'winRate',
            'winningTrades',
            'losingTrades',
            'profitPct',
            'maxDrawdown',
            'allTimeHigh',
            'todayTradesCount',
            'todayProfit',
            'currentBalance',
            'chartData',
            'filter',
            'dateFilter'
        ));
    }

    public function pendingOrders()
    {
        // Get all pending orders (limit/stop) for the logged in user
        $trades = TradingLog::where('user_id', Auth::id())
            ->whereIn('type', ['buy_limit', 'sell_limit', 'buy_stop', 'sell_stop', 'unknown_pending'])
            ->orderBy('created_at', 'desc')
            ->get();
            
        return view('pending', compact('trades'));
    }

    public function openOrders()
    {
        // Get all running/open orders (buy/sell) for the logged in user
        $trades = TradingLog::where('user_id', Auth::id())
            ->whereIn('type', ['buy', 'sell']) // Usually "buy" or "sell" for open positions
            ->orderBy('created_at', 'desc')
            ->get();
            
        return view('open', compact('trades'));
    }

    public function updateTelegram(Request $request)
    {
        $request->validate([
            'telegram_chat_id' => 'nullable|string|max:50',
        ]);

        $user = auth()->user();
        $user->telegram_chat_id = $request->telegram_chat_id;
        $user->save();

        return redirect()->back()->with('success', 'Telegram Chat ID updated successfully.');
    }
}
