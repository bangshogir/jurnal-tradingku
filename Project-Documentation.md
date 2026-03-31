# Dokumentasi Sistem Jurnal Tradingku & MetaTrader EA

## Gambaran Umum (Overview)
**Jurnal Tradingku** adalah sebuah ekosistem trading terintegrasi yang terdiri dari dua komponen utama:
1. **Backend & Frontend Web (Laravel):** Berfungsi sebagai dasbor analisis, pencatat jurnal trading otomatis, dan pusat profil pengguna.
2. **Expert Advisor (EA) MetaTrader 5/4:** Skrip MQL5/4 yang bertindak sebagai pencatat transaksi (tracker), manajer risiko (risk manager), sekaligus mesin trading otomatis (auto-trader).

Kedua komponen ini saling berkomunikasi melalui protokol HTTP (Webhook API). Setiap aktivitas di MetaTrader secara otomatis dikirimkan ke server web sehingga pengguna dapat menganalisis performa trading-nya (Win Rate, PnL, dll) tanpa perlu mencatat manual di Excel.

---

## Bagian 1: Aplikasi Web (Laravel 11)

Aplikasi web dibangun menggunakan framework PHP Laravel 11. Berikut adalah fitur dan fungsionalitas utamanya:

### 1. Webhook API Listener (`/api/webhook/trading-log`)
Ini adalah jantung dari sistem pencatatan. Endpoint ini menerima data *payload* berbasis JSON dari MetaTrader EA setiap kali ada transaksi baru. 
- **Verifikasi Keamanan:** Endpoint memvalidasi asal data menggunakan `X-Webhook-Token` yang dikonfigurasi secara unik untuk setiap pengguna (mendukung skema *Software as a Service / Multi-User*).
- **Pemrosesan Data:** Menyimpan detail seperti identitas tiket, nama simbol, tipe transaksi, harga entry & close, letak Stop Loss (SL) / Take Profit (TP), besaran lot, profit/loss, swap, dan fee komisi.

### 2. Dasbor Analitik (Dashboard Analytics)
Antarmuka untuk menampilkan data secara visual.
- Memisahkan data transaksi menjadi beberapa tabulasi: **Open Orders** (transaksi yang masih berjalan), **Pending Orders** (Limit/Stop order yang belum tereksekusi), dan **Reports / History** (riwayat transaksi yang sudah ditutup).
- Mengkalkulasi metrik penting secara instan: Total Balance, Win Rate, Profit Factor, serta grafik performa akumulasi Profit & Loss (PnL).

### 3. Integrasi Telegram (Telegram Routings)
- Melalui `TelegramRoutingController`, aplikasi memungkinkan pengguna untuk menautkan akun dengan bot Telegram (lewat *Telegram Chat ID*).
- **Penggunaan:** Dapat digunakan untuk memberikan notifikasi *real-time* kepada trader langsung ke HP mereka ketika ada posisi trading yang tertutup, deposit/withdrawal, atau metrik target harian tercapai.

### 4. Sistem Autentikasi dan Manajemen Role
- Menggunakan session driver dan Auth Laravel standar untuk mengelola pengguna.
- Terdapat role dan pembagian *scope* (Contoh: Rute Admin vs Rute User), di mana User ID bertindak sebagai pemilik data *trading log* (isolasi data antar pengguna).

---

## Bagian 2: MetaTrader EAs (Expert Advisors)

Di dalam repositori ini terdapat beberapa skrip EA dengan tujuan yang berbeda, mulai dari sekadar *tracker* transaksi hingga bot trading otomatis sepenuhnya.

### A. TradingJournalWebhook (`TradingJournalWebhook.mq5`)
Ini adalah versi skrip EA paling dasar.
- **Tujuan Utama:** Memonitor segala kejadian transaksi (`OnTradeTransaction`) di terminal MT5.
- **Cara Kerja:** Mendeteksi transaksi penutupan (`deal_close`) serta pemesanan pesanan tertunda (`pending_order`); lalu memformatnya dalam bentuk JSON yang mencakup (Lot, Posisi Entry/Exit, Magic Number, dll.) untuk dikirim via Curl/WebRequest POST ke server Laravel.

### B. RiskPanel JurnalTradingku (`RiskPanel_JurnalTradingku.mq5`)
EA ini bertindak sebagai alat bantu (utilitas) visual berwujud antarmuka panel (GUI) langsung di atas grafik MT5.
- **Manajemen Risiko Otomatis (Risk Management):** Trader dapat memasukkan berapa risiko kerugian yang mereka sanggupi (misal: 1% dari Balance atau $10), kemudian menentukan harga *Entry* dan *Stop Loss* (SL). EA akan mengkalkulasi besaran otomatis **Lot Size** yang paling aman sesuai toleransi risiko tersebut (Lot Auto-Calculation).
- **Proteksi Cut Loss (Virtual SL):** Fitur yang dapat dihidupkan (ON/OFF). Jika dihidupkan, EA menempatkan *hard SL* sesungguhnya jauh di belakang harga, dan hanya akan menutup posisi secara *Market Execution* **JIKA** jarum harga (*candle*) ditutup di luar batas SL asli. Berfungsi untuk menghindari pancingan para "Stop Hunter"/Broker (Spike hunting).
- **Auto Close Friday:** Terdapat logika keamanan opsional untuk menutup paksa seluruh posisi dan pending order beberapa menit sebelum jam perdagangan pasar tutup pada hari Jumat. Menghindarkan trader dari celah lonjakan harga pembukaan market hari Senin (*Weekend Gaps*).
- **Auto Resync History:** Ketika pertama kali dipasang di MT5, EA ini sanggup mensinkronisasikan riwayat transaksi beberapa hari ke belakang (misal: 7 hari terakhir) ke jajaran database Laravel secara *retroactive*, agar data tidak hilang sebelum Webhook terpasang.

### C. AutoSnD RiskPanel (`AutoSnD_RiskPanel.mq5 / .mq4`)
Merupakan peleburan dari `RiskPanel_JurnalTradingku.mq5` dengan teknologi **Trading Otomatis (Auto Trading Engine)** yang berbasis metodologi aksi harga (Price Action).
- **Pendeteksi Market Structure:** Algoritmanya bekerja memetakan *Pivot High* dan *Pivot Low* guna mendeteksi Break Of Structure (BOS) baik di pasar *bullish* maupun *bearish*.
- **Otomasi Supply and Demand (SnD):** Setiap kali terdeteksi pematahan struktur tren (BOS), skrip segera menelusuri ke arah sumber mula pergerakan (Origin) untuk menggambarkan secara visual zona warna Supply (Area Sell) atau Demand (Area Buy). Zona yang sudah tersentuh akan "termitigasi" dan dihilangkan otomatis profil warnanya.
- **Filter Fibonacci (Golden Zone):** EA tidak akan sembarangan entry pada zona SnD yang dibuatnya. Setelah menggambar zona, EA menarik garis ukur Fibo dari pantulan BOS barunya. Zona SnD **HANYA akan diaktifkan untuk Auto Tradings** jika zona tersebut bertepatan letaknya dengan rentang zona sakral Fibo ke 38.2% dan 61.8% dalam gelombang ayunannya.
- **Auto Limit Order Execution:** Jika semua syarat Market Structure dan zona terpenuhi, EA tanpa henti mendikte kalkulator bawaan risiko (dari form pengaturan 1%), menyetel Stop Loss/Take Profit secara proporsional, dan menancapkan order tipe *Buy Limit / Sell Limit*. Hasil langsung dicolok bersamaan ke dasbor rekaman harian Webhook di Laravel.
