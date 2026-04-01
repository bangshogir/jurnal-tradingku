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
                            $sub->whereNull('close_time')->whereDate('open_time', $now->toDateString())
                                ->orWhere(function ($sub2) use ($now) {
                                    $sub2->whereNull('close_time')->whereNull('open_time')->whereDate('created_at', $now->toDateString());
                                });
                        });
                } elseif ($dateFilter === 'last_7_days') {
                    $query->where('close_time', '>=', $now->copy()->subDays(7))
                        ->orWhere(function ($sub) use ($now) {
                            $sub->whereNull('close_time')->where('open_time', '>=', $now->copy()->subDays(7))
                                ->orWhere(function ($sub2) use ($now) {
                                    $sub2->whereNull('close_time')->whereNull('open_time')->where('created_at', '>=', $now->copy()->subDays(7));
                                });
                        });
                } elseif ($dateFilter === 'last_30_days') {
                    $query->where('close_time', '>=', $now->copy()->subDays(30))
                        ->orWhere(function ($sub) use ($now) {
                            $sub->whereNull('close_time')->where('open_time', '>=', $now->copy()->subDays(30))
                                ->orWhere(function ($sub2) use ($now) {
                                    $sub2->whereNull('close_time')->whereNull('open_time')->where('created_at', '>=', $now->copy()->subDays(30));
                                });
                        });
                } elseif ($dateFilter === 'this_month') {
                    $query->whereMonth('close_time', $now->month)->whereYear('close_time', $now->year)
                        ->orWhere(function ($sub) use ($now) {
                            $sub->whereNull('close_time')->whereMonth('open_time', $now->month)->whereYear('open_time', $now->year)
                                ->orWhere(function ($sub2) use ($now) {
                                    $sub2->whereNull('close_time')->whereNull('open_time')->whereMonth('created_at', $now->month)->whereYear('created_at', $now->year);
                                });
                        });
                } elseif ($dateFilter === 'last_month') {
                    $lastMonth = $now->copy()->subMonth();
                    $query->whereMonth('close_time', $lastMonth->month)->whereYear('close_time', $lastMonth->year)
                        ->orWhere(function ($sub) use ($lastMonth) {
                            $sub->whereNull('close_time')->whereMonth('open_time', $lastMonth->month)->whereYear('open_time', $lastMonth->year)
                                ->orWhere(function ($sub2) use ($lastMonth) {
                                    $sub2->whereNull('close_time')->whereNull('open_time')->whereMonth('created_at', $lastMonth->month)->whereYear('created_at', $lastMonth->year);
                                });
                        });
                } elseif ($dateFilter === 'this_year') {
                    $query->whereYear('close_time', $now->year)
                        ->orWhere(function ($sub) use ($now) {
                            $sub->whereNull('close_time')->whereYear('open_time', $now->year)
                                ->orWhere(function ($sub2) use ($now) {
                                    $sub2->whereNull('close_time')->whereNull('open_time')->whereYear('created_at', $now->year);
                                });
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

        // 1. Sort by newest date (close_time first, fallback open_time, then created_at)
        // 2. Paginate
        $trades = $query->orderByRaw('COALESCE(close_time, open_time, created_at) DESC')->paginate(10)->withQueryString();

        // Calculate statistics based on all completed trades within the date filter
        $allTradesQuery = TradingLog::where('user_id', Auth::id())
            ->whereIn('type', ['buy_closed', 'sell_closed', 'other_closed']);
        $applyDateFilter($allTradesQuery);
        // Order by close_time or open_time or created_at for accurate drawdown calculation
        $allTrades = $allTradesQuery->orderByRaw('COALESCE(close_time, open_time, created_at) ASC')->get();

        $totalTrades = $allTrades->count();
        $totalProfit = $allTrades->sum('profit_loss');
        
        // Win / Loss statistics
        $winningTrades = $allTrades->where('profit_loss', '>', 0)->count();
        $losingTrades  = $allTrades->where('profit_loss', '<', 0)->count();
        $winRate       = $totalTrades > 0 ? round(($winningTrades / $totalTrades) * 100, 2) : 0;
        
        // Calculate Max Drawdown & All Time High based on REAL balance history
        $allFinancialEvents = TradingLog::where('user_id', Auth::id())
            ->whereIn('type', ['buy_closed', 'sell_closed', 'other_closed', 'deposit', 'withdrawal'])
            ->orderByRaw('COALESCE(close_time, open_time, created_at) ASC')
            ->get();

        $totalHistoricalChange = $allFinancialEvents->sum('profit_loss');
        $currentBalance = Auth::user()->balance ?? 0;
        $initialBalance = $currentBalance - $totalHistoricalChange;

        // Calculate total net deposits (sum of deposits & withdrawals)
        $netDeposits = $allFinancialEvents->whereIn('type', ['deposit', 'withdrawal'])->sum('profit_loss');
        $totalCapital = $initialBalance + $netDeposits;

        // Return on Investment Percentage (based on actual capital)
        $profitPct = $totalCapital > 0 ? round(($totalProfit / $totalCapital) * 100, 2) : 0;

        $runningBalance = $initialBalance;
        $peakBalance    = $runningBalance;
        $lowestBalance  = $runningBalance;
        $maxDrawdownAmt = 0;
        $allTimeHigh    = max(0, $runningBalance); // At least initial

        foreach ($allFinancialEvents as $t) {
            $runningBalance += $t->profit_loss;
            if ($runningBalance > $peakBalance) {
                $peakBalance = $runningBalance;
            }
            if ($runningBalance < $lowestBalance) {
                $lowestBalance = $runningBalance;
            }
            $drawdownAmt = $peakBalance - $runningBalance;
            $maxDrawdownAmt = max($maxDrawdownAmt, $drawdownAmt);
            $allTimeHigh = max($allTimeHigh, $runningBalance);
        }
        $maxDrawdown = round($maxDrawdownAmt, 2);
        $lowestBalance = round($lowestBalance, 2);
        $allTimeHigh = round($allTimeHigh, 2);
        
        // Today calculations
        $todayStart = \Carbon\Carbon::today();
        
        // Trades closed today
        $todayTradesList = $allTrades->filter(function($trade) use ($todayStart) {
            $dateToUse = $trade->close_time ?? $trade->open_time;
            if (!$dateToUse && in_array($trade->type, ['buy_closed', 'sell_closed', 'other_closed'])) {
                return false; // Prevent missing-date historical trades from showing up as today
            }
            $dateToUse = $dateToUse ?? $trade->created_at;
            return $dateToUse >= $todayStart;
        });
        
        $todayTradesCount = $todayTradesList->count();
        $todayProfit = $todayTradesList->sum('profit_loss');
        
        // Chart: daily P&L for last 30 days (based on closed trades for this user)
        $chartData = [];
        for ($i = 29; $i >= 0; $i--) {
            $day = \Carbon\Carbon::today()->subDays($i);
            $dayProfit = $allTrades->filter(function ($t) use ($day) {
                $date = $t->close_time ?? $t->open_time;
                if (!$date && in_array($t->type, ['buy_closed', 'sell_closed', 'other_closed'])) {
                    return false; // Skip closed trades with missing dates (same as todayTradesList)
                }
                $date = $date ?? $t->created_at;
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
            'lowestBalance',
            'allTimeHigh',
            'todayTradesCount',
            'todayProfit',
            'currentBalance',
            'initialBalance',
            'totalCapital',
            'chartData',
            'filter',
            'dateFilter'
        ));
    }

    public function settings()
    {
        $telegramRoutings = \App\Models\TelegramRouting::where('user_id', Auth::id())->get();
        return view('settings', compact('telegramRoutings'));
    }

    public function reports(\Illuminate\Http\Request $request)
    {
        $userId = Auth::id();

        // 1. Daily Profit/Loss for requested month (default: current)
        $month = $request->input('month', now()->month);
        $year = $request->input('year', now()->year);

        try {
            $baseDate = \Carbon\Carbon::createFromDate($year, $month, 1);
        } catch (\Exception $e) {
            $baseDate = now();
        }

        $startOfMonth = $baseDate->copy()->startOfMonth();
        $endOfMonth = $baseDate->copy()->endOfMonth();

        $prevMonth = $baseDate->copy()->subMonth();
        $nextMonth = $baseDate->copy()->addMonth();

        $dailyTrades = TradingLog::where('user_id', $userId)
            ->whereIn('type', ['buy_closed', 'sell_closed'])
            ->where(function ($query) use ($startOfMonth, $endOfMonth) {
                $query->whereBetween('close_time', [$startOfMonth, $endOfMonth])
                      ->orWhere(function ($sub) use ($startOfMonth, $endOfMonth) {
                          $sub->whereNull('close_time')->whereBetween('open_time', [$startOfMonth, $endOfMonth]);
                      })
                      ->orWhere(function ($sub) use ($startOfMonth, $endOfMonth) {
                          $sub->whereNull('close_time')->whereNull('open_time')->whereBetween('created_at', [$startOfMonth, $endOfMonth]);
                      });
            })
            ->selectRaw('DATE(COALESCE(close_time, open_time, created_at)) as date, SUM(profit_loss) as total_profit')
            ->groupBy('date')
            ->get()
            ->keyBy('date')
            ->map(function ($item) {
                return $item->total_profit;
            })->toArray();

        $pairStatsQuery = TradingLog::where('user_id', $userId)
            ->whereIn('type', ['buy_closed', 'sell_closed'])
            ->selectRaw('symbol, 
                SUM(CASE WHEN profit_loss > 0 THEN 1 ELSE 0 END) as wins, 
                SUM(CASE WHEN profit_loss <= 0 THEN 1 ELSE 0 END) as losses,
                SUM(profit_loss) as total_profit')
            ->groupBy('symbol');

        // Apply sorting based on request
        $sort = $request->input('sort', 'profit_desc'); // default sort
        
        switch ($sort) {
            case 'wins_desc':
                $pairStatsQuery->orderByDesc('wins');
                break;
            case 'losses_desc':
                $pairStatsQuery->orderByDesc('losses');
                break;
            case 'profit_asc':
                $pairStatsQuery->orderBy('total_profit', 'asc');
                break;
            case 'winrate_desc':
                // (wins / (wins+losses)) sorting logic can't easily be done directly in eloquent 
                // but we can sort by raw expression
                $pairStatsQuery->orderByRaw('(SUM(CASE WHEN profit_loss > 0 THEN 1 ELSE 0 END) / COUNT(*)) DESC');
                break;
            case 'profit_desc':
            default:
                $pairStatsQuery->orderByDesc('total_profit');
                break;
        }

        $pairStats = $pairStatsQuery->get();

        // 3. Deposit & Withdrawal (All-Time)
        $totalDeposit = TradingLog::where('user_id', $userId)->where('type', 'deposit')->sum('profit_loss');
        $totalWithdrawal = TradingLog::where('user_id', $userId)->where('type', 'withdrawal')->sum('profit_loss');

        return view('reports', compact('dailyTrades', 'pairStats', 'startOfMonth', 'endOfMonth', 'prevMonth', 'nextMonth', 'sort', 'totalDeposit', 'totalWithdrawal'));
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
