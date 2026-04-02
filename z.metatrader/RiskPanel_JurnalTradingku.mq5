//+------------------------------------------------------------------+
//|                          RiskPanel_JurnalTradingku.mq5           |
//|         Risk Panel + Webhook Journal Sync untuk MT5              |
//|                        Copyright 2026, Antigravity               |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity"
#property link      "https://jurnaltradingku.my.id"
#property version   "1.00"

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
input group "=== Webhook / Journal ==="
input string  InpWebhookURL   = "http://jurnaltradingku.my.id/api/webhook/trading-log"; // Webhook URL
input string  InpWebhookToken = "";    // Webhook API Token
input int     InpResyncDays   = 365;   // Auto Resync History (Days)

input group "=== Auto Close Friday ==="
input bool    InpEnableAutoCloseFriday  = false; // Enable Auto Close Friday
input int     InpAutoCloseMinutesBefore = 15;    // Minutes before market close (Friday)

//=====================================================================
// [2] GLOBALS
//=====================================================================
int  g_obj_id = 0;
bool g_resync_done = false;

string NextID() { return IntegerToString(++g_obj_id); }

//=====================================================================
// [3] LOT CALCULATION
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
// [4] CUT LOSS & FRIDAY MONITOR
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
      if(StringFind(comment, "RP_CL_") != 0) continue;
      int    idx  = StringFind(comment, "CL_");
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
   if(tm.day_of_week != 5) return; // Jumat saja

   static int  last_day = -1;
   static uint friday_close_sec = 86399;
   if(last_day != tm.day)
     {
      datetime from, to;
      uint last_close = 0;
      for(int i = 0; i < 5; i++)
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
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
           { ExtTrade.PositionClose(ticket); actionsTaken = true; }
        }
      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         ulong ticket = OrderGetTicket(i);
         if(OrderGetString(ORDER_SYMBOL) == _Symbol)
           { ExtTrade.OrderDelete(ticket); actionsTaken = true; }
        }
      if(actionsTaken) Print("Auto Close Friday triggered at: ", TimeCurrent());
     }
  }

