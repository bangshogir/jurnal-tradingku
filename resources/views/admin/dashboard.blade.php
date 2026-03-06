@extends('layouts.admin')

@section('title', 'Dashboard')
@section('page-title', 'Dashboard Overview')
@section('page-subtitle', 'Ringkasan data trading Anda hari ini')

@section('content')

    {{-- Modern Stat Cards --}}
    <dl class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4 xl:grid-cols-6 mb-8 mt-4">
        @php
            $cards = [
                [
                    'label' => 'Total Users',
                    'value' => number_format($totalUsers),
                    'valColor' => 'text-indigo-600',
                    'icon' =>
                        '<svg class="w-5 h-5 text-indigo-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5V4H2v16h5m8 0v-4h-6v4m6 0H9"></path></svg>',
                ],
                [
                    'label' => 'Total Trades',
                    'value' => number_format($totalTrades),
                    'valColor' => 'text-slate-900',
                    'icon' =>
                        '<svg class="w-5 h-5 text-slate-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"></path></svg>',
                ],
                [
                    'label' => 'Today Trades',
                    'value' => number_format($todayTradesCount),
                    'valColor' => 'text-slate-900',
                    'icon' =>
                        '<svg class="w-5 h-5 text-slate-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>',
                ],
                [
                    'label' => 'Total All PnL',
                    'value' => ($totalProfit >= 0 ? '$' : '-$') . number_format(abs($totalProfit), 2),
                    'valColor' => $totalProfit >= 0 ? 'text-emerald-500' : 'text-red-500',
                    'icon' =>
                        '<svg class="w-5 h-5 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>',
                ],
                [
                    'label' => 'Today PnL',
                    'value' => ($todayProfit >= 0 ? '$' : '-$') . number_format(abs($todayProfit), 2),
                    'valColor' => $todayProfit >= 0 ? 'text-emerald-500' : 'text-red-500',
                    'icon' =>
                        '<svg class="w-5 h-5 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>',
                ],
                [
                    'label' => 'Global Win Rate',
                    'value' => $winRate . '%',
                    'valColor' => 'text-blue-500',
                    'icon' =>
                        '<svg class="w-5 h-5 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"></path></svg>',
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
                    <span
                        class="text-[11px] font-semibold text-slate-500 uppercase tracking-wide">{{ $card['label'] }}</span>
                </div>
                <div class="mt-3">
                    <p class="text-2xl font-bold {{ $card['valColor'] }} tracking-tight">
                        {{ $card['value'] }}
                    </p>
                </div>
            </div>
        @endforeach
    </dl>

    {{-- System Wide Trades Table --}}
    <div class="mb-4 flex items-center justify-between mt-2">
        <h2 class="text-lg font-bold text-slate-900 tracking-tight">System Wide Logs</h2>
        <div class="flex gap-2">
            <button onclick="window.location.reload()"
                class="bg-white border border-slate-200 text-slate-600 text-[11px] font-medium px-3 py-1.5 rounded-lg hover:bg-slate-50 transition-colors flex items-center gap-1.5 shadow-sm">
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                        d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15">
                    </path>
                </svg>
                Refresh
            </button>
        </div>
    </div>

    {{-- Tabs --}}
    <div class="flex gap-6 border-b border-slate-200 mb-6 text-sm font-semibold text-slate-500">
        <button class="pb-3 border-b-2 border-brand-600 text-brand-600">All Users Trades</button>
    </div>

    <div class="bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden">
        <div class="overflow-x-auto">
            <table class="min-w-full text-sm">
                <thead
                    class="bg-white text-[11px] text-slate-400 font-semibold tracking-wider uppercase border-b border-slate-100">
                    <tr>
                        <th class="px-6 py-4 text-left font-medium">Ticket / Pair</th>
                        <th class="px-6 py-4 text-left font-medium">User</th>
                        <th class="px-6 py-4 text-left font-medium">Date</th>
                        <th class="px-6 py-4 text-left font-medium">Type</th>
                        <th class="px-6 py-4 text-left font-medium">Lot</th>
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
                            <td class="px-6 py-4 whitespace-nowrap">
                                <p class="font-semibold text-slate-800 tracking-tight">{{ $trade->user->name ?? 'Unknown' }}
                                </p>
                                <p class="text-[11px] text-slate-400">{{ $trade->user->email ?? '' }}</p>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-slate-500">
                                {{ $trade->open_time ? $trade->open_time->format('d M') : '-' }}
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
                            <td class="px-6 py-4 whitespace-nowrap font-semibold">
                                @if (str_contains(strtolower($trade->type), 'closed') || $trade->close_time)
                                    @if ($trade->profit_loss >= 0)
                                        <span class="text-emerald-500">+${{ number_format($trade->profit_loss, 2) }}</span>
                                    @else
                                        <span
                                            class="text-red-500">-${{ number_format(abs($trade->profit_loss), 2) }}</span>
                                    @endif
                                @else
                                    <span class="text-slate-400">-</span>
                                @endif
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap">
                                <div class="flex items-center gap-2">
                                    @if (str_contains(strtolower($trade->type), 'closed') || $trade->close_time)
                                        <span
                                            class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-emerald-50 text-emerald-600 font-semibold text-[11px] border border-emerald-100">
                                            <span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span> Closed
                                        </span>
                                    @elseif (str_contains(strtolower($trade->type), 'limit') || str_contains(strtolower($trade->type), 'stop'))
                                        <span
                                            class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-amber-50 text-amber-600 font-semibold text-[11px] border border-amber-100">
                                            <span class="w-1.5 h-1.5 rounded-full bg-amber-500"></span> Pending
                                        </span>
                                    @else
                                        <span
                                            class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-blue-50 text-blue-600 font-semibold text-[11px] border border-blue-100">
                                            <span class="w-1.5 h-1.5 rounded-full bg-blue-500 animate-pulse"></span> Open
                                        </span>
                                    @endif
                                    <button class="text-slate-400 hover:text-slate-600 mt-0.5">
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
                                        <span class="text-3xl">📭</span>
                                    </div>
                                    <p class="font-semibold text-slate-700">No trades recorded</p>
                                    <p class="text-sm text-slate-400 mt-1 max-w-sm">No users have placed any trades yet.</p>
                                </div>
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>

@endsection
