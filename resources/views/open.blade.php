@extends('layouts.admin')

@section('title', 'Dashboard')
@section('page-title', 'Dashboard Overview')
@section('page-subtitle', 'Ringkasan data trading Anda hari ini')

@section('content')

    {{-- Open Orders Table / Last Sales style --}}
    <div class="mb-4 flex items-center justify-between mt-2">
        <div>
            <h2 class="text-lg font-bold text-slate-900 tracking-tight">Open / Running Orders</h2>
            <p class="text-xs text-slate-400 mt-0.5">Gunakan tombol 🗑️ Hapus jika data lama tidak sinkron dengan MT5</p>
        </div>
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
        <button class="pb-3 border-b-2 border-brand-600 text-brand-600">Active Positions</button>
    </div>

    <div class="bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden">
        <div class="overflow-x-auto">
            <table class="min-w-full text-sm">
                <thead
                    class="bg-white text-[11px] text-slate-400 font-semibold tracking-wider uppercase border-b border-slate-100">
                    <tr>
                        <th class="px-6 py-4 text-left font-medium">Position ID</th>
                        <th class="px-6 py-4 text-left font-medium">Date</th>
                        <th class="px-6 py-4 text-left font-medium">Type</th>
                        <th class="px-6 py-4 text-left font-medium">Lot</th>
                        <th class="px-6 py-4 text-left font-medium">Entry</th>
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
                                        <div class="flex items-center gap-2">
                                            <p class="font-semibold text-slate-800 tracking-tight">{{ $trade->symbol }}</p>
                                            @if($trade->timeframe)
                                                <span class="px-1.5 py-0.5 rounded text-[10px] font-bold bg-slate-100 text-slate-500 border border-slate-200">{{ $trade->timeframe }}</span>
                                            @endif
                                        </div>
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
                                <div class="flex flex-col gap-1.5">
                                    <span>{{ number_format($trade->entry_price, 5) }}</span>
                                    @if($trade->rr_ratio)
                                        <span class="text-[9.5px] font-sans font-bold bg-indigo-50 text-indigo-600 px-1.5 py-0.5 rounded w-max tracking-wide">RR {{ $trade->rr_ratio }}</span>
                                    @endif
                                </div>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap">
                                <div class="flex items-center gap-2">
                                    <span
                                        class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-blue-50 text-blue-600 font-semibold text-[11px] border border-blue-100">
                                        <span class="w-1.5 h-1.5 rounded-full bg-blue-500 animate-pulse"></span> In Progress
                                    </span>
                                    <button onclick="confirmDismiss({{ $trade->id }}, '{{ $trade->symbol }}', '#{{ $trade->ticket_id }}')"
                                        class="text-red-300 hover:text-red-500 transition-colors" title="Hapus dari jurnal">
                                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                                d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16">
                                            </path>
                                        </svg>
                                    </button>
                                </div>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="6" class="px-6 py-20 text-center">
                                <div class="flex flex-col items-center justify-center">
                                    <div class="w-16 h-16 bg-slate-50 rounded-full flex items-center justify-center mb-3">
                                        <span class="text-3xl">📈</span>
                                    </div>
                                    <p class="font-semibold text-slate-700">No active positions</p>
                                    <p class="text-sm text-slate-400 mt-1 max-w-sm">Market orders will appear here while
                                        they are running.</p>
                                </div>
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>

    {{-- Flash Messages --}}
    @if (session('success'))
        <div class="fixed bottom-5 right-5 z-50 bg-emerald-500 text-white text-sm font-semibold px-5 py-3 rounded-xl shadow-lg flex items-center gap-2">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>
            {{ session('success') }}
        </div>
    @endif

    {{-- Confirm Delete Modal --}}
    <div id="dismissModal" class="hidden fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm">
        <div class="bg-white rounded-2xl shadow-2xl p-6 max-w-sm w-full mx-4">
            <div class="flex items-center gap-3 mb-4">
                <div class="w-10 h-10 bg-red-50 rounded-full flex items-center justify-center">
                    <svg class="w-5 h-5 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"></path></svg>
                </div>
                <div>
                    <h3 class="font-bold text-slate-900">Hapus dari Jurnal?</h3>
                    <p class="text-xs text-slate-400">Aksi ini tidak dapat dibatalkan</p>
                </div>
            </div>
            <p class="text-sm text-slate-600 mb-5" id="dismissModalText">Apakah Anda yakin ingin menghapus trade ini dari jurnal?</p>
            <div class="flex gap-3">
                <button onclick="closeDismissModal()" class="flex-1 px-4 py-2 bg-slate-100 text-slate-700 rounded-xl text-sm font-semibold hover:bg-slate-200 transition-colors">Batal</button>
                <form id="dismissForm" method="POST">
                    @csrf
                    @method('DELETE')
                    <button type="submit" class="flex-1 px-4 py-2 bg-red-500 text-white rounded-xl text-sm font-semibold hover:bg-red-600 transition-colors">Ya, Hapus</button>
                </form>
            </div>
        </div>
    </div>

@push('scripts')
<script>
    function confirmDismiss(id, symbol, ticket) {
        document.getElementById('dismissModalText').textContent =
            `Hapus trade ${symbol} ${ticket} dari jurnal? Trade ini sudah tidak ada di MT5.`;
        document.getElementById('dismissForm').action = `/trades/${id}/dismiss`;
        document.getElementById('dismissModal').classList.remove('hidden');
    }
    function closeDismissModal() {
        document.getElementById('dismissModal').classList.add('hidden');
    }
    document.getElementById('dismissModal').addEventListener('click', function(e) {
        if (e.target === this) closeDismissModal();
    });
</script>
@endpush

@endsection
