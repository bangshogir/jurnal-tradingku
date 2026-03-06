<!DOCTYPE html>
<html lang="id">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Login — Jurnal Tradingku</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <style>
        body {
            font-family: 'Inter', sans-serif;
        }
    </style>
</head>

<body class="bg-slate-950 min-h-screen flex items-center justify-center">

    <div class="w-full max-w-md px-6">

        {{-- Logo --}}
        <div class="text-center mb-8">
            <div
                class="inline-flex items-center justify-center w-14 h-14 bg-blue-600 rounded-2xl shadow-lg shadow-blue-900/50 mb-4">
                <span class="text-2xl">📈</span>
            </div>
            <h1 class="text-2xl font-bold text-white">Jurnal Tradingku</h1>
            <p class="text-slate-400 text-sm mt-1">Masuk ke dashboard Anda</p>
        </div>

        {{-- Card --}}
        <div class="bg-slate-900 border border-slate-800 rounded-2xl p-8 shadow-2xl">

            @if ($errors->any())
                <div class="mb-5 px-4 py-3 bg-red-900/50 border border-red-700/50 rounded-xl">
                    @foreach ($errors->all() as $error)
                        <p class="text-red-400 text-sm">{{ $error }}</p>
                    @endforeach
                </div>
            @endif

            <form method="POST" action="{{ route('login') }}" class="space-y-5">
                @csrf

                <div>
                    <label class="block text-sm font-medium text-slate-300 mb-1.5">Email</label>
                    <input type="email" name="email" value="{{ old('email') }}" required autofocus
                        class="w-full bg-slate-800 border border-slate-700 text-white placeholder-slate-500 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-600 focus:border-transparent transition"
                        placeholder="admin@jurnaltradingku.my.id">
                </div>

                <div>
                    <label class="block text-sm font-medium text-slate-300 mb-1.5">Password</label>
                    <input type="password" name="password" required
                        class="w-full bg-slate-800 border border-slate-700 text-white placeholder-slate-500 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-600 focus:border-transparent transition"
                        placeholder="••••••••">
                </div>

                <div class="flex items-center">
                    <input type="checkbox" name="remember" id="remember"
                        class="rounded border-slate-600 bg-slate-800 text-blue-600">
                    <label for="remember" class="ml-2 text-sm text-slate-400">Ingat saya</label>
                </div>

                <button type="submit"
                    class="w-full bg-blue-600 hover:bg-blue-700 text-white font-semibold py-2.5 px-4 rounded-xl transition-all duration-200 shadow-lg shadow-blue-900/40 text-sm">
                    Masuk
                </button>
            </form>
        </div>

        <p class="text-center text-slate-400 text-sm mt-6 mb-2">
            Belum punya akun? <a href="{{ route('register') }}"
                class="text-blue-500 hover:text-blue-400 font-medium transition-colors">Daftar sekarang</a>
        </p>

        <p class="text-center text-slate-600 text-xs">
            Jurnal Tradingku &copy; {{ date('Y') }}
        </p>
    </div>

</body>

</html>
