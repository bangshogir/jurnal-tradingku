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
        'swap',
        'commission',
        'magic_number',
        'comment',
        'strategy',
        'timeframe',
    ];

    protected $casts = [
        'open_time' => 'datetime',
        'close_time' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function getRrRatioAttribute()
    {
        if (empty($this->entry_price) || empty($this->sl_price) || empty($this->tp_price)) {
            return null;
        }

        $risk = abs($this->entry_price - $this->sl_price);
        $reward = abs($this->tp_price - $this->entry_price);

        if ($risk == 0) return null;

        $ratio = round($reward / $risk, 1);
        return "1:{$ratio}";
    }
}
