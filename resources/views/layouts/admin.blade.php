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
                        brand: {
                            50: '#eff6ff',
                            100: '#dbeafe',
                            500: '#6366f1',
                            600: '#4f46e5',
                        }
                    }
                }
            }
        }
    </script>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Inter', sans-serif; background: #f8fafc; color: #1e293b; }

        /* ===== APP SHELL ===== */
        .app-shell {
            display: flex;
            height: 100dvh;
            overflow: hidden;
        }

        /* ===== SIDEBAR ===== */
        .sidebar {
            position: fixed;
            top: 0;
            left: 0;
            bottom: 0;
            z-index: 50;
            width: 250px;
            height: 100dvh;
            background: #ffffff;
            border-right: 1px solid #e2e8f0;
            display: flex;
            flex-direction: column;
            transform: translateX(-100%);
            transition: transform 0.25s ease;
            overflow-y: auto;
        }
        .sidebar.is-open {
            transform: translateX(0);
            box-shadow: 4px 0 20px rgba(0,0,0,.12);
        }

        /* ===== OVERLAY ===== */
        .sidebar-overlay {
            display: none;
            position: fixed;
            inset: 0;
            background: rgba(15,23,42,.5);
            z-index: 40;
        }
        .sidebar-overlay.is-open { display: block; }

        /* ===== MAIN AREA ===== */
        .main-area {
            flex: 1;
            display: flex;
            flex-direction: column;
            overflow: hidden;
            min-width: 0;
        }

        /* ===== TOPBAR ===== */
        .topbar {
            background: rgba(255,255,255,.85);
            backdrop-filter: blur(12px);
            border-bottom: 1px solid #e2e8f0;
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 0.75rem 1rem;
            position: sticky;
            top: 0;
            z-index: 10;
            flex-shrink: 0;
        }

        /* ===== HAMBURGER ===== */
        .hamburger {
            display: flex;
            align-items: center;
            justify-content: center;
            width: 36px;
            height: 36px;
            border-radius: 8px;
            border: 1px solid #e2e8f0;
            background: #f8fafc;
            cursor: pointer;
            color: #475569;
            flex-shrink: 0;
            margin-right: 0.75rem;
        }
        .hamburger:hover { background:#eff6ff; color:#4f46e5; border-color:#c7d2fe; }

        /* ===== SIDEBAR LINKS ===== */
        .sidebar-link {
            display: flex;
            align-items: center;
            gap: 10px;
            padding: 9px 14px;
            border-radius: 10px;
            font-size: 13.5px;
            font-weight: 500;
            color: #64748b;
            text-decoration: none;
            transition: all .15s;
            margin: 1px 0;
        }
        .sidebar-link:hover { background:#f1f5f9; color:#0f172a; }
        .sidebar-link.active { background:#eff6ff; color:#4f46e5; font-weight:600; }
        .sidebar-link svg { width:18px; height:18px; flex-shrink:0; opacity:.7; }
        .sidebar-link:hover svg, .sidebar-link.active svg { opacity:1; }

        .sidebar-section-label {
            font-size: 10.5px;
            font-weight: 700;
            color: #94a3b8;
            letter-spacing: .06em;
            text-transform: uppercase;
            padding: 0 14px;
            margin: 20px 0 6px;
        }

        /* ===== PAGE CONTENT ===== */
        .page-content {
            flex: 1;
            overflow-y: auto;
            padding: 1rem;
        }

        /* ===== DESKTOP ===== */
        @media (min-width: 1024px) {
            .sidebar {
                position: relative;
                transform: translateX(0);
                box-shadow: none;
                flex-shrink: 0;
            }
            .sidebar-overlay { display: none !important; }
            .hamburger { display: none !important; }
            .page-content { padding: 2rem; }
            .topbar { padding: 0.875rem 2rem; }
        }
    </style>
</head>

<body>

    <!-- Overlay -->
    <div class="sidebar-overlay" id="sidebarOverlay" onclick="closeSidebar()"></div>

    <div class="app-shell">

        <!-- ============ SIDEBAR ============ -->
        <aside class="sidebar" id="sidebar">

            <!-- Logo -->
            <div style="padding:20px 18px 16px; border-bottom:1px solid #f1f5f9; flex-shrink:0;">
                <div style="display:flex;align-items:center;gap:10px;">
                    <div style="width:36px;height:36px;background:linear-gradient(135deg,#6366f1,#4f46e5);border-radius:10px;display:flex;align-items:center;justify-content:center;flex-shrink:0;">
                        <svg width="18" height="18" fill="none" stroke="white" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.2" d="M7 12l3-3 3 3 4-4M8 21l4-4 4 4M3 4h18M4 4h16v12a1 1 0 01-1 1H5a1 1 0 01-1-1V4z"/>
                        </svg>
                    </div>
                    <div>
                        <div style="font-weight:800;font-size:17px;line-height:1;color:#0f172a;">Jurnal<span style="color:#4f46e5;">.</span></div>
                        <div style="font-size:9.5px;font-weight:700;letter-spacing:.1em;color:#94a3b8;text-transform:uppercase;margin-top:2px;">Trading</div>
                    </div>
                </div>
            </div>

            <!-- Nav -->
            <nav style="flex:1;padding:10px 10px 0;">
                <div class="sidebar-section-label">General</div>

                @if (auth()->user()->isAdmin())
                    <a href="{{ route('admin.dashboard') }}"
                        class="sidebar-link {{ request()->routeIs('admin.dashboard') ? 'active' : '' }}">
                        <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8"
                                d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"/>
                        </svg>
                        Admin Dashboard
                    </a>
                @endif

                <a href="{{ route('dashboard') }}"
                    class="sidebar-link {{ request()->routeIs('dashboard') ? 'active' : '' }}">
                    <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8"
                            d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"/>
                    </svg>
                    Dashboard
                </a>

                @if (!auth()->user()->isAdmin())
                    <div class="sidebar-section-label">Trading Menu</div>

                    <a href="{{ route('dashboard.open') }}"
                        class="sidebar-link {{ request()->routeIs('dashboard.open') ? 'active' : '' }}">
                        <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"/>
                        </svg>
                        Open Orders
                        @php
                            $openOrdersCount = \App\Models\TradingLog::where('user_id', auth()->id())
                                ->whereIn('type', ['buy', 'sell'])->count();
                        @endphp
                        @if ($openOrdersCount > 0)
                            <span style="margin-left:auto;font-size:10px;font-weight:700;background:#eff6ff;color:#4f46e5;padding:1px 7px;border-radius:99px;">{{ $openOrdersCount }}</span>
                        @endif
                    </a>

                    <a href="{{ route('dashboard.pending') }}"
                        class="sidebar-link {{ request()->routeIs('dashboard.pending') ? 'active' : '' }}">
                        <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                        </svg>
                        Pending Orders
                        @php
                            $pendingOrdersCount = \App\Models\TradingLog::where('user_id', auth()->id())
                                ->whereIn('type', ['buy_limit', 'sell_limit', 'buy_stop', 'sell_stop'])->count();
                        @endphp
                        @if ($pendingOrdersCount > 0)
                            <span style="margin-left:auto;font-size:10px;font-weight:700;background:#f1f5f9;color:#64748b;padding:1px 7px;border-radius:99px;">{{ $pendingOrdersCount }}</span>
                        @endif
                    </a>
                @endif

                <div class="sidebar-section-label">Settings</div>
                <div class="sidebar-link" style="opacity:.45;cursor:not-allowed;">
                    <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8"
                            d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/>
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                    </svg>
                    Settings
                </div>
            </nav>

            <!-- User/Logout -->
            <div style="padding:12px 10px;border-top:1px solid #f1f5f9;flex-shrink:0;">
                <form method="POST" action="{{ route('logout') }}">
                    @csrf
                    <button type="submit" class="sidebar-link" style="width:100%;border:none;background:none;cursor:pointer;text-align:left;color:#ef4444;" onmouseover="this.style.background='#fef2f2'" onmouseout="this.style.background='none'">
                        <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" style="width:18px;height:18px;flex-shrink:0;">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8"
                                d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"/>
                        </svg>
                        Log out
                    </button>
                </form>

                <div style="display:flex;align-items:center;gap:10px;padding:8px 14px 4px;">
                    <img src="https://ui-avatars.com/api/?name={{ urlencode(auth()->user()->name) }}&background=eff6ff&color=4f46e5&bold=true"
                        style="width:32px;height:32px;border-radius:50%;flex-shrink:0;" alt="Avatar">
                    <div style="min-width:0;">
                        <div style="font-size:13px;font-weight:600;color:#1e293b;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">{{ auth()->user()->name }}</div>
                        <div style="font-size:11px;color:#94a3b8;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">{{ auth()->user()->email }}</div>
                    </div>
                </div>
            </div>
        </aside>

        <!-- ============ MAIN AREA ============ -->
        <div class="main-area">

            <!-- TOPBAR -->
            <header class="topbar">
                <div style="display:flex;align-items:center;min-width:0;">
                    <!-- Hamburger (mobile only) -->
                    <button class="hamburger" id="hamburgerBtn" onclick="openSidebar()" aria-label="Open menu">
                        <svg width="18" height="18" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.2" d="M4 6h16M4 12h16M4 18h16"/>
                        </svg>
                    </button>

                    <div style="min-width:0;">
                        <div style="font-size:11px;color:#94a3b8;display:flex;align-items:center;gap:4px;">
                            <span>Pages</span>
                            <span>/</span>
                            <span style="color:#0f172a;font-weight:600;">@yield('page-title', 'Dashboard')</span>
                        </div>
                    </div>
                </div>

                <div style="display:flex;align-items:center;gap:10px;flex-shrink:0;">
                    <!-- Search (hidden on mobile) -->
                    <div style="position:relative;display:none;" class="hidden lg:block">
                        <svg style="position:absolute;left:10px;top:50%;transform:translateY(-50%);color:#94a3b8;" width="15" height="15" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
                        </svg>
                        <input type="text" placeholder="Search..."
                            style="width:220px;padding:7px 12px 7px 32px;border:1px solid #e2e8f0;border-radius:99px;font-size:13px;background:#f8fafc;outline:none;color:#1e293b;">
                    </div>

                    <!-- Notification -->
                    <button style="position:relative;width:34px;height:34px;border-radius:8px;border:1px solid #e2e8f0;background:#f8fafc;display:flex;align-items:center;justify-content:center;cursor:pointer;color:#64748b;">
                        <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"/>
                        </svg>
                        <span style="position:absolute;top:5px;right:5px;width:7px;height:7px;background:#f43f5e;border-radius:50%;border:2px solid white;"></span>
                    </button>

                    <!-- Avatar -->
                    <img src="https://ui-avatars.com/api/?name={{ urlencode(auth()->user()->name) }}&background=eff6ff&color=4f46e5&bold=true"
                        style="width:32px;height:32px;border-radius:50%;cursor:pointer;" alt="Avatar">
                </div>
            </header>

            <!-- PAGE CONTENT -->
            <main class="page-content">
                @if (session('success'))
                    <div style="margin-bottom:1.25rem;padding:12px 16px;background:#f0fdf4;border:1px solid #bbf7d0;color:#166534;border-radius:10px;font-size:13px;font-weight:500;">
                        {{ session('success') }}
                    </div>
                @endif
                @yield('content')
            </main>

        </div>
    </div>

    <script>
        function openSidebar() {
            document.getElementById('sidebar').classList.add('is-open');
            document.getElementById('sidebarOverlay').classList.add('is-open');
            document.body.style.overflow = 'hidden';
        }
        function closeSidebar() {
            document.getElementById('sidebar').classList.remove('is-open');
            document.getElementById('sidebarOverlay').classList.remove('is-open');
            document.body.style.overflow = '';
        }
    </script>

</body>

</html>
