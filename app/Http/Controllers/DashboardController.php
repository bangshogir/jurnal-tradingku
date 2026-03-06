<?php

namespace App\Http\Controllers;

use App\Models\TradingLog;
use Illuminate\Http\Request;

use Illuminate\Support\Facades\Auth;

class DashboardController extends Controller
{
    public function index()
    {
        // Get all closed trades ordered by newest first, strictly constrained to the logged in user
        $trades = TradingLog::where('user_id', '=', Auth::id())
            ->whereIn('type', ['buy_closed', 'sell_closed', 'other_closed'])
            ->orderBy('created_at', 'desc')
            ->get();

        // Calculate statistics
        $totalTrades = $trades->count();
        $totalProfit = $trades->sum('profit_loss');
        
        // Calculate Win Rate based on positive profit_loss
        $winningTrades = $trades->where('profit_loss', '>', 0)->count();
        $winRate = $totalTrades > 0 ? round(($winningTrades / $totalTrades) * 100, 2) : 0;
        
        // Today calculations
        $todayStart = \Carbon\Carbon::today();
        
        // Trades closed today (using close_time from MT5 if available, fallback to created_at)
        $todayTradesList = $trades->filter(function($trade) use ($todayStart) {
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
            'currentBalance'
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
