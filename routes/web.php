<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\Auth\AuthController;
use App\Http\Controllers\TelegramRoutingController; // Added for new routes
use App\Http\Controllers\Auth\GoogleController;

// ─── Auth Routes ────────────────────────────────────────────
Route::middleware('guest')->group(function () {
    Route::get('/login',     [AuthController::class, 'showLogin'])->name('login');
    Route::post('/login',    [AuthController::class, 'login']);
    Route::get('/register',  [AuthController::class, 'showRegister'])->name('register');
    Route::post('/register', [AuthController::class, 'register']);
    
    // Google OAuth Routes
    Route::get('/auth/google', [GoogleController::class, 'redirectToGoogle'])->name('auth.google');
    Route::get('/auth/google/callback', [GoogleController::class, 'handleGoogleCallback']);
});

Route::post('/logout', [AuthController::class, 'logout'])->middleware('auth')->name('logout');

// ─── User Routes ─────────────────────────────────────────────
Route::middleware(['auth'])->group(function () {
    Route::get('/', function () {
        return redirect()->route('dashboard');
    });
    Route::get('/dashboard', [DashboardController::class, 'index'])->name('dashboard');
    Route::get('/pending', [DashboardController::class, 'pendingOrders'])->name('dashboard.pending');
    Route::get('/open', [DashboardController::class, 'openOrders'])->name('dashboard.open');
    Route::get('/reports', [DashboardController::class, 'reports'])->name('dashboard.reports');
    Route::get('/settings', [DashboardController::class, 'settings'])->name('settings');
    Route::post('/profile/telegram', [DashboardController::class, 'updateTelegram'])->name('profile.telegram');
    Route::delete('/trades/{id}/dismiss', [DashboardController::class, 'dismissTrade'])->name('trades.dismiss');

    // Telegram Routing endpoints
    Route::post('/telegram-routings', [TelegramRoutingController::class, 'store'])->name('telegram-routings.store');
    Route::delete('/telegram-routings/{telegramRouting}', [TelegramRoutingController::class, 'destroy'])->name('telegram-routings.destroy');

    // Telegram Debug (Test Notification)
    Route::get('/debug/telegram', function () {
        $user = auth()->user();
        $token = config('services.telegram.bot_token');
        $chatId = $user->telegram_chat_id;

        if (empty($token)) {
            return response()->json(['status' => 'error', 'message' => 'TELEGRAM_BOT_TOKEN is missing in .env']);
        }
        if (empty($chatId)) {
            return response()->json(['status' => 'error', 'message' => 'No Default Chat ID set for your account. Go to Settings and save a Chat ID first.']);
        }

        $result = \App\Services\TelegramService::sendMessage(
            "✅ <b>Test Notifikasi Berhasil!</b>\n🤖 Bot terhubung dengan Jurnal Trading.\n👤 User: <b>{$user->name}</b>",
            $chatId
        );

        if ($result) {
            return response()->json(['status' => 'ok', 'message' => 'Pesan test berhasil dikirim ke Chat ID: ' . $chatId]);
        }
        return response()->json(['status' => 'error', 'message' => 'Gagal mengirim pesan. Cek laravel.log untuk detail error dari Telegram API.']);
    })->name('debug.telegram');
});

// ─── Admin Routes ────────────────────────────────────────────
Route::middleware(['auth', 'role:admin'])->prefix('admin')->group(function () {
    Route::get('/', [\App\Http\Controllers\AdminController::class, 'index'])->name('admin.dashboard');
});

