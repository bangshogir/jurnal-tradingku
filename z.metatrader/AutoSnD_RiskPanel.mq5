//+------------------------------------------------------------------+
//|                                        AutoSnD_RiskPanel.mq5     |
//|         Supply Demand + Fibo Auto Trading dengan Risk Panel      |
//|                                    Copyright 2026, Antigravity   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity"
#property link      "https://jurnaltradingku.my.id"
#property version   "3.00"
#property strict

#include <Controls\Dialog.mqh>
#include <Controls\Label.mqh>
#include <Controls\Edit.mqh>
#include <Controls\Button.mqh>
#include <Controls\ComboBox.mqh>
#include <Trade\Trade.mqh>

CTrade ExtTrade;

// Helper to get clean timeframe string (e.g. PERIOD_M15 -> M15)
string GetTFString() {
   string tf = EnumToString(_Period);
   StringReplace(tf, "PERIOD_", "");
   return tf;
}

//=====================================================================
// [1] INPUT PARAMETERS
//=====================================================================
input group "=== Risk Panel & Webhook ==="
input string  InpWebhookURL = "http://jurnaltradingku.my.id/api/webhook/trading-log"; // Webhook URL
input string  InpWebhookToken = "";                                                   // Webhook API Token
input int     InpResyncDays = 365;                                                    // Auto Resync History (Days)

input group "=== Auto Close Friday ==="
input bool    InpEnableAutoCloseFriday = false; // Enable Auto Close Friday
input int     InpAutoCloseMinutesBefore = 15;   // Minutes before market close

input group "=== Auto SnD Trading Logic ==="
input int     InpPivotLB        = 5;     // Pivot Lookback (bars)
input int     InpOriginLookback = 50;    // Traceback max candle base
input double  InpBufferPoints   = 20.0;    // Jarak Buffer SL (Points)
input int     InpHistoryBars    = 600;     // Jumlah Bar Histori Discan
input bool   InpShowBOS        = true;    // Tampilkan Garis BOS di Chart
input color  InpDemandColor    = C'0,160,0';   // Warna Zona Demand
input color  InpSupplyColor    = C'190,0,0';   // Warna Zona Supply
input bool   InpShowMitigated  = true;          // Tampilkan Zona Termitigasi
input color  InpMitColor       = clrGray;       // Warna Border Zona Termitigasi
input bool   InpShowRbdDbr     = true;          // Tampilkan Zona Reversal (RBD/DBR)
input bool   InpShowRbrDbd     = true;          // Tampilkan Zona Continuation (RBR/DBD)
input bool   InpAutoTradeRbrDbd= false;         // Auto-Trade Zona Continuation
input color  InpContColor      = clrLightBlue;  // Warna Border Zona Continuation
input int    InpBaseMaxCandles = 3;             // Max Base Candles utk Continuation
input color  InpBOSBull        = clrDodgerBlue; // Warna Bullish BOS
input color  InpBOSBear        = clrOrangeRed;  // Warna Bearish BOS

input group "=== Momentum Indicator ==="
input int    InpEarlySignalSeconds  = 10;    // Detik Early Signal Momentum (0=Off)
input bool   InpEnableAutoMomentum  = false; // Enable Auto Trading Candle Momentum
input double InpMomentumRR        = 0.61;    // RR Ratio khusus Momentum (Jika > 0)
input double InpBodyPercentage = 0.75;       // Min body ratio (75%)
input double InpWickPercentage = 0.10;       // Max opposite wick ratio (10%)
input int    InpATRPeriod      = 14;         // Periode ATR
input double InpATRMultiplier  = 1.5;        // Min candle size vs ATR
input int    InpMomMaxCandlesAfterBase = 2;  // Maks jarak candle dari Base ke Momentum (untuk auto order)

input group "=== Profit Protection (Step Trailing SL) ==="
input bool   InpEnableProfitProtect = false; // Enable Step Profit Protection
input double InpStep1Pct = 50.0;             // Step 1: Pindah SL ke Entry (Breakeven) saat profit mencapai X% dari TP
input double InpStep2Pct = 90.0;             // Step 2: Pindah SL ke 50% profit saat mencapai X% dari TP

input group "=== Drawdown Protection ==="
input bool   InpEnableDailyLossLimit  = false; // Enable Daily Loss Limit (Aktifkan pembatasan loss harian)
input double InpMaxDailyLoss          = 500.0; // Max Daily Loss dalam mata uang AKUN (bukan real $). Akun Cent: 500 = 5 USD real | Akun Real: 500 = 500 USD
input bool   InpBlockManualOnLimit    = false;  // Blokir tombol manual Buy/Sell saat limit harian tercapai



//=====================================================================
// ZONE STRUCT & GLOBALS (copied from SnD_Zone.mq5)
//=====================================================================
enum ENUM_ZONE_TYPE { ZONE_RBD_DBR, ZONE_RBR_DBD };

struct ZoneData
  {
   string   rect_name;
   string   lbl_name;
   string   lbl_top;
   string   lbl_btm;
   bool     is_demand;
   double   top;
   double   btm;
   datetime start_time; // Candle pertama (tertua / kiri) dari Base
   datetime end_time;   // Candle terakhir (terbaru / kanan) dari Base
   bool     active;
   ENUM_ZONE_TYPE type;
  };

#define MAX_ZONES    300

ZoneData g_zones[MAX_ZONES];
int      g_zone_count   = 0;
int      g_obj_id       = 0;

double   g_last_ph      = 0;
datetime g_last_ph_time = 0;
double   g_last_pl      = 0;
datetime g_last_pl_time = 0;
double   g_old_last_ph  = 0;
double   g_old_last_pl  = 0;
datetime g_marked_ph_time = 0;
datetime g_marked_pl_time = 0;


datetime g_last_processed_bar = 0;


bool     g_is_scanning_history = false; // Prevents auto trades from firing during history scan

// === Daily Loss Limit State ===
bool     g_daily_limit_reached = false;  // Cached flag: true when daily loss >= InpMaxDailyLoss
datetime g_daily_limit_day     = 0;      // Broker day when limit was last recalculated

int      g_atr_handle = INVALID_HANDLE; // Handle untuk indikator ATR

// Array to prevent duplicate pending orders on the same zone
datetime g_traded_zones[];
bool IsZoneTraded(datetime t) { int s=ArraySize(g_traded_zones); for(int i=0;i<s;i++) if(g_traded_zones[i]==t) return true; return false; }
void MarkZoneTraded(datetime t) { int s=ArraySize(g_traded_zones); ArrayResize(g_traded_zones,s+1); g_traded_zones[s]=t; }

string NextID() { return IntegerToString(++g_obj_id); }

//=====================================================================
// [2] LOT CALCULATION
//=====================================================================
double CalcLotSize(double risk, double entry, double sl, string symbol)
  {
   double diff = MathAbs(entry - sl); if(diff == 0) return 0;
   double ts   = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tv   = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double vmin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double vstep= SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double vmax = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   if(ts == 0 || tv == 0) return -1;
   double lot  = risk / ((diff / ts) * tv);
   double lotn = MathFloor(lot / vstep) * vstep;
   if(lotn < vmin && lot > 0) return -2;
   if(lotn > vmax) lotn = vmax;
   return lotn;
  }

//=====================================================================
// [3] CUT LOSS & FRIDAY MONITOR
//=====================================================================
void CheckCutLoss()
  {
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   int    total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
     {
      ulong  ticket  = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      
      // Relaksasi pembacaan comment agar tidak gagal bila broker menambah prefix (misal ex: "[sl]RP_CL_")
      if(StringFind(comment, "RP_CL_") < 0 && StringFind(comment, "SND_CL_") < 0) continue;
      
      int idx = StringFind(comment, "CL_");
      if(idx < 0) continue;
      
      double cut  = StringToDouble(StringSubstr(comment, idx + 3));
      if(cut == 0) continue;
      
      bool is_buy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      bool do_cut = is_buy ? (bid <= cut) : (ask >= cut);
      
      if(do_cut) 
        {
         Print(">>> Cut Loss / Soft SL TRIGGERED! Ticket: ", ticket, " | Comment: ", comment, " | Harga Cut: ", cut, " | Harga Sekarang: ", (is_buy?bid:ask));
         ExtTrade.PositionClose(ticket, 10);
        }
     }
  }


