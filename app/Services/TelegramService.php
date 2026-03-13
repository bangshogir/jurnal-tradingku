<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class TelegramService
{
    /**
     * Send a formatted HTML text message to the Telegram Bot.
     */
    public static function sendMessage(string $message)
    {
        $token = env('TELEGRAM_BOT_TOKEN');
        $chatId = env('TELEGRAM_CHAT_ID');

        if (empty($token) || empty($chatId)) {
            Log::warning('Telegram Notification skipped: TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID is not configured in .env');
            return false;
        }

        $url = "https://api.telegram.org/bot{$token}/sendMessage";

        try {
            $response = Http::post($url, [
                'chat_id'    => $chatId,
                'text'       => $message,
                'parse_mode' => 'HTML',
                'disable_web_page_preview' => true,
            ]);

            if (!$response->successful()) {
                Log::error("Telegram API Error: " . $response->body());
                return false;
            }

            return true;
        } catch (\Exception $e) {
            Log::error("Telegram Service Exception: " . $e->getMessage());
            return false;
        }
    }
}