//=====================================================================
// [5] RISK PANEL CLASS
//=====================================================================
class CRiskPanel : public CAppDialog
  {
public:
   CLabel    m_lbl_balance, m_lbl_risk, m_lbl_entry, m_lbl_sl;
   CLabel    m_lbl_ratio,   m_lbl_lot,  m_lbl_status;
   CLabel    m_lbl_pair,    m_lbl_info;
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

   double    AdjRisk() {
      double r = StringToDouble(m_edt_risk.Text());
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      if(m_risk_in_percent) return balance * (r / 100.0);
      return IsCent() ? (r * 100.0) : r;
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

   void      OnCancelBtn() { m_edt_entry.Text(""); m_edt_sl.Text(""); m_lbl_lot.Text("Lot Size: --"); SetStatus("Dibatalkan."); }
   void      OnCutLoss()   { m_cl_active = !m_cl_active; m_btn_cutloss.Text(m_cl_active ? "CL: ON" : "CL: OFF"); SetStatus(m_cl_active ? "Cut Loss ON" : "Cut Loss OFF"); }

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
      SetStatus(result ? "Order Dipasang!" : "Gagal Pasang Order");
   }

   void      OnInput()     { UpdateLot(); }
   void      UpdateStats() { m_lbl_pair.Text(_Symbol); UpdateBalance(); }

   CRiskPanel() { m_cl_active = false; m_risk_in_percent = true; }

   virtual bool  Create(const long chart, const string name, const int sw, const int x1, const int y1, const int x2, const int y2) {
      if(!CAppDialog::Create(chart, name, sw, x1, y1, x2, y2)) return false;
      int y = 10, rh = 30;
      if(!MkLabel(m_lbl_pair,    "LPair",  _Symbol,           5, y,  75, y + 20)) return false;
      if(!MkLabel(m_lbl_info,    "LInfo",  "Risk Panel v1.0", 85, y, 270, y + 20)) return false;
      y += rh;
      if(!MkLabel(m_lbl_balance, "Bal",    "Balance: --",    15, y, 260, y + 20)) return false; y += rh;
      if(!MkLabel(m_lbl_risk,    "LR",     "Risk (%):",      15, y,  90, y + 20)) return false;
      if(!MkEdit(m_edt_risk,     "ER",     "1.0",            95, y, 180, y + 20)) return false;
      if(!MkButton(m_btn_risk_mode, "BRM", "MODE: %",       190, y, 260, y + 20)) return false;
      y += rh;
      if(!MkLabel(m_lbl_entry,   "LE",     "Entry Price:",   15, y, 105, y + 20)) return false;
      if(!MkEdit(m_edt_entry,    "EE",     "",              110, y, 260, y + 20)) return false; y += rh;
      if(!MkLabel(m_lbl_sl,      "LS",     "Stop Loss:",     15, y, 105, y + 20)) return false;
      if(!MkEdit(m_edt_sl,       "ES",     "",              110, y, 260, y + 20)) return false; y += rh;
      if(!MkLabel(m_lbl_ratio,   "LRt",    "Risk Ratio:",   15, y, 105, y + 20)) return false;
      if(!m_cbx_ratio.Create(m_chart_id, m_name + "CbR", m_subwin, 110, y, 260, y + 20)) return false;
      if(!Add(m_cbx_ratio)) return false;
      m_cbx_ratio.ItemAdd("1:1", 10); m_cbx_ratio.ItemAdd("1:1.5", 15); m_cbx_ratio.ItemAdd("1:2", 20); m_cbx_ratio.ItemAdd("1:3", 30); m_cbx_ratio.Select(2); y += rh;
      if(!MkLabel(m_lbl_lot, "LL", "Lot Size: --", 15, y, 260, y + 20)) return false; y += rh;
      if(!MkButton(m_btn_cutloss, "BCL", "CL: OFF",     10, y,  85, y + 25)) return false;
      if(!MkButton(m_btn_place,   "BP",  "PLACE ORDER", 90, y, 185, y + 25)) return false;
      m_btn_place.ColorBackground(C'30,144,255'); m_btn_place.Color(clrWhite);
      if(!MkButton(m_btn_cancel,  "BC",  "CANCEL",     190, y, 265, y + 25)) return false; y += 35;
      if(!MkLabel(m_lbl_status,   "LSt", "Status: Ready", 15, y, 260, y + 30)) return false;
      return true;
   }

   virtual bool  OnEvent(const int id, const long &lp, const double &dp, const string &sp) {
      if(id == CHARTEVENT_CUSTOM + ON_CLICK) {
         if(lp == m_btn_place.Id())    { OnPlace();          return true; }
         if(lp == m_btn_cancel.Id())   { OnCancelBtn();      return true; }
         if(lp == m_btn_cutloss.Id())  { OnCutLoss();        return true; }
         if(lp == m_btn_risk_mode.Id()){ OnRiskModeToggle(); return true; }
      }
      if(id == CHARTEVENT_CUSTOM + ON_END_EDIT) {
         if(lp == m_edt_risk.Id() || lp == m_edt_entry.Id() || lp == m_edt_sl.Id()) { OnInput(); return true; }
      }
      return CAppDialog::OnEvent(id, lp, dp, sp);
   }
  };

CRiskPanel ExtPanel;

//=====================================================================
// [6] WEBHOOK / JOURNAL SYNC
//=====================================================================
void SendToWebhook(string json)
  {
   if(InpWebhookURL == "" || InpWebhookToken == "") return;
   char post[], resW[];
   string headers = "Content-Type: application/json\r\nX-Webhook-Token: " + InpWebhookToken + "\r\n";
   StringToCharArray(json, post, 0, WHOLE_ARRAY, CP_UTF8);
   int ps = ArraySize(post); if(ps > 0) ArrayResize(post, ps - 1);
   string resHeaders;
   int res = WebRequest("POST", InpWebhookURL, headers, 3000, post, resW, resHeaders);
   if(res == -1) {
      int err = GetLastError();
      if(err == 4014) Print("WEBHOOK BLOCKED! Tools -> Options -> Expert Advisors -> Allow WebRequest: ", InpWebhookURL);
      else Print("WEBHOOK ERROR! Code: ", err);
   } else if(res != 200 && res != 201) {
      Print("WEBHOOK SERVER ERROR! HTTP ", res, " | Reply: ", CharArrayToString(resW));
   }
  }