//---------------------------------------------------------------------
// [3.1] PROFIT PROTECTION - Step-Based Trailing SL
//---------------------------------------------------------------------
void CheckProfitProtection()
  {
   if(!InpEnableProfitProtect) return;
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   int    total  = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
     {
      ulong  ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      double entry  = PositionGetDouble(POSITION_PRICE_OPEN);
      double tp     = PositionGetDouble(POSITION_TP);
      double sl     = PositionGetDouble(POSITION_SL);
      bool   isBuy  = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      if(tp == 0) continue;
      double tpDist = MathAbs(tp - entry);
      if(tpDist <= 0) continue;
      double curPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double progress = isBuy ? (curPrice - entry) / tpDist * 100.0 : (entry - curPrice) / tpDist * 100.0;
      if(progress <= 0) continue;
      double newSL = sl;
      if(progress >= InpStep2Pct)
        {
         double targetSL = isBuy ? NormalizeDouble(entry + tpDist * 0.5, digits) : NormalizeDouble(entry - tpDist * 0.5, digits);
         if(isBuy  && targetSL > newSL) newSL = targetSL;
         if(!isBuy && (newSL == 0 || targetSL < newSL)) newSL = targetSL;
        }
      else if(progress >= InpStep1Pct)
        {
         double targetSL = NormalizeDouble(entry, digits);
         if(isBuy  && targetSL > newSL) newSL = targetSL;
         if(!isBuy && (newSL == 0 || targetSL < newSL)) newSL = targetSL;
        }
      if(MathAbs(newSL - sl) > SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 0.5)
        {
         string stage = (progress >= InpStep2Pct) ? "Step2(50%Profit)" : "Step1(Breakeven)";
         if(ExtTrade.PositionModify(ticket, newSL, tp))
            Print("ProfitProtect [", stage, "] Ticket:", ticket, " NewSL:", DoubleToString(newSL, digits), " Progress:", DoubleToString(progress, 1), "%");
         else
            Print("ProfitProtect: Gagal modify SL ticket:", ticket, " Error:", GetLastError());
        }
     }
  }
void CheckAutoCloseFriday()
  {
   if(!InpEnableAutoCloseFriday) return;
   
   MqlDateTime tm;
   TimeCurrent(tm);
   if(tm.day_of_week != 5) return; // FRIDAY ONLY
   
   static int last_day = -1;
   static uint friday_close_sec = 86399; // Default 23:59:59
   if(last_day != tm.day)
     {
      datetime from, to;
      uint last_close = 0;
      for(int i=0; i<5; i++)
        {
         if(SymbolInfoSessionTrade(_Symbol, FRIDAY, i, from, to))
           { if((uint)to > last_close) last_close = (uint)to; }
         else break;
        }
      if(last_close > 0) friday_close_sec = last_close;
      last_day = tm.day;
     }
     
   uint current_sec = tm.hour * 3600 + tm.min * 60 + tm.sec;
   uint trigger_sec = friday_close_sec - (InpAutoCloseMinutesBefore * 60);
   
   if(current_sec >= trigger_sec && current_sec < friday_close_sec)
     {
      bool actionsTaken = false;
      int posTotal = PositionsTotal();
      for(int i = posTotal - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
           { ExtTrade.PositionClose(ticket); actionsTaken = true; }
        }
      int ordersTotal = OrdersTotal();
      for(int i = ordersTotal - 1; i >= 0; i--)
        {
         ulong ticket = OrderGetTicket(i);
         if(OrderGetString(ORDER_SYMBOL) == _Symbol)
           { ExtTrade.OrderDelete(ticket); actionsTaken = true; }
        }
      if(actionsTaken) Print("Auto Close Friday triggered at: ", TimeCurrent());
     }
  }

//=====================================================================
// [3b] DAILY LOSS LIMIT (Drawdown Protection)
//=====================================================================

// Returns total closed P&L for today (deals closed today) + floating P&L from open positions
double GetDailyPnL()
  {
   MqlDateTime now;
   TimeCurrent(now);
   // Build start-of-today timestamp (00:00:00 broker time)
   MqlDateTime dayStart; dayStart.year=now.year; dayStart.mon=now.mon; dayStart.day=now.day;
   dayStart.hour=0; dayStart.min=0; dayStart.sec=0; dayStart.day_of_week=0; dayStart.day_of_year=0;
   datetime todayMidnight = StructToTime(dayStart);

   double pnl = 0.0;

   // Sum all closed deals from today
   if(HistorySelect(todayMidnight, TimeCurrent()))
     {
      int deals = HistoryDealsTotal();
      for(int i = 0; i < deals; i++)
        {
         ulong dTicket = HistoryDealGetTicket(i);
         if(dTicket == 0) continue;
         long dEntry = HistoryDealGetInteger(dTicket, DEAL_ENTRY);
         if(dEntry != DEAL_ENTRY_OUT && dEntry != DEAL_ENTRY_INOUT) continue; // Only closing deals
         long dType = HistoryDealGetInteger(dTicket, DEAL_TYPE);
         if(dType == DEAL_TYPE_BALANCE) continue; // Skip deposits/withdrawals
         pnl += HistoryDealGetDouble(dTicket, DEAL_PROFIT)
              + HistoryDealGetDouble(dTicket, DEAL_SWAP)
              + HistoryDealGetDouble(dTicket, DEAL_COMMISSION);
        }
     }

   // Add floating P&L from currently open positions
   int posTotal = PositionsTotal();
   for(int i = 0; i < posTotal; i++)
     {
      ulong posTicket = PositionGetTicket(i);
      if(posTicket == 0) continue;
      pnl += PositionGetDouble(POSITION_PROFIT)
           + PositionGetDouble(POSITION_SWAP);
     }

   return pnl;
  }

// Returns true if daily loss has reached or exceeded the configured limit
bool IsDailyLossLimitReached()
  {
   if(!InpEnableDailyLossLimit) return false;

   // Re-check once per bar (or if day changed) to avoid heavy looping every tick
   MqlDateTime now; TimeCurrent(now);
   datetime todayKey = (datetime)(now.year * 10000 + now.mon * 100 + now.day); // compact day ID

   if(g_daily_limit_day != todayKey)
     {
      // New day → reset limit flag
      g_daily_limit_reached = false;
      g_daily_limit_day     = todayKey;
     }

   // Only do the full scan if not yet reached (saves CPU once locked)
   if(!g_daily_limit_reached)
     {
      double dailyPnL = GetDailyPnL();
      if(dailyPnL <= -MathAbs(InpMaxDailyLoss))
        {
         g_daily_limit_reached = true;
         Print(">>> DAILY LOSS LIMIT REACHED! Daily P&L: ", DoubleToString(dailyPnL, 2),
               " | Limit: -", DoubleToString(InpMaxDailyLoss, 2),
               " | Auto Trading PAUSED until tomorrow.");
        }
     }

   return g_daily_limit_reached;
  }

