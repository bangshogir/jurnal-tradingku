//+------------------------------------------------------------------+
//|                              RiskPanel_JurnalTradingku.mq4       |
//|          Risk Panel + Webhook Journal Sync untuk MT4             |
//|                           Copyright 2026, Antigravity            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity"
#property link      "https://jurnaltradingku.my.id"
#property version   "1.00"
#property strict

#include <Controls\Dialog.mqh>
#include <Controls\Label.mqh>
#include <Controls\Edit.mqh>
#include <Controls\Button.mqh>
#include <Controls\ComboBox.mqh>

// MT4 CTrade Equivalent Helper
class CTradeMT4 {
public:
   bool BuyLimit(double vol, double price, string sym, double sl, double tp, int type_time, datetime expr, string comment) {
      RefreshRates();
      int tk = OrderSend(sym, OP_BUYLIMIT, vol, price, 10, sl, tp, comment, 0, expr, clrBlue);
      return tk > 0;
   }
   bool SellLimit(double vol, double price, string sym, double sl, double tp, int type_time, datetime expr, string comment) {
      RefreshRates();
      int tk = OrderSend(sym, OP_SELLLIMIT, vol, price, 10, sl, tp, comment, 0, expr, clrRed);
      return tk > 0;
   }
   bool BuyStop(double vol, double price, string sym, double sl, double tp, int type_time, datetime expr, string comment) {
      RefreshRates();
      int tk = OrderSend(sym, OP_BUYSTOP, vol, price, 10, sl, tp, comment, 0, expr, clrBlue);
      return tk > 0;
   }
   bool SellStop(double vol, double price, string sym, double sl, double tp, int type_time, datetime expr, string comment) {
      RefreshRates();
      int tk = OrderSend(sym, OP_SELLSTOP, vol, price, 10, sl, tp, comment, 0, expr, clrRed);
      return tk > 0;
   }
   bool PositionClose(int ticket, int slippage=10) {
      if(OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) {
         RefreshRates();
         if(OrderType() == OP_BUY)  return OrderClose(ticket, OrderLots(), MarketInfo(OrderSymbol(), MODE_BID), slippage, clrWhite);
         if(OrderType() == OP_SELL) return OrderClose(ticket, OrderLots(), MarketInfo(OrderSymbol(), MODE_ASK), slippage, clrWhite);
      }
      return false;
   }
   bool OrderDelete(int ticket) {
      if(OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) {
         if(OrderType() > OP_SELL) return ::OrderDelete(ticket, clrWhite);
      }
      return false;
   }
};

CTradeMT4 ExtTrade;

//=====================================================================
// [1] INPUT PARAMETERS
//=====================================================================
input string  _sec1_ = "=== Webhook / Journal ===";
input string  InpWebhookURL   = "http://jurnaltradingku.my.id/api/webhook/trading-log"; // Webhook URL
input string  InpWebhookToken = "";    // Webhook API Token
input int     InpResyncDays   = 365;   // Auto Resync History (Days)

input string  _sec2_ = "=== Auto Close Friday ===";
input bool    InpEnableAutoCloseFriday  = false; // Enable Auto Close Friday
input int     InpAutoCloseMinutesBefore = 15;    // Minutes before market close (Friday)

//=====================================================================
// [2] GLOBALS
//=====================================================================
int      g_obj_id             = 0;
int      g_active_tickets[];
int      g_last_history_total = 0;
bool     g_resync_done        = false;

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
   double cls   = iClose(Symbol(), Period(), 1);
   int    total = OrdersTotal();
   for(int i = total - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderType() > OP_SELL) continue;
      string comment = OrderComment();
      if(StringFind(comment, "RP_CL_") != 0) continue;
      int idx = StringFind(comment, "CL_");
      double cut  = StringToDouble(StringSubstr(comment, idx + 3));
      if(cut == 0) continue;
      bool is_buy = (OrderType() == OP_BUY);
      bool do_cut = is_buy ? (cls < cut) : (cls > cut);
      if(do_cut) ExtTrade.PositionClose(OrderTicket(), 10);
     }
  }