string BuildJSON(string accountName, ulong ticket, string symbol, string typeStr,
                 double entry, double close, double sl, double tp,
                 double lot, double profit, double swap, double commission,
                 string openTS, string closeTS, long magic, string comment, double balance)
  {
   string accCurr = AccountInfoString(ACCOUNT_CURRENCY); StringToLower(accCurr);
   double div = (StringFind(accCurr, "c") >= 0) ? 100.0 : 1.0;
   string j = "{";
   j += "\"account_name\": \"" + accountName + "\",";
   j += "\"ticket_id\": \"" + IntegerToString(ticket) + "\", \"symbol\": \"" + symbol + "\", \"type\": \"" + typeStr + "\",";
   j += "\"entry_price\": " + DoubleToString(entry, 5) + ", \"close_price\": " + DoubleToString(close, 5) + ",";
   j += "\"sl_price\": " + DoubleToString(sl, 5) + ", \"tp_price\": " + DoubleToString(tp, 5) + ",";
   j += "\"lot_size\": " + DoubleToString(lot, 2) + ", \"profit_loss\": " + DoubleToString(profit/div, 2) + ",";
   j += "\"swap\": " + DoubleToString(swap/div, 2) + ", \"commission\": " + DoubleToString(commission/div, 2) + ",";
   if(openTS  != "") j += "\"open_time\": \""  + openTS  + "\",";
   if(closeTS != "") j += "\"close_time\": \"" + closeTS + "\",";
   j += "\"magic_number\": \"" + IntegerToString(magic) + "\",";
   StringReplace(comment, "\"", "\\\""); j += "\"comment\": \"" + comment + "\",";
   j += "\"balance\": " + DoubleToString(balance/div, 2) + "}";
   return j;
  }

string TS(datetime t) { if(t == 0) return ""; string s = TimeToString(t, TIME_DATE | TIME_SECONDS); StringReplace(s, ".", "-"); return s; }
string AccName()       { string n = IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN)) + " - " + AccountInfoString(ACCOUNT_SERVER); StringReplace(n, "\"", "\\\""); return n; }

void SendDealClose(ulong dealTicket)
  {
   if(!HistoryDealSelect(dealTicket)) return;
   string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
   long   dt     = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
   string typeStr = (dt == DEAL_TYPE_BUY) ? "buy_closed" : ((dt == DEAL_TYPE_SELL) ? "sell_closed" : "other_closed");
   double closePrice  = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
   double lot         = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
   double profit      = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
   double swap        = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
   double commission  = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
   long   magic       = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
   string comment     = HistoryDealGetString(dealTicket, DEAL_COMMENT);
   datetime closeTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
   long   posID       = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);

   double entryPrice = 0;
   datetime openTime = 0;
   double sl = 0, tp = 0;
   if(HistorySelectByPosition(posID)) {
      for(int i = 0; i < HistoryDealsTotal(); i++) {
         ulong d = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(d, DEAL_ENTRY) == DEAL_ENTRY_IN) {
            entryPrice = HistoryDealGetDouble(d, DEAL_PRICE);
            openTime   = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
            break;
         }
      }
      // Try to get SL/TP from history order
      for(int i = 0; i < HistoryOrdersTotal(); i++) {
         ulong ot = HistoryOrderGetTicket(i);
         if(HistoryOrderGetInteger(ot, ORDER_POSITION_ID) == posID) {
            sl = HistoryOrderGetDouble(ot, ORDER_SL);
            tp = HistoryOrderGetDouble(ot, ORDER_TP);
         }
      }
   }
   string json = BuildJSON(AccName(), posID, symbol, typeStr, entryPrice, closePrice, sl, tp,
                           lot, profit, swap, commission, TS(openTime), TS(closeTime), magic, comment,
                           AccountInfoDouble(ACCOUNT_BALANCE));
   SendToWebhook(json);
  }

