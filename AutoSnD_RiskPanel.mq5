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

//=====================================================================
// [1] INPUT PARAMETERS
//=====================================================================
input group "=== Risk Panel & Webhook ==="
input string  InpWebhookURL = "http://jurnaltradingku.my.id/api/webhook/trading-log"; // Webhook URL
input string  InpWebhookToken = "";                                                   // Webhook API Token
input int     InpResyncDays = 7;                                                      // Auto Resync History (Days)

input group "=== Auto Close Friday ==="
input bool    InpEnableAutoCloseFriday = false; // Enable Auto Close Friday
input int     InpAutoCloseMinutesBefore = 15;   // Minutes before market close

input group "=== Auto SnD Trading Logic ==="
input bool    InpEnableAutoSnD  = false; // Enable FULL AUTO TRADING
input int     InpPivotLB        = 5;     // Pivot Lookback (bars)
input int     InpOriginLookback = 50;    // Traceback max candle base
input double  InpBufferPoints   = 20.0;    // Jarak Buffer SL (Points)
input int     InpHistoryBars    = 600;     // Jumlah Bar Histori Discan
input bool   InpShowBOS        = true;    // Tampilkan Garis BOS di Chart
input color  InpDemandColor    = C'0,160,0';   // Warna Zona Demand
input color  InpSupplyColor    = C'190,0,0';   // Warna Zona Supply
input color  InpMitColor       = clrGray;       // Warna Zona Termitigasi
input color  InpBOSBull        = clrDodgerBlue; // Warna Bullish BOS
input color  InpBOSBear        = clrOrangeRed;  // Warna Bearish BOS

#define COL_EQH    clrTomato
#define COL_EQL    clrLimeGreen