void CheckAutoCloseFriday()
  {
   if(!InpEnableAutoCloseFriday) return;
   if(DayOfWeek() != 5) return; // Jumat
   int current_sec = TimeHour(TimeCurrent())*3600 + TimeMinute(TimeCurrent())*60 + TimeSeconds(TimeCurrent());
   int trigger_sec = 86399 - (InpAutoCloseMinutesBefore * 60);
   if(current_sec >= trigger_sec)
     {
      bool actionsTaken = false;
      int ordersTotal = OrdersTotal();
      for(int i = ordersTotal - 1; i >= 0; i--)
        {
         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
           {
            if(OrderSymbol() == Symbol())
              {
               if(OrderType() <= OP_SELL) ExtTrade.PositionClose(OrderTicket());
               else ExtTrade.OrderDelete(OrderTicket());
               actionsTaken = true;
              }
           }
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
      double raw_risk_amount = 0;
      if(m_risk_in_percent) raw_risk_amount = balance * (r / 100.0);
      else raw_risk_amount = IsCent() ? (r * 100.0) : r;
      return raw_risk_amount;
   }

   void      UpdateBalance() { double b = AccountInfoDouble(ACCOUNT_BALANCE); if(IsCent()) b /= 100.0; m_lbl_balance.Text("Balance: " + AccCurr() + " " + DoubleToString(b, 2)); }
   void      UpdateLot() {
      double r = StringToDouble(m_edt_risk.Text()); double e = StringToDouble(m_edt_entry.Text()); double s = StringToDouble(m_edt_sl.Text());
      if(r <= 0 || e <= 0 || s <= 0 || e == s) { m_lbl_lot.Text("Lot Size: --"); return; }
      double lot = CalcLotSize(AdjRisk(), e, s, Symbol());
      m_lbl_lot.Text(lot > 0 ? "Lot Size: " + DoubleToString(lot, 2) : "Lot Size: --");
   }

   bool      ValidStopLevel(double entry, double sl, bool is_buy) {
      long   pts  = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
      if(pts == 0) return true;
      double mind = pts * SymbolInfoDouble(Symbol(), SYMBOL_POINT);
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
      int digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
      entry = NormalizeDouble(entry, digits); sl = NormalizeDouble(sl, digits);
      bool is_buy = entry > sl;
      if(!ValidStopLevel(entry, sl, is_buy)) return;
      double lot = CalcLotSize(AdjRisk(), entry, sl, Symbol());
      if(lot <= 0) return;
      double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK); double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
      double diff = MathAbs(entry - sl);
      long val = m_cbx_ratio.Value(); if(val == 0) val = 10;
      double mult = val / 10.0;
      double tp = 0; bool result = false;
      if(m_cl_active) {
         double backup = is_buy ? NormalizeDouble(entry - diff * 2.0, digits) : NormalizeDouble(entry + diff * 2.0, digits);
         string clc = "RP_CL_" + DoubleToString(sl, digits);
         if(is_buy) { tp = NormalizeDouble(entry + diff * mult, digits); result = (entry < ask) ? ExtTrade.BuyLimit(lot, entry, Symbol(), backup, tp, 0, 0, clc)  : ExtTrade.BuyStop(lot, entry, Symbol(), backup, tp, 0, 0, clc); }
         else       { tp = NormalizeDouble(entry - diff * mult, digits); result = (entry > bid) ? ExtTrade.SellLimit(lot, entry, Symbol(), backup, tp, 0, 0, clc) : ExtTrade.SellStop(lot, entry, Symbol(), backup, tp, 0, 0, clc); }
      } else {
         if(is_buy) { tp = NormalizeDouble(entry + diff * mult, digits); result = (entry < ask) ? ExtTrade.BuyLimit(lot, entry, Symbol(), sl, tp, 0, 0, "RP")  : ExtTrade.BuyStop(lot, entry, Symbol(), sl, tp, 0, 0, "RP"); }
         else       { tp = NormalizeDouble(entry - diff * mult, digits); result = (entry > bid) ? ExtTrade.SellLimit(lot, entry, Symbol(), sl, tp, 0, 0, "RP") : ExtTrade.SellStop(lot, entry, Symbol(), sl, tp, 0, 0, "RP"); }
      }
      SetStatus(result ? "Order Dipasang!" : "Gagal Pasang Order");
   }

   void      OnInput()     { UpdateLot(); }
   void      UpdateStats() { m_lbl_pair.Text(Symbol()); UpdateBalance(); }

   CRiskPanel() { m_cl_active = false; m_risk_in_percent = true; }

   virtual bool  Create(const long chart, const string name, const int sw, const int x1, const int y1, const int x2, const int y2) {
      if(!CAppDialog::Create(chart, name, sw, x1, y1, x2, y2)) return false;
      int y = 10, rh = 30;
      if(!MkLabel(m_lbl_pair,    "LPair",  Symbol(),          5, y, 75,  y + 20)) return false;
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
void SendTradeDataToWebhook(int ticket, string eventType)
  {
   if(InpWebhookURL == "" || InpWebhookToken == "") return;

   string symbol = ""; string typeStr = ""; string comment = "";
   double entryPrice=0, closePrice=0, slPrice=0, tpPrice=0, lotSize=0, profitLoss=0, swap=0, commission=0;
   long magicNumber=0; datetime openTime=0, closeTime=0;

   int mode = (eventType == "deal_close" || eventType == "pending_cancel") ? MODE_HISTORY : MODE_TRADES;
   if(!OrderSelect(ticket, SELECT_BY_TICKET, mode)) return;

   symbol = OrderSymbol();
   int ot = OrderType();

   if(eventType == "deal_close" || eventType == "pending_cancel") {
      if(ot == OP_BUY)  typeStr = "buy_closed";
      else if(ot == OP_SELL) typeStr = "sell_closed";
      else typeStr = "pending_cancel";
   } else {
      if(ot == OP_BUY)      typeStr = "buy";
      else if(ot == OP_SELL)      typeStr = "sell";
      else if(ot == OP_BUYLIMIT)  typeStr = "buy_limit";
      else if(ot == OP_SELLLIMIT) typeStr = "sell_limit";
      else if(ot == OP_BUYSTOP)   typeStr = "buy_stop";
      else if(ot == OP_SELLSTOP)  typeStr = "sell_stop";
   }

   if(eventType == "balance") {
      typeStr     = (OrderProfit() >= 0) ? "deposit" : "withdrawal";
      entryPrice  = 0; closePrice = 0; slPrice = 0; tpPrice = 0;
      lotSize     = 0; profitLoss = OrderProfit();
      swap        = 0; commission = 0; magicNumber = 0;
      comment     = OrderComment();
      openTime    = OrderOpenTime(); closeTime = openTime;
      symbol      = "";
   } else {
      entryPrice  = OrderOpenPrice();  closePrice = OrderClosePrice();
      slPrice     = OrderStopLoss();   tpPrice    = OrderTakeProfit();
      lotSize     = OrderLots();       profitLoss = OrderProfit();
      swap        = OrderSwap();       commission = OrderCommission();
      magicNumber = OrderMagicNumber(); comment   = OrderComment();
      openTime    = OrderOpenTime();   closeTime  = OrderCloseTime();
   }

   string oTS = (openTime  > 0) ? TimeToString(openTime,  TIME_DATE | TIME_SECONDS) : "";
   string cTS = (closeTime > 0) ? TimeToString(closeTime, TIME_DATE | TIME_SECONDS) : "";
   StringReplace(oTS, ".", "-"); StringReplace(cTS, ".", "-");

   string accLogin   = IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN));
   string accServer  = AccountInfoString(ACCOUNT_SERVER);
   string accountName = accLogin + " - " + accServer;
   StringReplace(accountName, "\"", "\\\"");

   string accCurr = AccountInfoString(ACCOUNT_CURRENCY); StringToLower(accCurr);
   double div = (StringFind(accCurr, "c") >= 0) ? 100.0 : 1.0;

   string json = "{";
   json += "\"account_name\": \"" + accountName + "\",";
   json += "\"ticket_id\": \"" + IntegerToString(ticket) + "\", \"symbol\": \"" + symbol + "\", \"type\": \"" + typeStr + "\",";
   json += "\"entry_price\": " + DoubleToString(entryPrice, 5) + ", \"close_price\": " + DoubleToString(closePrice, 5) + ",";
   json += "\"sl_price\": " + DoubleToString(slPrice, 5) + ", \"tp_price\": " + DoubleToString(tpPrice, 5) + ",";
   json += "\"lot_size\": " + DoubleToString(lotSize, 2) + ", \"profit_loss\": " + DoubleToString(profitLoss/div, 2) + ",";
   json += "\"swap\": " + DoubleToString(swap/div, 2) + ", \"commission\": " + DoubleToString(commission/div, 2) + ",";
   if(oTS != "") json += "\"open_time\": \"" + oTS + "\",";
   if(cTS != "") json += "\"close_time\": \"" + cTS + "\",";
   json += "\"magic_number\": \"" + IntegerToString((int)magicNumber) + "\",";
   StringReplace(comment, "\"", "\\\""); json += "\"comment\": \"" + comment + "\",";
   json += "\"balance\": " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE)/div, 2) + "}";

   string headers = "Content-Type: application/json\r\nX-Webhook-Token: " + InpWebhookToken + "\r\n";
   char post[], resW[];
   StringToCharArray(json, post, 0, WHOLE_ARRAY, CP_UTF8);
   int ps = ArraySize(post); if(ps > 0) ArrayResize(post, ps - 1);
   string resHeaders;
   int res = WebRequest("POST", InpWebhookURL, headers, 3000, post, resW, resHeaders);
   if(res == -1) {
      int err = GetLastError();
      if(err == 4060) Print("WEBHOOK BLOCKED! Tools -> Options -> Expert Advisors -> Allow WebRequest: http://jurnaltradingku.my.id");
      else Print("WEBHOOK ERROR! Code: ", err);
   } else if(res != 200 && res != 201) {
      Print("WEBHOOK SERVER ERROR! HTTP ", res, " | Ticket: ", ticket, " Event: ", eventType);
      Print("Server Reply: ", CharArrayToString(resW));
   } else {
      Print("Webhook OK! Ticket ", ticket, " Event: ", eventType);
   }
  }