void SendDealOpen(ulong dealTicket)
  {
   if(!HistoryDealSelect(dealTicket)) return;
   string   symbol  = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
   long     dt      = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
   string   typeStr = (dt == DEAL_TYPE_BUY) ? "buy" : ((dt == DEAL_TYPE_SELL) ? "sell" : "other_open");
   double   entry   = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
   double   lot     = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
   datetime ot      = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
   long     magic   = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
   string   comment = HistoryDealGetString(dealTicket, DEAL_COMMENT);
   long     posID   = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
   double sl = 0, tp = 0;
   if(PositionSelectByTicket(posID)) { sl = PositionGetDouble(POSITION_SL); tp = PositionGetDouble(POSITION_TP); }
   string json = BuildJSON(AccName(), posID, symbol, typeStr, entry, 0, sl, tp,
                           lot, 0, 0, 0, TS(ot), "", magic, comment, AccountInfoDouble(ACCOUNT_BALANCE));
   SendToWebhook(json);
  }

void SendPendingOrder(ulong ticket, bool isCancel)
  {
   if(isCancel) { if(!HistoryOrderSelect(ticket)) return; }
   else         { if(!OrderSelect(ticket)) return; }

   string symbol  = isCancel ? HistoryOrderGetString(ticket, ORDER_SYMBOL) : OrderGetString(ORDER_SYMBOL);
   long   ot_type = isCancel ? HistoryOrderGetInteger(ticket, ORDER_TYPE) : OrderGetInteger(ORDER_TYPE);
   string typeStr = "";
   if(isCancel) typeStr = "pending_cancel";
   else {
      if(ot_type == ORDER_TYPE_BUY_LIMIT)   typeStr = "buy_limit";
      else if(ot_type == ORDER_TYPE_SELL_LIMIT)  typeStr = "sell_limit";
      else if(ot_type == ORDER_TYPE_BUY_STOP)    typeStr = "buy_stop";
      else if(ot_type == ORDER_TYPE_SELL_STOP)   typeStr = "sell_stop";
      else typeStr = "unknown_pending";
   }
   double entry   = isCancel ? HistoryOrderGetDouble(ticket, ORDER_PRICE_OPEN) : OrderGetDouble(ORDER_PRICE_OPEN);
   double sl      = isCancel ? HistoryOrderGetDouble(ticket, ORDER_SL) : OrderGetDouble(ORDER_SL);
   double tp      = isCancel ? HistoryOrderGetDouble(ticket, ORDER_TP) : OrderGetDouble(ORDER_TP);
   double lot     = isCancel ? HistoryOrderGetDouble(ticket, ORDER_VOLUME_INITIAL) : OrderGetDouble(ORDER_VOLUME_INITIAL);
   datetime openT = isCancel ? (datetime)HistoryOrderGetInteger(ticket, ORDER_TIME_SETUP) : (datetime)OrderGetInteger(ORDER_TIME_SETUP);
   datetime closeT= isCancel ? (datetime)HistoryOrderGetInteger(ticket, ORDER_TIME_DONE)  : 0;
   long   magic   = isCancel ? HistoryOrderGetInteger(ticket, ORDER_MAGIC) : OrderGetInteger(ORDER_MAGIC);
   string comment = isCancel ? HistoryOrderGetString(ticket, ORDER_COMMENT) : OrderGetString(ORDER_COMMENT);
   string json = BuildJSON(AccName(), ticket, symbol, typeStr, entry, 0, sl, tp,
                           lot, 0, 0, 0, TS(openT), TS(closeT), magic, comment, AccountInfoDouble(ACCOUNT_BALANCE));
   SendToWebhook(json);
  }

void SendBalance(ulong dealTicket)
  {
   if(!HistoryDealSelect(dealTicket)) return;
   double   profit  = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
   string   typeStr = (profit >= 0) ? "deposit" : "withdrawal";
   datetime ot      = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
   string   comment = HistoryDealGetString(dealTicket, DEAL_COMMENT);
   string json = BuildJSON(AccName(), dealTicket, "", typeStr, 0, 0, 0, 0,
                           0, profit, 0, 0, TS(ot), TS(ot), 0, comment, AccountInfoDouble(ACCOUNT_BALANCE));
   SendToWebhook(json);
  }

