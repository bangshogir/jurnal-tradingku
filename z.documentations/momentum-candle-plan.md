Kamu adalah Expert MQL5 Developer. Tugasmu adalah membuat Expert Advisor (EA) untuk MetaTrader 5 berdasarkan strategi "Price Action: Momentum Candle". EA ini tidak menggunakan indikator konvensional (seperti RSI/MACD), melainkan murni berdasarkan kalkulasi ukuran Candlestick, Volatilitas (ATR), dan rasio Fibonacci.

Berikut adalah Software Requirements Specification (SRS) untuk EA ini. Tolong buatkan kode MQL5 yang modular, bersih, dan diberikan komentar penjelasan pada setiap fungsinya.

# 1. INPUT PARAMETERS (Variabel yang bisa diubah oleh User)
- `InpTimeframe`: Timeframe operasional (Default: M15, Opsi: M5).
- `InpBodyPercentage`: Persentase minimal Body terhadap keseluruhan panjang Candle (Default: 0.75 atau 75%).
- `InpWickPercentage`: Persentase maksimal ekor berlawanan arah (Default: 0.10 atau 10%).
- `InpATRPeriod`: Periode Average True Range untuk memfilter "Lonjakan Volume" (Default: 14).
- `InpATRMultiplier`: Pengali ATR untuk memastikan candle saat ini lebih besar dari rata-rata (Default: 1.5).
- `InpFibRetracement`: Level Fibonacci untuk Entry Pullback Limit Order (Default: 0.236).
- `InpFibExtension`: Level Fibonacci untuk Take Profit (Default: -0.27).
- `InpSLBuffer`: Jarak buffer Stop Loss dalam poin/pips agar tidak terkena fakeout (Default: 30 points).
- `InpRiskPerTrade`: Persentase risiko dari balance untuk lot sizing otomatis (Default: 1.0%).

# 2. DEFINISI LOGIKA "MOMENTUM CANDLE" (Trigger Sinyal)
Sebuah candle (indeks [1], candle yang baru saja close) didefinisikan sebagai Momentum Candle JIKA DAN HANYA JIKA memenuhi 3 syarat matematika berikut:

A. Syarat Lonjakan Volume (ATR Filter):
   - TotalLength = High[1] - Low[1]
   - TotalLength > (ATR[1] * InpATRMultiplier) -> Ini mendeteksi breakout dari rentetan candle kecil.

B. Syarat Body Dominan:
   - BodyLength = MathAbs(Close[1] - Open[1])
   - BodyLength >= (TotalLength * InpBodyPercentage)

C. Syarat Ekor Minimum (Close Extreme):
   - Jika Bullish (Close[1] > Open[1]): 
     Ekor Bawah (Open[1] - Low[1]) <= (TotalLength * InpWickPercentage)
   - Jika Bearish (Close[1] < Open[1]): 
     Ekor Atas (High[1] - Open[1]) <= (TotalLength * InpWickPercentage)

# 3. LOGIKA ENTRY (Pending Order System)
Jika Momentum Candle terdeteksi pada indeks [1], kita TIDAK entry market execution, melainkan menggunakan Pending Order (Limit) untuk mendapatkan harga koreksi terbaik.

- Setup Bullish Momentum (Sinyal BUY):
  - Hitung Jarak: Range = High[1] - Low[1]
  - Entry Price (Buy Limit): High[1] - (Range * InpFibRetracement) -> *Koreksi ke 23.6%*
  - Stop Loss (SL): Low[1] - InpSLBuffer
  - Take Profit (TP): High[1] + (Range * MathAbs(InpFibExtension)) -> *Ekstensi ke -27%*

- Setup Bearish Momentum (Sinyal SELL):
  - Hitung Jarak: Range = High[1] - Low[1]
  - Entry Price (Sell Limit): Low[1] + (Range * InpFibRetracement) -> *Koreksi ke 23.6%*
  - Stop Loss (SL): High[1] + InpSLBuffer
  - Take Profit (TP): Low[1] - (Range * MathAbs(InpFibExtension)) -> *Ekstensi ke -27%*

# 4. TRADE MANAGEMENT & RULES TAMBAHAN
- Cancelation Rule: Jika Pending Order (Buy/Sell Limit) tidak tersentuh dalam 3 candle berikutnya (indeks [2], [3], [4]), maka hapus pending order tersebut (Kadaluarsa).
- Batasan Posisi: Hanya boleh ada 1 posisi terbuka atau 1 pending order aktif pada satu waktu untuk pair ini.
- Lot Sizing: Buat fungsi `CalculateLotSize` berdasarkan `InpRiskPerTrade` dan jarak Pips dari Entry Price ke SL.

Tolong hasilkan draft kode MQL5 yang mengimplementasikan logika di atas. Pisahkan deteksi sinyal ke dalam fungsi `bool IsBullishMomentum(int index)` dan `bool IsBearishMomentum(int index)` agar kode mudah dibaca.

Agar kamu bisa lebih memahami, kamu juga bisa menonton video strategi ini terlebih dahulu :

https://youtu.be/Utj8qRwNtgE?si=asXeTu4te-cK2p_B