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
        $sort = $request->query('sort', 'profit_desc');

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

        // Fetch all trades for calculation without pagination
        // (Pagination moved to history method)
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

        $totalHistoricalChange = 0;
        foreach ($allFinancialEvents as $t) {
            $totalHistoricalChange += ($t->profit_loss + $t->swap + $t->commission);
        }
        $currentBalance = Auth::user()->balance ?? 0;
        $initialBalance = $currentBalance - $totalHistoricalChange;

        // Calculate total net deposits (sum of deposits & withdrawals)
        $netDeposits = 0;
        foreach ($allFinancialEvents as $t) {
            if (in_array($t->type, ['deposit', 'withdrawal'])) {
                $netDeposits += ($t->profit_loss + $t->swap + $t->commission);
            }
        }
        $totalCapital = $initialBalance + $netDeposits;

        // Return on Investment Percentage (based on actual capital)
        // Adjust totalProfit to include swap and commission for accurate ROI
        $netProfit = $totalProfit + $allTradesQuery->sum('swap') + $allTradesQuery->sum('commission');
        $profitPct = $totalCapital > 0 ? round(($netProfit / $totalCapital) * 100, 2) : 0;

        $runningBalance = $initialBalance;
        $peakBalance    = $runningBalance;
        
        // Don't make lowestBalance the pre-deposit 0 state if possible
        $lowestBalance  = null; 
        $maxDrawdownAmt = 0;
        $allTimeHigh    = max(0, $runningBalance); // At least initial

        foreach ($allFinancialEvents as $t) {
            // Apply net change for this event
            $runningBalance += ($t->profit_loss + $t->swap + $t->commission);
            
            if ($lowestBalance === null) {
                // Initialize lowest balance after the first event (usually a deposit)
                $lowestBalance = $runningBalance;
            }

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
        
        if ($lowestBalance === null) $lowestBalance = $initialBalance;
        
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

        // --- NEW ANALYTICS SECTION ---
        
        // 1. Calendar Heatmap
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

        $dailyTrades = TradingLog::where('user_id', Auth::id())
            ->whereIn('type', ['buy_closed', 'sell_closed', 'other_closed'])
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

        // 2. Pair Stats (respects $dateFilter via $allTrades)
        $pairStatsCollection = collect();
        $groupedBySymbol = $allTrades->whereIn('type', ['buy_closed', 'sell_closed'])->groupBy('symbol');
        foreach ($groupedBySymbol as $symbol => $tradesGrp) {
            $wins = $tradesGrp->where('profit_loss', '>', 0)->count();
            $losses = $tradesGrp->where('profit_loss', '<=', 0)->count();
            $total_profit = $tradesGrp->sum('profit_loss');
            $pairStatsCollection->push((object)[
                'symbol' => $symbol,
                'wins' => $wins,
                'losses' => $losses,
                'total_profit' => $total_profit,
            ]);
        }

        switch ($sort) {
            case 'wins_desc':
                $pairStats = $pairStatsCollection->sortByDesc('wins')->values();
                break;
            case 'losses_desc':
                $pairStats = $pairStatsCollection->sortByDesc('losses')->values();
                break;
            case 'profit_asc':
                $pairStats = $pairStatsCollection->sortBy('total_profit')->values();
                break;
            case 'winrate_desc':
                $pairStats = $pairStatsCollection->sortByDesc(function ($item) {
                    $t = $item->wins + $item->losses;
                    return $t > 0 ? $item->wins / $t : 0;
                })->values();
                break;
            case 'profit_desc':
            default:
                $pairStats = $pairStatsCollection->sortByDesc('total_profit')->values();
                break;
        }

        // 3. Time Analytics (respects $dateFilter via $allTrades)
        $hourlyStats = [];
        for ($h = 0; $h < 24; $h++) {
            $hourlyStats[$h] = ['trades' => 0, 'wins' => 0, 'profit' => 0];
        }
        $sessions = [
            'Asia'     => ['label' => '🌏 Asia',     'range' => [7, 15],  'trades' => 0, 'wins' => 0, 'profit' => 0],
            'London'   => ['label' => '🇬🇧 London',   'range' => [15, 23], 'trades' => 0, 'wins' => 0, 'profit' => 0],
            'NewYork'  => ['label' => '🇺🇸 New York', 'range' => [20, 4],  'trades' => 0, 'wins' => 0, 'profit' => 0],
        ];

        foreach ($allTrades->whereIn('type', ['buy_closed', 'sell_closed']) as $t) {
            if (!$t->open_time) continue;
            
            $hour = \Carbon\Carbon::parse($t->open_time)->timezone('Asia/Jakarta')->hour;
            $pl   = $t->profit_loss;

            $hourlyStats[$hour]['trades']++;
            $hourlyStats[$hour]['profit'] += $pl;
            if ($pl > 0) $hourlyStats[$hour]['wins']++;

            foreach ($sessions as $key => &$session) {
                [$start, $end] = $session['range'];
                $inSession = ($start < $end)
                    ? ($hour >= $start && $hour < $end)
                    : ($hour >= $start || $hour < $end);
                if ($inSession) {
                    $session['trades']++;
                    $session['profit'] += $pl;
                    if ($pl > 0) $session['wins']++;
                }
            }
            unset($session);
        }

        $hourlyLabels  = array_map(fn($h) => str_pad($h, 2, '0', STR_PAD_LEFT) . ':00', range(0, 23));
        $hourlyWinRate = array_map(fn($s) => $s['trades'] > 0 ? round($s['wins'] / $s['trades'] * 100, 1) : 0, $hourlyStats);
        $hourlyProfit  = array_map(fn($s) => round($s['profit'], 2), $hourlyStats);
        $hourlyTrades  = array_map(fn($s) => $s['trades'], $hourlyStats);

        return view('dashboard', compact(
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
            'dateFilter',
            'dailyTrades', 'pairStats', 'startOfMonth', 'endOfMonth', 'prevMonth', 'nextMonth', 'sort',
            'hourlyLabels', 'hourlyWinRate', 'hourlyProfit', 'hourlyTrades', 'sessions'
        ));
    }

    public function history(Request $request)
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
            $query->whereIn('type', ['buy_closed', 'sell_closed', 'other_closed', 'pending_cancel']);
        }

        $trades = $query->orderByRaw('COALESCE(close_time, open_time, created_at) DESC')->paginate(15)->withQueryString();

        return view('history', compact('trades', 'filter', 'dateFilter'));
    }

    public function settings()
    {
        return view('settings');
    }

    public function reports(\Illuminate\Http\Request $request)
    {
        $userId = Auth::id();

        // Only keeping All-Time Deposit and Withdrawal
        $totalDeposit = TradingLog::where('user_id', $userId)->where('type', 'deposit')->sum('profit_loss');
        $totalWithdrawal = TradingLog::where('user_id', $userId)->where('type', 'withdrawal')->sum('profit_loss');

        return view('reports', compact('totalDeposit', 'totalWithdrawal'));
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

    public function dismissTrade(Request $request, $id)
    {
        $trade = TradingLog::where('user_id', Auth::id())->findOrFail($id);

        // Hanya izinkan dismiss untuk pending/open yang nyangkut (bukan history closed)
        $dismissible = ['buy', 'sell', 'buy_limit', 'sell_limit', 'buy_stop', 'sell_stop', 'unknown_pending'];
        if (!in_array($trade->type, $dismissible)) {
            return redirect()->back()->with('error', 'Trade ini tidak bisa dihapus manual.');
        }

        $trade->delete();
        return redirect()->back()->with('success', "Trade #{$trade->ticket_id} ({$trade->symbol}) berhasil dihapus dari jurnal.");
    }
}
