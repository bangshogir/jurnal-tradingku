encana Implementasi: Sistem Jurnal Trading Multi-User (SaaS)
Visi: Mengubah aplikasi jurnal trading dari single-user menjadi aplikasi multi-tenant (multi-user) di mana setiap pengguna terdaftar memiliki jurnal trading dan kunci API Webhook mereka masing-masing, sehingga privasi data antar pengguna terjamin sepenuhnya.

Pendekatan Teknis
Identifikasi Pemilik Data: Menghubungkan log trading ke tabel users melalui Foreign Key (user_id).
Kunci API Pribadi: Menambahkan kolom webhook_token yang di-generate otomatis untuk setiap user, yang akan digunakan oleh pengiriman data EA MT5 untuk mengenali siapa pengirim datanya.
Isolasi Tampilan: Mengubah logika Controller agar hanya memunculkan data yang dimiliki oleh pengguna yang sedang Login (Auth::id()).
Modifikasi EA: Update skrip MQL5 untuk menerima input "Webhook Token" yang dimasukkan oleh sang pengguna di MT5 mereka saat melakukan instalasi bot.
Perubahan Konkret (Proposed Changes)
Struktur Database & Relasi
[NEW] database/migrations/xxxx_xx_xx_add_user_id_and_token_to_trading_logs_table.php

Menambah kolom user_id (foreign key ke tabel users).
Menambah relasi "cascade on delete" agar ketika sebuah akun dihapus, riwayat tradingnya ikut terhapus otomatis.
[NEW] database/migrations/xxxx_xx_xx_add_webhook_token_to_users_table.php

Menambahkan kolom string bersifat unik bernama webhook_token di tabel users (dapat berupa string alfanumerik panjang seperti UUID/Str::random).
[MODIFY] 
app/Models/User.php

Tambahkan properti $fillable untuk webhook_token.
Buat relasi One to Many dengan nama tradingLogs() 
(return $this->hasMany(TradingLog::class))
.
Tambahkan Boot listener untuk otomatis men-generate secret key/token webhook_token acak ketika akun baru di regitrasi.
[MODIFY] 
app/Models/TradingLog.php

Tambahkan properti $fillable untuk user_id.
Buat relasi Belongs To dengan nama 
user()
 
(return $this->belongsTo(User::class))
.
Webhook API
[MODIFY] app/Http/Controllers/Api/WebhookController.php (Catatan: file ini akan di update berdasarkan controller webhook yang ada saat ini)

Endpoint webhook (MQL5 -> Laravel) wajib membutuhkan sebuah parameter payload token.
Dalam logic penerimaan request:
Cari 
User
 berdasarkan webhook_token yang dikirim dari EA.
Jika token tidak ditemukan, tolak akses dan return HTTP 401 Unauthorized.
Jika berhasil ditemukan, simpan log trading dengan user_id yang sesuai dari user tersebut.
Controller & View
[MODIFY] 
app/Http/Controllers/DashboardController.php

Ubah pengambilan data keseluruhan TradingLog::all() atau TradingLog::get() menjadi TradingLog::where('user_id', Auth::id())->get() untuk mengamankan data pengguna satu dengan lainnya.
[MODIFY] 
resources/views/dashboard.blade.php
 atau 
resources/views/layouts/admin.blade.php

Tampilkan API Key/Webhook Token sang pengguna di salah satu halaman profile agar mereka dapat menyalin token tersebut ke pengaturan EA MetaTrader 5 mereka.
MQL5 MetaTrader Script
[MODIFY] 
TradingJournalWebhook.mq5
 (Atau script pengirim data MQL5 yang digunakan)

Tambahkan parameter Input (di awal variabel EA) untuk Webhook Token: input string InpWebhookToken = ""; // Webhook Auth Token
Validasi awal (OnInit) untuk memastikan InpWebhookToken tidak kosong.
Modifikasi fungsi pengiriman CURL JSON, tambahkan data "token": InpWebhookToken ke body request atau via HTTP Headers Authorization: Bearer <InpWebhookToken>.
Rencana Verifikasi (Verification Plan)
Pengaturan Database: Jalankan migrasi dan pastikan data relasi tersambung dengan sukses.
Pendaftaran: Buat satu akun uji coba baru, pastikan webhook_token unik untuk akun itu langsung ter-generate dan di tersimpan di Database.
Simulasi EA API: Kirimkan Postman Request berisikan data EA menggunakan token milik Akun A dan token milik akun B.
Isolasi Dashboard: Pastikan Akun A dan Akun B hanya bisa melihat trades yang dimasukkan sesuai Token mereka di Dashboard UI masing-masing.