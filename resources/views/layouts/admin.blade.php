<!DOCTYPE html>
<html lang="id">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>@yield('title', 'Dashboard') — Jurnal Tradingku</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <script>
        tailwind.config = {
            theme: {
                extend: {
                    fontFamily: {
                        sans: ['Inter', 'sans-serif']
                    },
                    colors: {
                        sidebar: {
                            DEFAULT: '#ffffff',
                            hover: '#f8fafc',
                            active: '#f1f5f9'
                        },
                        brand: {
                            50: '#eff6ff',
                            100: '#dbeafe',
                            500: '#6366f1', // Indigo/Purple accent
                            600: '#4f46e5',
                        }
                    }
                }
            }
        }
    </script>
    <style type="text/tailwindcss">
        body {
            font-family: 'Inter', sans-serif;
        }

        .sidebar-link {
            @apply flex items-center gap-3 px-4 py-2.5 rounded-xl text-slate-500 text-sm font-medium transition-all duration-200 hover:bg-slate-50 hover:text-slate-900;
        }

        .sidebar-link.active {
            @apply bg-slate-100 text-brand-600 font-semibold;
        }

        .sidebar-icon {
            @apply w-5 h-5 opacity-70 transition-opacity;
        }

        .sidebar-link:hover .sidebar-icon,
        .sidebar-link.active .sidebar-icon {
            @apply opacity-100;
        }
    </style>
    {{-- Pure CSS for sidebar responsive behavior --}}
    <style>
        /* Sidebar base: fixed off-screen on mobile */
        .admin-sidebar {
            position: fixed;
            top: 0;
            left: 0;
            bottom: 0;
            z-index: 50;
            width: 16rem;
            transform: translateX(-100%);
            transition: transform 0.3s ease;
            background: #ffffff;
            border-right: 1px solid #e2e8f0;
            display: flex;
            flex-direction: column;
            flex-shrink: 0;
        }

        /* Sidebar open state (toggled by JS on mobile) */
        .admin-sidebar.sidebar-open {
            transform: translateX(0);
        }

        /* Sidebar overlay */
        #sidebar-overlay {
            display: none;
            position: fixed;
            inset: 0;
            background: rgba(15, 23, 42, 0.5);
            z-index: 40;
            backdrop-filter: blur(4px);
        }

        /* Hamburger button: visible on mobile */
        #mobile-menu-btn {
            display: flex;
            align-items: center;
            justify-content: center;
        }

        /* Desktop: sidebar always visible, not fixed */
        @media (min-width: 1024px) {
            .admin-sidebar {
                position: relative;
                transform: translateX(0);
                flex-shrink: 0;
            }
            #sidebar-overlay {
                display: none !important;
            }
            #mobile-menu-btn {
                display: none !important;
            }
        }
    </style>
</head>

