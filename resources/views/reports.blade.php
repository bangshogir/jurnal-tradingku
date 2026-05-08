@extends('layouts.admin')

@section('title', 'Reports')
@section('page-title', 'Financial Reports')
@section('page-subtitle', 'Laporan deposit dan penarikan dana Anda')

@section('content')

    {{-- DEPOSIT & WITHDRAWAL STATS --}}
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 sm:gap-6 lg:gap-8 mb-8">
        <div class="bg-white rounded-2xl shadow-sm border border-slate-200 p-6 flex flex-col sm:flex-row items-start sm:items-center gap-4 sm:gap-6 hover:shadow-md transition-shadow">
            <div class="w-14 h-14 bg-emerald-50 border border-emerald-100 text-emerald-600 rounded-full flex items-center justify-center shrink-0">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path></svg>
            </div>
            <div>
                <p class="text-sm font-semibold text-slate-500 mb-1 tracking-wide uppercase">Total Deposit (All Time)</p>
                <h4 class="text-3xl font-black text-slate-900 tracking-tight">${{ number_format($totalDeposit, 2) }}</h4>
            </div>
        </div>
        
        <div class="bg-white rounded-2xl shadow-sm border border-slate-200 p-6 flex flex-col sm:flex-row items-start sm:items-center gap-4 sm:gap-6 hover:shadow-md transition-shadow">
            <div class="w-14 h-14 bg-rose-50 border border-rose-100 text-rose-600 rounded-full flex items-center justify-center shrink-0">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 12H4"></path></svg>
            </div>
            <div>
                <p class="text-sm font-semibold text-slate-500 mb-1 tracking-wide uppercase">Total Withdrawal (All Time)</p>
                <h4 class="text-3xl font-black text-slate-900 tracking-tight">-${{ number_format(abs($totalWithdrawal), 2) }}</h4>
            </div>
        </div>
    </div>

    {{-- TRANSACTIONS TABLE --}}
    <div class="bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden">
        <div class="p-5 border-b border-slate-100 flex items-center justify-between">
            <h3 class="text-lg font-bold text-slate-900 tracking-tight">Riwayat Transaksi</h3>
        </div>
        <div class="overflow-x-auto">
            <table class="w-full text-left border-collapse">
                <thead>
                    <tr class="bg-slate-50/50 border-b border-slate-100 text-[11px] uppercase tracking-wider text-slate-500 font-semibold">
                        <th class="p-4 pl-6">Tanggal</th>
                        <th class="p-4">Tipe</th>
                        <th class="p-4 text-center">Ticket</th>
                        <th class="p-4 w-1/3">Catatan</th>
                        <th class="p-4 pr-6 text-right">Jumlah</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-slate-100">
                    @forelse($transactions as $trx)
                        <tr class="hover:bg-slate-50/50 transition-colors">
                            <td class="p-4 pl-6 text-[13px] font-medium text-slate-600">
                                {{ \Carbon\Carbon::parse($trx->close_time ?? $trx->open_time ?? $trx->created_at)->format('j/n/Y') }}
                            </td>
                            <td class="p-4">
                                <span class="inline-flex items-center px-2 py-1 rounded-md text-[11px] font-bold uppercase tracking-wider {{ $trx->type == 'deposit' ? 'bg-emerald-100/50 text-emerald-700' : 'bg-rose-100/50 text-rose-700' }}">
                                    {{ $trx->type }}
                                </span>
                            </td>
                            <td class="p-4 text-[12px] font-mono text-slate-400 text-center">
                                #{{ $trx->ticket_id }}
                            </td>
                            <td class="p-4 text-[13px] text-slate-500 max-w-[200px] truncate" title="{{ $trx->comment }}">
                                {{ $trx->comment ?? '-' }}
                            </td>
                            <td class="p-4 pr-6 text-right text-sm font-bold {{ $trx->type == 'deposit' ? 'text-emerald-600' : 'text-rose-600' }}">
                                {{ $trx->type == 'deposit' ? '+' : '-' }}${{ number_format(abs($trx->profit_loss), 2) }}
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="5" class="p-8 text-center text-slate-500">
                                <div class="flex flex-col items-center justify-center gap-2">
                                    <svg class="w-10 h-10 text-slate-300" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                                    <p class="text-sm">Belum ada riwayat deposit atau penarikan.</p>
                                </div>
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
        
        @if($transactions->hasPages())
        <div class="p-4 border-t border-slate-100 bg-slate-50/50">
            {{ $transactions->links() }}
        </div>
        @endif
    </div>

@endsection