//=====================================================================
// [4] RISK PANEL CLASS
//=====================================================================
class CRiskPanel : public CAppDialog
  {
public:
   CLabel    m_lbl_balance, m_lbl_risk, m_lbl_entry, m_lbl_sl;
   CLabel    m_lbl_ratio,   m_lbl_lot,  m_lbl_status;
   CLabel    m_lbl_pair, m_lbl_spread, m_lbl_atr, m_lbl_footer, m_lbl_clock;
   CEdit     m_edt_risk, m_edt_entry, m_edt_sl, m_edt_ratio;
   CButton   m_btn_place, m_btn_cancel, m_btn_cutloss, m_btn_risk_mode;
   CButton   m_btn_buy_mkt, m_btn_sell_mkt, m_btn_close_all;
   bool      m_cl_active;
   bool      m_risk_in_percent;

   bool      MkLabel(CLabel &l, string n, string t, int x1, int y1, int x2, int y2, int fs=7) { if(!l.Create(m_chart_id, m_name + n, m_subwin, x1, y1, x2, y2)) return false; l.Text(t); l.FontSize(fs); return Add(l); }
   bool      MkEdit(CEdit &e, string n, string t, int x1, int y1, int x2, int y2, int fs=7)  { if(!e.Create(m_chart_id, m_name + n, m_subwin, x1, y1, x2, y2)) return false; e.Text(t); e.FontSize(fs); return Add(e); }
   bool      MkButton(CButton &b, string n, string t, int x1, int y1, int x2, int y2, int fs=7){ if(!b.Create(m_chart_id, m_name + n, m_subwin, x1, y1, x2, y2)) return false; b.Text(t); b.FontSize(fs); return Add(b); }
   void      SetStatus(string t) { m_lbl_status.Text("Status: " + t); }
   bool      IsCent() { string c = AccountInfoString(ACCOUNT_CURRENCY); return StringFind(c, "USC") >= 0 || StringFind(c, "ent") >= 0; }
   string    AccCurr() { return IsCent() ? "USD" : AccountInfoString(ACCOUNT_CURRENCY); }
   
   // Calculates the raw risk amount in account currency terms
   double    AdjRisk() { 
      double r = StringToDouble(m_edt_risk.Text());
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double raw_risk_amount = 0;
      
      if(m_risk_in_percent)
         raw_risk_amount = balance * (r / 100.0);
      else
         raw_risk_amount = IsCent() ? (r * 100.0) : r;
         
      return raw_risk_amount;
   }
   
   void      UpdateBalance() { double b = AccountInfoDouble(ACCOUNT_BALANCE); if(IsCent()) b /= 100.0; m_lbl_balance.Text("Balance: " + AccCurr() + " " + DoubleToString(b, 2)); }
   void      UpdateLot() { 
      double r = StringToDouble(m_edt_risk.Text()); double e = StringToDouble(m_edt_entry.Text()); double s = StringToDouble(m_edt_sl.Text());
      if(r <= 0 || e <= 0 || s <= 0 || e == s) { m_lbl_lot.Text("Lot Size: --"); return; }
      double lot = CalcLotSize(AdjRisk(), e, s, _Symbol);
      m_lbl_lot.Text(lot > 0 ? "Lot Size: " + DoubleToString(lot, 2) : "Lot Size: --");
   }
   
   void      UpdateClock(datetime barTime) {
      MqlDateTime loc; TimeToStruct(TimeLocal(), loc);
      int sec_left = (int)(barTime + PeriodSeconds(_Period) - TimeCurrent());
      if(sec_left < 0) sec_left = 0;
      m_lbl_clock.Text(StringFormat("LOC %02d:%02d | BAR %02d:%02d", loc.hour, loc.min, sec_left/60, sec_left%60));
   }
   
   bool      ValidStopLevel(double entry, double sl, bool is_buy) {
      long   pts  = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      if(pts == 0) return true;
      double mind = pts * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if( is_buy && sl >= entry - mind) { SetStatus("SL terlalu dekat! Min: " + IntegerToString((int)pts) + " pts"); return false; }
      if(!is_buy && sl <= entry + mind) { SetStatus("SL terlalu dekat! Min: " + IntegerToString((int)pts) + " pts"); return false; }
      return true;
   }

   string    RetcodeMsg(uint c) { return "Code: " + IntegerToString((int)c); }
   void      OnCancelBtn() { m_edt_entry.Text(""); m_edt_sl.Text(""); m_lbl_lot.Text("Lot Size: --"); SetStatus("Dibatalkan."); }
   void      OnCutLoss() { m_cl_active = !m_cl_active; m_btn_cutloss.Text(m_cl_active ? "CL: ON" : "CL: OFF"); SetStatus(m_cl_active ? "Cut Loss ON" : "Cut Loss OFF"); }
   
   void      OnRiskModeToggle() {
      m_risk_in_percent = !m_risk_in_percent;
      m_btn_risk_mode.Text(m_risk_in_percent ? " % " : " $ ");
      m_lbl_risk.Text(m_risk_in_percent ? "Risk (%):" : "Risk ($):");
      UpdateLot();
   }
   
   void      OnPlace() {
      double risk = StringToDouble(m_edt_risk.Text()); double entry = StringToDouble(m_edt_entry.Text()); double sl = StringToDouble(m_edt_sl.Text());
      if(risk <= 0 || entry <= 0 || sl <= 0 || entry == sl) return;
      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      entry = NormalizeDouble(entry, digits); sl = NormalizeDouble(sl, digits);
      bool is_buy = entry > sl;
      if(!ValidStopLevel(entry, sl, is_buy)) return;
      double lot = CalcLotSize(AdjRisk(), entry, sl, _Symbol);
      if(lot <= 0) return;
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK); double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double diff = MathAbs(entry - sl);
      double mult = StringToDouble(m_edt_ratio.Text()); if(mult <= 0) mult = 2.0;
      double tp = 0; bool result = false;
      if(m_cl_active) {
         double backup = is_buy ? NormalizeDouble(entry - diff * 2.0, digits) : NormalizeDouble(entry + diff * 2.0, digits);
         string clc = "RP_CL_" + DoubleToString(sl, digits) + "[" + GetTFString() + "]";
         if(is_buy) { tp = NormalizeDouble(entry + diff * mult, digits); result = (entry < ask) ? ExtTrade.BuyLimit(lot, entry, _Symbol, backup, tp, ORDER_TIME_GTC, 0, clc)  : ExtTrade.BuyStop(lot, entry, _Symbol, backup, tp, ORDER_TIME_GTC, 0, clc); }
         else       { tp = NormalizeDouble(entry - diff * mult, digits); result = (entry > bid) ? ExtTrade.SellLimit(lot, entry, _Symbol, backup, tp, ORDER_TIME_GTC, 0, clc) : ExtTrade.SellStop(lot, entry, _Symbol, backup, tp, ORDER_TIME_GTC, 0, clc); }
      } else {
         string rpc = "RP[" + GetTFString() + "]";
         if(is_buy) { tp = NormalizeDouble(entry + diff * mult, digits); result = (entry < ask) ? ExtTrade.BuyLimit(lot, entry, _Symbol, sl, tp, ORDER_TIME_GTC, 0, rpc)  : ExtTrade.BuyStop(lot, entry, _Symbol, sl, tp, ORDER_TIME_GTC, 0, rpc); }
         else       { tp = NormalizeDouble(entry - diff * mult, digits); result = (entry > bid) ? ExtTrade.SellLimit(lot, entry, _Symbol, sl, tp, ORDER_TIME_GTC, 0, rpc) : ExtTrade.SellStop(lot, entry, _Symbol, sl, tp, ORDER_TIME_GTC, 0, rpc); }
      }
      SetStatus(result ? "Order Manual Dipasang" : "Gagal Pasang Order");
   }
   
   void      OnBuyMarket() { ExecuteMarketOrder(true); }
   void      OnSellMarket() { ExecuteMarketOrder(false); }
   
   void      OnCloseAll() {
      int count = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         ulong ticket = PositionGetTicket(i);
         if(PositionGetString(POSITION_SYMBOL) == _Symbol) { ExtTrade.PositionClose(ticket); count++; }
      }
      for(int i = OrdersTotal() - 1; i >= 0; i--) {
         ulong ticket = OrderGetTicket(i);
         if(OrderGetString(ORDER_SYMBOL) == _Symbol) { ExtTrade.OrderDelete(ticket); count++; }
      }
      SetStatus(count > 0 ? "Tertutup " + IntegerToString(count) + " order/posisi." : "Tidak ada order aktif.");
   }
   
   void      ExecuteMarketOrder(bool is_buy) {
      // *** DRAWDOWN PROTECTION: Block manual order if InpBlockManualOnLimit is true ***
      if(InpBlockManualOnLimit && IsDailyLossLimitReached())
        { SetStatus("Daily Loss Limit Reached!"); return; }
      double risk = StringToDouble(m_edt_risk.Text()); double sl = StringToDouble(m_edt_sl.Text());
      if(risk <= 0 || sl <= 0) { SetStatus("Isi Risk & SL"); return; }
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double entry = is_buy ? ask : bid;
      if(is_buy && sl >= entry) { SetStatus("SL Buy harus < Harga"); return; }
      if(!is_buy && sl <= entry) { SetStatus("SL Sell harus > Harga"); return; }
      
      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      entry = NormalizeDouble(entry, digits); sl = NormalizeDouble(sl, digits);
      if(!ValidStopLevel(entry, sl, is_buy)) return;
      
      double lot = CalcLotSize(AdjRisk(), entry, sl, _Symbol);
      if(lot <= 0) return;
      double diff = MathAbs(entry - sl);
      double mult = StringToDouble(m_edt_ratio.Text()); if(mult <= 0) mult = 2.0;
      double tp = is_buy ? NormalizeDouble(entry + diff * mult, digits) : NormalizeDouble(entry - diff * mult, digits);
      bool result = false;
      string comm = m_cl_active ? ("RP_CL_" + DoubleToString(sl, digits)) : "RP_MKT";
      comm = comm + "[" + GetTFString() + "]";
      double hard_sl = sl;
      if (m_cl_active) hard_sl = is_buy ? NormalizeDouble(entry - diff * 2.0, digits) : NormalizeDouble(entry + diff * 2.0, digits);
      
      if(is_buy) result = ExtTrade.Buy(lot, _Symbol, entry, hard_sl, tp, comm);
      else result = ExtTrade.Sell(lot, _Symbol, entry, hard_sl, tp, comm);
      
      SetStatus(result ? ("Order " + (is_buy?"BUY":"SELL") + " MKT Dipasang") : "Gagal Pasang Order");
   }

   void      OnInput() { UpdateLot(); }
   void      UpdateStats() { m_lbl_pair.Text(_Symbol); UpdateBalance(); }

   CRiskPanel() { m_cl_active = false; m_risk_in_percent = false; }
   virtual bool  Create(const long chart, const string name, const int sw, const int x1, const int y1, const int x2, const int y2) {
      if(!CAppDialog::Create(chart, name, sw, x1, y1, x2, y2)) return false;

      int lx  = 18;   
      int rx  = 267;  
      int rh  = 30;   
      int ch  = 22;   
      int bh  = 28;   
      int y   = 15;   
      int lbl = 75;   
      int gap = 12;   
      int ex  = lx + lbl + gap;

      // Row 1: Symbol & Status
      if(!MkLabel(m_lbl_pair,   "LPair",   _Symbol,                         lx, y, lx+80, y+ch, 8)) return false;
      if(!MkLabel(m_lbl_spread, "LSpread", "Spread: 0", lx+85, y, rx, y+ch, 8)) return false;
      y += ch + 5;

      // Row 2: Balance
      if(!MkLabel(m_lbl_balance, "Bal",  "Balance: --", lx, y, rx, y+ch, 8)) return false;
      y += ch + 15;

      // Row 3: Risk
      if(!MkLabel(m_lbl_risk, "LR", "Risk ($):",  lx, y, ex-gap, y+ch)) return false;
      if(!MkEdit(m_edt_risk,  "ER", "0.5",       ex, y, rx-50, y+ch)) return false;
      if(!MkButton(m_btn_risk_mode, "BRM", " $ ", rx-45, y, rx, y+ch)) return false;
      y += rh;

      // Row 4: Entry Price
      if(!MkLabel(m_lbl_entry, "LE", "Entry:",    lx, y, ex-gap, y+ch)) return false;
      if(!MkEdit(m_edt_entry,  "EE", "",            ex, y, rx,   y+ch)) return false;
      y += rh;

      // Row 5: Stop Loss
      if(!MkLabel(m_lbl_sl, "LS", "Stop Loss:", lx, y, ex-gap, y+ch)) return false;
      if(!MkEdit(m_edt_sl,  "ES", "",             ex, y, rx,   y+ch)) return false;
      y += rh;

      // Row 6: RR Ratio
      if(!MkLabel(m_lbl_ratio, "LRt", "RR Ratio:", lx, y, ex-gap, y+ch)) return false;
      if(!MkEdit(m_edt_ratio, "ERt", "2.0", ex, y, rx, y+ch)) return false;
      y += rh;

      // Row 7: Lot Size
      if(!MkLabel(m_lbl_lot, "LL", "Lot Size: --", lx, y, rx, y+ch, 8)) return false;
      y += ch + 20;

      // Action Buttons
      int bww = (rx - lx - 10) / 2; // Half width minus gap
      
      // Row 8: Modifiers (Cutloss & Cancel)
      if(!MkButton(m_btn_cutloss, "BCL", "CL: OFF",     lx,        y, lx+bww,  y+bh)) return false;
      if(!MkButton(m_btn_cancel,  "BC",  "CAN. EDIT",   lx+bww+10, y, rx,      y+bh)) return false;
      y += bh + 10;

      // Row 9: Limit Order
      if(!MkButton(m_btn_place,   "BP",  "PLACE LIMIT ORDER", lx, y, rx, y+bh, 8)) return false;
      m_btn_place.ColorBackground(C'30,144,255'); m_btn_place.Color(clrWhite);
      y += bh + 10;

      // Row 10: Market Orders
      if(!MkButton(m_btn_buy_mkt,  "BBM", "BUY MKT",  lx,        y, lx+bww,  y+bh, 8)) return false;
      m_btn_buy_mkt.ColorBackground(C'0,130,80'); m_btn_buy_mkt.Color(clrWhite);
      if(!MkButton(m_btn_sell_mkt, "BSM", "SELL MKT", lx+bww+10, y, rx,      y+bh, 8)) return false;
      m_btn_sell_mkt.ColorBackground(C'176,0,32'); m_btn_sell_mkt.Color(clrWhite);
      y += bh + 10;

      // Row 11: Close All
      if(!MkButton(m_btn_close_all, "BCAll", "CLOSE ALL POSITIONS", lx, y, rx, y+bh, 8)) return false;
      m_btn_close_all.ColorBackground(C'50,50,50'); m_btn_close_all.Color(clrWhite);
      y += bh + 15;

      // Status
      if(!MkLabel(m_lbl_status, "LSt", "Status: AutoSnD Ready", lx, y, rx, y+ch)) return false;
      y += ch + 5;
      
      // Clock
      if(!MkLabel(m_lbl_clock, "LClk", "LOC --:-- | BAR --:--", lx, y, rx, y+ch, 8)) return false;
      m_lbl_clock.Color(clrDodgerBlue);
      
      return true;
   }
   virtual bool  OnEvent(const int id, const long &lp, const double &dp, const string &sp) {
      if(id == CHARTEVENT_CUSTOM + ON_CLICK) {
         if(lp == m_btn_place.Id())   { OnPlace();     return true; }
         if(lp == m_btn_cancel.Id())  { OnCancelBtn(); return true; }
         if(lp == m_btn_cutloss.Id()) { OnCutLoss();   return true; }
         if(lp == m_btn_risk_mode.Id()){ OnRiskModeToggle(); return true; }
         if(lp == m_btn_buy_mkt.Id()) { OnBuyMarket(); return true; }
         if(lp == m_btn_sell_mkt.Id()) { OnSellMarket(); return true; }
         if(lp == m_btn_close_all.Id()) { OnCloseAll(); return true; }
      }
      if(id == CHARTEVENT_CUSTOM + ON_END_EDIT) { if(lp == m_edt_risk.Id() || lp == m_edt_entry.Id() || lp == m_edt_sl.Id() || lp == m_edt_ratio.Id()) { OnInput(); return true; } }
      return CAppDialog::OnEvent(id, lp, dp, sp);
   }
};

