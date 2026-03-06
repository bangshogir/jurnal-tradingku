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
                            DEFAULT: '#0f172a',
                            hover: '#1e293b',
                            active: '#1d4ed8'
                        },
                    }
                }
            }
        }
    </script>
    <style>
        body {
            font-family: 'Inter', sans-serif;
        }

        .sidebar-link {
            @apply flex items-center gap-3 px-4 py-2.5 rounded-lg text-slate-400 text-sm font-medium transition-all duration-200 hover:bg-slate-800 hover:text-white;
        }

        .sidebar-link.active {
            @apply bg-blue-600 text-white shadow-lg shadow-blue-900/40;
        }
    </style>
</head>

<body class="bg-slate-100 text-slate-800">

    <div class="flex h-screen overflow-hidden">

        {{-- ═══════════════════════════════════════ SIDEBAR ═══════════════════════════════════════ --}}
        <aside id="sidebar" class="w-64 bg-slate-900 flex flex-col flex-shrink-0 transition-all duration-300">

            {{-- Logo --}}
            <div class="flex items-center gap-3 px-6 py-5 border-b border-slate-800">
                <div
                    class="w-8 h-8 bg-blue-600 rounded-lg flex items-center justify-center text-white font-bold text-sm">
                    📈</div>
                <div>
                    <span class="text-white font-bold text-sm leading-tight block">Jurnal Tradingku</span>
                    <span class="text-slate-500 text-xs">Admin Panel</span>
                </div>
            </div>

            {{-- Nav Menu --}}
            <nav class="flex-1 px-3 py-5 space-y-1 overflow-y-auto">
                <p class="text-xs text-slate-600 uppercase font-semibold px-4 mb-2 tracking-widest">Menu</p>

                @if (auth()->user()->isAdmin())
                    <a href="{{ route('admin.dashboard') }}"
                        class="sidebar-link {{ request()->routeIs('admin.dashboard') ? 'active' : '' }}">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
                        </svg>
                        Admin Dashboard
                    </a>
                @else
                    <a href="{{ route('dashboard') }}"
                        class="sidebar-link {{ request()->routeIs('dashboard') ? 'active' : '' }}">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
                        </svg>
                        Dashboard
                    </a>
                @endif

                <a href="{{ route('dashboard') }}"
                    class="sidebar-link {{ request()->routeIs('dashboard') ? 'active' : '' }}">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                            d="M9 17v-2m3 2v-4m3 4v-6m2 10H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                    </svg>
                    Trade History
                </a>

                @if (!auth()->user()->isAdmin())
                    <a href="{{ route('dashboard.pending') }}"
                        class="sidebar-link {{ request()->routeIs('dashboard.pending') ? 'active' : '' }}">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                        </svg>
                        Pending Orders
                    </a>
                @endif

                <div class="sidebar-link opacity-40 cursor-not-allowed">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                            d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                            d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    </svg>
                    Settings <span class="ml-auto text-xs bg-slate-700 px-1.5 py-0.5 rounded text-slate-400">Soon</span>
                </div>
            </nav>

            {{-- User Info --}}
            <div class="px-4 py-4 border-t border-slate-800">
                <div class="flex items-center gap-3">
                    <div
                        class="w-8 h-8 rounded-full bg-blue-600 flex items-center justify-center text-white text-sm font-bold">
                        {{ strtoupper(substr(auth()->user()->name, 0, 1)) }}
                    </div>
                    <div class="flex-1 min-w-0">
                        <p class="text-white text-sm font-medium truncate">{{ auth()->user()->name }}</p>
                        <p class="text-slate-500 text-xs truncate">{{ auth()->user()->email }}</p>
                    </div>
                </div>
                <form method="POST" action="{{ route('logout') }}" class="mt-3">
                    @csrf
                    <button type="submit"
                        class="w-full flex items-center justify-center gap-2 text-xs text-slate-400 hover:text-red-400 hover:bg-red-900/20 px-3 py-2 rounded-lg transition-all duration-200">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
                        </svg>
                        Logout
                    </button>
                </form>
            </div>
        </aside>

        {{-- ═══════════════════════════════════════ MAIN AREA ═══════════════════════════════════════ --}}
        <div class="flex-1 flex flex-col overflow-hidden">

            {{-- HEADER --}}
            <header
                class="bg-white shadow-sm border-b border-slate-200 flex items-center justify-between px-6 py-4 flex-shrink-0">
                <div>
                    <h1 class="text-lg font-semibold text-slate-800">@yield('page-title', 'Dashboard')</h1>
                    <p class="text-xs text-slate-400 mt-0.5">@yield('page-subtitle', 'Selamat datang kembali!')</p>
                </div>
                <div class="flex items-center gap-3">
                    <div class="text-right">
                        <p class="text-sm font-medium text-slate-700">{{ auth()->user()->name }}</p>
                        <span
                            class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium {{ auth()->user()->isAdmin() ? 'bg-indigo-100 text-indigo-700' : 'bg-emerald-100 text-emerald-700' }}">
                            {{ auth()->user()->isAdmin() ? 'Admin' : 'User' }}
                        </span>
                    </div>
                    <div
                        class="w-9 h-9 rounded-full bg-gradient-to-br from-blue-500 to-indigo-600 flex items-center justify-center text-white font-bold text-sm shadow">
                        {{ strtoupper(substr(auth()->user()->name, 0, 1)) }}
                    </div>
                </div>
            </header>

            {{-- PAGE CONTENT --}}
            <main class="flex-1 overflow-y-auto p-6">
                @if (session('success'))
                    <div class="mb-4 px-4 py-3 bg-green-50 border border-green-200 text-green-700 rounded-lg text-sm">
                        {{ session('success') }}</div>
                @endif
                @yield('content')
            </main>

        </div>
    </div>

</body>

</html>
