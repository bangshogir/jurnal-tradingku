@extends('layouts.admin')

@section('title', 'Reports')
@section('page-title', 'Trading Reports')
@section('page-subtitle', 'Analisa performa trading Anda (Proit/Loss Harian & Statistik Pair)')

@section('content')

    {{-- DEPOSIT & WITHDRAWAL STATS --}}
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 sm:gap-6 lg:gap-8 mb-8">
        <div class="bg-white rounded-2xl shadow-sm border border-slate-200 p-6 flex flex-col sm:flex-row items-start sm:items-center gap-4 sm:gap-6">
            <div class="w-12 h-12 bg-emerald-50 text-emerald-500 rounded-full flex items-center justify-center shrink-0">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path></svg>
            </div>
            <div>
                <p class="text-sm font-medium text-slate-500 mb-1">Total Deposit (All Time)</p>
                <h4 class="text-3xl font-bold text-slate-900">${{ number_format($totalDeposit, 2) }}</h4>
            </div>
        </div>
        
        <div class="bg-white rounded-2xl shadow-sm border border-slate-200 p-6 flex flex-col sm:flex-row items-start sm:items-center gap-4 sm:gap-6">
            <div class="w-12 h-12 bg-red-50 text-red-500 rounded-full flex items-center justify-center shrink-0">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 12H4"></path></svg>
            </div>
            <div>
                <p class="text-sm font-medium text-slate-500 mb-1">Total Withdrawal (All Time)</p>
                <h4 class="text-3xl font-bold text-slate-900">-${{ number_format(abs($totalWithdrawal), 2) }}</h4>
            </div>
        </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">

        {{-- CALENDAR HEATMAP --}}
        <div class="bg-white rounded-2xl shadow-sm border border-slate-200 p-6 overflow-hidden">
            <h3 class="text-lg font-bold text-slate-900 tracking-tight mb-6">Daily Profit/Loss ({{ $startOfMonth->format('F Y') }})</h3>
            
            @php
                $daysInMonth = $startOfMonth->daysInMonth;
                $firstDayOfWeek = $startOfMonth->dayOfWeekIso; // 1 (Mon) to 7 (Sun)
                $currentDay = 1;
            @endphp

            <div class="w-full">
                <div class="grid grid-cols-7 gap-1 sm:gap-2 mb-2">
                    <div class="text-center text-[10px] sm:text-xs font-semibold text-slate-500 uppercase tracking-wider">Mon</div>
                    <div class="text-center text-[10px] sm:text-xs font-semibold text-slate-500 uppercase tracking-wider">Tue</div>
                    <div class="text-center text-[10px] sm:text-xs font-semibold text-slate-500 uppercase tracking-wider">Wed</div>
                    <div class="text-center text-[10px] sm:text-xs font-semibold text-slate-500 uppercase tracking-wider">Thu</div>
                    <div class="text-center text-[10px] sm:text-xs font-semibold text-slate-500 uppercase tracking-wider">Fri</div>
                    <div class="text-center text-[10px] sm:text-xs font-semibold text-slate-500 uppercase tracking-wider">Sat</div>
                    <div class="text-center text-[10px] sm:text-xs font-semibold text-slate-500 uppercase tracking-wider">Sun</div>
                </div>

                <div class="grid grid-cols-7 gap-1 sm:gap-2">
                    {{-- Empty slots before the 1st of the month --}}
                    @for ($i = 1; $i < $firstDayOfWeek; $i++)
                        <div class="aspect-square bg-slate-50 rounded-lg"></div>
                    @endfor

                    {{-- Days of the month --}}
                    @for ($i = 1; $i <= $daysInMonth; $i++)
                        @php
                            $dateString = $startOfMonth->copy()->addDays($i - 1)->format('Y-m-d');
                            $profit = $dailyTrades[$dateString] ?? null;
                            
                            $bgColor = 'bg-slate-100 hover:bg-slate-200';
                            $textColor = 'text-slate-500';
                            $profitText = '-';

                            if (is_numeric($profit)) {
                                if ($profit > 0) {
                                    $bgColor = 'bg-emerald-100 hover:bg-emerald-200 border border-emerald-200';
                                    $textColor = 'text-emerald-700';
                                    $profitText = '+$' . number_format($profit, 2);
                                } elseif ($profit < 0) {
                                    $bgColor = 'bg-red-100 hover:bg-red-200 border border-red-200';
                                    $textColor = 'text-red-700';
                                    $profitText = '-$' . number_format(abs($profit), 2);
                                } else {
                                    $bgColor = 'bg-slate-200';
                                    $profitText = '$0.00';
                                }
                            }
                        @endphp
                        
                        <div class="{{ $bgColor }} aspect-square rounded-lg flex flex-col items-center justify-center p-1 sm:p-2 transition-colors relative group cursor-pointer">
                            <span class="text-xs sm:text-sm font-bold {{ $textColor }}">{{ $i }}</span>
                            <span class="text-[8px] sm:text-[10px] font-medium {{ $textColor }} mt-1 truncate w-full text-center">
                                {{ $profitText }}
                            </span>
                            
                            {{-- Tooltip for exact value --}}
                            @if(is_numeric($profit))
                            <div class="opacity-0 group-hover:opacity-100 transition-opacity absolute bottom-full left-1/2 -translate-x-1/2 mb-2 px-2 py-1 bg-slate-800 text-white text-[10px] rounded whitespace-nowrap z-10 pointer-events-none">
                                {{ $startOfMonth->copy()->addDays($i - 1)->format('d M') }}: {{ $profit >= 0 ? '+' : '-' }}${{ number_format(abs($profit), 2) }}
                                <svg class="absolute text-slate-800 h-2 w-full left-0 top-full" x="0px" y="0px" viewBox="0 0 255 255" xml:space="preserve"><polygon class="fill-current" points="0,0 127.5,127.5 255,0"/></svg>
                            </div>
                            @endif
                        </div>
                    @endfor
                </div>
            </div>
            
            <div class="mt-6 flex items-center justify-center gap-4 sm:gap-6 text-xs text-slate-500 font-medium">
                <div class="flex items-center gap-2">
                    <div class="w-3 h-3 rounded-sm bg-emerald-100 border border-emerald-200"></div> Profit
                </div>
                <div class="flex items-center gap-2">
                    <div class="w-3 h-3 rounded-sm bg-red-100 border border-red-200"></div> Loss
                </div>
                <div class="flex items-center gap-2">
                    <div class="w-3 h-3 rounded-sm bg-slate-100"></div> No Trades
                </div>
            </div>
        </div>

        {{-- PAIR STATS --}}
        <div class="bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden flex flex-col">
            <div class="p-6 border-b border-slate-100 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                <h3 class="text-lg font-bold text-slate-900 tracking-tight">Statistik Pair (Win/Loss)</h3>
                <form method="GET" action="{{ route('dashboard.reports') }}">
                    <div class="relative">
                        <select name="sort" onchange="this.form.submit()"
                            class="appearance-none bg-slate-50 border border-slate-200 text-slate-700 text-xs font-semibold px-4 py-2 pr-8 rounded-xl hover:bg-slate-100 transition-colors focus:outline-none focus:ring-2 focus:ring-brand-500 cursor-pointer">
                            <option value="profit_desc" {{ $sort === 'profit_desc' ? 'selected' : '' }}>Tertinggi P/L</option>
                            <option value="profit_asc" {{ $sort === 'profit_asc' ? 'selected' : '' }}>Terendah P/L</option>
                            <option value="wins_desc" {{ $sort === 'wins_desc' ? 'selected' : '' }}>Terbanyak Win</option>
                            <option value="losses_desc" {{ $sort === 'losses_desc' ? 'selected' : '' }}>Terbanyak Loss</option>
                            <option value="winrate_desc" {{ $sort === 'winrate_desc' ? 'selected' : '' }}>Tertinggi Win Rate</option>
                        </select>
                        <div class="pointer-events-none absolute inset-y-0 right-0 flex items-center px-2.5 text-slate-400">
                            <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 9l4-4 4 4m0 6l-4 4-4-4"></path>
                            </svg>
                        </div>
                    </div>
                </form>
            </div>
            
            <div class="flex-1 overflow-auto">
                <table class="w-full text-left border-collapse">
                    <thead>
                        <tr class="bg-slate-50/50 border-b border-slate-100 text-[11px] uppercase tracking-wider text-slate-500 font-semibold">
                            <th class="p-4 pl-6">Pair / Symbol</th>
                            <th class="p-4 text-center">Wins</th>
                            <th class="p-4 text-center">Losses</th>
                            <th class="p-4 text-center">Win Rate</th>
                            <th class="p-4 pr-6 text-right">Total P/L</th>
                        </tr>
                    </thead>
                    <tbody class="divide-y divide-slate-100">
                        @forelse($pairStats as $stat)
                            @php
                                $totalTrades = $stat->wins + $stat->losses;
                                $winRate = $totalTrades > 0 ? round(($stat->wins / $totalTrades) * 100) : 0;
                            @endphp
                            <tr class="hover:bg-slate-50/50 transition-colors">
                                <td class="p-4 pl-6 font-bold text-slate-900">
                                    {{ $stat->symbol }}
                                </td>
                                <td class="p-4 text-center font-medium text-emerald-600">
                                    {{ $stat->wins }}
                                </td>
                                <td class="p-4 text-center font-medium text-red-600">
                                    {{ $stat->losses }}
                                </td>
                                <td class="p-4 text-center">
                                    <div class="flex items-center justify-center gap-2">
                                        <span class="text-xs font-bold text-slate-700 w-8">{{ $winRate }}%</span>
                                        <div class="w-16 h-1.5 bg-slate-100 rounded-full overflow-hidden">
                                            <div class="h-full bg-brand-500 rounded-full" style="width: {{ $winRate }}%"></div>
                                        </div>
                                    </div>
                                </td>
                                <td class="p-4 pr-6 text-right font-bold {{ $stat->total_profit >= 0 ? 'text-emerald-500' : 'text-red-500' }}">
                                    {{ $stat->total_profit >= 0 ? '+' : '-' }}${{ number_format(abs($stat->total_profit), 2) }}
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="5" class="p-8 text-center text-slate-500">
                                    <div class="flex flex-col items-center justify-center gap-3">
                                        <svg class="w-10 h-10 text-slate-300" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"></path></svg>
                                        <p>Belum ada data untuk ditampilkan.</p>
                                    </div>
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>
        </div>

    </div>

@endsection
