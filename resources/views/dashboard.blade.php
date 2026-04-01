@extends('layouts.admin')

@section('title', 'Dashboard')
@section('page-title', 'Dashboard Overview')
@section('page-subtitle', 'Ringkasan data trading Anda hari ini')

@section('content')


    {{-- Header title for overview --}}
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-4">
        <h2 class="text-lg font-bold text-slate-900 tracking-tight">Overview</h2>
        <form method="GET" action="{{ route('dashboard') }}" class="flex gap-2 items-center">
            @if (request('filter'))
                <input type="hidden" name="filter" value="{{ request('filter') }}">
            @endif
            <div class="relative">
                <select name="date_filter" onchange="this.form.submit()"
                    class="appearance-none bg-white border border-slate-200 text-slate-700 text-[12px] font-semibold px-4 py-2 pr-9 rounded-xl hover:bg-slate-50 transition-colors shadow-sm focus:outline-none focus:ring-2 focus:ring-brand-500 cursor-pointer">
                    <option value="today" {{ $dateFilter === 'today' ? 'selected' : '' }}>Today</option>
                    <option value="last_7_days" {{ $dateFilter === 'last_7_days' ? 'selected' : '' }}>Last 7 Days</option>
                    <option value="last_30_days" {{ $dateFilter === 'last_30_days' ? 'selected' : '' }}>Last 30 Days
                    </option>
                    <option value="this_month" {{ $dateFilter === 'this_month' ? 'selected' : '' }}>This Month</option>
                    <option value="last_month" {{ $dateFilter === 'last_month' ? 'selected' : '' }}>Last Month</option>
                    <option value="this_year" {{ $dateFilter === 'this_year' ? 'selected' : '' }}>This Year</option>
                    <option value="all_time" {{ $dateFilter === 'all_time' ? 'selected' : '' }}>All Time</option>
                </select>
                <div class="pointer-events-none absolute inset-y-0 right-0 flex items-center px-2.5 text-slate-400">
                    <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
                    </svg>
                </div>
            </div>
        </form>
    </div>

    {{-- Modern Stat Cards --}}
    <dl class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4 mb-8">
        @php
            $cards = [
                [
                    'label' => 'Total Profit/Loss',
                    'value' => ($totalProfit >= 0 ? '$' : '-$') . number_format(abs($totalProfit), 2),
                    'change' => ($todayProfit >= 0 ? '+' : '') . '$' . number_format($todayProfit, 2),
                    'changeColor' => $todayProfit >= 0 ? 'text-emerald-500' : 'text-red-500',
                    'subtext' => 'profit today',
                    'icon' =>
                        '<svg class="w-5 h-5 text-brand-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>',
                    'valColor' => $totalProfit >= 0 ? 'text-slate-900' : 'text-red-500',
                ],
                [
                    'label' => 'Win Rate',
                    'value' => $winRate . '%',
                    'change' => '',
                    'changeColor' => 'text-emerald-500',
                    'subtext' => 'overall',
                    'icon' =>
                        '<svg class="w-5 h-5 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"></path></svg>',
                    'valColor' => 'text-slate-900',
                ],
                [
                    'label' => 'Total Trades',
                    'value' => number_format($totalTrades),
                    'change' => '+' . number_format($todayTradesCount),
                    'changeColor' => 'text-blue-500',
                    'subtext' => 'trades today',
                    'icon' =>
                        '<svg class="w-5 h-5 text-indigo-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"></path></svg>',
                    'valColor' => 'text-slate-900',
                ],
                [
                    'label' => 'Current Balance',
                    'value' => '$' . number_format($currentBalance, 2),
                    'change' => '',
                    'changeColor' => 'text-emerald-500',
                    'subtext' => 'Modal: $' . number_format($totalCapital ?? 0, 2),
                    'icon' =>
                        '<svg class="w-5 h-5 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z"></path></svg>',
                    'valColor' => 'text-slate-900',
                ],
                [
                    'label' => 'Win / Loss',
                    'value' => ($winningTrades ?? 0) . ' / ' . ($losingTrades ?? 0),
                    'change' => '',
                    'changeColor' => 'text-slate-500',
                    'subtext' => 'trades count',
                    'icon' =>
                        '<svg class="w-5 h-5 text-teal-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>',
                    'valColor' => 'text-slate-900',
                ],
                [
                    'label' => 'Return on Investment',
                    'value' => ($profitPct >= 0 ? '+' : '') . ($profitPct ?? 0) . '%',
                    'change' => '',
                    'changeColor' => 'text-emerald-500',
                    'subtext' => 'from total capital',
                    'icon' =>
                        '<svg class="w-5 h-5 text-amber-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"></path></svg>',
                    'valColor' => 'text-slate-900',
                ],
                [
                    'label' => 'Lowest Balance',
                    'value' => '$' . number_format($lowestBalance ?? 0, 2),
                    'change' => '',
                    'changeColor' => 'text-slate-500',
                    'subtext' => 'min balance reached',
                    'icon' =>
                        '<svg class="w-5 h-5 text-rose-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 17h8m0 0V9m0 8l-8-8-4 4-6-6"></path></svg>',
                    'valColor' => 'text-slate-900',
                ],
                [
                    'label' => 'All Time High',
                    'value' => '+$' . number_format($allTimeHigh ?? 0, 2),
                    'change' => '',
                    'changeColor' => 'text-emerald-500',
                    'subtext' => 'peak profit',
                    'icon' =>
                        '<svg class="w-5 h-5 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 10l7-7m0 0l7 7m-7-7v18"></path></svg>',
                    'valColor' => 'text-emerald-600',
                ],
            ];
        @endphp

        @foreach ($cards as $card)
            <div
                class="bg-white rounded-2xl p-5 shadow-sm border border-slate-100 hover:shadow-md transition-shadow duration-200">
                <div class="flex items-center gap-2 mb-3">
                    <div class="p-2 bg-slate-50 rounded-lg">
                        {!! $card['icon'] !!}
                    </div>
                    <span class="text-xs font-semibold text-slate-500">{{ $card['label'] }}</span>
                    <button class="ml-auto text-slate-300 hover:text-slate-500">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                        </svg>
                    </button>
                </div>
                <div class="mt-4">
                    <p class="text-2xl sm:text-3xl font-bold {{ $card['valColor'] }} tracking-tight shadow-sm-text">
                        {{ $card['value'] }}
                    </p>
                    <p class="text-[11px] font-medium mt-1 flex items-center gap-1.5 min-h-[16px]">
                        @if ($card['change'])
                            <span class="{{ $card['changeColor'] }}">{{ $card['change'] }}</span>
                        @endif
                        <span class="text-slate-400">{{ $card['subtext'] }}</span>
                    </p>
                </div>
            </div>
        @endforeach
    </dl>


    {{-- Trade History Table / Last Sales style --}}
    <div class="mb-4 flex items-center justify-between">
        <h2 class="text-lg font-bold text-slate-900 tracking-tight">Trade History</h2>
        <div class="flex gap-2">
            <button
                class="bg-white border border-slate-200 text-slate-600 text-[11px] font-medium px-3 py-1.5 rounded-lg hover:bg-slate-50 transition-colors shadow-sm">View
                all</button>
            <button
                class="bg-white border border-slate-200 text-slate-600 text-[11px] font-medium px-3 py-1.5 rounded-lg hover:bg-slate-50 transition-colors flex items-center gap-1.5 shadow-sm">
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                        d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12"></path>
                </svg>
                Export
            </button>
        </div>
    </div>

    {{-- Tabs --}}
    <div class="flex gap-6 border-b border-slate-200 mb-6 text-sm font-semibold text-slate-500">
        <a href="{{ route('dashboard', ['filter' => 'all', 'date_filter' => $dateFilter]) }}"
            class="pb-3 border-b-2 {{ $filter === 'all' ? 'border-brand-600 text-brand-600' : 'border-transparent hover:text-slate-800 hover:border-slate-300 transition-colors' }}">
            All trades
        </a>
        <a href="{{ route('dashboard', ['filter' => 'completed', 'date_filter' => $dateFilter]) }}"
            class="pb-3 border-b-2 {{ $filter === 'completed' ? 'border-brand-600 text-brand-600' : 'border-transparent hover:text-slate-800 hover:border-slate-300 transition-colors' }}">
            Completed
        </a>
        <a href="{{ route('dashboard', ['filter' => 'cancelled', 'date_filter' => $dateFilter]) }}"
            class="pb-3 border-b-2 {{ $filter === 'cancelled' ? 'border-brand-600 text-brand-600' : 'border-transparent hover:text-slate-800 hover:border-slate-300 transition-colors' }}">
            Cancelled
        </a>
    </div>

    <div class="bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden">
        <div class="overflow-x-auto">
            <table class="min-w-full text-sm">
                <thead
                    class="bg-white text-[11px] text-slate-400 font-semibold tracking-wider uppercase border-b border-slate-100">
                    <tr>
                        <th class="px-6 py-4 text-left font-medium">Ticket / Pair</th>
                        <th class="px-6 py-4 text-left font-medium">Date</th>
                        <th class="px-6 py-4 text-left font-medium">Type</th>
                        <th class="px-6 py-4 text-left font-medium">Lot</th>
                        <th class="px-6 py-4 text-left font-medium">Price</th>
                        <th class="px-6 py-4 text-left font-medium">P/L</th>
                        <th class="px-6 py-4 text-left font-medium">Status</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-slate-50">
                    @forelse ($trades as $trade)
                        <tr class="hover:bg-slate-50/50 transition-colors duration-150">
                            <td class="px-6 py-4 whitespace-nowrap">
                                <div class="flex items-center gap-3">
                                    <input type="checkbox"
                                        class="rounded border-slate-300 text-brand-600 focus:ring-brand-500">
                                    <div>
                                        <p class="font-semibold text-slate-800 tracking-tight">{{ $trade->symbol }}</p>
                                        <p class="text-[11px] text-slate-400">#{{ $trade->ticket_id }}</p>
                                    </div>
                                </div>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-slate-500">
                                {{ $trade->open_time ? $trade->open_time->format('d M Y') : '-' }}
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap">
                                @php
                                    $typeStr = strtolower($trade->type);
                                    $typeLabel = str_replace('_', ' ', $typeStr);
                                    $isBuy = str_contains($typeStr, 'buy');
                                    $isSell = str_contains($typeStr, 'sell');
                                    $badgeClass = $isBuy
                                        ? 'text-blue-700 bg-blue-50 border-blue-200'
                                        : ($isSell
                                            ? 'text-rose-700 bg-rose-50 border-rose-200'
                                            : 'text-slate-700 bg-slate-50 border-slate-200');
                                @endphp
                                <span
                                    class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-semibold border {{ $badgeClass }} capitalize">
                                    {{ $typeLabel }}
                                </span>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-slate-500 font-mono text-[12px]">
                                {{ number_format($trade->lot_size, 2) }}
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap font-mono text-[12px] text-slate-600">
                                {{ number_format($trade->entry_price, 5) }}
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap font-semibold">
                                @if ($trade->profit_loss >= 0)
                                    <span class="text-emerald-500">+${{ number_format($trade->profit_loss, 2) }}</span>
                                @else
                                    <span class="text-red-500">-${{ number_format(abs($trade->profit_loss), 2) }}</span>
                                @endif
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap">
                                <div class="flex items-center gap-2">
                                    <span
                                        class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-emerald-50 text-emerald-600 font-semibold text-[11px] border border-emerald-100">
                                        <span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span> Completed
                                    </span>
                                    <button class="text-slate-400 hover:text-slate-600">
                                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                                d="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z">
                                            </path>
                                        </svg>
                                    </button>
                                </div>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="7" class="px-6 py-20 text-center">
                                <div class="flex flex-col items-center justify-center">
                                    <div class="w-16 h-16 bg-slate-50 rounded-full flex items-center justify-center mb-3">
                                        <svg class="w-8 h-8 text-slate-300" fill="none" stroke="currentColor"
                                            viewBox="0 0 24 24">
                                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                                d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z">
                                            </path>
                                        </svg>
                                    </div>
                                    <p class="font-semibold text-slate-700">No trades yet</p>
                                    <p class="text-sm text-slate-400 mt-1 max-w-sm">When your EA executes a trade, it will
                                        automatically appear here synced via Webhook.</p>
                                </div>
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        @if ($trades->hasPages())
            <div class="px-6 py-4 border-t border-slate-100 bg-white">
                {{ $trades->links('pagination::tailwind') }}
            </div>
        @endif
    </div>

@endsection