//=====================================================================
// ZONE STRUCT & GLOBALS (copied from SnD_Zone.mq5)
//=====================================================================
struct ZoneData
  {
   string   rect_name;
   string   lbl_name;
   string   lbl_top;
   string   lbl_btm;
   bool     is_demand;
   double   top;
   double   btm;
   datetime start_time;
   bool     active;
   bool     has_idm;
   bool     is_ultra;
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

// Tracks BOS origin level for Fibo drawing (set when BOS fires)
double   g_fibo_origin_bullish = 0; // Swing Low origin of Bullish BOS move
double   g_fibo_origin_bearish = 0; // Swing High origin of Bearish BOS move
datetime g_fibo_origin_bull_time = 0;
datetime g_fibo_origin_bear_time = 0;
bool     g_fibo_bull_pending = false; // Waiting for pivot confirmation after Bull BOS
bool     g_fibo_bear_pending = false; // Waiting for pivot confirmation after Bear BOS
int      g_pending_bull_zone_idx = -1; // Exact zone index created by latest Bull BOS
int      g_pending_bear_zone_idx = -1; // Exact zone index created by latest Bear BOS

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
   double cls   = iClose(_Symbol, _Period, 1);
   int    total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
     {
      ulong  ticket  = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, "RP_CL_") != 0 && StringFind(comment, "SND_CL_") != 0) continue;
      int idx = StringFind(comment, "CL_");
      double cut  = StringToDouble(StringSubstr(comment, idx + 3));
      if(cut == 0) continue;
      bool is_buy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      bool do_cut = is_buy ? (cls < cut) : (cls > cut);
      if(do_cut) ExtTrade.PositionClose(ticket, 10);
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
// [4] RISK PANEL CLASS
//=====================================================================
class CRiskPanel : public CAppDialog
  {
public:
   CLabel    m_lbl_balance, m_lbl_risk, m_lbl_entry, m_lbl_sl;
   CLabel    m_lbl_ratio,   m_lbl_lot,  m_lbl_status;
   CLabel    m_lbl_pair, m_lbl_spread, m_lbl_atr, m_lbl_footer;
   CEdit     m_edt_risk, m_edt_entry, m_edt_sl;
   CComboBox m_cbx_ratio;
   CButton   m_btn_place, m_btn_cancel, m_btn_cutloss, m_btn_risk_mode;
   bool      m_cl_active;
   bool      m_risk_in_percent;

   bool      MkLabel(CLabel &l, string n, string t, int x1, int y1, int x2, int y2) { if(!l.Create(m_chart_id, m_name + n, m_subwin, x1, y1, x2, y2)) return false; l.Text(t); return Add(l); }
   bool      MkEdit(CEdit &e, string n, string t, int x1, int y1, int x2, int y2)  { if(!e.Create(m_chart_id, m_name + n, m_subwin, x1, y1, x2, y2)) return false; e.Text(t); return Add(e); }
   bool      MkButton(CButton &b, string n, string t, int x1, int y1, int x2, int y2){ if(!b.Create(m_chart_id, m_name + n, m_subwin, x1, y1, x2, y2)) return false; b.Text(t); return Add(b); }
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
      m_btn_risk_mode.Text(m_risk_in_percent ? "MODE: %" : "MODE: $");
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
      long val = m_cbx_ratio.Value(); if(val == 0) val = 10;
      double mult = val / 10.0;
      double tp = 0; bool result = false;
      if(m_cl_active) {
         double backup = is_buy ? NormalizeDouble(entry - diff * 2.0, digits) : NormalizeDouble(entry + diff * 2.0, digits);
         string clc = "RP_CL_" + DoubleToString(sl, digits);
         if(is_buy) { tp = NormalizeDouble(entry + diff * mult, digits); result = (entry < ask) ? ExtTrade.BuyLimit(lot, entry, _Symbol, backup, tp, ORDER_TIME_GTC, 0, clc)  : ExtTrade.BuyStop(lot, entry, _Symbol, backup, tp, ORDER_TIME_GTC, 0, clc); }
         else       { tp = NormalizeDouble(entry - diff * mult, digits); result = (entry > bid) ? ExtTrade.SellLimit(lot, entry, _Symbol, backup, tp, ORDER_TIME_GTC, 0, clc) : ExtTrade.SellStop(lot, entry, _Symbol, backup, tp, ORDER_TIME_GTC, 0, clc); }
      } else {
         if(is_buy) { tp = NormalizeDouble(entry + diff * mult, digits); result = (entry < ask) ? ExtTrade.BuyLimit(lot, entry, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "RP")  : ExtTrade.BuyStop(lot, entry, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "RP"); }
         else       { tp = NormalizeDouble(entry - diff * mult, digits); result = (entry > bid) ? ExtTrade.SellLimit(lot, entry, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "RP") : ExtTrade.SellStop(lot, entry, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "RP"); }
      }
      SetStatus(result ? "Order Manual Dipasang" : "Gagal Pasang Order");
   }

   void      OnInput() { UpdateLot(); }
   void      UpdateStats() { m_lbl_pair.Text(_Symbol); UpdateBalance(); }

   CRiskPanel() { m_cl_active = false; m_risk_in_percent = true; }
   virtual bool  Create(const long chart, const string name, const int sw, const int x1, const int y1, const int x2, const int y2) {
      if(!CAppDialog::Create(chart, name, sw, x1, y1, x2, y2)) return false;
      int y = 10, rh = 30;
      if(!MkLabel(m_lbl_pair,   "LPair",   _Symbol,          5, y, 75,  y + 20)) return false;
      if(!MkLabel(m_lbl_spread, "LSpread", "SND AUTO: " + (InpEnableAutoSnD ? "ON" : "OFF"), 85, y, 270, y + 20)) return false;
      y += rh;
      if(!MkLabel(m_lbl_balance, "Bal", "Balance: --",        15, y, 260, y + 20)) return false; y += rh;
      if(!MkLabel(m_lbl_risk,    "LR",  "Risk (%):", 15, y, 90, y + 20)) return false;
      if(!MkEdit(m_edt_risk,     "ER",  "1.0",               95, y, 180, y + 20)) return false;
      if(!MkButton(m_btn_risk_mode, "BRM", "MODE: %",       190, y, 260, y + 20)) return false;
      y += rh;
      if(!MkLabel(m_lbl_entry,   "LE",  "Entry Price:",        15, y, 105, y + 20)) return false;
      if(!MkEdit(m_edt_entry,    "EE",  "",                  110, y, 260, y + 20)) return false; y += rh;
      if(!MkLabel(m_lbl_sl,      "LS",  "Stop Loss:",          15, y, 105, y + 20)) return false;
      if(!MkEdit(m_edt_sl,       "ES",  "",                  110, y, 260, y + 20)) return false; y += rh;
      if(!MkLabel(m_lbl_ratio,   "LRt", "Risk Ratio:",         15, y, 105, y + 20)) return false;
      if(!m_cbx_ratio.Create(m_chart_id, m_name + "CbR", m_subwin, 110, y, 260, y + 20)) return false;
      if(!Add(m_cbx_ratio)) return false;
      m_cbx_ratio.ItemAdd("1:1", 10); m_cbx_ratio.ItemAdd("1:1.5", 15); m_cbx_ratio.ItemAdd("1:2", 20); m_cbx_ratio.ItemAdd("1:3", 30); m_cbx_ratio.Select(2); y += rh;
      if(!MkLabel(m_lbl_lot, "LL", "Lot Size: --", 15, y, 260, y + 20)) return false; y += rh;
      if(!MkButton(m_btn_cutloss, "BCL", "CL: OFF",      10, y,  85, y + 25)) return false;
      if(!MkButton(m_btn_place,   "BP",  "PLACE ORDER",  90, y, 185, y + 25)) return false;
      m_btn_place.ColorBackground(C'30,144,255'); m_btn_place.Color(clrWhite);
      if(!MkButton(m_btn_cancel,  "BC",  "CANCEL",      190, y, 265, y + 25)) return false; y += 35;
      if(!MkLabel(m_lbl_status, "LSt", "Status: AutoSnD Ready", 15, y, 260, y + 30)) return false;
      return true;
   }
   virtual bool  OnEvent(const int id, const long &lp, const double &dp, const string &sp) {
      if(id == CHARTEVENT_CUSTOM + ON_CLICK) {
         if(lp == m_btn_place.Id())   { OnPlace();     return true; }
         if(lp == m_btn_cancel.Id())  { OnCancelBtn(); return true; }
         if(lp == m_btn_cutloss.Id()) { OnCutLoss();   return true; }
         if(lp == m_btn_risk_mode.Id()){ OnRiskModeToggle(); return true; }
      }
      if(id == CHARTEVENT_CUSTOM + ON_END_EDIT) { if(lp == m_edt_risk.Id() || lp == m_edt_entry.Id() || lp == m_edt_sl.Id()) { OnInput(); return true; } }
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
      if(!HistoryDealSelect(ticket)) return;
      symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
      dealType = HistoryDealGetInteger(ticket, DEAL_TYPE);
      typeStr = (dealType == DEAL_TYPE_BUY) ? "buy_closed" : ((dealType == DEAL_TYPE_SELL) ? "sell_closed" : "other_closed");
      closePrice = HistoryDealGetDouble(ticket, DEAL_PRICE);
      lotSize = HistoryDealGetDouble(ticket, DEAL_VOLUME);
      profitLoss = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      swap = HistoryDealGetDouble(ticket, DEAL_SWAP); commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      magicNumber = HistoryDealGetInteger(ticket, DEAL_MAGIC); comment = HistoryDealGetString(ticket, DEAL_COMMENT);
      closeTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      long posID = HistoryDealGetInteger(ticket, DEAL_POSITION_ID); ticket = posID;
      if(HistorySelectByPosition(posID)) {
         for(int i=0; i<HistoryDealsTotal(); i++) {
            ulong dt = HistoryDealGetTicket(i);
            if(HistoryDealGetInteger(dt, DEAL_ENTRY) == DEAL_ENTRY_IN) { entryPrice = HistoryDealGetDouble(dt, DEAL_PRICE); openTime = (datetime)HistoryDealGetInteger(dt, DEAL_TIME); break; }
         }
      }
     }
   else if(eventType == "deal_open") // OPEN ORDER/POSITION
     {
      if(!HistoryDealSelect(ticket)) return;
      symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
      dealType = HistoryDealGetInteger(ticket, DEAL_TYPE);
      typeStr = (dealType == DEAL_TYPE_BUY) ? "buy" : ((dealType == DEAL_TYPE_SELL) ? "sell" : "other_open");
      long posID = HistoryDealGetInteger(ticket, DEAL_POSITION_ID); ticket = posID;
      entryPrice = HistoryDealGetDouble(ticket, DEAL_PRICE); lotSize = HistoryDealGetDouble(ticket, DEAL_VOLUME);
      openTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME); magicNumber = HistoryDealGetInteger(ticket, DEAL_MAGIC);
      comment = HistoryDealGetString(ticket, DEAL_COMMENT);
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
      magicNumber = isCancel ? HistoryOrderGetInteger(ticket, ORDER_MAGIC) : OrderGetInteger(ORDER_MAGIC);
      comment = isCancel ? HistoryOrderGetString(ticket, ORDER_COMMENT) : OrderGetString(ORDER_COMMENT);
     }

   string oTS = (openTime > 0) ? TimeToString(openTime, TIME_DATE | TIME_SECONDS) : "";
   string cTS = (closeTime > 0) ? TimeToString(closeTime, TIME_DATE | TIME_SECONDS) : "";
   StringReplace(oTS, ".", "-"); StringReplace(cTS, ".", "-");
   string accCurr = AccountInfoString(ACCOUNT_CURRENCY); StringToLower(accCurr);
   double div = (StringFind(accCurr, "c") >= 0) ? 100.0 : 1.0;
   
   string json = "{";
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
   WebRequest("POST", InpWebhookURL, headers, 3000, post, resW, headers);
  }