CRiskPanel ExtPanel;

//=====================================================================
// [5] JOURNAL WEBHOOK & RESYNC
//=====================================================================
void SendTradeDataToWebhook(ulong ticket, string eventType)
  {
   if(InpWebhookURL == "" || InpWebhookToken == "") return;
   string symbol = "", typeStr = "", comment = "";
   double entryPrice=0, closePrice=0, slPrice=0, tpPrice=0, lotSize=0, profitLoss=0, swap=0, commission=0;
   long magicNumber=0, dealType=-1; datetime openTime=0, closeTime=0;

   if(eventType == "deal_close")
     {
      ulong dealTicket = ticket; // Save the original close deal ticket BEFORE any overwrite
      if(!HistoryDealSelect(dealTicket)) return;
      symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
      dealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
      typeStr = (dealType == DEAL_TYPE_BUY) ? "buy_closed" : ((dealType == DEAL_TYPE_SELL) ? "sell_closed" : "other_closed");
      closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
      lotSize    = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
      profitLoss = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
      swap       = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
      commission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
      magicNumber = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
      comment    = HistoryDealGetString(dealTicket, DEAL_COMMENT);
      closeTime  = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME); // Use dealTicket, NOT ticket
      long posID = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
      ticket = posID; // Now it is safe to override ticket (used as the Laravel matching key)
      if(HistorySelectByPosition(posID)) {
         for(int i=0; i<HistoryDealsTotal(); i++) {
            ulong dt = HistoryDealGetTicket(i);
            if(HistoryDealGetInteger(dt, DEAL_ENTRY) == DEAL_ENTRY_IN) { entryPrice = HistoryDealGetDouble(dt, DEAL_PRICE); openTime = (datetime)HistoryDealGetInteger(dt, DEAL_TIME); break; }
         }
      }
     }
   else if(eventType == "deal_open") // OPEN ORDER/POSITION
     {
      ulong dealTicket = ticket; // Save the original open deal ticket BEFORE any overwrite
      if(!HistoryDealSelect(dealTicket)) return;
      symbol   = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
      dealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
      typeStr  = (dealType == DEAL_TYPE_BUY) ? "buy" : ((dealType == DEAL_TYPE_SELL) ? "sell" : "other_open");
      entryPrice  = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
      lotSize     = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
      openTime    = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
      magicNumber = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
      comment     = HistoryDealGetString(dealTicket, DEAL_COMMENT);
      long posID  = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
      ticket = posID; // Override ticket with posID as the Laravel record key
      if(PositionSelectByTicket(posID)) { slPrice = PositionGetDouble(POSITION_SL); tpPrice = PositionGetDouble(POSITION_TP); }
     }
   else if(eventType == "pending_order" || eventType == "pending_cancel")
     {
      bool isCancel = (eventType == "pending_cancel");
      if(isCancel) { if(!HistoryOrderSelect(ticket)) return; } else { if(!OrderSelect(ticket)) return; }
      symbol = isCancel ? HistoryOrderGetString(ticket, ORDER_SYMBOL) : OrderGetString(ORDER_SYMBOL);
      dealType = isCancel ? HistoryOrderGetInteger(ticket, ORDER_TYPE) : OrderGetInteger(ORDER_TYPE);
      if(dealType == ORDER_TYPE_BUY_LIMIT) typeStr = "buy_limit"; else if(dealType == ORDER_TYPE_SELL_LIMIT) typeStr = "sell_limit";
      else if(dealType == ORDER_TYPE_BUY_STOP) typeStr = "buy_stop"; else if(dealType == ORDER_TYPE_SELL_STOP) typeStr = "sell_stop";
      if(isCancel) typeStr = "pending_cancel";
      entryPrice = isCancel ? HistoryOrderGetDouble(ticket, ORDER_PRICE_OPEN) : OrderGetDouble(ORDER_PRICE_OPEN);
      slPrice = isCancel ? HistoryOrderGetDouble(ticket, ORDER_SL) : OrderGetDouble(ORDER_SL);
      tpPrice = isCancel ? HistoryOrderGetDouble(ticket, ORDER_TP) : OrderGetDouble(ORDER_TP);
      lotSize = isCancel ? HistoryOrderGetDouble(ticket, ORDER_VOLUME_INITIAL) : OrderGetDouble(ORDER_VOLUME_INITIAL);
      openTime = isCancel ? (datetime)HistoryOrderGetInteger(ticket, ORDER_TIME_SETUP) : (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      closeTime = isCancel ? (datetime)HistoryOrderGetInteger(ticket, ORDER_TIME_DONE) : 0;
      magicNumber = isCancel ? HistoryOrderGetInteger(ticket, ORDER_MAGIC) : OrderGetInteger(ORDER_MAGIC);
      comment = isCancel ? HistoryOrderGetString(ticket, ORDER_COMMENT) : OrderGetString(ORDER_COMMENT);
     }
   else if(eventType == "balance")
     {
      if(!HistoryDealSelect(ticket)) return;
      dealType = HistoryDealGetInteger(ticket, DEAL_TYPE);
      profitLoss = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      typeStr = (profitLoss >= 0) ? "deposit" : "withdrawal";
      openTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      closeTime = openTime;
      comment = HistoryDealGetString(ticket, DEAL_COMMENT);
      symbol = ""; lotSize = 0; entryPrice = 0; closePrice = 0; slPrice = 0; tpPrice = 0; swap = 0; commission = 0; magicNumber = 0;
     }

   string oTS = (openTime > 0) ? TimeToString(openTime, TIME_DATE | TIME_SECONDS) : "";
   string cTS = (closeTime > 0) ? TimeToString(closeTime, TIME_DATE | TIME_SECONDS) : "";
   StringReplace(oTS, ".", "-"); StringReplace(cTS, ".", "-");
   string accCurr = AccountInfoString(ACCOUNT_CURRENCY); StringToLower(accCurr);
   double div = (StringFind(accCurr, "c") >= 0) ? 100.0 : 1.0;
   
   string accLogin = IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN));
   string accServer = AccountInfoString(ACCOUNT_SERVER);
   string accountName = accLogin + " - " + accServer;
   StringReplace(accountName, "\"", "\\\"");
   
   string json = "{";
   json += "\"account_name\": \"" + accountName + "\",";
   json += "\"ticket_id\": \"" + IntegerToString(ticket) + "\", \"symbol\": \"" + symbol + "\", \"type\": \"" + typeStr + "\",";
   json += "\"entry_price\": " + DoubleToString(entryPrice, 5) + ", \"close_price\": " + DoubleToString(closePrice, 5) + ",";
   json += "\"sl_price\": " + DoubleToString(slPrice, 5) + ", \"tp_price\": " + DoubleToString(tpPrice, 5) + ",";
   json += "\"lot_size\": " + DoubleToString(lotSize, 2) + ", \"profit_loss\": " + DoubleToString(profitLoss/div, 2) + ",";
   json += "\"swap\": " + DoubleToString(swap/div, 2) + ", \"commission\": " + DoubleToString(commission/div, 2) + ",";
   if(oTS != "") json += "\"open_time\": \"" + oTS + "\",";
   if(cTS != "") json += "\"close_time\": \"" + cTS + "\",";
   json += "\"magic_number\": \"" + IntegerToString(magicNumber) + "\",";
   StringReplace(comment, "\"", "\\\""); json += "\"comment\": \"" + comment + "\",";
   json += "\"balance\": " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE)/div, 2) + "}";

   char post[], resW[];
   string headers = "Content-Type: application/json\r\nX-Webhook-Token: " + InpWebhookToken + "\r\n";
   StringToCharArray(json, post, 0, WHOLE_ARRAY, CP_UTF8);
   int ps = ArraySize(post); if(ps > 0) ArrayResize(post, ps - 1);
   string resHeaders;
   int res = WebRequest("POST", InpWebhookURL, headers, 3000, post, resW, resHeaders);
   if(res == -1) {
      int err = GetLastError();
      if(err == 4014) Print("WEBHOOK BLOCKED! Please go to Tools -> Options -> Expert Advisors, tick 'Allow WebRequest' and add: ", InpWebhookURL);
      else Print("WEBHOOK ERROR! Ticket: ", ticket, " Event: ", eventType, " Code: ", err);
   } else if(res != 200 && res != 201) {
      Print("WEBHOOK SERVER ERROR! HTTP ", res, " | Ticket: ", ticket, " Event: ", eventType);
   }
  }

