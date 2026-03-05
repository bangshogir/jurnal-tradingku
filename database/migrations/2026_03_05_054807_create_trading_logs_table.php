<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('trading_logs', function (Blueprint $table) {
            $table->id();
            $table->string('ticket_id')->unique();
            $table->string('symbol');
            $table->string('type'); // buy or sell
            $table->decimal('entry_price', 15, 5);
            $table->decimal('close_price', 15, 5);
            $table->decimal('sl_price', 15, 5)->nullable();
            $table->decimal('tp_price', 15, 5)->nullable();
            $table->decimal('lot_size', 10, 2);
            $table->decimal('profit_loss', 15, 2);
            $table->timestamp('open_time')->nullable();
            $table->timestamp('close_time')->nullable();
            $table->decimal('swap', 10, 2)->default(0);
            $table->decimal('commission', 10, 2)->default(0);
            $table->string('magic_number')->nullable();
            $table->text('comment')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('trading_logs');
    }
};
