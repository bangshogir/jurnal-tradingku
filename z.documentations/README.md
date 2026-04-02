# Jurnal Tradingku - Automated Trading Journal System

Jurnal Tradingku adalah sistem jurnal trading otomatis yang menghubungkan aktivitas trading di MetaTrader 5 (MT5) dengan sebuah dashboard analisis berbasis web menggunakan Laravel 11. 

Setiap kali Anda menutup posisi trading (Take Profit, Stop Loss, atau Close Manual), sistem secara otomatis akan mengirimkan data transaksi tersebut ke server web untuk dicatat. Anda kemudian dapat melihat statistik performa trading Anda, seperti Win Rate, Profit Factor, dan history trade secara visual di Dashboard.

## 🚀 Fitur Utama
1. **Webhook Integrasi via MQL5**: Script Expert Advisor (EA) MT5 yang memonitor trading history dan mengirim data ke backend melalui Webhook.
2. **Dashboard Laravel & TailwindCSS**: Interface modern untuk melihat ringkasan akun trading dan daftar transaksi.
3. **Statistik Trading**: Menghitung metrics penting seperti Win Rate, Total PnL, Total Trade, dan visualisasi chart.
4. **Pencatatan Otomatis**: Tidak perlu lagi mencatat jurnal secara manual (Excel/Notion).

---

## 🛠️ Persyaratan Sistem

- PHP 8.2 atau lebih baru
- Composer
- Node.js & NPM
- MySQL / MariaDB
- MetaTrader 5 (MT5) Terminal

---

## 💻 Panduan Instalasi Backend (Web / Laravel)

1. **Persiapan Project**
   Buka terminal di folder project ini, lalu jalankan perintah:
   ```bash
   composer install
   ```

2. **Konfigurasi Environment**
   Salin file konfigurasi bawaan Laravel:
   ```bash
   cp .env.example .env
   ```
   Buka file `.env` dan sesuaikan pengaturan database Anda:
   ```env
   DB_CONNECTION=mysql
   DB_HOST=127.0.0.1
   DB_PORT=3306
   DB_DATABASE=nama_database_anda
   DB_USERNAME=root
   DB_PASSWORD=
   ```

3. **Generate Application Key**
   ```bash
   php artisan key:generate
   ```

4. **Migrasi Database**
   Buat tabel untuk menyimpan log trading:
   ```bash
   php artisan migrate
   ```

5. **Build Frontend (Tailwind + Vite)**
   Instal dependensi Node dan build aset CSS/JS:
   ```bash
   npm install
   npm run build
   ```
   *(Atau jalankan `npm run dev` jika Anda masih dalam tahap pengembangan).*

6. **Jalankan Development Server**
   ```bash
   php artisan serve
   ```
   Aplikasi Anda sekarang dapat diakses melalui `http://localhost:8000`.

---

## 📈 Panduan Instalasi Script MQL5 (MetaTrader 5)

Agar MT5 dapat mengirimkan data ke web Jurnal Tradingku, Anda perlu memasang script **TradingJournalWebhook.mq5**.

1. **Buka MetaEditor**
   Buka aplikasi MT5, kemudian tekan tombol `F4` di keyboard untuk membuka MetaEditor.
2. **Pindahkan Script**
   Salin file `TradingJournalWebhook.mq5` dari project ini ke folder direktori data MT5 Anda (biasanya di folder `MQL5/Experts/` atau `MQL5/Scripts/`).
3. **Sesuaikan URL Webhook (PENTING)**
   Buka file `TradingJournalWebhook.mq5` di MetaEditor. Temukan variabel URL dan pastikan mengarah ke server Laravel Anda.
   Jika Anda menjalankan server di localhost (`http://localhost:8000`), dan MT5 juga di PC yang sama, gunakan alamat localhost. 
   *(Catatan: Jika web ini di-hosting di server publik, ganti URL string dengan alamat domain web Anda, contoh: `https://webjurnaltradingku.com/api/trading-webhook`)*.
4. **Compile Script**
   Tekan tombol `F7` atau klik tombol **Compile** pada MetaEditor. Pastikan proses compile berjalan tanpa error (0 errors, 0 warnings).
5. **Izinkan WebRequest di MT5**
   Kembali ke platform MT5.
   - Buka menu **Tools > Options** (atau tekan `Ctrl+O`).
   - Pergi ke tab **Expert Advisors**.
   - Centang opsi **"Allow WebRequest for listed URL"**.
   - Tambahkan URL tujuan webhook ke dalam daftar (misalnya `http://localhost:8000` atau alamat domain server web Anda).
   - Klik OK.
6. **Pasangkan EA ke Chart**
   Buka chart pair mata uang apa pun di MT5, lalu drag and drop *TradingJournalWebhook* dari bagian Navigator ke dalam chart. Script sekarang aktif dan sedang memonitor trading.

---

## 📖 Cara Penggunaan Sistem
1. Tradinglah seperti biasa di platform MetaTrader 5 Anda.
2. Setiap kali ada posisi yang tertutup (Misal SL/TP tersentuh, close parsial, atau close manual), script `TradingJournalWebhook` akan mengirim detail trading (Simbol, Lot, Profit, Waktu Open/Close, dll.) ke Endpoint API Laravel.
3. Buka browser dan pergi ke halaman Dashboard Web Anda (`http://localhost:8000/dashboard`).
4. Halaman kemudian akan otomatis menampilkan log transaksi trading terbaru Anda beserta perubahan pada ringkasan modal (Balance), Win Rate, Trading History.