void SendAlertToWebhook(string message)
  {
   if(InpWebhookURL == "" || InpWebhookToken == "") return;

   string accLogin   = IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN));
   string accServer  = AccountInfoString(ACCOUNT_SERVER);
   string accountName = accLogin + " - " + accServer;
   StringReplace(accountName, "\"", "\\\"");
   
   string safeMsg = message;
   StringReplace(safeMsg, "\"", "\\\"");
   StringReplace(safeMsg, "\n", " ");
   
   string json = "{";
   json += "\"account_name\": \"" + accountName + "\",";
   json += "\"type\": \"alert\",";
   json += "\"symbol\": \"" + _Symbol + "\",";
   json += "\"comment\": \"" + safeMsg + "\"";
   json += "}";

   string headers = "Content-Type: application/json\r\nX-Webhook-Token: " + InpWebhookToken + "\r\n";
   char post[], resW[];
   StringToCharArray(json, post, 0, WHOLE_ARRAY, CP_UTF8);
   int ps = ArraySize(post); if(ps > 0) ArrayResize(post, ps - 1);
   string resHeaders;
   WebRequest("POST", InpWebhookURL, headers, 3000, post, resW, resHeaders);
  }

void ResyncHistory()
  {
   if(InpResyncDays <= 0 || InpWebhookURL == "") return;
   Print("ResyncHistory: starting sync for last ", InpResyncDays, " days...");
   
   datetime to   = TimeCurrent() + 86400;
   datetime from = TimeCurrent() - (InpResyncDays * 86400);
   
   // -----------------------------------------------------------------------
   // STEP 1: Closed trades (DEAL_ENTRY_OUT) & Balance deals from history
   // -----------------------------------------------------------------------
   ulong outDeals[];
   ulong balanceDeals[];
   if(HistorySelect(from, to))
     {
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
        {
         ulong t = HistoryDealGetTicket(i);
         long  dealEntry = HistoryDealGetInteger(t, DEAL_ENTRY);
         long  dealType  = HistoryDealGetInteger(t, DEAL_TYPE);
         if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
           {
            int sz = ArraySize(outDeals);
            ArrayResize(outDeals, sz + 1);
            outDeals[sz] = t;
           }
         else if(dealType == DEAL_TYPE_BALANCE)
           {
            int sz = ArraySize(balanceDeals);
            ArrayResize(balanceDeals, sz + 1);
            balanceDeals[sz] = t;
           }
        }
     }
   // Send closed trades
   for(int i = 0; i < ArraySize(outDeals); i++)
      SendTradeDataToWebhook(outDeals[i], "deal_close");
   // Send balance/deposit/withdrawal
   for(int i = 0; i < ArraySize(balanceDeals); i++)
      SendTradeDataToWebhook(balanceDeals[i], "balance");

   Print("ResyncHistory: sent ", ArraySize(outDeals), " closed trades, ", ArraySize(balanceDeals), " balance entries.");

   // -----------------------------------------------------------------------
   // STEP 2: Currently open positions (send as deal_open)
   // -----------------------------------------------------------------------
   int openCount = 0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong posTicket = PositionGetTicket(i); // Also selects the position
      if(posTicket == 0) continue;
      long posID = PositionGetInteger(POSITION_IDENTIFIER);
      // Find the IN deal for this position
      if(HistorySelectByPosition(posID))
        {
         for(int d = 0; d < HistoryDealsTotal(); d++)
           {
            ulong dt = HistoryDealGetTicket(d);
            if(HistoryDealGetInteger(dt, DEAL_ENTRY) == DEAL_ENTRY_IN)
              {
               SendTradeDataToWebhook(dt, "deal_open");
               openCount++;
               break;
              }
           }
        }
     }
   Print("ResyncHistory: sent ", openCount, " open positions.");

   // -----------------------------------------------------------------------
   // STEP 3: Pending orders
   // -----------------------------------------------------------------------
   int pendingCount = 0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong ot = OrderGetTicket(i);
      if(ot == 0) continue;
      SendTradeDataToWebhook(ot, "pending_order");
      pendingCount++;
     }
   Print("ResyncHistory: sent ", pendingCount, " pending orders. DONE.");
  }


//=====================================================================
// [6] AUTO SND TRADING ENGINE - SnD_Zone Logic + Fibo Filter
//=====================================================================

