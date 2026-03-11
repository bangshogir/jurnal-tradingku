@extends('layouts.admin')

@section('title', 'Dashboard')
@section('page-title', 'Dashboard Overview')
@section('page-subtitle', 'Ringkasan data trading Anda hari ini')

@section('content')

    {{-- Webhook Token Banner (Modern Purple Gradient) --}}
    <div
        class="mb-8 bg-gradient-to-r from-brand-500 to-indigo-500 rounded-2xl p-6 sm:p-8 flex flex-col sm:flex-row sm:items-center justify-between gap-6 relative overflow-hidden shadow-lg shadow-brand-500/20">
        <!-- Decoration element -->
        <div
            class="absolute top-0 right-0 -mt-4 -mr-4 w-32 h-32 bg-white opacity-10 rounded-full blur-2xl pointer-events-none">
        </div>
        <div class="absolute bottom-0 left-1/4 w-24 h-24 bg-white opacity-10 rounded-full blur-xl pointer-events-none"></div>

        <div class="relative z-10 w-full md:w-auto">
            <span
                class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-white/20 text-white text-[11px] font-semibold tracking-wide uppercase mb-3 backdrop-blur-sm shadow-sm border border-white/10">
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z">
                    </path>
                </svg>
                EA Integration
            </span>
            <h3 class="font-bold text-white text-xl md:text-2xl tracking-tight mb-2">
                Webhook API Token
            </h3>
            <p class="text-indigo-100 text-sm md:text-base max-w-xl leading-relaxed">
                Connect your MetaTrader 5 Expert Advisor to automatically sync trades in real-time.
            </p>
        </div>
        <div class="relative z-10 flex flex-col sm:flex-row sm:items-center gap-3 w-full sm:w-auto mt-2 sm:mt-0">
            <div
                class="bg-white/10 px-5 py-3.5 rounded-xl border border-white/20 font-mono text-sm text-white shadow-inner flex-1 flex items-center justify-between backdrop-blur-sm min-w-[280px]">
                <div>
                    <span id="token-hidden" class="tracking-widest opacity-80">••••••••••••••••••••••••</span>
                    <span id="token-visible" class="hidden select-all">{{ auth()->user()->webhook_token }}</span>
                </div>
                <button
                    onclick="document.getElementById('token-hidden').classList.toggle('hidden'); document.getElementById('token-visible').classList.toggle('hidden');"
                    class="text-white/60 hover:text-white transition-colors ml-4 focus:outline-none"
                    title="Show/Hide Token">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                            d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                            d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z">
                        </path>
                    </svg>
                </button>
            </div>
            <button
                onclick="navigator.clipboard.writeText('{{ auth()->user()->webhook_token }}'); alert('Token berhasil disalin!');"
                class="bg-white hover:bg-slate-50 text-brand-600 px-6 py-3.5 rounded-xl text-sm font-semibold transition-all shadow-sm flex items-center justify-center gap-2 whitespace-nowrap">
                Copy Token
            </button>
        </div>
    </div>

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

    {{-- ==================== STAT CARDS ROW 1 ==================== --}}
    <div class="grid grid-cols-2 gap-3 mb-3">
        {{-- Total Users (hidden from normal users, shown here as placeholder or we can use another stat) --}}
        <div class="bg-white rounded-2xl p-4 border border-slate-100 shadow-sm">
            <div class="flex items-center gap-2 mb-2.5">
                <div class="w-8 h-8 bg-blue-50 rounded-lg flex items-center justify-center shrink-0">
                    <svg class="w-4 h-4 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/></svg>
                </div>
                <span class="text-[10.5px] font-bold text-slate-400 uppercase tracking-wider">Total Trades</span>
            </div>
            <p class="text-2xl font-extrabold text-slate-800 leading-none">{{ number_format($totalTrades) }}</p>
        </div>

        {{-- Current Balance --}}
        <div class="bg-white rounded-2xl p-4 border border-slate-100 shadow-sm">
            <div class="flex items-center gap-2 mb-2.5">
                <div class="w-8 h-8 bg-slate-50 rounded-lg flex items-center justify-center shrink-0">
                    <svg class="w-4 h-4 text-slate-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z"/></svg>
                </div>
                <span class="text-[10.5px] font-bold text-slate-400 uppercase tracking-wider">Balance</span>
            </div>
            <p class="text-2xl font-extrabold text-slate-800 leading-none">${{ number_format($currentBalance, 2) }}</p>
        </div>
    </div>

    {{-- ==================== STAT CARDS ROW 2 ==================== --}}
    <div class="grid grid-cols-2 gap-3 mb-3">
        {{-- Win Count --}}
        <div class="bg-white rounded-2xl p-4 border border-slate-100 shadow-sm">
            <div class="flex items-center gap-2 mb-2.5">
                <div class="w-8 h-8 bg-emerald-50 rounded-lg flex items-center justify-center shrink-0">
                    <svg class="w-4 h-4 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                </div>
                <span class="text-[10.5px] font-bold text-slate-400 uppercase tracking-wider">Win</span>
            </div>
            <p class="text-2xl font-extrabold text-emerald-600 leading-none">{{ number_format($winningTrades ?? 0) }}</p>
            <p class="text-[11px] text-slate-400 mt-1">Win Rate {{ $winRate }}%</p>
        </div>

        {{-- Loss Count --}}
        <div class="bg-white rounded-2xl p-4 border border-slate-100 shadow-sm">
            <div class="flex items-center gap-2 mb-2.5">
                <div class="w-8 h-8 bg-rose-50 rounded-lg flex items-center justify-center shrink-0">
                    <svg class="w-4 h-4 text-rose-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                </div>
                <span class="text-[10.5px] font-bold text-slate-400 uppercase tracking-wider">Loss</span>
            </div>
            <p class="text-2xl font-extrabold text-rose-600 leading-none">{{ number_format($losingTrades ?? 0) }}</p>
            <p class="text-[11px] text-slate-400 mt-1">Loss Rate {{ ($winningTrades + ($losingTrades ?? 0)) > 0 ? round((($losingTrades ?? 0) / ($winningTrades + ($losingTrades ?? 0))) * 100, 1) : 0 }}%</p>
        </div>
    </div>

    {{-- ==================== STAT CARDS ROW 3 ==================== --}}
    <div class="grid grid-cols-2 gap-3 mb-3">
        {{-- Total P&L --}}
        <div class="bg-white rounded-2xl p-4 border border-slate-100 shadow-sm">
            <div class="flex items-center gap-2 mb-2.5">
                <div class="w-8 h-8 {{ $totalProfit >= 0 ? 'bg-emerald-50' : 'bg-rose-50' }} rounded-lg flex items-center justify-center shrink-0">
                    <svg class="w-4 h-4 {{ $totalProfit >= 0 ? 'text-emerald-600' : 'text-rose-600' }}" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                </div>
                <span class="text-[10.5px] font-bold text-slate-400 uppercase tracking-wider">Total P&amp;L</span>
            </div>
            <p class="text-[22px] font-extrabold {{ $totalProfit >= 0 ? 'text-emerald-600' : 'text-rose-600' }} leading-none">
                {{ $totalProfit >= 0 ? '+' : '-' }}${{ number_format(abs($totalProfit), 2) }}
            </p>
        </div>

        {{-- Today P&L --}}
        <div class="bg-white rounded-2xl p-4 border border-slate-100 shadow-sm">
            <div class="flex items-center gap-2 mb-2.5">
                <div class="w-8 h-8 bg-amber-50 rounded-lg flex items-center justify-center shrink-0">
                    <svg class="w-4 h-4 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                </div>
                <span class="text-[10.5px] font-bold text-slate-400 uppercase tracking-wider">Today P&amp;L</span>
            </div>
            <p class="text-[22px] font-extrabold {{ $todayProfit >= 0 ? 'text-emerald-600' : 'text-rose-600' }} leading-none">
                {{ $todayProfit >= 0 ? '+' : '-' }}${{ number_format(abs($todayProfit), 2) }}
            </p>
            <p class="text-[11px] text-slate-400 mt-1">{{ $todayTradesCount }} trades today</p>
        </div>
    </div>

    {{-- ==================== STAT CARDS ROW 4 ==================== --}}
    <div class="grid grid-cols-2 gap-3 mb-4">
        {{-- Max Drawdown --}}
        <div class="bg-white rounded-2xl p-4 border border-slate-100 shadow-sm">
            <div class="flex items-center gap-2 mb-2.5">
                <div class="w-8 h-8 bg-rose-50 rounded-lg flex items-center justify-center shrink-0">
                    <svg class="w-4 h-4 text-rose-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 17h8m0 0V9m0 8l-8-8-4 4-6-6"/></svg>
                </div>
                <span class="text-[10.5px] font-bold text-slate-400 uppercase tracking-wider">Max Drawdown</span>
            </div>
            <p class="text-[22px] font-extrabold text-rose-600 leading-none">-${{ number_format($maxDrawdown ?? 0, 2) }}</p>
        </div>

        {{-- All Time High --}}
        <div class="bg-white rounded-2xl p-4 border border-slate-100 shadow-sm">
            <div class="flex items-center gap-2 mb-2.5">
                <div class="w-8 h-8 bg-emerald-50 rounded-lg flex items-center justify-center shrink-0">
                    <svg class="w-4 h-4 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"/></svg>
                </div>
                <span class="text-[10.5px] font-bold text-slate-400 uppercase tracking-wider">All Time High</span>
            </div>
            <p class="text-[22px] font-extrabold text-emerald-600 leading-none">+${{ number_format($allTimeHigh ?? 0, 2) }}</p>
        </div>
    </div>

    {{-- ==================== PROFIT % + WIN RATE BAR ==================== --}}
    <div class="bg-white rounded-2xl p-4 border border-slate-100 shadow-sm mb-4">
        <div class="flex items-center justify-between mb-2">
            <span class="text-xs font-bold text-slate-800">Profit Factor</span>
            <span class="text-xs font-bold text-brand-600">{{ $profitPct ?? 0 }}%</span>
        </div>
        <div class="bg-slate-100 rounded-full h-2 overflow-hidden">
            <div class="bg-gradient-to-r from-brand-600 to-cyan-400 h-full rounded-full transition-all duration-500" style="width:{{ $profitPct ?? 0 }}%;"></div>
        </div>
        <div class="flex items-center justify-between mt-3 mb-2">
            <span class="text-xs font-bold text-slate-800">Win Rate</span>
            <span class="text-xs font-bold text-emerald-600">{{ $winRate }}%</span>
        </div>
        <div class="bg-slate-100 rounded-full h-2 overflow-hidden">
            <div class="bg-gradient-to-r from-emerald-500 to-green-300 h-full rounded-full transition-all duration-500" style="width:{{ $winRate }}%;"></div>
        </div>
    </div>

    {{-- ==================== CHART ==================== --}}
    <div class="bg-white rounded-2xl p-4 border border-slate-100 shadow-sm mb-6">
        <div class="flex items-center justify-between mb-4">
            <div>
                <p class="text-[13px] font-bold text-slate-800">Daily P&amp;L (30 Days)</p>
                <p class="text-[11px] text-slate-400">Profit/Loss per hari</p>
            </div>
        </div>
        <canvas id="dailyPnlChart" class="w-full max-h-[220px]"></canvas>
    </div>

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

    {{-- Chart.js Initialization --}}
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
    <script>
        document.addEventListener('DOMContentLoaded', function() {
            var chartData = @json($chartData ?? []);
            if(chartData.length === 0) return;

            var labels  = chartData.map(function(d) { return d.date; });
            var profits = chartData.map(function(d) { return d.profit; });

            var colors = profits.map(function(v) { return v >= 0 ? 'rgba(16, 185, 129, 0.85)' : 'rgba(225, 29, 72, 0.85)'; });
            var borders = profits.map(function(v) { return v >= 0 ? '#10b981' : '#e11d48'; });

            var ctx = document.getElementById('dailyPnlChart');
            if (!ctx) return;

            new Chart(ctx, {
                type: 'bar',
                data: {
                    labels: labels,
                    datasets: [{
                        data: profits,
                        backgroundColor: colors,
                        borderColor: borders,
                        borderWidth: 1.5,
                        borderRadius: 4,
                        borderSkipped: false,
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: { display: false },
                        tooltip: {
                            callbacks: {
                                label: function(c) {
                                    return (c.raw >= 0 ? '+$' : '-$') + Math.abs(c.raw).toFixed(2);
                                }
                            }
                        }
                    },
                    scales: {
                        x: {
                            grid: { display: false },
                            ticks: { font: { size: 10, family: 'Inter' }, color: '#94a3b8', maxTicksLimit: 7 }
                        },
                        y: {
                            grid: { color: '#f1f5f9' },
                            ticks: {
                                font: { size: 10, family: 'Inter' }, color: '#94a3b8',
                                callback: function(v) { return '$' + v; }
                            }
                        }
                    }
                }
            });
        });
    </script>
@endsection