void ResyncHistory()
  {
   if(InpResyncDays <= 0 || InpWebhookURL == "") return;
   datetime to = TimeCurrent() + 86400; datetime from = TimeCurrent() - (InpResyncDays * 86400);
   if(HistorySelect(from, to)) {
      for(int i = 0; i < HistoryDealsTotal(); i++) {
         ulong t = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(t, DEAL_ENTRY) == DEAL_ENTRY_OUT) SendTradeDataToWebhook(t, "deal_close");
      }
   }
   for(int i = 0; i < PositionsTotal(); i++) {
      long posID = PositionGetInteger(POSITION_IDENTIFIER);
      if(HistorySelectByPosition(posID)) {
         for(int d = 0; d < HistoryDealsTotal(); d++) {
            ulong t = HistoryDealGetTicket(d);
            if(HistoryDealGetInteger(t, DEAL_ENTRY) == DEAL_ENTRY_IN) { SendTradeDataToWebhook(t, "deal_open"); break; }
         }
      }
   }
   for(int i = 0; i < OrdersTotal(); i++) SendTradeDataToWebhook(OrderGetTicket(i), "pending_order");
  }

//=====================================================================
// [6] AUTO SND TRADING ENGINE - SnD_Zone Logic + Fibo Filter
//=====================================================================

