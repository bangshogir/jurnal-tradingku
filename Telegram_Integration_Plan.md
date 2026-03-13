# Rencana Integrasi Notifikasi Telegram (Trading Journal)

## 📌 1. Tujuan
Mengirimkan notifikasi langsung secara *real-time* ke handphone (via Telegram) setiap kali ada aktivitas transaksi di MetaTrader (Open Posisi, Penutupan Posisi/Take Profit/Stop Loss, dan Pending Order).

## 🏗️ 2. Arsitektur Alur Sistem
Sesuai dengan kesepakatan, kita akan menggunakan arsitektur tersentralisasi:
> **MetaTrader (EA)** ➡️ **Web Server Jurnal (Laravel)** ➡️ **Telegram Bot API** ➡️ **Handphone User**

**Keuntungan Alur Ini:**
* Mengurangi beban proses di MetaTrader (EA tetap ringan tanpa perlu HTTP Request ekstra ke server Telegram).
* Format pesan bisa dikombinasikan dengan database. Misalnya: menotifikasikan "Balance Anda sekarang: $10,050" yang dihitung dari total saldo terakhir di Web App secara real-time.
* Lebih aman (Token Telegram disimpan rahasia di server, bukan di sisi klien/MT4 yang rentan dicuri bila EA tersebar).

## 🛠️ 3. Prasyarat Integrasi
1. **Telegram Bot Token**: Dibuat secara gratis melalui [BotFather](https://t.me/BotFather) di aplikasi Telegram Anda.
2. **Chat ID Pengguna**: Bisa didapatkan melalui bot seperti `@userinfobot` atau `@RawDataBot` di Telegram. (Ini menentukan apakah pesan dikirim ke Chat Pribadi Anda, atau ke Chat Grup trader Anda).

## 🚀 4. Langkah-Langkah Implementasi

### Tahap 1: Konfigurasi Laravel Lingkungan (.env)
Menambahkan variabel lingkungan agar konfigurasi rahasia Anda mudah diganti sewaktu-waktu tanpa membongkar kode:
```env
TELEGRAM_BOT_TOKEN="123456789:ABCDefGhiJkLmnOpQrSTuVWxYz"
TELEGRAM_CHAT_ID="987654321"
```

### Tahap 2: Pembuatan Telegram Service (Laravel)
Membuat helper interaksi HTTP statis (`app/Services/TelegramService.php`) yang memanfaatkan `Illuminate\Support\Facades\Http` ke Endpoint API resmi:
`https://api.telegram.org/bot<TOKEN>/sendMessage`

### Tahap 3: Pemanggilan Notifikasi di Webhook Controller
Menyelipkan trigger Telegram ke dalam `TradingWebhookController.php` (tepatnya di dalam fungsi `store()`). Pengiriman notifikasi ke Telegram hanya akan ditembak ketika database sukses di-update oleh sinyal MetaTrader.

### Tahap 4: Formatting Pesan (Message Templates)
Membuat 3 template notifikasi yang estetis menggunakan parse mode HTML yang sangat mudah dibaca/bersih:

**✅ 1. Pesanan Baru (Deal Open)**
```text
🚨 <b>NEW ORDER EXECUTED</b> 🚨
🏷️ Pair: XAUUSD
📈 Type: BUY
🎯 Entry: 2150.00
🛑 SL: 2145.00 | 💰 TP: 2160.00
⚖️ Lot: 0.10
---
⏳ Waktu: 13-03-2026 10:45:00
```

**🏁 2. Transaksi Selesai (Deal Close)**
```text
🏁 <b>TRADE CLOSED</b> 🏁
🏷️ Pair: EURUSD
📉 Type: SELL
🚪 Close Price: 1.0500
💲 Profit/Loss: +$25.50 ✅
---
💼 Balance Sekarang: $1.025.50
```

**⏳ 3. Pending Order Dibuat/Dibatalkan**
```text
📌 <b>PENDING ORDER PLACED</b> 📌
🏷️ Pair: GBPUSD
📈 Type: BUY LIMIT
🎯 Target Entry: 1.2500
```

## 🔄 5. Verifikasi dan Pengujian
* **Langkah 1:** Menjalankan `php artisan tinker` untuk menguji trigger statis layanan Telegram.
* **Langkah 2:** Mendesimulasikan *Place Order* melalui form *Risk Panel EA* di akun demo untuk memastikan waktu tempuh (latency) notifikasi di Telegram HP kurang dari 2 detik.
