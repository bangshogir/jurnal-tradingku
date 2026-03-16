<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\Auth\AuthController;
use App\Http\Controllers\TelegramRoutingController; // Added for new routes

// ─── Auth Routes ────────────────────────────────────────────
Route::middleware('guest')->group(function () {
    Route::get('/login',     [AuthController::class, 'showLogin'])->name('login');
    Route::post('/login',    [AuthController::class, 'login']);
    Route::get('/register',  [AuthController::class, 'showRegister'])->name('register');
    Route::post('/register', [AuthController::class, 'register']);
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
    Route::get('/settings', [DashboardController::class, 'settings'])->name('settings');
    Route::post('/profile/telegram', [DashboardController::class, 'updateTelegram'])->name('profile.telegram');

    // Telegram Routing endpoints
    Route::post('/telegram-routings', [TelegramRoutingController::class, 'store'])->name('telegram-routings.store');
    Route::delete('/telegram-routings/{telegramRouting}', [TelegramRoutingController::class, 'destroy'])->name('telegram-routings.destroy');
});

// ─── Admin Routes ────────────────────────────────────────────
Route::middleware(['auth', 'role:admin'])->prefix('admin')->group(function () {
    Route::get('/', [\App\Http\Controllers\AdminController::class, 'index'])->name('admin.dashboard');
});