// ---- Zone Drawing (from SnD_Zone.mq5) ----
void DrawZone(bool is_demand, double top, double btm, datetime start_time)
  {
   if(g_zone_count >= MAX_ZONES) return;
   color col_use = is_demand ? InpDemandColor : InpSupplyColor;
   string uid=NextID(), rname="SnD_Z_"+uid, lname="SnD_ZL_"+uid;
   if(ObjectCreate(0,rname,OBJ_RECTANGLE,0,start_time,top,D'2099.12.31',btm))
     { ObjectSetInteger(0,rname,OBJPROP_COLOR,col_use); ObjectSetInteger(0,rname,OBJPROP_FILL,true); ObjectSetInteger(0,rname,OBJPROP_BACK,true); ObjectSetInteger(0,rname,OBJPROP_SELECTABLE,false); ObjectSetString(0,rname,OBJPROP_TOOLTIP,(is_demand?"Demand":"Supply")+" | Top:"+DoubleToString(top,_Digits)+" Btm:"+DoubleToString(btm,_Digits)); }
   if(ObjectCreate(0,lname,OBJ_TEXT,0,start_time,top))
     { ObjectSetString(0,lname,OBJPROP_TEXT,is_demand?" Origin Demand":" Origin Supply"); ObjectSetInteger(0,lname,OBJPROP_COLOR,col_use); ObjectSetInteger(0,lname,OBJPROP_FONTSIZE,7); ObjectSetInteger(0,lname,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,lname,OBJPROP_BACK,true); }
   string ptop="SnD_PT_"+uid, pbtm="SnD_PB_"+uid;
   if(ObjectCreate(0,ptop,OBJ_TEXT,0,start_time,top)) { ObjectSetString(0,ptop,OBJPROP_TEXT," "+DoubleToString(top,_Digits)); ObjectSetInteger(0,ptop,OBJPROP_COLOR,col_use); ObjectSetInteger(0,ptop,OBJPROP_FONTSIZE,8); ObjectSetInteger(0,ptop,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER); ObjectSetInteger(0,ptop,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,ptop,OBJPROP_BACK,true); }
   if(ObjectCreate(0,pbtm,OBJ_TEXT,0,start_time,btm)) { ObjectSetString(0,pbtm,OBJPROP_TEXT," "+DoubleToString(btm,_Digits)); ObjectSetInteger(0,pbtm,OBJPROP_COLOR,col_use); ObjectSetInteger(0,pbtm,OBJPROP_FONTSIZE,8); ObjectSetInteger(0,pbtm,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER); ObjectSetInteger(0,pbtm,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,pbtm,OBJPROP_BACK,true); }
   g_zones[g_zone_count].rect_name=rname; g_zones[g_zone_count].lbl_name=lname; g_zones[g_zone_count].lbl_top=ptop; g_zones[g_zone_count].lbl_btm=pbtm;
   g_zones[g_zone_count].is_demand=is_demand; g_zones[g_zone_count].top=top; g_zones[g_zone_count].btm=btm; g_zones[g_zone_count].start_time=start_time;
   g_zones[g_zone_count].active=true; g_zones[g_zone_count].has_idm=false; g_zones[g_zone_count].is_ultra=false;
   g_zone_count++;
  }

