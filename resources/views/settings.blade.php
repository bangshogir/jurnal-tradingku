@extends('layouts.admin')

@section('title', 'Settings')
@section('page-title', 'Settings')
@section('page-subtitle', 'Manage your API connection and Telegram notification rules')

@section('content')

    {{-- Session Alerts --}}
    @if(session('success'))
        <div class="mb-6 bg-emerald-50 border border-emerald-200 text-emerald-600 px-4 py-3 rounded-xl shadow-sm text-sm font-medium flex items-center gap-2">
            <svg class="w-5 h-5 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
            {{ session('success') }}
        </div>
    @endif

    @if($errors->any())
        <div class="mb-6 bg-rose-50 border border-rose-200 text-rose-600 px-4 py-3 rounded-xl shadow-sm text-sm font-medium flex gap-2">
            <svg class="w-5 h-5 text-rose-500 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
            <ul class="list-disc pl-4 space-y-1">
                @foreach($errors->all() as $error)
                    <li>{{ $error }}</li>
                @endforeach
            </ul>
        </div>
    @endif

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        {{-- EA Integration Card --}}
        <div class="bg-gradient-to-r from-brand-500 to-indigo-500 rounded-2xl p-6 relative overflow-hidden shadow-lg shadow-brand-500/20">
            <div class="absolute top-0 right-0 -mt-4 -mr-4 w-32 h-32 bg-white opacity-10 rounded-full blur-2xl pointer-events-none"></div>
            
            <div class="relative z-10 mb-4">
                <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-white/20 text-white text-[11px] font-semibold tracking-wide uppercase mb-3 backdrop-blur-sm border border-white/10">
                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"></path></svg>
                    EA Integration
                </span>
                <h3 class="font-bold text-white text-xl tracking-tight mb-1">Webhook API Token</h3>
                <p class="text-indigo-100 text-sm leading-relaxed">Connect your MT4/MT5 to automatically sync trades.</p>
            </div>
            
            <div class="relative z-10 flex flex-col sm:flex-row gap-3">
                <div class="bg-white/10 px-4 py-3 rounded-xl border border-white/20 font-mono text-sm text-white shadow-inner flex-1 flex items-center justify-between backdrop-blur-sm">
                    <div>
                        <span id="token-hidden" class="tracking-widest opacity-80">••••••••••••••••••••</span>
                        <span id="token-visible" class="hidden select-all">{{ auth()->user()->webhook_token }}</span>
                    </div>
                    <button onclick="document.getElementById('token-hidden').classList.toggle('hidden'); document.getElementById('token-visible').classList.toggle('hidden');" class="text-white/60 hover:text-white transition-colors focus:outline-none" title="Show/Hide Token">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path></svg>
                    </button>
                </div>
                <button onclick="navigator.clipboard.writeText('{{ auth()->user()->webhook_token }}'); alert('Token berhasil disalin!');" class="bg-white hover:bg-slate-50 text-brand-600 px-5 py-3 rounded-xl text-sm font-semibold transition-all shadow-sm flex items-center justify-center whitespace-nowrap">
                    Copy
                </button>
            </div>
        </div>

        {{-- Telegram Integration Card --}}
        <div class="bg-gradient-to-r from-sky-500 to-blue-600 rounded-2xl p-6 relative overflow-hidden shadow-lg shadow-sky-500/20">
            <div class="absolute top-0 right-0 -mt-4 -mr-4 w-32 h-32 bg-white opacity-10 rounded-full blur-2xl pointer-events-none"></div>
            
            <div class="relative z-10 mb-4">
                <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-white/20 text-white text-[11px] font-semibold tracking-wide uppercase mb-3 backdrop-blur-sm border border-white/10">
                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"></path></svg>
                    Telegram Alert
                </span>
                <h3 class="font-bold text-white text-xl tracking-tight mb-1">Notification Chat ID</h3>
                <p class="text-sky-100 text-sm leading-relaxed">Default Chat ID for alerts when trades execute.</p>
            </div>
            
            <form method="POST" action="{{ route('profile.telegram') }}" class="relative z-10 flex flex-col sm:flex-row gap-3">
                @csrf
                <div class="flex-1">
                    <input type="text" name="telegram_chat_id" value="{{ auth()->user()->telegram_chat_id }}" placeholder="e.g. 123456789" class="w-full bg-white/10 text-white placeholder-sky-200 px-4 py-3 rounded-xl border border-white/20 font-mono text-sm shadow-inner backdrop-blur-sm focus:outline-none focus:ring-2 focus:ring-white/50 transition-all">
                </div>
                <button type="submit" class="bg-white hover:bg-slate-50 text-sky-600 px-5 py-3 rounded-xl text-sm font-semibold transition-all shadow-sm flex items-center justify-center whitespace-nowrap">
                    Save ID
                </button>
            </form>
        </div>
    </div>

    {{-- Telegram Account Routing Section --}}
    <div class="mb-8">
        <div class="bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden">
            <div class="p-6 border-b border-slate-100 flex items-center justify-between">
                <div>
                    <h2 class="text-lg font-bold text-slate-900 tracking-tight">Telegram Account Routing</h2>
                    <p class="text-sm text-slate-500 mt-1">Route notifications from specific MT4/MT5 accounts to different Telegram Groups/Channels.</p>
                </div>
            </div>
            <div class="p-6 bg-slate-50">
                <form action="{{ route('telegram-routings.store') }}" method="POST" class="flex flex-col sm:flex-row gap-4 items-end">
                    @csrf
                    <div class="flex-1 w-full">
                        <label class="block text-xs font-semibold text-slate-600 mb-1.5 uppercase tracking-wider">Account Number</label>
                        <input type="text" name="account_number" required placeholder="e.g 1234567"
                            class="w-full text-sm placeholder-slate-400 focus:ring-2 focus:ring-brand-500 focus:border-brand-500 border-slate-200 rounded-lg shadow-sm">
                    </div>
                    <div class="flex-1 w-full">
                        <label class="block text-xs font-semibold text-slate-600 mb-1.5 uppercase tracking-wider">Target Chat ID</label>
                        <input type="text" name="telegram_chat_id" required placeholder="e.g -100987654321"
                            class="w-full text-sm placeholder-slate-400 focus:ring-2 focus:ring-brand-500 focus:border-brand-500 border-slate-200 rounded-lg shadow-sm">
                    </div>
                    <div class="flex-1 w-full">
                        <label class="block text-xs font-semibold text-slate-600 mb-1.5 uppercase tracking-wider">Description (Optional)</label>
                        <input type="text" name="description" placeholder="e.g Live Account"
                            class="w-full text-sm placeholder-slate-400 focus:ring-2 focus:ring-brand-500 focus:border-brand-500 border-slate-200 rounded-lg shadow-sm">
                    </div>
                    <div class="w-full sm:w-auto">
                        <button type="submit"
                            class="w-full px-5 py-2.5 bg-brand-600 text-white text-sm font-semibold rounded-lg hover:bg-brand-700 shadow-sm transition-colors focus:ring-2 focus:ring-offset-2 focus:ring-brand-500">
                            Add Route
                        </button>
                    </div>
                </form>

                @if($telegramRoutings && $telegramRoutings->count() > 0)
                <div class="mt-6 border border-slate-200 rounded-xl bg-white overflow-hidden">
                    <table class="min-w-full text-sm">
                        <thead class="bg-slate-50 text-[11px] text-slate-500 font-semibold tracking-wider uppercase border-b border-slate-200">
                            <tr>
                                <th class="px-5 py-3 text-left">Account Number</th>
                                <th class="px-5 py-3 text-left">Target Chat ID</th>
                                <th class="px-5 py-3 text-left">Description</th>
                                <th class="px-5 py-3 text-right">Action</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-slate-100">
                            @foreach($telegramRoutings as $route)
                            <tr class="hover:bg-slate-50 transition-colors">
                                <td class="px-5 py-3 text-slate-900 font-medium">{{ $route->account_number }}</td>
                                <td class="px-5 py-3 text-slate-600 font-mono text-xs">{{ $route->telegram_chat_id }}</td>
                                <td class="px-5 py-3 text-slate-500">{{ $route->description ?? '-' }}</td>
                                <td class="px-5 py-3 text-right">
                                    <form action="{{ route('telegram-routings.destroy', $route) }}" method="POST" class="inline">
                                        @csrf
                                        @method('DELETE')
                                        <button type="submit" class="text-rose-500 hover:text-rose-700 font-medium text-xs bg-rose-50 hover:bg-rose-100 px-2 py-1 rounded transition-colors">
                                            Remove
                                        </button>
                                    </form>
                                </td>
                            </tr>
                            @endforeach
                        </tbody>
                    </table>
                </div>
                @endif
            </div>
        </div>
    </div>

@endsection
