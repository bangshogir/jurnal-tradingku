<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\TelegramRouting;

class TelegramRoutingController extends Controller
{
    public function store(Request $request)
    {
        $request->validate([
            'account_number'   => 'required|string|max:50',
            'telegram_chat_id' => 'required|string|max:50',
            'description'      => 'nullable|string|max:255',
        ]);

        try {
            TelegramRouting::create([
                'user_id'          => auth()->id(),
                'account_number'   => $request->account_number,
                'telegram_chat_id' => $request->telegram_chat_id,
                'description'      => $request->description,
            ]);
            return back()->with('success', 'Telegram Routing added successfully.');
        } catch (\Exception $e) {
            return back()->with('error', 'Failed to add routing. Make sure the Account Number is unique for your account.');
        }
    }

    public function destroy(TelegramRouting $telegramRouting)
    {
        if ($telegramRouting->user_id !== auth()->id()) {
            abort(403);
        }

        $telegramRouting->delete();
        return back()->with('success', 'Telegram Routing deleted successfully.');
    }
}