void InitialHistorySync()
  {
   if(InpResyncDays <= 0 || InpWebhookURL == "") return;
   datetime from = TimeCurrent() - (InpResyncDays * 86400);
   Print("ResyncHistory: starting sync for last ", InpResyncDays, " days...");

   int closedCount = 0, balanceCount = 0;
   int histTotal   = OrdersHistoryTotal();
   for(int i = 0; i < histTotal; i++)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      int      ot     = OrderType();
      datetime closeT = OrderCloseTime();
      if(closeT < from && closeT != 0) continue;
      if(ot == 6) { SendTradeDataToWebhook(OrderTicket(), "balance"); balanceCount++; }
      else if(ot <= OP_SELL) { SendTradeDataToWebhook(OrderTicket(), "deal_close"); closedCount++; }
      else SendTradeDataToWebhook(OrderTicket(), "pending_cancel");
     }
   Print("ResyncHistory: sent ", closedCount, " closed trades, ", balanceCount, " balance entries.");

   ArrayResize(g_active_tickets, 0);
   int current_tickets[];
   int openCount = 0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      int sz = ArraySize(current_tickets);
      ArrayResize(current_tickets, sz + 1);
      current_tickets[sz] = OrderTicket();
     }
   ArrayResize(g_active_tickets, ArraySize(current_tickets));
   for(int i = 0; i < ArraySize(current_tickets); i++)
     {
      g_active_tickets[i] = current_tickets[i];
      if(!OrderSelect(current_tickets[i], SELECT_BY_TICKET, MODE_TRADES)) continue;
      int ot = OrderType();
      if(ot <= OP_SELL) { SendTradeDataToWebhook(current_tickets[i], "deal_open"); openCount++; }
      else SendTradeDataToWebhook(current_tickets[i], "pending_order");
     }
   Print("ResyncHistory: sent ", openCount, " open positions. DONE.");
  }

