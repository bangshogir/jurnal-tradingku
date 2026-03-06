<?php

namespace App\Http\Controllers;

use App\Models\TradingLog;
use App\Models\User;
use Illuminate\Http\Request;

class AdminController extends Controller
{
    public function index()
    {
        // Get all trades ordered by newest first from ALL users
        $trades = TradingLog::with('user')->orderBy('created_at', 'desc')->get();

        $totalUsers = User::where('role', '=', 'user')->count();
        $totalTrades = $trades->count();
        $totalProfit = $trades->sum('profit_loss');
        
        $winningTrades = $trades->where('profit_loss', '>', 0)->count();
        $winRate = $totalTrades > 0 ? round(($winningTrades / $totalTrades) * 100, 2) : 0;
        
        $todayStart = \Carbon\Carbon::today();
        
        $todayTradesList = $trades->filter(function($trade) use ($todayStart) {
            $dateToUse = $trade->close_time ? $trade->close_time : $trade->created_at;
            return $dateToUse >= $todayStart;
        });
        
        $todayTradesCount = $todayTradesList->count();
        $todayProfit = $todayTradesList->sum('profit_loss');

        return view('admin.dashboard', compact(
            'trades', 
            'totalUsers',
            'totalTrades', 
            'totalProfit', 
            'winRate',
            'todayTradesCount',
            'todayProfit'
        ));
    }
}
