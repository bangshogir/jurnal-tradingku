<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class TelegramRouting extends Model
{
    protected $fillable = [
        'user_id',
        'account_number',
        'telegram_chat_id',
        'description',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
