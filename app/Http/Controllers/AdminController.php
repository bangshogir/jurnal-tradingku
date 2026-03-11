<?php

namespace App\Http\Controllers;

use App\Models\TradingLog;
use App\Models\User;
use Illuminate\Http\Request;
use Carbon\Carbon;

class AdminController extends Controller
{
    public function index()
    {
        // Get all trades ordered by newest first from ALL users
        $allTrades = TradingLog::with('user')->orderBy('created_at', 'desc')->get();

        // Only closed trades count for profit stats
        $closedTrades = $allTrades->filter(function ($t) {
            return $t->close_time !== null || str_contains(strtolower($t->type), 'closed');
        });

        $totalUsers  = User::where('role', 'user')->count();
        $totalTrades = $allTrades->count();
        $totalProfit = $closedTrades->sum('profit_loss');

        // Win / Loss counts
        $winCount  = $closedTrades->where('profit_loss', '>', 0)->count();
        $lossCount = $closedTrades->where('profit_loss', '<', 0)->count();
        $winRate   = ($winCount + $lossCount) > 0
            ? round(($winCount / ($winCount + $lossCount)) * 100, 2)
            : 0;

        // Profit factor: gross profit / gross loss
        $grossProfit = $closedTrades->where('profit_loss', '>', 0)->sum('profit_loss');
        $grossLoss   = abs($closedTrades->where('profit_loss', '<', 0)->sum('profit_loss'));
        $profitPct   = ($grossProfit + $grossLoss) > 0
            ? round(($grossProfit / ($grossProfit + $grossLoss)) * 100, 2)
            : 0;

        // Max Drawdown & All Time High (peak cumulative P&L)
        $sortedClosed = $closedTrades->sortBy(function ($t) {
            return $t->close_time ?? $t->created_at;
        });
        $cumulative  = 0;
        $peak        = 0;
        $maxDrawdown = 0;
        $allTimeHigh = 0;
        foreach ($sortedClosed as $t) {
            $cumulative += $t->profit_loss;
            if ($cumulative > $peak) {
                $peak = $cumulative;
            }
            $drawdown    = $peak - $cumulative;
            $maxDrawdown = max($maxDrawdown, $drawdown);
            $allTimeHigh = max($allTimeHigh, $cumulative);
        }

        // Today stats
        $todayStart = Carbon::today();
        $todayTradesList = $allTrades->filter(function ($t) use ($todayStart) {
            $date = $t->close_time ?? $t->created_at;
            return $date >= $todayStart;
        });
        $todayTradesCount = $todayTradesList->count();
        $todayProfit      = $todayTradesList->sum('profit_loss');

        // Chart: daily P&L for last 30 days (closed trades)
        $chartData = [];
        for ($i = 29; $i >= 0; $i--) {
            $day = Carbon::today()->subDays($i);
            $dayProfit = $closedTrades->filter(function ($t) use ($day) {
                $date = $t->close_time ?? $t->created_at;
                return $date && Carbon::parse($date)->isSameDay($day);
            })->sum('profit_loss');
            $chartData[] = [
                'date'   => $day->format('d M'),
                'profit' => round($dayProfit, 2),
            ];
        }

        $trades = $allTrades;

        return view('admin.dashboard', compact(
            'trades',
            'totalUsers',
            'totalTrades',
            'totalProfit',
            'winRate',
            'winCount',
            'lossCount',
            'profitPct',
            'maxDrawdown',
            'allTimeHigh',
            'todayTradesCount',
            'todayProfit',
            'chartData'
        ));
    }
}
