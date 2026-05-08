@extends('layouts.admin')

@section('title', 'Trade History')
@section('page-title', 'Trade History')
@section('page-subtitle', 'Daftar riwayat letak eksekusi order Anda')

@section('content')

    {{-- Header filter --}}
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6">
        <h2 class="text-lg font-bold text-slate-900 tracking-tight">History</h2>
        <form method="GET" action="{{ route('dashboard.history') }}" class="flex gap-2 items-center">
            @if (request('filter'))
                <input type="hidden" name="filter" value="{{ request('filter') }}">
            @endif
            <div class="relative">
                <select name="date_filter" onchange="this.form.submit()"
                    class="appearance-none bg-white border border-slate-200 text-slate-700 text-[12px] font-semibold px-4 py-2 pr-9 rounded-xl hover:bg-slate-50 transition-colors shadow-sm focus:outline-none focus:ring-2 focus:ring-brand-500 cursor-pointer">
                    <option value="today" {{ $dateFilter === 'today' ? 'selected' : '' }}>Today</option>
                    <option value="last_7_days" {{ $dateFilter === 'last_7_days' ? 'selected' : '' }}>Last 7 Days</option>
                    <option value="last_30_days" {{ $dateFilter === 'last_30_days' ? 'selected' : '' }}>Last 30 Days</option>
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
            <button type="button" class="bg-white border border-slate-200 text-slate-600 text-[11px] font-medium px-3 py-2 rounded-xl hover:bg-slate-50 transition-colors flex items-center gap-1.5 shadow-sm">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12"></path>
                </svg>
                Export
            </button>
        </form>
    </div>

    {{-- Tabs --}}
    <div class="flex gap-6 border-b border-slate-200 mb-6 text-sm font-semibold text-slate-500">
        <a href="{{ route('dashboard.history', ['filter' => 'all', 'date_filter' => $dateFilter]) }}"
            class="pb-3 border-b-2 {{ $filter === 'all' ? 'border-brand-600 text-brand-600' : 'border-transparent hover:text-slate-800 hover:border-slate-300 transition-colors' }}">
            All trades
        </a>
        <a href="{{ route('dashboard.history', ['filter' => 'completed', 'date_filter' => $dateFilter]) }}"
            class="pb-3 border-b-2 {{ $filter === 'completed' ? 'border-brand-600 text-brand-600' : 'border-transparent hover:text-slate-800 hover:border-slate-300 transition-colors' }}">
            Completed
        </a>
        <a href="{{ route('dashboard.history', ['filter' => 'cancelled', 'date_filter' => $dateFilter]) }}"
            class="pb-3 border-b-2 {{ $filter === 'cancelled' ? 'border-brand-600 text-brand-600' : 'border-transparent hover:text-slate-800 hover:border-slate-300 transition-colors' }}">
            Cancelled
        </a>
    </div>

    <div class="bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden">
        <div class="overflow-x-auto">
            <table class="min-w-full text-sm">
                <thead
                    class="bg-slate-50/80 text-[10px] text-slate-500 font-bold tracking-wider uppercase border-b border-slate-200">
                    <tr>
                        <th class="px-6 py-4 text-left font-medium">Ticket / Pair</th>
                        <th class="px-6 py-4 text-left font-medium">Date</th>
                        <th class="px-6 py-4 text-left font-medium">Type</th>
                        <th class="px-6 py-4 text-left font-medium">Lot</th>
                        <th class="px-6 py-4 text-left font-medium">R. Rasio</th>
                        <th class="px-6 py-4 text-left font-medium">Strategy</th>
                        <th class="px-6 py-4 text-left font-medium">P/L</th>
                        <th class="px-6 py-4 text-left font-medium">Status</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-slate-100">
                    @forelse ($trades as $trade)
                        <tr class="hover:bg-slate-50/80 transition-colors group">
                            <td class="px-6 py-4 whitespace-nowrap">
                                <div class="flex items-center gap-3">
                                    <input type="checkbox"
                                        class="rounded border-slate-300 text-brand-600 focus:ring-brand-600 opacity-50 group-hover:opacity-100 transition-opacity">
                                    <div>
                                        <div class="font-bold text-slate-900 text-[13px] flex items-center gap-2">
                                            {{ $trade->symbol }}
                                            @if($trade->timeframe)
                                                <span class="px-1.5 py-0.5 rounded text-[10px] font-bold bg-slate-100 text-slate-500 border border-slate-200">{{ $trade->timeframe }}</span>
                                            @endif
                                        </div>
                                        <p class="text-[11px] text-slate-400">#{{ $trade->ticket_id }}</p>
                                    </div>
                                </div>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-slate-500 text-[11px] font-medium">
                                {{ $trade->open_time ? $trade->open_time->format('j/n/Y') : '-' }}
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap">
                                @php
                                    $typeStr = strtolower($trade->type);
                                    $isBuy = str_contains($typeStr, 'buy');
                                    $isSell = str_contains($typeStr, 'sell');
                                    $typeLabel = $isBuy ? 'Buy' : ($isSell ? 'Sell' : 'Other');
                                    $badgeClass = $isBuy
                                        ? 'text-blue-700 bg-blue-50 border-blue-200'
                                        : ($isSell
                                            ? 'text-rose-700 bg-rose-50 border-rose-200'
                                            : 'text-slate-700 bg-slate-50 border-slate-200');
                                @endphp
                                <span class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-semibold border {{ $badgeClass }} capitalize">
                                    {{ $typeLabel }}
                                </span>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-slate-500 font-mono text-[12px]">
                                {{ number_format($trade->lot_size, 2) }}
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap font-mono text-[12px] text-slate-600">
                                @if($trade->rr_ratio)
                                    <span class="inline-flex items-center px-1.5 py-0.5 rounded text-[11px] font-semibold bg-indigo-50 text-indigo-600 border border-indigo-100 whitespace-nowrap">
                                        {{ $trade->rr_ratio }}
                                    </span>
                                @else
                                    <span class="text-slate-400 text-xs">-</span>
                                @endif
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap">
                                @php
                                    $strategyLabel = $trade->strategy ?? 'Manual';
                                    $isMomentum = str_contains($strategyLabel, 'Momentum');
                                    $stratBadge = $isMomentum
                                        ? 'bg-indigo-50 text-indigo-700 border-indigo-200'
                                        : 'bg-slate-50 text-slate-500 border-slate-200';
                                @endphp
                                <span class="inline-flex items-center gap-1 px-2 py-0.5 rounded text-[11px] font-semibold border {{ $stratBadge }}">
                                    {{ $isMomentum ? '🚀' : '✏️' }} {{ $strategyLabel }}
                                </span>
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
                                    @if($trade->profit_loss > 0)
                                        <span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-emerald-50 text-emerald-600 font-semibold text-[11px] border border-emerald-100 w-20 justify-center">
                                            <span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span> Win
                                        </span>
                                    @elseif($trade->profit_loss < 0)
                                        <span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-rose-50 text-rose-600 font-semibold text-[11px] border border-rose-100 w-20 justify-center">
                                            <span class="w-1.5 h-1.5 rounded-full bg-rose-500"></span> Loss
                                        </span>
                                    @else
                                        <span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-slate-50 text-slate-600 font-semibold text-[11px] border border-slate-200 w-20 justify-center">
                                            <span class="w-1.5 h-1.5 rounded-full bg-slate-400"></span> BEP
                                        </span>
                                    @endif
                                    <form method="POST" action="{{ route('trades.dismiss', $trade->id) }}" class="inline" id="dismiss-form-{{ $trade->id }}">
                                        @csrf
                                        @method('DELETE')
                                        <button type="button" onclick="confirmDismiss({{ $trade->id }}, '{{ $trade->symbol }}', '#{{ $trade->ticket_id }}')" class="text-slate-400 hover:text-red-500 transition-colors" title="Hapus dari jurnal">
                                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
                                            </svg>
                                        </button>
                                    </form>
                                </div>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="8" class="px-6 py-20 text-center">
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

    {{-- Script for delete confirmation --}}
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
    <script>
        function confirmDismiss(id, symbol, ticket) {
            Swal.fire({
                title: 'Hapus Trade?',
                text: "Data " + symbol + " (" + ticket + ") tidak akan dihitung lagi di statistik. Anda tidak dapat mengembalikannya!",
                icon: 'warning',
                showCancelButton: true,
                confirmButtonColor: '#ef4444',
                cancelButtonColor: '#64748b',
                confirmButtonText: 'Ya, Hapus!',
                cancelButtonText: 'Batal'
            }).then((result) => {
                if (result.isConfirmed) {
                    document.getElementById('dismiss-form-' + id).submit();
                }
            })
        }
    </script>
@endsection