//=====================================================================
// [7] RESYNC HISTORY (OnInit)
//=====================================================================
void ResyncHistory()
  {
   if(InpResyncDays <= 0 || InpWebhookURL == "") return;
   Print("ResyncHistory: starting sync for last ", InpResyncDays, " days...");

   datetime to   = TimeCurrent() + 86400;
   datetime from = TimeCurrent() - ((long)InpResyncDays * 86400);

   ulong outDeals[], balanceDeals[];
   if(HistorySelect(from, to))
     {
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
        {
         ulong t     = HistoryDealGetTicket(i);
         long  entry = HistoryDealGetInteger(t, DEAL_ENTRY);
         long  dtype = HistoryDealGetInteger(t, DEAL_TYPE);
         if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
           { int s = ArraySize(outDeals); ArrayResize(outDeals, s+1); outDeals[s] = t; }
         else if(dtype == DEAL_TYPE_BALANCE)
           { int s = ArraySize(balanceDeals); ArrayResize(balanceDeals, s+1); balanceDeals[s] = t; }
        }
     }

   for(int i = 0; i < ArraySize(outDeals); i++)     SendDealClose(outDeals[i]);
   for(int i = 0; i < ArraySize(balanceDeals); i++) SendBalance(balanceDeals[i]);
   Print("ResyncHistory: sent ", ArraySize(outDeals), " closed trades, ", ArraySize(balanceDeals), " balance entries.");

   int openCount = 0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong posTicket = PositionGetTicket(i);
      if(posTicket == 0) continue;
      long posID = PositionGetInteger(POSITION_IDENTIFIER);
      if(HistorySelectByPosition(posID))
        {
         for(int d = 0; d < HistoryDealsTotal(); d++)
           {
            ulong dt = HistoryDealGetTicket(d);
            if(HistoryDealGetInteger(dt, DEAL_ENTRY) == DEAL_ENTRY_IN)
              { SendDealOpen(dt); openCount++; break; }
           }
        }
     }

   int pendingCount = 0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong ot = OrderGetTicket(i);
      if(ot == 0) continue;
      SendPendingOrder(ot, false);
      pendingCount++;
     }
   Print("ResyncHistory: sent ", openCount, " open positions, ", pendingCount, " pending orders. DONE.");
  }

//=====================================================================
// [8] ONTRADE TRANSACTION (Real-time event handler MT5)
//=====================================================================
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &req, const MqlTradeResult &result)
  {
   ulong ticket = trans.order;

   switch(trans.type)
     {
      // --- Posisi terbuka baru (DEAL_ENTRY_IN) ---
      case TRANS_DEAL_ADD:
        {
         if(!HistoryDealSelect(trans.deal)) break;
         long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
         long dtype = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
         if(entry == DEAL_ENTRY_IN)
           {
            SendDealOpen(trans.deal);
           }
         else if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
           {
            SendDealClose(trans.deal);
           }
         else if(dtype == DEAL_TYPE_BALANCE)
           {
            SendBalance(trans.deal);
           }
         break;
        }

      // --- Pending Order baru dipasang ---
      case TRANS_ORDER_ADD:
        {
         if(trans.order_state == ORDER_STATE_PLACED)
           {
            Sleep(200);
            SendPendingOrder(trans.order, false);
           }
         break;
        }

      // --- Pending Order dibatalkan/expired ---
      case TRANS_ORDER_DELETE:
        {
         if(trans.order_state == ORDER_STATE_CANCELED || trans.order_state == ORDER_STATE_EXPIRED)
           {
            if(HistoryOrderSelect(trans.order))
               SendPendingOrder(trans.order, true);
           }
         break;
        }

      default: break;
     }
  }

//=====================================================================
// [9] EVENT HANDLERS
//=====================================================================
int OnInit()
  {
   ChartSetInteger(0, CHART_FOREGROUND, false);
   if(!ExtPanel.Create(0, "Risk Panel - Jurnal Tradingku", 0, 20, 30, 295, 400)) return INIT_FAILED;
   ExtPanel.Run();
   Print("RiskPanel MT5 v1.00 Ready. Webhook: ", (InpWebhookURL != "" ? "ON" : "OFF"));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   ExtPanel.Destroy(reason);
  }

void OnTick()
  {
   if(!g_resync_done) { ResyncHistory(); g_resync_done = true; }

   ExtPanel.UpdateStats();
   CheckCutLoss();
   CheckAutoCloseFriday();
  }

void OnChartEvent(const int id, const long &lp, const double &dp, const string &sp)
  { ExtPanel.ChartEvent(id, lp, dp, sp); }
//+------------------------------------------------------------------+
