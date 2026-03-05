Rencana Implementasi: Detail Jurnal Trading & Kartu Metrik
Tujuan dari pembaruan ini adalah untuk menyimpan lebih banyak detail dari setiap transaksi yang selesai serta menampilkan statistik kunci di Dashboard, termasuk PnL dan Jumlah Trade khusus untuk hari ini, serta Balance akun (yang disesuaikan dengan Cent account jika ada).

Proposed Changes
Database & Models
Untuk menyimpan detail tambahan seperti waktu buka/tutup posisi secara akurat dari MT5 (bukan hanya waktu webhook diterima), kita perlu menambahkan kolom waktu ke tabel.

[MODIFY] database/migrations/2026_03_05_054807_create_trading_logs_table.php
Menambahkan kolom open_time (timestamp) untuk mencatat waktu order dibuka di MT5.
Menambahkan kolom close_time (timestamp) untuk mencatat waktu order ditutup di MT5.
Menambahkan kolom sl_price (decimal) untuk menyimpan Stop Loss.
Menambahkan kolom tp_price (decimal) untuk menyimpan Take Profit.
[MODIFY] app/Models/TradingLog.php
Mendaftarkan kolom open_time, close_time, sl_price, dan tp_price ke dalam properti $fillable.
Mendaftarkan type casting untuk tanggal menggunakan sifat $casts.
MQL5 EA (MetaTrader 5)
[MODIFY] TradingJournalWebhook.mq5
Menambahkan logika untuk mengambil harga Stop Loss (ORDER_SL / DEAL_SL) dan Take Profit (ORDER_TP / DEAL_TP).
Menambahkan logika untuk mengambil waktu buka dan tutup transaksi menggunakan DEAL_TIME dan waktu dari position/order entry.
Mengubah format JSON payload agar menyertakan data SL, TP, Open Time, dan Close Time.
Backend API & Controller
[MODIFY] app/Http/Controllers/Api/TradingWebhookController.php
Memperbarui aturan validasi (validation rules) untuk menerima input sl_price, tp_price, open_time, dan close_time.
Memperbarui query TradingLog::create() untuk menyimpan 4 field baru tersebut ke dalam database.
[MODIFY] app/Http/Controllers/DashboardController.php
Mengambil total modal/balance terakhir dari request atau menghitung secara kumulatif. (Catatan: Kita bisa mendapatkan Current Balance langsung dari MT5 setiap kali webhook dikirim).
Menambahkan perhitungan:
Today Trade: Menghitung jumlah record yang close_time-nya adalah hari ini (sesuai zona waktu).
Today PnL: Menjumlahkan profit_loss untuk trade hari ini.
Balance: Mengambil Balance terakhir dari parameter terbaru MT5.
Frontend Dashboard
[MODIFY] resources/views/dashboard.blade.php
Kartu Metrik (Top Cards):
Memperbarui layout grid di atas tabel untuk menampung 6 kartu: Total Trade, Today Trade, All PnL, Today PnL, Win Rate, dan Balance.
Tabel Data:
Menyesuaikan kolom tabel dengan request: Time/Tanggal (Open & Close), Pair, Type, Volume, Entry Price, SL Price, TP Price, Profit/Loss.
Menambahkan warna (hijau/merah) untuk visualisasi SL/TP jika tersentuh (opsional berdasarkan jarak harga).
Verification Plan
Automated/Local Tests
Refresh Database: Jalankan php artisan migrate:fresh untuk menerapkan struktur tabel baru dan mengosongkan data lama (aman karena masih tahap development).
Compile EA MQL5: Tekan F7 di MetaEditor untuk memastikan kode bebas error.
Simulasi Webhook via Tinker/Postman: Menyuntikkan satu data dummy JSON yang berisi SL, TP, dan format waktu, lalu memastikan data tersimpan ke tabel.
Manual Verification
Tes Order MT5: Pasang pending order, lalu modifikasi SL dan TP-nya melalui platform MT5.
Close Order: Tutup order tersebut agar EA mengirimkan webhook trigger ke Laravel.
Cek Dashboard: Buka http://localhost:8000/dashboard, lalu pastikan:
Baris tabel baru berhasil muncul dengan nilai SL, TP, Entry yang presisi.
Kartu metrik Today Trade bertambah 1.
Kartu metrik Today PnL berubah sesuai hasil trade.
Kartu metrik Balance menampilkan saldo terakhir di MT5.