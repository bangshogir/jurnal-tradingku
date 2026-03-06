@extends('layouts.admin')

@section('title', 'Dashboard')
@section('page-title', 'Dashboard Overview')
@section('page-subtitle', 'Ringkasan data trading Anda hari ini')

@section('content')

    {{-- 6 Stat Cards --}}
    <dl class="grid grid-cols-2 gap-4 sm:grid-cols-3 xl:grid-cols-6 mb-6">
        @php
            $cards = [
                [
                    'label' => 'Total Trades',
                    'value' => number_format($totalTrades),
                    'color' => 'text-slate-800',
                    'icon' => '📊',
                ],
                [
                    'label' => 'Today Trades',
                    'value' => number_format($todayTradesCount),
                    'color' => 'text-slate-800',
                    'icon' => '📅',
                ],
                [
                    'label' => 'All PnL',
                    'value' => ($totalProfit >= 0 ? '+' : '') . '$' . number_format($totalProfit, 2),
                    'color' => $totalProfit >= 0 ? 'text-emerald-600' : 'text-red-500',
                    'icon' => '💰',
                ],
                [
                    'label' => 'Today PnL',
                    'value' => ($todayProfit >= 0 ? '+' : '') . '$' . number_format($todayProfit, 2),
                    'color' => $todayProfit >= 0 ? 'text-emerald-600' : 'text-red-500',
                    'icon' => '📈',
                ],
                ['label' => 'Win Rate', 'value' => $winRate . '%', 'color' => 'text-blue-600', 'icon' => '🏆'],
                [
                    'label' => 'Total Users',
                    'value' => number_format($totalUsers),
                    'color' => 'text-indigo-600',
                    'icon' => '👥',
                ],
            ];
        @endphp

        @foreach ($cards as $card)
            <div
                class="bg-white rounded-xl p-5 shadow-sm border border-slate-100 hover:shadow-md transition-shadow duration-200">
                <div class="flex items-start justify-between mb-3">
                    <span class="text-xl">{{ $card['icon'] }}</span>
                </div>
                <p class="text-xs font-medium text-slate-400 uppercase tracking-wide mb-1">{{ $card['label'] }}</p>
                <p class="text-xl font-bold {{ $card['color'] }} leading-tight">{{ $card['value'] }}</p>
            </div>
        @endforeach
    </dl>

    {{-- Trade History Table --}}
    <div class="bg-white rounded-xl shadow-sm border border-slate-100 overflow-hidden">
        <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100">
            <h2 class="font-semibold text-slate-800">Trade History</h2>
            <button onclick="window.location.reload()"
                class="inline-flex items-center gap-1.5 text-xs text-slate-500 hover:text-blue-600 hover:bg-blue-50 px-3 py-1.5 rounded-lg transition-all duration-200">
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                        d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                </svg>
                Refresh
            </button>
        </div>

        <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-slate-100 text-sm">
                <thead class="bg-slate-50 text-xs text-slate-400 uppercase tracking-wide">
                    <tr>
                        <th class="px-6 py-3 text-left">Time / Tanggal</th>
                        <th class="px-6 py-3 text-left">User</th>
                        <th class="px-6 py-3 text-left">Pair</th>
                        <th class="px-6 py-3 text-left">Type</th>
                        <th class="px-6 py-3 text-left">Volume</th>
                        <th class="px-6 py-3 text-left">Entry Price</th>
                        <th class="px-6 py-3 text-left">SL Price</th>
                        <th class="px-6 py-3 text-left">TP Price</th>
                        <th class="px-6 py-3 text-left">Profit / Loss</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-slate-50">
                    @forelse ($trades as $trade)
                        <tr class="hover:bg-slate-50/70 transition-colors duration-150">
                            <td class="px-6 py-4 text-slate-500 whitespace-nowrap">
                                <div class="font-medium text-slate-700">
                                    {{ $trade->open_time ? $trade->open_time->format('d M Y') : '-' }}</div>
                                <div class="text-xs text-slate-400">
                                    {{ $trade->open_time ? $trade->open_time->format('H:i') : '' }}
                                    @if ($trade->close_time)
                                        → {{ $trade->close_time->format('H:i') }}
                                    @endif
                                </div>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap">
                                <p class="font-semibold text-slate-800">{{ $trade->user->name ?? 'Unknown' }}</p>
                                <p class="text-xs text-slate-400">{{ $trade->user->email ?? '' }}</p>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap">
                                <p class="font-semibold text-slate-800">{{ $trade->symbol }}</p>
                                <p class="text-xs text-slate-400">#{{ $trade->ticket_id }}</p>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap">
                                @if (str_contains(strtolower($trade->type), 'buy'))
                                    <span
                                        class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-blue-100 text-blue-700">{{ str_replace('_', ' ', strtoupper($trade->type)) }}</span>
                                @else
                                    <span
                                        class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-orange-100 text-orange-700">{{ str_replace('_', ' ', strtoupper($trade->type)) }}</span>
                                @endif
                            </td>
                            <td class="px-6 py-4 text-slate-600 whitespace-nowrap">{{ number_format($trade->lot_size, 2) }}
                            </td>
                            <td class="px-6 py-4 text-slate-600 whitespace-nowrap font-mono text-xs">
                                {{ number_format($trade->entry_price, 5) }}</td>
                            <td class="px-6 py-4 whitespace-nowrap font-mono text-xs">
                                @php $slClose = $trade->sl_price > 0 && abs($trade->close_price - $trade->sl_price) <= 0.0005; @endphp
                                <span class="{{ $slClose ? 'text-red-600 font-bold' : 'text-slate-500' }}">
                                    {{ $trade->sl_price > 0 ? number_format($trade->sl_price, 5) : '-' }}
                                </span>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap font-mono text-xs">
                                @php $tpClose = $trade->tp_price > 0 && abs($trade->close_price - $trade->tp_price) <= 0.0005; @endphp
                                <span class="{{ $tpClose ? 'text-emerald-600 font-bold' : 'text-slate-500' }}">
                                    {{ $trade->tp_price > 0 ? number_format($trade->tp_price, 5) : '-' }}
                                </span>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap">
                                @if ($trade->profit_loss >= 0)
                                    <span
                                        class="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-emerald-50 text-emerald-700 font-bold text-xs border border-emerald-200">
                                        +${{ number_format($trade->profit_loss, 2) }}
                                    </span>
                                @else
                                    <span
                                        class="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-red-50 text-red-600 font-bold text-xs border border-red-200">
                                        -${{ number_format(abs($trade->profit_loss), 2) }}
                                    </span>
                                @endif
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="9" class="px-6 py-16 text-center">
                                <div class="flex flex-col items-center text-slate-400">
                                    <span class="text-4xl mb-3">⏳</span>
                                    <p class="font-medium">Belum ada data trading</p>
                                    <p class="text-sm mt-1">Menunggu data dari MT5 Webhook...</p>
                                </div>
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>

@endsection
