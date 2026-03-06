<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class TradingLog extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'ticket_id',
        'symbol',
        'type',
        'entry_price',
        'close_price',
        'sl_price',
        'tp_price',
        'lot_size',
        'profit_loss',
        'open_time',
        'close_time',
        'profit_loss',
        'swap',
        'commission',
        'magic_number',
        'comment',
    ];

    protected $casts = [
        'open_time' => 'datetime',
        'close_time' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
