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

    {{-- Empty State Info --}}
    <div class="bg-white rounded-2xl shadow-sm border border-slate-200 p-10 text-center flex flex-col items-center justify-center">
        <svg class="w-16 h-16 text-slate-300 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"></path></svg>
        <h3 class="text-lg font-bold text-slate-800 mb-2">Semua fitur Analitik telah dipindahkan ke Dashboard</h3>
        <p class="text-slate-500 max-w-sm text-sm">Untuk pengalaman yang lebih baik, laporan statistik Pair, grafik Win Rate, dan data P/L harian kini tergabung dalam satu ringkasan komprehensif di halaman utama (Dashboard).</p>
        <a href="{{ route('dashboard') }}" class="mt-6 inline-flex items-center gap-2 px-5 py-2.5 bg-brand-600 hover:bg-brand-700 text-white text-sm font-semibold rounded-xl transition-colors shadow-sm shadow-brand-500/30">
            Ke Halaman Dashboard
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3"></path></svg>
        </a>
    </div>

@endsection