// ---- Zone Drawing (from SnD_Zone.mq5) ----
void DrawZone(bool is_demand, double top, double btm, datetime start_time, ENUM_ZONE_TYPE ztype=ZONE_RBD_DBR, datetime end_time=0)
  {
   if(g_zone_count >= MAX_ZONES) return;
   
   bool show_visual = (ztype == ZONE_RBD_DBR) ? InpShowRbdDbr : InpShowRbrDbd;
   color col_use = (ztype == ZONE_RBD_DBR) ? (is_demand ? InpDemandColor : InpSupplyColor) : InpContColor;
   bool  fill_box = true;
   string stype = (ztype == ZONE_RBD_DBR) ? (is_demand?"Origin Demand":"Origin Supply") : (is_demand?"Demand (RBR)":"Supply (DBD)");
   
   string uid=NextID(), rname="SnD_Z_"+uid;
   if(show_visual)
     {
      if(ObjectCreate(0,rname,OBJ_RECTANGLE,0,start_time,top,D'2099.12.31',btm))
        { ObjectSetInteger(0,rname,OBJPROP_COLOR,col_use); ObjectSetInteger(0,rname,OBJPROP_FILL,fill_box); ObjectSetInteger(0,rname,OBJPROP_BACK,true); ObjectSetInteger(0,rname,OBJPROP_SELECTABLE,false); ObjectSetString(0,rname,OBJPROP_TOOLTIP,stype+" | Top:"+DoubleToString(top,_Digits)+" Btm:"+DoubleToString(btm,_Digits)); }
      double center_price = top - ((top - btm) / 2.0);
      datetime right_edge = TimeCurrent();
      datetime mid_time = (datetime)(((long)start_time + (long)right_edge) / 2);
      string pinfo="SnD_PI_"+uid;
      string price_txt = DoubleToString(top,_Digits) + " / " + DoubleToString(btm,_Digits);
      if(ObjectCreate(0,pinfo,OBJ_TEXT,0,mid_time,center_price)) { 
          ObjectSetString(0,pinfo,OBJPROP_TEXT,price_txt); 
          ObjectSetInteger(0,pinfo,OBJPROP_COLOR,clrBlack); 
          ObjectSetInteger(0,pinfo,OBJPROP_FONTSIZE,6);
          ObjectSetInteger(0,pinfo,OBJPROP_ANCHOR,ANCHOR_CENTER);
          ObjectSetInteger(0,pinfo,OBJPROP_SELECTABLE,false); 
          ObjectSetInteger(0,pinfo,OBJPROP_BACK,false); 
      }
     }
   
   g_zones[g_zone_count].rect_name=rname; g_zones[g_zone_count].lbl_name=""; g_zones[g_zone_count].lbl_top=show_visual ? "SnD_PI_"+uid : ""; g_zones[g_zone_count].lbl_btm="";
   g_zones[g_zone_count].is_demand=is_demand; g_zones[g_zone_count].top=top; g_zones[g_zone_count].btm=btm;
   g_zones[g_zone_count].start_time=start_time;
   g_zones[g_zone_count].end_time = (end_time > 0) ? end_time : start_time; // Default ke start_time jika tidak disetel
   g_zones[g_zone_count].active=true;
   g_zones[g_zone_count].type=ztype;
   g_zone_count++;
  }

void DrawBOS(bool is_bull, double price, datetime x1, datetime x2)
  {
   if(!InpShowBOS) return;
   color col=is_bull?InpBOSBull:InpBOSBear;
   string uid=NextID(),ln="SnD_B_"+uid,lb="SnD_BL_"+uid;
   if(ObjectCreate(0,ln,OBJ_TREND,0,x1,price,x2,price)) { ObjectSetInteger(0,ln,OBJPROP_COLOR,col); ObjectSetInteger(0,ln,OBJPROP_STYLE,STYLE_DASH); ObjectSetInteger(0,ln,OBJPROP_RAY_RIGHT,false); ObjectSetInteger(0,ln,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,ln,OBJPROP_BACK,true); }
   datetime mid=(datetime)(((long)x1+(long)x2)/2);
   if(ObjectCreate(0,lb,OBJ_TEXT,0,mid,price)) { ObjectSetString(0,lb,OBJPROP_TEXT,"BOS"); ObjectSetInteger(0,lb,OBJPROP_COLOR,col); ObjectSetInteger(0,lb,OBJPROP_FONTSIZE,6); ObjectSetInteger(0,lb,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,lb,OBJPROP_BACK,true); }
  }

void MitigateZone(int idx, datetime t)
  {
   g_zones[idx].active=false;
   
   // Always delete text labels for mitigated zones
   ObjectDelete(0,g_zones[idx].lbl_name); 
   ObjectDelete(0,g_zones[idx].lbl_top); 
   ObjectDelete(0,g_zones[idx].lbl_btm);
   
   if(InpShowMitigated)
     {
      // Cap the rectangle at the mitigation time
      ObjectSetInteger(0,g_zones[idx].rect_name,OBJPROP_TIME,1,t);
      // Change styling to background color, transparent background
      ObjectSetInteger(0,g_zones[idx].rect_name,OBJPROP_COLOR,InpMitColor);
      ObjectSetInteger(0,g_zones[idx].rect_name,OBJPROP_FILL,false); // Transparent background
     }
   else
     {
      ObjectDelete(0,g_zones[idx].rect_name); 
     }
  }

void UpdateZoneLabelsTime(datetime t)
  {
   // Teks harga dikalkulasi posisinya agar selalu terpusat di tengah-tengah zona yang membentang aktif
   for(int i=0;i<g_zone_count;i++) 
      if(g_zones[i].active && g_zones[i].lbl_top != "") 
        { 
         datetime mid = (datetime)(((long)g_zones[i].start_time + (long)t) / 2);
         double center_price = g_zones[i].top - ((g_zones[i].top - g_zones[i].btm) / 2.0);
         ObjectMove(0,g_zones[i].lbl_top,0,mid,center_price); 
        }
  }

// ---- Pivot Detection ----
double GetPivotHigh(int lb, int shift)
  {
   if(shift+2*lb >= iBars(_Symbol,_Period)) return 0;
   double c = iHigh(_Symbol,_Period,shift+lb);
   for(int i=shift;i<=shift+2*lb;i++) { if(i==shift+lb) continue; if(iHigh(_Symbol,_Period,i)>=c) return 0; }
   return c;
  }

double GetPivotLow(int lb, int shift)
  {
   if(shift+2*lb >= iBars(_Symbol,_Period)) return 0;
   double c = iLow(_Symbol,_Period,shift+lb);
   for(int i=shift;i<=shift+2*lb;i++) { if(i==shift+lb) continue; if(iLow(_Symbol,_Period,i)<=c) return 0; }
   return c;
  }

int FindDemandBase(datetime pivot_time, double &top, double &btm) {
    int pi = iBarShift(_Symbol, _Period, pivot_time);
    if(pi < 0) return -1;
    // SMC: Tipe DBR (Demand) - Cari Last Down Candle tertambat pada Pivot Low
    for(int i = pi; i <= pi + 5; i++) {
        if(iClose(_Symbol, _Period, i) < iOpen(_Symbol, _Period, i)) { // Bearish candle
            top = iOpen(_Symbol, _Period, i); // Opsi B: Top adalah OPEN dari candle bearish
            btm = iLow(_Symbol, _Period, i);  // Bottom adalah LOW
            return i;
        }
    }
    return -1;
}

int FindSupplyBase(datetime pivot_time, double &top, double &btm) {
    int pi = iBarShift(_Symbol, _Period, pivot_time);
    if(pi < 0) return -1;
    // SMC: Tipe RBD (Supply) - Cari Last Up Candle tertambat pada Pivot High
    for(int i = pi; i <= pi + 5; i++) {
        if(iClose(_Symbol, _Period, i) > iOpen(_Symbol, _Period, i)) { // Bullish candle
            top = iHigh(_Symbol, _Period, i); // Opsi B: Top adalah HIGH
            btm = iOpen(_Symbol, _Period, i); // Bottom adalah OPEN dari candle bullish
            return i;
        }
    }
    return -1;
}

void CheckMitigation(int shift)
  {
   double high=iHigh(_Symbol,_Period,shift);
   double low=iLow(_Symbol,_Period,shift);
   datetime bt=iTime(_Symbol,_Period,shift);
   for(int i=g_zone_count-1;i>=0;i--)
     {
      if(!g_zones[i].active||bt<=g_zones[i].start_time) continue;
      // Mitigasi dengan sentuhan (Wicks) di dinding zona (1-Tap Mitigation)
      bool mit=g_zones[i].is_demand?(low <= g_zones[i].top):(high >= g_zones[i].btm);
      if(mit) MitigateZone(i,bt);
     }
  }

// ---- Filter: Momentum Candle wajib muncul dalam N candle setelah candle terakhir Base ----
bool IsMomentumAfterBase(bool isBullish, int shift, double &out_sl_level) {
   datetime candle_time = iTime(_Symbol, _Period, shift);
   double   pt          = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   for(int i = 0; i < g_zone_count; i++) {
      if(!g_zones[i].active)                    continue; // Hanya zona masih aktif
      if(g_zones[i].type != ZONE_RBR_DBD)       continue; // Hanya Original Zone
      if(isBullish  && !g_zones[i].is_demand)   continue; // Bullish → cari Demand
      if(!isBullish &&  g_zones[i].is_demand)   continue; // Bearish → cari Supply
      if(g_zones[i].end_time >= candle_time)    continue; // Base harus selesai SEBELUM candle momentum
      
      // Hitung jarak candle dari UJUNG (candle terakhir) Base ke candle momentum
      int end_bar    = iBarShift(_Symbol, _Period, g_zones[i].end_time);
      int distance   = end_bar - shift; // Berapa candle ke kanan dari akhir base
      
      if(distance >= 0 && distance <= InpMomMaxCandlesAfterBase) {
         // SL dipasang di BATAS ZONA, bukan di wick candle momentum
         out_sl_level = isBullish
            ? NormalizeDouble(g_zones[i].btm - InpBufferPoints * pt, _Digits) // Bawah Demand Zone
            : NormalizeDouble(g_zones[i].top + InpBufferPoints * pt, _Digits); // Atas Supply Zone
         return true;
      }
   }
   return false;
}

