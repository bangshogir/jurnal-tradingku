<!DOCTYPE html>
<html lang="id">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Register — Jurnal Tradingku</title>
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
            <p class="text-slate-400 text-sm mt-1">Buat akun baru</p>
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

            <form method="POST" action="{{ route('register') }}" class="space-y-5">
                @csrf

                <div>
                    <label class="block text-sm font-medium text-slate-300 mb-1.5">Nama Lengkap</label>
                    <input type="text" name="name" value="{{ old('name') }}" required autofocus
                        class="w-full bg-slate-800 border border-slate-700 text-white placeholder-slate-500 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-600 focus:border-transparent transition"
                        placeholder="Nama kamu">
                </div>

                <div>
                    <label class="block text-sm font-medium text-slate-300 mb-1.5">Email</label>
                    <input type="email" name="email" value="{{ old('email') }}" required
                        class="w-full bg-slate-800 border border-slate-700 text-white placeholder-slate-500 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-600 focus:border-transparent transition"
                        placeholder="email@kamu.com">
                </div>

                <div>
                    <label class="block text-sm font-medium text-slate-300 mb-1.5">Password</label>
                    <input type="password" name="password" required
                        class="w-full bg-slate-800 border border-slate-700 text-white placeholder-slate-500 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-600 focus:border-transparent transition"
                        placeholder="Min. 8 karakter">
                </div>

                <div>
                    <label class="block text-sm font-medium text-slate-300 mb-1.5">Konfirmasi Password</label>
                    <input type="password" name="password_confirmation" required
                        class="w-full bg-slate-800 border border-slate-700 text-white placeholder-slate-500 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-600 focus:border-transparent transition"
                        placeholder="Ulangi password">
                </div>

                <button type="submit"
                    class="w-full bg-blue-600 hover:bg-blue-700 text-white font-semibold py-2.5 px-4 rounded-xl transition-all duration-200 shadow-lg shadow-blue-900/40 text-sm">
                    Daftar
                </button>
            </form>

            <p class="text-center text-slate-500 text-sm mt-5">
                Sudah punya akun?
                <a href="{{ route('login') }}" class="text-blue-400 hover:text-blue-300 font-medium">Masuk</a>
            </p>
        </div>

        <p class="text-center text-slate-600 text-xs mt-6">
            Jurnal Tradingku &copy; {{ date('Y') }}
        </p>
    </div>

</body>

</html>