<body class="bg-slate-100 text-slate-800">

    <div class="flex h-screen overflow-hidden bg-slate-50">

        <!-- Sidebar Overlay -->
        <div id="sidebar-overlay" onclick="closeSidebar()"></div>

        <aside id="sidebar" class="admin-sidebar">

            {{-- Logo --}}
            <div class="flex items-center gap-3 px-6 py-6 border-b border-transparent">
                {{-- Candlestick / Chart Icon --}}
                <div
                    class="w-9 h-9 bg-gradient-to-br from-brand-500 to-indigo-600 rounded-xl flex items-center justify-center text-white shadow-md shadow-brand-500/30">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.2"
                            d="M7 12l3-3 3 3 4-4M8 21l4-4 4 4M3 4h18M4 4h16v12a1 1 0 01-1 1H5a1 1 0 01-1-1V4z" />
                    </svg>
                </div>
                <div class="flex flex-col">
                    <span class="text-slate-900 font-extrabold text-[20px] leading-none tracking-tight">
                        Jurnal<span class="text-brand-600">.</span>
                    </span>
                    <span class="text-[10px] uppercase tracking-widest text-slate-400 font-bold mt-0.5">Trading</span>
                </div>
            </div>

            {{-- Nav Menu --}}
            <nav class="flex-1 px-4 py-4 space-y-1.5 overflow-y-auto">
                <p class="text-[11px] text-slate-400 font-semibold px-2 mb-3 tracking-wider uppercase">General</p>

                @if (auth()->user()->isAdmin())
                    <a href="{{ route('admin.dashboard') }}"
                        class="sidebar-link {{ request()->routeIs('admin.dashboard') ? 'active' : '' }}">
                        <svg class="sidebar-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8"
                                d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
                        </svg>
                        Admin Dashboard
                    </a>
                @endif

                <a href="{{ route('dashboard') }}"
                    class="sidebar-link {{ request()->routeIs('dashboard') ? 'active' : '' }}">
                    <svg class="sidebar-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8"
                            d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
                    </svg>
                    Dashboard
                </a>

                @if (!auth()->user()->isAdmin())
                    <p class="text-[11px] text-slate-400 font-semibold px-2 mt-6 mb-3 tracking-wider uppercase">Trading
                        Menu</p>
                    <a href="{{ route('dashboard.open') }}"
                        class="sidebar-link {{ request()->routeIs('dashboard.open') ? 'active' : '' }}">
                        <svg class="sidebar-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8"
                                d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
                        </svg>
                        Open Orders
                        @php
                            $openOrdersCount = \App\Models\TradingLog::where('user_id', auth()->id())
                                ->whereIn('type', ['buy', 'sell'])
                                ->count();
                        @endphp
                        @if ($openOrdersCount > 0)
                            <span
                                class="ml-auto text-[10px] font-bold bg-brand-100 text-brand-700 px-2 py-0.5 rounded-full">{{ $openOrdersCount }}</span>
                        @endif
                    </a>

                    <a href="{{ route('dashboard.pending') }}"
                        class="sidebar-link {{ request()->routeIs('dashboard.pending') ? 'active' : '' }}">
                        <svg class="sidebar-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8"
                                d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                        </svg>
                        Pending Orders
                        @php
                            $pendingOrdersCount = \App\Models\TradingLog::where('user_id', auth()->id())
                                ->whereIn('type', ['buy_limit', 'sell_limit', 'buy_stop', 'sell_stop'])
                                ->count();
                        @endphp
                        @if ($pendingOrdersCount > 0)
                            <span
                                class="ml-auto text-[10px] font-bold bg-slate-200 text-slate-700 px-2 py-0.5 rounded-full">{{ $pendingOrdersCount }}</span>
                        @endif
                    </a>
                @endif

                <p class="text-[11px] text-slate-400 font-semibold px-2 mt-6 mb-3 tracking-wider uppercase">Settings</p>
                <div class="sidebar-link opacity-50 cursor-not-allowed">
                    <svg class="sidebar-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8"
                            d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8"
                            d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    </svg>
                    Settings
                </div>
            </nav>

            {{-- User Info --}}
            <div class="px-4 py-4 mt-auto">
                <form method="POST" action="{{ route('logout') }}">
                    @csrf
                    <button type="submit"
                        class="w-full flex items-center gap-3 px-4 py-2.5 rounded-xl text-slate-500 text-sm font-medium hover:bg-red-50 hover:text-red-600 transition-all duration-200">
                        <svg class="sidebar-icon text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8"
                                d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
                        </svg>
                        Log out
                    </button>
                </form>

                <div class="flex items-center gap-3 mt-4 px-2">
                    <img src="https://ui-avatars.com/api/?name={{ urlencode(auth()->user()->name) }}&background=f1f5f9&color=475569"
                        class="w-9 h-9 rounded-full" alt="Avatar">
                    <div class="flex-1 min-w-0">
                        <p class="text-slate-700 text-sm font-semibold truncate">{{ auth()->user()->name }}</p>
                        <p class="text-slate-400 text-xs truncate">{{ auth()->user()->email }}</p>
                    </div>
                </div>
            </div>
        </aside>

        {{-- ═══════════════════════════════════════ MAIN AREA ═══════════════════════════════════════ --}}
        <div class="flex-1 flex flex-col overflow-hidden">

            {{-- HEADER --}}
            <header
                class="bg-white/80 backdrop-blur-md border-b border-slate-200 flex items-center justify-between px-4 lg:px-8 py-4 flex-shrink-0 z-10 sticky top-0">
                <div class="flex items-center gap-2 text-sm">
                    <button id="mobile-menu-btn" class="text-slate-500 hover:text-brand-600 transition-colors p-1 mr-1">
                        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"></path>
                        </svg>
                    </button>
                    <button class="desktop-only-btn text-slate-400 hover:text-slate-600 transition-colors p-1">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                d="M15 19l-7-7 7-7"></path>
                        </svg>
                    </button>
                    <button class="text-slate-400 hover:text-slate-600 transition-colors p-1 mr-2">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7">
                            </path>
                        </svg>
                    </button>
                    <span class="text-slate-400">Pages <span class="mx-1">/</span></span>
                    <span class="font-semibold text-slate-800">@yield('page-title', 'Dashboard')</span>
                </div>

                <div class="flex items-center gap-6">
                    {{-- Search Bar --}}
                    <div class="relative hidden py-1 md:block w-64 lg:w-80">
                        <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                            <svg class="h-4 w-4 text-slate-400" fill="none" stroke="currentColor"
                                viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                    d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
                            </svg>
                        </div>
                        <input type="text"
                            class="block w-full pl-10 pr-3 py-2 border border-slate-200 rounded-full leading-5 bg-slate-50 placeholder-slate-400 focus:outline-none focus:bg-white focus:ring-1 focus:ring-brand-500 focus:border-brand-500 sm:text-sm transition-colors"
                            placeholder="Search transactions, pairs...">
                    </div>

                    {{-- Icons --}}
                    <div class="flex items-center gap-3">
                        <button class="text-slate-400 hover:text-slate-600 transition-colors">
                            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                    d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z">
                                </path>
                            </svg>
                        </button>
                        <button class="text-slate-400 hover:text-slate-600 transition-colors relative">
                            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                    d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9">
                                </path>
                            </svg>
                            <span
                                class="absolute top-0 right-0 block h-2 w-2 rounded-full bg-red-400 ring-2 ring-white"></span>
                        </button>
                        <img src="https://ui-avatars.com/api/?name={{ urlencode(auth()->user()->name) }}&background=f1f5f9&color=475569"
                            class="w-8 h-8 rounded-full ml-1" alt="Avatar">
                    </div>
                </div>
            </header>

            {{-- PAGE CONTENT --}}
            <main class="flex-1 overflow-y-auto p-4 lg:p-8">
                @if (session('success'))
                    <div
                        class="mb-6 px-4 py-3 bg-green-50 border border-green-200 text-green-700 rounded-xl text-sm font-medium shadow-sm">
                        {{ session('success') }}</div>
                @endif
                @yield('content')
            </main>

        </div>
    </div>

    <!-- Mobile Sidebar Toggle Script -->
    <script>
        function openSidebar() {
            document.getElementById('sidebar').classList.add('sidebar-open');
            document.getElementById('sidebar-overlay').style.display = 'block';
        }
        function closeSidebar() {
            document.getElementById('sidebar').classList.remove('sidebar-open');
            document.getElementById('sidebar-overlay').style.display = 'none';
        }
        document.addEventListener('DOMContentLoaded', function() {
            var btn = document.getElementById('mobile-menu-btn');
            if (btn) {
                btn.addEventListener('click', function() {
                    var sidebar = document.getElementById('sidebar');
                    if (sidebar.classList.contains('sidebar-open')) {
                        closeSidebar();
                    } else {
                        openSidebar();
                    }
                });
            }
        });
    </script>
</body>

</html>