// ---- Auto Momentum Trade Execution ----
void ExecuteMomentumAutoTrade(bool isBullish, int shift, double customSL = 0)
  {
   if(!InpEnableAutoMomentum) return;

   // *** DRAWDOWN PROTECTION: Block auto trading if daily loss limit is reached ***
   if(IsDailyLossLimitReached())
     {
      ExtPanel.SetStatus("Daily Loss Limit! Auto paused.");
      return;
     }
   
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double pt     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double high   = iHigh(_Symbol, _Period, shift);
   double low    = iLow(_Symbol, _Period, shift);
   
   // SL: gunakan custom SL dari zona jika tersedia, fallback ke wick candle + buffer
   double stopLoss;
   if(customSL > 0)
      stopLoss = customSL;
   else
      stopLoss = isBullish
               ? NormalizeDouble(low  - InpBufferPoints * pt, digits)
               : NormalizeDouble(high + InpBufferPoints * pt, digits);
   
   // Entry: harga pasar saat ini
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double entry = isBullish ? ask : bid;
   
   // Validasi arah SL
   if(isBullish  && stopLoss >= entry) { Print("AutoMomentum: SL BUY tidak valid:", stopLoss, " >= entry:", entry);  return; }
   if(!isBullish && stopLoss <= entry) { Print("AutoMomentum: SL SELL tidak valid:", stopLoss, " <= entry:", entry); return; }
   
   double riskAmount = ExtPanel.AdjRisk();
   if(riskAmount <= 0) { Print("AutoMomentum: Risk <= 0, cek panel."); return; }
   
   double lot = CalcLotSize(riskAmount, entry, stopLoss, _Symbol);
   if(lot <= 0)
     {
      string msg = "AutoMomentum: Lot tidak valid (" + DoubleToString(lot,2) + "). Cek Risk Panel atau jarak SL.";
      Print(msg); SendAlertToWebhook(msg);
      return;
     }
   
   // TP berdasarkan input RR khusus (jika disetel > 0), jika tidak gunakan dari panel
   double mult = InpMomentumRR > 0 ? InpMomentumRR : StringToDouble(ExtPanel.m_edt_ratio.Text());
   if(mult <= 0) mult = 2.0;
   double diff = MathAbs(entry - stopLoss);
   double tp   = isBullish
               ? NormalizeDouble(entry + diff * mult, digits)
               : NormalizeDouble(entry - diff * mult, digits);
   
   // Gunakan Soft CL jika aktif (hard SL lebih jauh, komentar menyimpan level cut)
   double hardSL = stopLoss;
   string comm   = "MOM_AUTO[" + GetTFString() + "]";
   if(ExtPanel.m_cl_active)
     {
      comm   = "MOM_AUTO|RP_CL_" + DoubleToString(stopLoss, digits) + "[" + GetTFString() + "]";
      hardSL = isBullish
             ? NormalizeDouble(entry - diff * 2.0, digits)
             : NormalizeDouble(entry + diff * 2.0, digits);
     }
   
   bool result = isBullish
               ? ExtTrade.Buy (lot, _Symbol, entry, hardSL, tp, comm)
               : ExtTrade.Sell(lot, _Symbol, entry, hardSL, tp, comm);
   
   string dir = isBullish ? "BUY" : "SELL";
   if(result)
     {
      Print("AutoMomentum Executed: ", dir, " Lot:", lot, " Entry:", entry, " SL:", stopLoss, " TP:", tp);
      ExtPanel.SetStatus("Auto Mom " + dir + " | Lot: " + DoubleToString(lot,2));
     }
   else
     {
      string err = "AutoMomentum FAILED " + dir + " | Error: " + IntegerToString(GetLastError());
      Print(err); SendAlertToWebhook(err);
      ExtPanel.SetStatus("AutoMom Gagal: Err " + IntegerToString(GetLastError()));
     }
  }



// ---- Main ProcessBar (identical to SnD_Zone + Fibo trigger) ----
void ProcessBar(int shift)
  {
   g_old_last_ph=g_last_ph; g_old_last_pl=g_last_pl;

   double ph=GetPivotHigh(InpPivotLB,shift);
   if(ph>0)
     {
      datetime t=iTime(_Symbol,_Period,shift+InpPivotLB);
      g_last_ph=ph; g_last_ph_time=t;
     }

   double pl=GetPivotLow(InpPivotLB,shift);
   if(pl>0)
     {
      datetime t=iTime(_Symbol,_Period,shift+InpPivotLB);
      g_last_pl=pl; g_last_pl_time=t;
     }

   double cls=iClose(_Symbol,_Period,shift);

   bool bull_bos=g_last_ph>0&&cls>g_last_ph&&g_last_ph_time!=g_marked_ph_time;
   bool bear_bos=g_last_pl>0&&cls<g_last_pl&&g_last_pl_time!=g_marked_pl_time;

   if(bull_bos)
     {
      g_marked_ph_time=g_last_ph_time;
      DrawBOS(true,g_last_ph,g_last_ph_time,iTime(_Symbol,_Period,shift));
      
      if(InpShowRbdDbr) {
         double top = -1, btm = -1;
         int base = FindDemandBase(g_last_pl_time, top, btm);
         if(base != -1) DrawZone(true, top, btm, iTime(_Symbol, _Period, base));
      }
     }

   if(bear_bos)
     {
      g_marked_pl_time=g_last_pl_time;
      DrawBOS(false,g_last_pl,g_last_pl_time,iTime(_Symbol,_Period,shift));
      
      if(InpShowRbdDbr) {
         double top = -1, btm = -1;
         int base = FindSupplyBase(g_last_ph_time, top, btm);
         if(base != -1) DrawZone(false, top, btm, iTime(_Symbol, _Period, base));
      }
     }

   CheckMitigation(shift);
   CheckContinuationZone(shift);

  }

void ScanHistory()
  {
   g_is_scanning_history = true;
   int total=iBars(_Symbol,_Period);
   int start=MathMin(InpHistoryBars+InpPivotLB*2+InpOriginLookback,total-2);
   for(int i=start;i>=1;i--) ProcessBar(i);
   g_is_scanning_history = false;
  }

void DeleteAllSnDObjects()
  {
   for(int i=ObjectsTotal(0)-1;i>=0;i--)
     { string n=ObjectName(0,i); if(StringFind(n,"SnD_")==0) ObjectDelete(0,n); }
  }

//=====================================================================
// [6.1] MOMENTUM INDICATOR & DETECTOR
//=====================================================================
void DrawMomentumArrow(bool isBullish, int index) {
   datetime t = iTime(_Symbol, _Period, index);
   double high = iHigh(_Symbol, _Period, index);
   double low  = iLow(_Symbol, _Period, index);
   double range = high - low;
   string objName = (isBullish ? "MomUp_" : "MomDn_") + TimeToString(t);
   
   double price = isBullish ? (low - (range * 0.2)) : (high + (range * 0.2));
   
   if(ObjectFind(0, objName) >= 0) {
      ObjectMove(0, objName, 0, t, price);
      return;
   }
   
   if(isBullish) {
      ObjectCreate(0, objName, OBJ_ARROW_UP, 0, t, price);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      ObjectSetString(0, objName, OBJPROP_TOOLTIP, "Bullish Momentum Candle");
   } else {
      ObjectCreate(0, objName, OBJ_ARROW_DOWN, 0, t, price);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrCrimson);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      ObjectSetString(0, objName, OBJPROP_TOOLTIP, "Bearish Momentum Candle");
   }
}

bool IsBullishMomentum(int index = 1) {
   double atr[];
   if(CopyBuffer(g_atr_handle, 0, index, 1, atr) <= 0) return false;
   
   double high = iHigh(_Symbol, _Period, index);
   double low  = iLow(_Symbol, _Period, index);
   double open = iOpen(_Symbol, _Period, index);
   double close= iClose(_Symbol, _Period, index);
   
   double totalLength = high - low;
   if(totalLength <= 0) return false;
   
   // 1. ATR Filter
   if(totalLength <= atr[0] * InpATRMultiplier) return false;
   
   // 2. Dominant Body
   if(close <= open) return false; // Not bullish
   double bodyLength = close - open;
   if(bodyLength < totalLength * InpBodyPercentage) return false;
   
   // 3. Minimal Lower Wick (opposite wick)
   double lowerWick = open - low;
   if(lowerWick > totalLength * InpWickPercentage) return false;
   
   return true;
}

bool IsBearishMomentum(int index = 1) {
   double atr[];
   if(CopyBuffer(g_atr_handle, 0, index, 1, atr) <= 0) return false;
   
   double high = iHigh(_Symbol, _Period, index);
   double low  = iLow(_Symbol, _Period, index);
   double open = iOpen(_Symbol, _Period, index);
   double close= iClose(_Symbol, _Period, index);
   
   double totalLength = high - low;
   if(totalLength <= 0) return false;
   
   // 1. ATR Filter
   if(totalLength <= atr[0] * InpATRMultiplier) return false;
   
   // 2. Dominant Body
   if(open <= close) return false; // Not bearish
   double bodyLength = open - close;
   if(bodyLength < totalLength * InpBodyPercentage) return false;
   
   // 3. Minimal Upper Wick (opposite wick)
   double upperWick = high - open;
   if(upperWick > totalLength * InpWickPercentage) return false;
   
   return true;
}

