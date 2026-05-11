@extends('layouts.admin')

@section('title', 'Dokumentasi & Panduan')
@section('page-title', 'Panduan Penggunaan Sistem')
@section('page-subtitle', 'Pelajari cara setup Jurnal, AutoSnD EA, dan Integrasi Telegram')

@section('content')
<div class="flex flex-col md:flex-row gap-6 mb-8 items-start">

    {{-- SIDEBAR NAVIGATION FOR DOCS --}}
    <aside class="w-full md:w-1/4 flex-shrink-0 sticky top-24">
        <div class="bg-white rounded-2xl border border-slate-200 p-4 shadow-sm">
            <h3 class="text-xs font-bold text-slate-400 uppercase tracking-wider mb-4 px-3">Bab Dokumentasi</h3>
            <nav class="flex flex-col space-y-1 docs-nav">
                <button onclick="switchTab('tab-intro')" id="btn-intro" class="w-full text-left px-3 py-2.5 rounded-lg text-sm font-semibold text-brand-600 bg-brand-50 hover:bg-brand-50 transition-colors">
                    1. Pengenalan & Webhook
                </button>
                <button onclick="switchTab('tab-ea')" id="btn-ea" class="w-full text-left px-3 py-2.5 rounded-lg text-sm font-medium text-slate-600 hover:bg-slate-50 hover:text-slate-900 transition-colors">
                    2. Setup EA & MT5
                </button>
                <button onclick="switchTab('tab-features')" id="btn-features" class="w-full text-left px-3 py-2.5 rounded-lg text-sm font-medium text-slate-600 hover:bg-slate-50 hover:text-slate-900 transition-colors">
                    3. Fitur AutoSnD
                </button>
                <button onclick="switchTab('tab-telegram')" id="btn-telegram" class="w-full text-left px-3 py-2.5 rounded-lg text-sm font-medium text-slate-600 hover:bg-slate-50 hover:text-slate-900 transition-colors">
                    4. Setup Bot Telegram
                </button>
            </nav>
        </div>
        
        <div class="mt-6 bg-amber-50 rounded-2xl border border-amber-200 p-4">
            <div class="flex items-start gap-3">
                <svg class="w-5 h-5 text-amber-500 mt-0.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                <div class="text-sm text-amber-800">
                    <p class="font-bold mb-1">Butuh Gambar/Screenshot</p>
                    <p class="text-xs leading-relaxed">Admin dapat menambahkan screenshot pada kotak-kotak bertanda khusus di dalam panduan ini untuk memperjelas instruksi visual.</p>
                </div>
            </div>
        </div>
    </aside>

    {{-- MAIN CONTENT AREA --}}
    <main class="w-full md:w-3/4 bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
        
        {{-- BAB 1: INTRO & WEBHOOK --}}
        <section id="tab-intro" class="p-6 sm:p-10 docs-content block prose prose-slate max-w-none">
            <h2 class="text-2xl font-bold text-slate-900 mb-6">1. Memulai Jurnal & Webhook</h2>
            
            <p class="text-slate-600 leading-relaxed">
                Jurnal Tradingku dirancang untuk terintegrasi mulus dengan platform MetaTrader 5 Anda menggunakan bridge *Webhook*. Seluruh data eksekusi (Open/Close Order) dari EA akan otomatis terkirim dan tercatat ke dalam database Jurnal ini secara real-time.
            </p>
            
            <h3 class="text-lg font-semibold text-slate-800 mt-8 mb-3">Apa itu URL Webhook?</h3>
            <p class="text-slate-600 leading-relaxed mb-4">
                Webhook adalah *endpoint URL* unik yang digunakan EA MetaTrader untuk mengirim request HTTP POST setiap kali Anda melakukan transaksi. 
            </p>
            
            <div class="bg-slate-50 p-4 rounded-xl border border-slate-200 mt-4 mb-6">
                <p class="text-xs text-slate-500 uppercase font-semibold mb-2">Endpoint URL Anda:</p>
                <code class="text-brand-600 bg-brand-50 px-2 py-1 rounded font-mono text-sm break-all">
                    {{ url('/webhook/mt5') }}
                </code>
            </div>

            <!-- Placeholder Screenshot -->
            <div class="bg-slate-100 border-2 border-dashed border-slate-300 rounded-xl p-8 text-center my-6 flex flex-col items-center justify-center text-slate-500">
                <svg class="w-8 h-8 mb-2 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
                <span class="font-medium text-sm">[ SCREENSHOT: Tampilan Dashboard/Halaman Profil yang memperlihatkan menu copy Webhook ]</span>
            </div>

            <p class="text-slate-600 leading-relaxed mb-4">
                Selain URL, Anda wajib menyiapkan **Akun ID** yang digunakan di MT5. Pastikan Anda telah menambahkannya di Database Jurnal Tradingku agar sistem bisa menautkan data *trading* langsung dengan *history* akun Anda yang bersangkutan.
            </p>
        </section>


        {{-- BAB 2: EA SETUP --}}
        <section id="tab-ea" class="p-6 sm:p-10 docs-content hidden prose prose-slate max-w-none">
            <h2 class="text-2xl font-bold text-slate-900 mb-6">2. Setup EA & MetaTrader 5</h2>
            
            <p class="text-slate-600 leading-relaxed mb-6">
                Agar AutoSnD EA bisa mendeteksi pergerakan *Supply & Demand* dengan benar dan mengeksekusi order (serta mengirimnya ke Jurnal), terminal MT5 harus dikonfigurasi melalui Options.
            </p>

            <h3 class="text-lg font-semibold text-slate-800 mt-6 mb-3">Mengaktifkan WebRequest & Algo Trading</h3>
            <ol class="list-decimal list-outside ml-5 space-y-3 text-slate-600">
                <li>Buka terminal MT5 Anda.</li>
                <li>Pilih menu <strong>Tools</strong> pada navbar atas, lalu klik <strong>Options</strong> (atau tekan CTRL+O).</li>
                <li>Arahkan ke tab <strong>Expert Advisors</strong>.</li>
                <li>Centang opsi <strong>Allow algorithmic trading</strong>.</li>
                <li>Centang bagian bawah bertuliskan <strong>Allow WebRequest for listed URL:</strong>.</li>
                <li>Klik tombol <kbd class="px-2 py-1 bg-slate-100 border border-slate-300 rounded text-xs font-mono"><b>+</b></kbd> warna hijau, dan masukkan URL: <br><code class="text-brand-600 bg-brand-50 px-2 py-1 rounded text-sm mt-1 inline-block">{{ url('/webhook/mt5') }}</code></li>
                <li>Klik OK.</li>
            </ol>
            
            <!-- Placeholder Screenshot -->
            <div class="bg-slate-100 border-2 border-dashed border-slate-300 rounded-xl p-8 text-center my-6 flex flex-col items-center justify-center text-slate-500">
                <svg class="w-8 h-8 mb-2 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
                <span class="font-medium text-sm">[ SCREENSHOT: Jendela pop-up 'Options' -> Tab 'Expert Advisors' yang sudah dicentang dan diisi WebRequest URL-nya ]</span>
            </div>

            <h3 class="text-lg font-semibold text-slate-800 mt-8 mb-3">Memasang EA pada Chart</h3>
            <p class="text-slate-600 leading-relaxed mb-4">
                Tarik <em>(Drag & Drop)</em> file `AutoSnD_RiskPanel.ex5` dari tab Navigator MT5 ke dalam chart Anda. Pada jendela parameter yang muncul, Anda bisa mengatur besaran % Risk, Base detection, hingga API endpoint. Pastikan URL Jurnal sudah terisi di kolom Input param EA.
            </p>

            <!-- Placeholder Screenshot -->
            <div class="bg-slate-100 border-2 border-dashed border-slate-300 rounded-xl p-8 text-center my-6 flex flex-col items-center justify-center text-slate-500">
                <svg class="w-8 h-8 mb-2 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
                <span class="font-medium text-sm">[ SCREENSHOT: Jendela "Inputs" milik EA saat ditempel pada chart, memperlihatkan setup pengaturan Webhook dan Risk]</span>
            </div>
            
        </section>


        {{-- BAB 3: EA FEATURES --}}
        <section id="tab-features" class="p-6 sm:p-10 docs-content hidden prose prose-slate max-w-none">
            <h2 class="text-2xl font-bold text-slate-900 mb-6">3. Fitur Utama AutoSnD EA</h2>
            
            <p class="text-slate-600 leading-relaxed mb-6">
                AutoSnD RiskPanel dikembangkan bukan sekadar penggambar kotak Supply & Demand, tetapi merupakan eksekutor mandiri ketika syarat-syarat *Price Action / Smart Money Concept (SMC)* terpenuhi.
            </p>

            <div class="space-y-8 mt-6">
                <!-- Feature 1 -->
                <div>
                    <h3 class="text-lg font-bold text-indigo-900 mb-2 flex items-center gap-2">
                        <span class="w-6 h-6 rounded-full bg-indigo-100 text-indigo-600 flex items-center justify-center text-sm">A</span>
                        Pemetaan Zona RBR, DBD, RBD, DBR
                    </h3>
                    <p class="text-slate-600 leading-relaxed text-sm mb-4">
                        EA mendeteksi Pivot Tertinggi (PH) dan Pivot Terendah (PL). Ketika Pivot tertembus (mengakibatkan <strong>Break of Structure / BOS</strong>), EA melacak ke belakang mencari <em>Base Order Block</em> sesungguhnya berbasis open/high/low candle. Zona ini akan merentang secara dinamis dan memiliki label harga sebelum harga kembali mitigasi <em>(Retest)</em>.
                    </p>
                    <!-- Placeholder Screenshot -->
                    <div class="bg-slate-100 border-2 border-dashed border-slate-300 rounded-xl p-6 text-center flex flex-col items-center justify-center text-slate-500">
                        <span class="font-medium text-xs">[ SCREENSHOT: Chart MT5 yang menunjukkan indikasi kotak hijau/merah Origin Zone dan Continuation Box dengan tulisan BOS ]</span>
                    </div>
                </div>

                <!-- Feature 2 -->
                <div>
                    <h3 class="text-lg font-bold text-indigo-900 mb-2 flex items-center gap-2">
                        <span class="w-6 h-6 rounded-full bg-indigo-100 text-indigo-600 flex items-center justify-center text-sm">B</span>
                        Momentum Candle Detection
                    </h3>
                    <p class="text-slate-600 leading-relaxed text-sm mb-4">
                        Sebuah zona baru dianggap valid jika *breakout* dari Base di-trigger oleh **Momentum Candle** penuh (rasio Body terhadap total Wick minimal di atas persentase X). EA menolak zona yang *choppy* dan hanya mempercayai breakout solid khas pergerakan institusional.
                    </p>
                </div>

                <!-- Feature 3 -->
                <div>
                    <h3 class="text-lg font-bold text-indigo-900 mb-2 flex items-center gap-2">
                        <span class="w-6 h-6 rounded-full bg-indigo-100 text-indigo-600 flex items-center justify-center text-sm">C</span>
                        Auto Execution & Risk Panel
                    </h3>
                    <p class="text-slate-600 leading-relaxed text-sm mb-4">
                        Terdapat panel di sebelah kanan layar MT5. Jika fitur <strong>Auto Trade Momentum</strong> diaktifkan, EA akan menempatkan order Buy/Sell Limit atau Market order persis pada dasar zona Base dengan menghitung ukuran Lot otomatis berbasis <em>Fixed Risk Percentage</em> terhadap Capital akun Anda. Stop loss otomatis ditempatkan di seberang pinggir zona.
                    </p>
                    <!-- Placeholder Screenshot -->
                    <div class="bg-slate-100 border-2 border-dashed border-slate-300 rounded-xl p-6 text-center flex flex-col items-center justify-center text-slate-500">
                        <span class="font-medium text-xs">[ SCREENSHOT: Overlay panel Risk/Tombol hijau-merah Buy/Sell pada chart MT5 bagian kanan atas atau bawah ]</span>
                    </div>
                </div>
            </div>
            
        </section>


        {{-- BAB 4: TELEGRAM BOT --}}
        <section id="tab-telegram" class="p-6 sm:p-10 docs-content hidden prose prose-slate max-w-none">
            <h2 class="text-2xl font-bold text-slate-900 mb-6">4. Setup Bot Telegram & Notifikasi</h2>
            
            <p class="text-slate-600 leading-relaxed mb-6">
                Dengan menghubungkan Telegram, Anda bisa langsung menerima notifikasi di handphone ketika EA mengeksekusi order, tanpa harus membuka Jurnal web atau layar MT5.
            </p>

            <h3 class="text-lg font-semibold text-slate-800 mt-6 mb-3">Langkah 1: Membuat Bot di @BotFather</h3>
            <ol class="list-decimal list-outside ml-5 space-y-2 text-slate-600 text-sm">
                <li>Buka aplikasi Telegram dan cari akun resmi <strong>@BotFather</strong> (dengan cetak biru verified).</li>
                <li>Ketik <code class="bg-slate-100 px-1 rounded">/newbot</code> dan tekan Enter.</li>
                <li>Ikuti instruksinya: Masukkan Nama Bot Anda, lalu *Username* Bot (harus diakhiri kata <em>bot</em>, misal: <code class="bg-slate-100 px-1 rounded">JurnalTradingAlert_bot</code>).</li>
                <li>BotFather akan memberikan teks panjang yang merupakan <strong>HTTP API Token</strong> Anda.</li>
                <li>Copy token tersebut. Masukkan ke file <code>.env</code> milik Laravel pada variabel <code>TELEGRAM_BOT_TOKEN="xxx"</code>.</li>
            </ol>
            
            <!-- Placeholder Screenshot -->
            <div class="bg-slate-100 border-2 border-dashed border-slate-300 rounded-xl p-6 text-center my-6 flex flex-col items-center justify-center text-slate-500">
                <svg class="w-8 h-8 mb-2 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
                <span class="font-medium text-xs">[ SCREENSHOT: Bukti dialog dengan @BotFather saat Token API berwarna merah tercetak di Telegram ]</span>
            </div>

            <h3 class="text-lg font-semibold text-slate-800 mt-8 mb-3">Langkah 2: Menemukan Chat ID Anda</h3>
            <p class="text-slate-600 text-sm mb-3">
                Server Laravel butuh alamat target (Chat ID) agar tahu kemana notifikasi diteruskan.
            </p>
            <ol class="list-decimal list-outside ml-5 space-y-2 text-slate-600 text-sm mb-6">
                <li>Cari bot bernama <strong>@userinfobot</strong> di kolom pencarian Telegram.</li>
                <li>Tekan tombol <strong>Start</strong>.</li>
                <li>Bot akan membalas dengan menampilkan <strong>Id</strong> Anda (berupa digit angka).</li>
            </ol>

            <h3 class="text-lg font-semibold text-slate-800 mt-8 mb-3">Langkah 3: Tautkan di Dashboard Setting</h3>
            <p class="text-slate-600 text-sm mb-3">
                Masuk ke menu <a href="{{ route('settings') }}" class="text-brand-600 font-medium hover:underline">Settings</a> di dashboard Anda. Di bagian <strong>Telegram Interface</strong>, masukkan angka Chat ID yang baru saja Anda temukan. Pastikan Anda klik <em>Test Notification</em> untuk menguji koneksinya!
            </p>

            <!-- Placeholder Screenshot -->
            <div class="bg-slate-100 border-2 border-dashed border-slate-300 rounded-xl p-6 text-center my-6 flex flex-col items-center justify-center text-slate-500">
                <svg class="w-8 h-8 mb-2 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
                <span class="font-medium text-xs">[ SCREENSHOT: Halaman menu Settings Jurnal Tradingku -> Bagian Telegram Chat ID dengan tombol Test hijau ]</span>
            </div>
            
        </section>

    </main>
</div>

<script>
    function switchTab(tabId) {
        // Hide all content sections
        document.querySelectorAll('.docs-content').forEach(el => {
            el.classList.add('hidden');
            el.classList.remove('block');
        });
        
        // Remove active styles from all buttons
        document.querySelectorAll('.docs-nav button').forEach(btn => {
            btn.classList.remove('text-brand-600', 'bg-brand-50', 'font-semibold');
            btn.classList.add('text-slate-600', 'hover:bg-slate-50', 'hover:text-slate-900', 'font-medium');
        });
        
        // Show selected content
        const target = document.getElementById(tabId);
        if (target) {
            target.classList.remove('hidden');
            target.classList.add('block');
        }
        
        // Add active styles to clicked button
        const activeBtn = document.getElementById(tabId.replace('tab', 'btn'));
        if (activeBtn) {
            activeBtn.classList.remove('text-slate-600', 'hover:bg-slate-50', 'hover:text-slate-900', 'font-medium');
            activeBtn.classList.add('text-brand-600', 'bg-brand-50', 'font-semibold');
        }
    }
</script>
@endsection
