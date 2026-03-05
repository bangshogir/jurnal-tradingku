<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

use App\Http\Controllers\Api\TradingWebhookController;

Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');

// MT5 Webhook Endpoint
Route::post('/webhook/trading-log', [TradingWebhookController::class, 'store']);