void DrawBOS(bool is_bull, double price, datetime x1, datetime x2)
  {
   if(!InpShowBOS) return;
   color col=is_bull?InpBOSBull:InpBOSBear;
   string uid=NextID(),ln="SnD_B_"+uid,lb="SnD_BL_"+uid;
   if(ObjectCreate(0,ln,OBJ_TREND,0,x1,price,x2,price)) { ObjectSetInteger(0,ln,OBJPROP_COLOR,col); ObjectSetInteger(0,ln,OBJPROP_STYLE,STYLE_DASH); ObjectSetInteger(0,ln,OBJPROP_RAY_RIGHT,false); ObjectSetInteger(0,ln,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,ln,OBJPROP_BACK,true); }
   datetime mid=(datetime)(((long)x1+(long)x2)/2);
   if(ObjectCreate(0,lb,OBJ_TEXT,0,mid,price)) { ObjectSetString(0,lb,OBJPROP_TEXT,"BOS"); ObjectSetInteger(0,lb,OBJPROP_COLOR,col); ObjectSetInteger(0,lb,OBJPROP_FONTSIZE,8); ObjectSetInteger(0,lb,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,lb,OBJPROP_BACK,true); }
  }

void MitigateZone(int idx, datetime t)
  {
   g_zones[idx].active=false;
   ObjectDelete(0,g_zones[idx].rect_name); ObjectDelete(0,g_zones[idx].lbl_name); ObjectDelete(0,g_zones[idx].lbl_top); ObjectDelete(0,g_zones[idx].lbl_btm);
  }

