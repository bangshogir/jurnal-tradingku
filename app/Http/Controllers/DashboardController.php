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
        $allTrades = $allTradesQuery->get();

        // Calculate statistics based on all completed trades
        $totalTrades = $allTrades->count();
        $totalProfit = $allTrades->sum('profit_loss');
        
        // Calculate Win Rate based on positive profit_loss
        $winningTrades = $allTrades->where('profit_loss', '>', 0)->count();
        $winRate = $totalTrades > 0 ? round(($winningTrades / $totalTrades) * 100, 2) : 0;
        
        // Today calculations
        $todayStart = \Carbon\Carbon::today();
        
        // Trades closed today (using close_time from MT5 if available, fallback to created_at)
        $todayTradesList = $allTrades->filter(function($trade) use ($todayStart) {
            $dateToUse = $trade->close_time ? $trade->close_time : $trade->created_at;
            return $dateToUse >= $todayStart;
        });
        
        $todayTradesCount = $todayTradesList->count();
        $todayProfit = $todayTradesList->sum('profit_loss');
        
        // Real balance from MT5 (updated on each webhook event)
        $currentBalance = Auth::user()->balance;

        return view('dashboard', compact(
            'trades',
            'totalTrades',
            'totalProfit',
            'winRate',
            'todayTradesCount',
            'todayProfit',
            'currentBalance',
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
}
