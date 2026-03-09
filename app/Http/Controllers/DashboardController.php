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

        $query = TradingLog::where('user_id', Auth::id());

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

        // Calculate statistics
        $allTrades = TradingLog::where('user_id', Auth::id())
            ->whereIn('type', ['buy_closed', 'sell_closed', 'other_closed'])
            ->get();

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
            'filter'
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