void PollTradeEvents()
  {
   int current_tickets[];
   for(int i = 0; i < OrdersTotal(); i++) {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         int tk = OrderTicket();
         int s  = ArraySize(current_tickets); ArrayResize(current_tickets, s + 1); current_tickets[s] = tk;
         bool found = false;
         for(int j = 0; j < ArraySize(g_active_tickets); j++) if(g_active_tickets[j] == tk) { found = true; break; }
         if(!found) {
            if(OrderType() <= OP_SELL) SendTradeDataToWebhook(tk, "deal_open");
            else SendTradeDataToWebhook(tk, "pending_order");
         }
      }
   }

   for(int i = 0; i < ArraySize(g_active_tickets); i++) {
      int old_tk = g_active_tickets[i];
      bool found = false;
      for(int j = 0; j < ArraySize(current_tickets); j++) if(current_tickets[j] == old_tk) { found = true; break; }
      if(!found) {
         if(OrderSelect(old_tk, SELECT_BY_TICKET, MODE_HISTORY)) {
            if(OrderType() <= OP_SELL) SendTradeDataToWebhook(old_tk, "deal_close");
            else SendTradeDataToWebhook(old_tk, "pending_cancel");
         }
      }
   }

   int histTotal = OrdersHistoryTotal();
   if(histTotal > g_last_history_total) {
      for(int i = g_last_history_total; i < histTotal; i++) {
         if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) {
            if(OrderType() == 6) SendTradeDataToWebhook(OrderTicket(), "balance");
         }
      }
      g_last_history_total = histTotal;
   }

   ArrayResize(g_active_tickets, ArraySize(current_tickets));
   for(int i = 0; i < ArraySize(current_tickets); i++) g_active_tickets[i] = current_tickets[i];
  }

//=====================================================================
// [7] EVENT HANDLERS
//=====================================================================
int OnInit()
  {
   ChartSetInteger(0, CHART_FOREGROUND, false);
   if(!ExtPanel.Create(0, "Risk Panel - Jurnal Tradingku", 0, 20, 30, 295, 400)) return INIT_FAILED;
   ExtPanel.Run();
   Print("RiskPanel v1.00 Ready. Webhook: ", (InpWebhookURL != "" ? "ON" : "OFF"));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   ExtPanel.Destroy(reason);
  }

void OnTick()
  {
   if(!g_resync_done) { InitialHistorySync(); g_resync_done = true; }

   PollTradeEvents();
   ExtPanel.UpdateStats();
   CheckCutLoss();
   CheckAutoCloseFriday();
  }

void OnChartEvent(const int id, const long &lp, const double &dp, const string &sp)
  { ExtPanel.ChartEvent(id, lp, dp, sp); }
//+------------------------------------------------------------------+