void ScanHistoricalMomentum() {
   int total = iBars(_Symbol, _Period);
   int start = MathMin(InpHistoryBars, total - 2);
   for(int i = start; i >= 1; i--) {
      if(IsBullishMomentum(i)) DrawMomentumArrow(true, i);
      else if(IsBearishMomentum(i)) DrawMomentumArrow(false, i);
   }
}

void CheckContinuationZone(int shift) {
   if(!InpShowRbrDbd && !InpAutoTradeRbrDbd) return;
   
   bool is_bull_rally = IsBullishMomentum(shift);
   bool is_bear_drop  = IsBearishMomentum(shift);
   if(!is_bull_rally && !is_bear_drop) return;
   
   double leg_out_range = iHigh(_Symbol, _Period, shift) - iLow(_Symbol, _Period, shift);
   int best_base_start = -1;
   int best_base_end = -1;
   
   for(int k=1; k<=InpBaseMaxCandles; k++) {
      int idx_leg_in = shift + k + 1;
      bool leg_in_valid = is_bull_rally ? (iClose(_Symbol,_Period,idx_leg_in) > iOpen(_Symbol,_Period,idx_leg_in))
                                        : (iClose(_Symbol,_Period,idx_leg_in) < iOpen(_Symbol,_Period,idx_leg_in));
      if(!leg_in_valid) continue;
      
      bool valid_base = true;
      double max_h = 0, min_l = 999999;
      for(int b=1; b<=k; b++) {
         int b_idx = shift + b;
         double h = iHigh(_Symbol, _Period, b_idx);
         double l = iLow(_Symbol, _Period, b_idx);
         if(h > max_h) max_h = h;
         if(l < min_l) min_l = l;
         double rng = h - l;
         if(rng > leg_out_range * 0.6) { valid_base = false; break; }
      }
      if(valid_base && (max_h - min_l) < leg_out_range * 1.5) {
         best_base_start = shift + k;
         best_base_end = shift + 1;
         break;
      }
   }
   
   if(best_base_end != -1) {
      double top = 0, btm = 999999;
      for(int i=best_base_end; i<=best_base_start; i++) {
         if(iHigh(_Symbol, _Period, i) > top) top = iHigh(_Symbol, _Period, i);
         if(iLow(_Symbol, _Period, i) < btm) btm = iLow(_Symbol, _Period, i);
      }
      datetime st = iTime(_Symbol, _Period, best_base_start);
      for(int z=0; z<g_zone_count; z++) {
         if(g_zones[z].start_time == st && g_zones[z].type == ZONE_RBR_DBD) return;
      }
      
      datetime et = iTime(_Symbol, _Period, best_base_end); // Waktu candle TERAKHIR (terkanan) base
      DrawZone(is_bull_rally, top, btm, st, ZONE_RBR_DBD, et);
   }
}

//=====================================================================
// [7] EVENT HANDLERS
//=====================================================================
bool g_resync_done = false;

int OnInit()
  {
   // Panel height increased to accommodate new padded rows (total 520px)
   if(!ExtPanel.Create(0, "AutoSnD - Risk Panel", 0, 20, 30, 305, 520)) return INIT_FAILED;
   ExtPanel.Run();
   
   g_atr_handle = iATR(_Symbol, _Period, InpATRPeriod);
   if(g_atr_handle == INVALID_HANDLE) { Print("Gagal inisialisasi ATR untuk Momentum"); return INIT_FAILED; }
   
   // Reset semua state zona agar tidak ada "hantu" dari timeframe sebelumnya
   g_zone_count = 0;
   g_obj_id = 0;
   g_last_ph = 0; g_last_ph_time = 0;
   g_last_pl = 0; g_last_pl_time = 0;
   g_old_last_ph = 0; g_old_last_pl = 0;
   g_marked_ph_time = 0; g_marked_pl_time = 0;
   g_resync_done = false;
   
   ScanHistory(); // Scan full history using SnD_Zone logic
   ScanHistoricalMomentum(); // Scan Momentum indicators
   
   g_last_processed_bar = iTime(_Symbol, _Period, 0);
   UpdateZoneLabelsTime(TimeCurrent()); // Posisikan label teks presisi di tengah-tengah seketika EA dinyalakan
   
   Print("AutoSnD EA v3.00 Ready.");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   DeleteAllSnDObjects();
   for(int i=ObjectsTotal(0)-1;i>=0;i--) {
      string n=ObjectName(0,i);
      if(StringFind(n,"MomUp_")==0 || StringFind(n,"MomDn_")==0) ObjectDelete(0,n);
   }
   ExtPanel.Destroy(reason);
  }

void OnTick()
  {
   if(!g_resync_done) { ResyncHistory(); g_resync_done = true; }
   ExtPanel.UpdateStats();
   CheckCutLoss();
   CheckProfitProtection();
   CheckAutoCloseFriday();

   // Show daily loss limit warning on panel every tick when active
   if(InpEnableDailyLossLimit && IsDailyLossLimitReached())
      ExtPanel.SetStatus("Daily Limit! Auto paused.");
   
   // Selalu update label text agar dinamis terus berada di TENGAH kotak
   UpdateZoneLabelsTime(TimeCurrent());
   
   // Engine Auto SnD memproses candle jika baru ditutup
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime != g_last_processed_bar)
     {
      ProcessBar(1); // Proses lilin 1 (baru tertutup)
      
      bool isBullMom = IsBullishMomentum(1);
      bool isBearMom = IsBearishMomentum(1);
      
      if(isBullMom) {
         DrawMomentumArrow(true, 1);
         double sl_zone = 0;
         if(IsMomentumAfterBase(true, 1, sl_zone)) ExecuteMomentumAutoTrade(true, 1, sl_zone);
      } else if(isBearMom) {
         DrawMomentumArrow(false, 1);
         double sl_zone = 0;
         if(IsMomentumAfterBase(false, 1, sl_zone)) ExecuteMomentumAutoTrade(false, 1, sl_zone);
      }
      
      g_last_processed_bar = currentBarTime;
     }

   // Update jam digital di panel setiap tick
   ExtPanel.UpdateClock(currentBarTime);
   
   // --- Early Momentum Signal (Realtime check di shift 0) ---
   if(InpEarlySignalSeconds > 0)
     {
      int seconds_left = (int)(currentBarTime + PeriodSeconds(_Period) - TimeCurrent());
      if(seconds_left > 0 && seconds_left <= InpEarlySignalSeconds)
        {
         if(IsBullishMomentum(0)) DrawMomentumArrow(true, 0);
         else if(IsBearishMomentum(0)) DrawMomentumArrow(false, 0);
         else {
            // Jika tiba-tiba syarat batal, hapus panah
            ObjectDelete(0, "MomUp_" + TimeToString(currentBarTime));
            ObjectDelete(0, "MomDn_" + TimeToString(currentBarTime));
         }
        }
     }
  }

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &req, const MqlTradeResult &res)
  {
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD) {
      if(HistoryDealSelect(trans.deal)) {
         long dealType = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
         if(dealType == DEAL_TYPE_BALANCE) {
            SendTradeDataToWebhook(trans.deal, "balance");
         } else {
            long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
            if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT) SendTradeDataToWebhook(trans.deal, "deal_close");
            else if(entry == DEAL_ENTRY_IN) SendTradeDataToWebhook(trans.deal, "deal_open");
         }
      }
   }
   if(trans.type == TRADE_TRANSACTION_ORDER_ADD) {
      if(OrderSelect(trans.order)) {
         long ot = OrderGetInteger(ORDER_TYPE);
         if(ot==ORDER_TYPE_BUY_LIMIT||ot==ORDER_TYPE_SELL_LIMIT||ot==ORDER_TYPE_BUY_STOP||ot==ORDER_TYPE_SELL_STOP) { Sleep(100); SendTradeDataToWebhook(trans.order, "pending_order"); }
      }
   }
   if(trans.type == TRADE_TRANSACTION_HISTORY_ADD) {
      if(HistoryOrderSelect(trans.order)) {
         long ot = HistoryOrderGetInteger(trans.order, ORDER_TYPE); long os = HistoryOrderGetInteger(trans.order, ORDER_STATE);
         if((ot==ORDER_TYPE_BUY_LIMIT||ot==ORDER_TYPE_SELL_LIMIT||ot==ORDER_TYPE_BUY_STOP||ot==ORDER_TYPE_SELL_STOP) && os==ORDER_STATE_CANCELED) { Sleep(100); SendTradeDataToWebhook(trans.order, "pending_cancel"); }
      }
   }
  }

void OnChartEvent(const int id, const long &lp, const double &dp, const string &sp)
  { ExtPanel.ChartEvent(id, lp, dp, sp); }
//+------------------------------------------------------------------+