void UpdateZoneLabelsTime(datetime t)
  {
   for(int i=0;i<g_zone_count;i++) if(g_zones[i].active) { ObjectMove(0,g_zones[i].lbl_top,0,t,g_zones[i].top); ObjectMove(0,g_zones[i].lbl_btm,0,t,g_zones[i].btm); }
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

int FindDemandBase(int shift) { for(int i=shift+1;i<=shift+InpOriginLookback;i++) if(iClose(_Symbol,_Period,i)<iOpen(_Symbol,_Period,i)) return i; return -1; }
int FindSupplyBase(int shift) { for(int i=shift+1;i<=shift+InpOriginLookback;i++) if(iClose(_Symbol,_Period,i)>iOpen(_Symbol,_Period,i)) return i; return -1; }

void CheckMitigation(int shift)
  {
   double l=iLow(_Symbol,_Period,shift), h=iHigh(_Symbol,_Period,shift);
   datetime bt=iTime(_Symbol,_Period,shift);
   for(int i=g_zone_count-1;i>=0;i--)
     {
      if(!g_zones[i].active||bt<=g_zones[i].start_time) continue;
      bool mit=g_zones[i].is_demand?(l<=g_zones[i].top):(h>=g_zones[i].btm);
      if(mit) MitigateZone(i,bt);
     }
  }

// ---- Execution ----
void ExecuteAutoTrade(bool isDemand, double zoneTop, double zoneBtm, datetime zoneTime)
  {
   if(!InpEnableAutoSnD) return;
   if(IsZoneTraded(zoneTime)) return;
   double risk = StringToDouble(ExtPanel.m_edt_risk.Text());
   if(risk <= 0) return;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double entryPrice = isDemand ? zoneTop : zoneBtm;
   double stopLoss = isDemand ? (zoneBtm - InpBufferPoints*pt) : (zoneTop + InpBufferPoints*pt);
   entryPrice = NormalizeDouble(entryPrice, digits);
   stopLoss = NormalizeDouble(stopLoss, digits);
   double lot = CalcLotSize(ExtPanel.AdjRisk(), entryPrice, stopLoss, _Symbol);
   if(lot <= 0) return;
   long val = ExtPanel.m_cbx_ratio.Value(); if(val == 0) val = 10;
   double mult = val / 10.0;
   double diff = MathAbs(entryPrice - stopLoss);
   double tpPrice = isDemand ? (entryPrice + diff*mult) : (entryPrice - diff*mult);
   tpPrice = NormalizeDouble(tpPrice, digits);
   string comm = "SND_AUTO";
   if(ExtPanel.m_cl_active) comm = "SND_CL_" + DoubleToString(stopLoss, digits);
   bool result = isDemand ? ExtTrade.BuyLimit(lot, entryPrice, _Symbol, stopLoss, tpPrice, ORDER_TIME_GTC, 0, comm)
                          : ExtTrade.SellLimit(lot, entryPrice, _Symbol, stopLoss, tpPrice, ORDER_TIME_GTC, 0, comm);
   if(result)
     {
      MarkZoneTraded(zoneTime);
      Print("AutoSnD Executed: ", (isDemand?"BuyLimit":"SellLimit"), " Entry:", entryPrice, " SL:", stopLoss, " TP:", tpPrice);
     }
  }

// ---- Draw only Fibo 38.2 and 61.8 levels (only when a valid zone is found) ----
void DrawFiboLines(double f382, double f618, datetime from_time)
  {
   string uid = NextID();
   string name382 = "SnD_F382_" + uid;
   string name618 = "SnD_F618_" + uid;
   color fibo_col = clrMagenta;
   
   // Line spans ~20 candles from from_time
   int bar_from = iBarShift(_Symbol, _Period, from_time);
   int bar_end  = MathMax(bar_from - 20, 0);
   datetime end_time = iTime(_Symbol, _Period, bar_end);
   
   if(ObjectCreate(0, name382, OBJ_TREND, 0, from_time, f382, end_time, f382))
     {
      ObjectSetInteger(0, name382, OBJPROP_COLOR, fibo_col);
      ObjectSetInteger(0, name382, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, name382, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name382, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, name382, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name382, OBJPROP_BACK, true);
      ObjectSetString(0, name382, OBJPROP_TOOLTIP, "Fibo 38.2%: " + DoubleToString(f382, _Digits));
      string lbl382 = "SnD_FL382_" + uid;
      if(ObjectCreate(0, lbl382, OBJ_TEXT, 0, end_time, f382))
        { ObjectSetString(0,lbl382,OBJPROP_TEXT," 38.2"); ObjectSetInteger(0,lbl382,OBJPROP_COLOR,fibo_col); ObjectSetInteger(0,lbl382,OBJPROP_FONTSIZE,8); ObjectSetInteger(0,lbl382,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,lbl382,OBJPROP_BACK,true); ObjectSetInteger(0,lbl382,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER); }
     }
   
   if(ObjectCreate(0, name618, OBJ_TREND, 0, from_time, f618, end_time, f618))
     {
      ObjectSetInteger(0, name618, OBJPROP_COLOR, fibo_col);
      ObjectSetInteger(0, name618, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, name618, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name618, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, name618, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name618, OBJPROP_BACK, true);
      ObjectSetString(0, name618, OBJPROP_TOOLTIP, "Fibo 61.8%: " + DoubleToString(f618, _Digits));
      string lbl618 = "SnD_FL618_" + uid;
      if(ObjectCreate(0, lbl618, OBJ_TEXT, 0, end_time, f618))
        { ObjectSetString(0,lbl618,OBJPROP_TEXT," 61.8"); ObjectSetInteger(0,lbl618,OBJPROP_COLOR,fibo_col); ObjectSetInteger(0,lbl618,OBJPROP_FONTSIZE,8); ObjectSetInteger(0,lbl618,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,lbl618,OBJPROP_BACK,true); ObjectSetInteger(0,lbl618,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER); }
     }
  }

// ---- Fibo Filter: Check a specific zone vs Fibo Golden Zone ----
void CheckFiboAndTrade(double fibo_low, double fibo_high, datetime from_time, int zone_idx)
  {
   if(zone_idx < 0 || zone_idx >= g_zone_count) return;
   if(!g_zones[zone_idx].active) return;
   if(IsZoneTraded(g_zones[zone_idx].start_time)) return;

   // Golden Zone boundaries
   double dist    = fibo_high - fibo_low;
   double f_upper = fibo_high - dist * 0.382; // 38.2 level
   double f_lower = fibo_high - dist * 0.618; // 61.8 level

   // Check if the zone overlaps the Golden Zone
   bool overlaps = (g_zones[zone_idx].top >= f_lower) && (g_zones[zone_idx].btm <= f_upper);
   if(!overlaps) return;

   // Zone IS in the Golden Zone — draw Fibo lines and execute
   DrawFiboLines(f_upper, f_lower, from_time);
   ExecuteAutoTrade(g_zones[zone_idx].is_demand, g_zones[zone_idx].top, g_zones[zone_idx].btm, g_zones[zone_idx].start_time);
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

   bool bull_fvg=iLow(_Symbol,_Period,shift)>iHigh(_Symbol,_Period,shift+2);
   bool bear_fvg=iHigh(_Symbol,_Period,shift)<iLow(_Symbol,_Period,shift+2);
   double cls=iClose(_Symbol,_Period,shift);

   bool bull_bos=bull_fvg&&g_last_ph>0&&cls>g_last_ph&&g_last_ph_time!=g_marked_ph_time;
   bool bear_bos=bear_fvg&&g_last_pl>0&&cls<g_last_pl&&g_last_pl_time!=g_marked_pl_time;

   if(bull_bos)
     {
      g_marked_ph_time=g_last_ph_time;
      DrawBOS(true,g_last_ph,g_last_ph_time,iTime(_Symbol,_Period,shift));
      int base=FindDemandBase(shift);
      if(base!=-1)
        {
         DrawZone(true,iHigh(_Symbol,_Period,base),iLow(_Symbol,_Period,base),iTime(_Symbol,_Period,base));
         g_pending_bull_zone_idx = g_zone_count - 1; // Track exact zone index
         // Record fibo origin: Swing Low before BOS → will wait for new Pivot High
         g_fibo_origin_bullish  = g_last_pl;
         g_fibo_origin_bull_time = g_last_pl_time;
         g_fibo_bull_pending = true;
        }
     }

   if(bear_bos)
     {
      g_marked_pl_time=g_last_pl_time;
      DrawBOS(false,g_last_pl,g_last_pl_time,iTime(_Symbol,_Period,shift));
      int base=FindSupplyBase(shift);
      if(base!=-1)
        {
         DrawZone(false,iHigh(_Symbol,_Period,base),iLow(_Symbol,_Period,base),iTime(_Symbol,_Period,base));
         g_pending_bear_zone_idx = g_zone_count - 1; // Track exact zone index
         // Record fibo origin: Swing High before BOS → will wait for new Pivot Low
         g_fibo_origin_bearish  = g_last_ph;
         g_fibo_origin_bear_time = g_last_ph_time;
         g_fibo_bear_pending = true;
        }
     }

   // --- Fibo: Fire on first new pivot after BOS ---
   if(g_fibo_bull_pending && ph > 0 && g_last_ph_time > g_fibo_origin_bull_time)
     {
      // Fibo from Swing Low (origin) to new Pivot High — only check the zone from THIS BOS
      CheckFiboAndTrade(g_fibo_origin_bullish, g_last_ph, g_fibo_origin_bull_time, g_pending_bull_zone_idx);
      g_fibo_bull_pending = false;
      g_pending_bull_zone_idx = -1;
     }

   if(g_fibo_bear_pending && pl > 0 && g_last_pl_time > g_fibo_origin_bear_time)
     {
      // Fibo from new Pivot Low to Swing High (origin) — only check the zone from THIS BOS
      CheckFiboAndTrade(g_last_pl, g_fibo_origin_bearish, g_fibo_origin_bear_time, g_pending_bear_zone_idx);
      g_fibo_bear_pending = false;
      g_pending_bear_zone_idx = -1;
     }

   CheckMitigation(shift);
  }

void ScanHistory()
  {
   int total=iBars(_Symbol,_Period);
   int start=MathMin(InpHistoryBars+InpPivotLB*2+InpOriginLookback,total-2);
   for(int i=start;i>=1;i--) ProcessBar(i);
  }

void DeleteAllSnDObjects()
  {
   for(int i=ObjectsTotal(0)-1;i>=0;i--)
     { string n=ObjectName(0,i); if(StringFind(n,"SnD_")==0) ObjectDelete(0,n); }
  }


//=====================================================================
// [7] EVENT HANDLERS
//=====================================================================
bool g_resync_done = false;

int OnInit()
  {
   if(!ExtPanel.Create(0, "AutoSnD - Risk Panel", 0, 20, 30, 300, 420)) return INIT_FAILED;
   ExtPanel.Run();
   
   ScanHistory(); // Scan full history using SnD_Zone logic
   g_last_processed_bar = iTime(_Symbol, _Period, 0);
   
   Print("AutoSnD EA v3.00 Ready. Trading: ", (InpEnableAutoSnD?"ON":"OFF"));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   DeleteAllSnDObjects();
   ExtPanel.Destroy(reason);
  }

void OnTick()
  {
   if(!g_resync_done) { ResyncHistory(); g_resync_done = true; }
   ExtPanel.UpdateStats();
   CheckCutLoss();
   CheckAutoCloseFriday();
   
   // Engine Auto SnD memproses candle jika baru ditutup
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime != g_last_processed_bar)
     {
      ProcessBar(1); // Proses lilin 1 (baru tertutup)
      g_last_processed_bar = currentBarTime;
     }
  }

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &req, const MqlTradeResult &res)
  {
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD) {
      if(HistoryDealSelect(trans.deal)) {
         long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
         if(entry == DEAL_ENTRY_OUT) SendTradeDataToWebhook(trans.deal, "deal_close");
         else if(entry == DEAL_ENTRY_IN) SendTradeDataToWebhook(trans.deal, "deal_open");
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
