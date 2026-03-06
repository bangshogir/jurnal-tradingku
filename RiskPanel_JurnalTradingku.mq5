//+------------------------------------------------------------------+
//|                                    RiskPanel_JurnalTradingku.mq5 |
//|         Risk Manager Panel + Cut Loss + Trading Journal Webhook  |
//|                                    Copyright 2026, Luthfi Shogir |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Luthfi Shogir"
#property link      "https://jurnaltradingku.my.id"
#property version   "2.00"
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
input group "=== Risk Panel ==="
input string  InpWebhookURL = "http://jurnaltradingku.my.id/api/webhook/trading-log"; // Webhook URL
input string  InpWebhookToken = "";                                                   // Webhook API Token

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
// [3] CUT LOSS MONITOR
// Posisi CL diidentifikasi via comment: "RP_CL_<cut_level>"
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
      double cut  = StringToDouble(StringSubstr(comment, 6));
      if(cut == 0) continue;
      bool is_buy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      bool do_cut = is_buy ? (cls < cut) : (cls > cut);
      if(do_cut) ExtTrade.PositionClose(ticket, 10);
     }
  }

//=====================================================================
// [4] RISK PANEL CLASS
//=====================================================================
class CRiskPanel : public CAppDialog
  {
private:
   CLabel    m_lbl_balance, m_lbl_risk, m_lbl_entry, m_lbl_sl;
   CLabel    m_lbl_ratio,   m_lbl_lot,  m_lbl_status;
   CLabel    m_lbl_pair, m_lbl_spread, m_lbl_atr, m_lbl_footer;
   CEdit     m_edt_risk, m_edt_entry, m_edt_sl;
   CComboBox m_cbx_ratio;
   CButton   m_btn_place, m_btn_cancel, m_btn_cutloss;
   bool      m_cl_active;

   bool      MkLabel(CLabel &l, string n, string t, int x1, int y1, int x2, int y2);
   bool      MkEdit(CEdit &e, string n, string t, int x1, int y1, int x2, int y2);
   bool      MkButton(CButton &b, string n, string t, int x1, int y1, int x2, int y2);
   void      SetStatus(string t) { m_lbl_status.Text("Status: " + t); }
   bool      IsCent();
   double    AdjRisk();
   string    AccCurr();
   void      UpdateBalance();
   void      UpdateLot();
   bool      ValidStopLevel(double entry, double sl, bool is_buy);
   string    RetcodeMsg(uint code);
   void      OnPlace();
   void      OnCancelBtn();
   void      OnCutLoss();
   void      OnInput() { UpdateLot(); }

public:
                  CRiskPanel() { m_cl_active = false; }
                 ~CRiskPanel() {}
   void      UpdateStats();
   virtual bool  Create(const long chart, const string name, const int sw,
                        const int x1, const int y1, const int x2, const int y2);
   virtual bool  OnEvent(const int id, const long &lp, const double &dp, const string &sp);
  };

CRiskPanel ExtPanel;

//--- Implementations
bool CRiskPanel::MkLabel(CLabel &l, string n, string t, int x1, int y1, int x2, int y2)
  { if(!l.Create(m_chart_id, m_name + n, m_subwin, x1, y1, x2, y2)) return false; l.Text(t); return Add(l); }
bool CRiskPanel::MkEdit(CEdit &e, string n, string t, int x1, int y1, int x2, int y2)
  { if(!e.Create(m_chart_id, m_name + n, m_subwin, x1, y1, x2, y2)) return false; e.Text(t); return Add(e); }
bool CRiskPanel::MkButton(CButton &b, string n, string t, int x1, int y1, int x2, int y2)
  { if(!b.Create(m_chart_id, m_name + n, m_subwin, x1, y1, x2, y2)) return false; b.Text(t); return Add(b); }

bool CRiskPanel::IsCent()
  { string c = AccountInfoString(ACCOUNT_CURRENCY); return StringFind(c, "USC") >= 0 || StringFind(c, "ent") >= 0; }
string CRiskPanel::AccCurr()
  { return IsCent() ? "USD" : AccountInfoString(ACCOUNT_CURRENCY); }
double CRiskPanel::AdjRisk()
  { double r = StringToDouble(m_edt_risk.Text()); return IsCent() ? r * 100.0 : r; }

void CRiskPanel::UpdateBalance()
  {
   double b = AccountInfoDouble(ACCOUNT_BALANCE);
   if(IsCent()) b /= 100.0;
   m_lbl_balance.Text("Balance: " + AccCurr() + " " + DoubleToString(b, 2));
  }

void CRiskPanel::UpdateLot()
  {
   double r = StringToDouble(m_edt_risk.Text());
   double e = StringToDouble(m_edt_entry.Text());
   double s = StringToDouble(m_edt_sl.Text());
   if(r <= 0 || e <= 0 || s <= 0 || e == s) { m_lbl_lot.Text("Lot Size: --"); return; }
   double lot = CalcLotSize(AdjRisk(), e, s, _Symbol);
   m_lbl_lot.Text(lot > 0 ? "Lot Size: " + DoubleToString(lot, 2) : "Lot Size: --");
  }

void CRiskPanel::UpdateStats()
  {
   m_lbl_pair.Text(_Symbol);
   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = (ask - bid) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   m_lbl_spread.Text("Spread: " + IntegerToString((int)MathRound(spread)));
   double atr_sum = 0;
   for(int i = 1; i <= 14; i++)
      atr_sum += (iHigh(_Symbol, PERIOD_D1, i) - iLow(_Symbol, PERIOD_D1, i));
   double atr = atr_sum / 14.0;
   int atr_pts = (int)MathRound(atr / SymbolInfoDouble(_Symbol, SYMBOL_POINT));
   m_lbl_atr.Text("Daily ATR: " + IntegerToString(atr_pts));
   UpdateBalance();
  }

bool CRiskPanel::ValidStopLevel(double entry, double sl, bool is_buy)
  {
   long   pts  = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(pts == 0) return true;
   double mind = pts * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if( is_buy && sl >= entry - mind) { SetStatus("SL terlalu dekat! Min: " + IntegerToString((int)pts) + " pts"); return false; }
   if(!is_buy && sl <= entry + mind) { SetStatus("SL terlalu dekat! Min: " + IntegerToString((int)pts) + " pts"); return false; }
   return true;
  }

string CRiskPanel::RetcodeMsg(uint c)
  {
   switch(c)
     {
      case 10004: return "Requote! Coba lagi.";
      case 10006: return "Request ditolak broker.";
      case 10013: return "Request tidak valid.";
      case 10014: return "Volume lot tidak valid.";
      case 10015: return "Harga tidak valid.";
      case 10016: return "SL/TP tidak valid.";
      case 10017: return "Trading dinonaktifkan.";
      case 10018: return "Market sedang tutup.";
      case 10019: return "Margin tidak cukup!";
      case 10021: return "Harga tidak tersedia.";
      case 10024: return "Terlalu banyak request.";
      case 10026: return "AutoTrading dilarang server.";
      case 10031: return "Tidak ada koneksi.";
      case 10033: return "Batas pending order tercapai.";
      case 10034: return "Batas volume tercapai.";
      default:    return "Gagal (kode: " + IntegerToString((int)c) + ")";
     }
  }

void CRiskPanel::OnCancelBtn()
  { m_edt_entry.Text(""); m_edt_sl.Text(""); m_lbl_lot.Text("Lot Size: --"); SetStatus("Dibatalkan."); }

void CRiskPanel::OnCutLoss()
  {
   m_cl_active = !m_cl_active;
   m_btn_cutloss.Text(m_cl_active ? "CL: ON" : "CL: OFF");
   SetStatus(m_cl_active ? "Cut Loss ON - SL via candle close" : "Cut Loss OFF - SL normal");
  }

void CRiskPanel::OnPlace()
  {
   ENUM_SYMBOL_TRADE_MODE tm = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(tm == SYMBOL_TRADE_MODE_DISABLED)  { SetStatus("Error: Market tutup!"); return; }
   if(tm == SYMBOL_TRADE_MODE_CLOSEONLY) { SetStatus("Error: Close Only mode."); return; }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) { SetStatus("Error: AutoTrading OFF!"); return; }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))           { SetStatus("Error: EA tidak diizinkan!"); return; }
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))   { SetStatus("Error: Akun diblokir!"); return; }

   double risk  = StringToDouble(m_edt_risk.Text());
   double entry = StringToDouble(m_edt_entry.Text());
   double sl    = StringToDouble(m_edt_sl.Text());

   if(risk <= 0 || entry <= 0 || sl <= 0) { SetStatus("Error: Semua nilai harus > 0"); return; }
   if(entry == sl)                         { SetStatus("Error: Entry = SL!"); return; }

   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   entry = NormalizeDouble(entry, digits); sl = NormalizeDouble(sl, digits);
   bool is_buy   = entry > sl;

   if(!ValidStopLevel(entry, sl, is_buy)) return;

   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(ts == 0 || tv == 0) { SetStatus("Error: Data simbol belum siap."); return; }

   double lot = CalcLotSize(AdjRisk(), entry, sl, _Symbol);
   if(lot == -1) { SetStatus("Error: Data tick tidak valid."); return; }
   if(lot == -2) { SetStatus("Error: Risk terlalu kecil! Min lot: " + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), 2)); return; }
   if(lot <= 0)  { SetStatus("Error: Tidak bisa hitung lot."); return; }

   long   val  = m_cbx_ratio.Value(); if(val == 0) val = 10;
   double mult = val / 10.0;
   double diff = MathAbs(entry - sl);

   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = ask - bid;
   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(spread >= diff)
     {
      int sp = (point > 0) ? (int)MathRound(spread / point) : 0;
      int sd = (point > 0) ? (int)MathRound(diff   / point) : 0;
      SetStatus("BLOKIR! Spread (" + IntegerToString(sp) + " pts) >= SL (" + IntegerToString(sd) + " pts)");
      return;
     }

   if(is_buy) sl = NormalizeDouble(sl - spread, digits);
   else       sl = NormalizeDouble(sl + spread, digits);
   diff = MathAbs(entry - sl);
   lot  = CalcLotSize(AdjRisk(), entry, sl, _Symbol);
   if(lot <= 0) { SetStatus("Error: Tidak bisa hitung lot setelah kompensasi Spread."); return; }
   string swarn = "Info: Spread dikompensasi ke SL. ";

   double tp = 0; bool result = false;
   UpdateLot();

   if(m_cl_active)
     {
      double backup = is_buy ? NormalizeDouble(entry - diff * 2.0, digits) : NormalizeDouble(entry + diff * 2.0, digits);
      string clc    = "RP_CL_" + DoubleToString(sl, digits);
      if(is_buy)
        { tp = NormalizeDouble(entry + diff * mult, digits); result = (entry < ask) ? ExtTrade.BuyLimit(lot, entry, _Symbol, backup, tp, ORDER_TIME_GTC, 0, clc)  : ExtTrade.BuyStop(lot, entry, _Symbol, backup, tp, ORDER_TIME_GTC, 0, clc); }
      else
        { tp = NormalizeDouble(entry - diff * mult, digits); result = (entry > bid) ? ExtTrade.SellLimit(lot, entry, _Symbol, backup, tp, ORDER_TIME_GTC, 0, clc) : ExtTrade.SellStop(lot, entry, _Symbol, backup, tp, ORDER_TIME_GTC, 0, clc); }
      SetStatus(result ? swarn + "CL Sukses! Monitor via candle close." : RetcodeMsg(ExtTrade.ResultRetcode()));
     }
   else
     {
      if(is_buy)
        { tp = NormalizeDouble(entry + diff * mult, digits); result = (entry < ask) ? ExtTrade.BuyLimit(lot, entry, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "RP")  : ExtTrade.BuyStop(lot, entry, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "RP"); }
      else
        { tp = NormalizeDouble(entry - diff * mult, digits); result = (entry > bid) ? ExtTrade.SellLimit(lot, entry, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "RP") : ExtTrade.SellStop(lot, entry, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "RP"); }
      SetStatus(result ? swarn + "Sukses! Order dipasang." : RetcodeMsg(ExtTrade.ResultRetcode()));
     }
  }

bool CRiskPanel::Create(const long chart, const string name, const int sw,
                        const int x1, const int y1, const int x2, const int y2)
  {
   if(!CAppDialog::Create(chart, name, sw, x1, y1, x2, y2)) return false;
   int y = 10, rh = 30;

   if(!MkLabel(m_lbl_pair,   "LPair",   _Symbol,          5, y, 75,  y + 20)) return false;
   if(!MkLabel(m_lbl_spread, "LSpread", "Spread: --",    85, y, 165, y + 20)) return false;
   if(!MkLabel(m_lbl_atr,    "LAtR",    "Daily ATR: --", 175, y, 270, y + 20)) return false;
   y += rh;

   if(!MkLabel(m_lbl_balance, "Bal", "Balance: --",        15, y, 260, y + 20)) return false; UpdateBalance(); y += rh;
   if(!MkLabel(m_lbl_risk,    "LR",  "Risk (" + AccCurr() + "):", 15, y, 105, y + 20)) return false;
   if(!MkEdit(m_edt_risk,     "ER",  "1.0",               110, y, 260, y + 20)) return false; y += rh;
   if(!MkLabel(m_lbl_entry,   "LE",  "Entry Price:",        15, y, 105, y + 20)) return false;
   if(!MkEdit(m_edt_entry,    "EE",  "",                  110, y, 260, y + 20)) return false; y += rh;
   if(!MkLabel(m_lbl_sl,      "LS",  "Stop Loss:",          15, y, 105, y + 20)) return false;
   if(!MkEdit(m_edt_sl,       "ES",  "",                  110, y, 260, y + 20)) return false; y += rh;
   if(!MkLabel(m_lbl_ratio,   "LRt", "Risk Ratio:",         15, y, 105, y + 20)) return false;
   if(!m_cbx_ratio.Create(m_chart_id, m_name + "CbR", m_subwin, 110, y, 260, y + 20)) return false;
   if(!Add(m_cbx_ratio)) return false;
   m_cbx_ratio.ItemAdd("1:1", 10); m_cbx_ratio.ItemAdd("1:1.5", 15);
   m_cbx_ratio.ItemAdd("1:2", 20); m_cbx_ratio.ItemAdd("1:3",   30);
   m_cbx_ratio.Select(0); y += rh;

   if(!MkLabel(m_lbl_lot, "LL", "Lot Size: --", 15, y, 260, y + 20)) return false; y += rh;

   if(!MkButton(m_btn_cutloss, "BCL", "CL: OFF",      10, y,  85, y + 25)) return false;
   if(!MkButton(m_btn_place,   "BP",  "PLACE ORDER",  90, y, 185, y + 25)) return false;
   m_btn_place.ColorBackground(C'30,144,255'); m_btn_place.Color(clrWhite);
   if(!MkButton(m_btn_cancel,  "BC",  "CANCEL",      190, y, 265, y + 25)) return false; y += 35;

   if(!MkLabel(m_lbl_status, "LSt", "Status: Ready",                15, y, 260, y + 30)) return false; y += 35;
   if(!MkLabel(m_lbl_footer, "LCpr","Copyright : Luthfi Shogir",   65, y, 250, y + 20)) return false;

   UpdateStats();
   return true;
  }

bool CRiskPanel::OnEvent(const int id, const long &lp, const double &dp, const string &sp)
  {
   if(id == CHARTEVENT_CUSTOM + ON_CLICK)
     {
      if(lp == m_btn_place.Id())   { OnPlace();     return true; }
      if(lp == m_btn_cancel.Id())  { OnCancelBtn(); return true; }
      if(lp == m_btn_cutloss.Id()) { OnCutLoss();   return true; }
     }
   if(id == CHARTEVENT_CUSTOM + ON_END_EDIT)
     { if(lp == m_edt_risk.Id() || lp == m_edt_entry.Id() || lp == m_edt_sl.Id()) { OnInput(); return true; } }
   return CAppDialog::OnEvent(id, lp, dp, sp);
  }

//=====================================================================
// [5] JOURNAL WEBHOOK - SEND TRADE DATA
//=====================================================================
void SendTradeDataToWebhook(ulong ticket, string eventType)
  {
   string   symbol     = "";
   string   typeStr    = "";
   double   closePrice = 0.0;
   double   lotSize    = 0.0;
   double   profitLoss = 0.0;
   double   slPrice    = 0.0;
   double   tpPrice    = 0.0;
   double   swap       = 0.0;
   double   commission = 0.0;
   long     magicNumber= 0;
   string   comment    = "";
   double   entryPrice = 0.0;
   datetime openTime   = 0;
   datetime closeTime  = 0;
   long     dealType   = -1;

   if(eventType == "deal_close")
     {
      if(!HistoryDealSelect(ticket)) return;
      symbol    = HistoryDealGetString(ticket, DEAL_SYMBOL);
      dealType  = HistoryDealGetInteger(ticket, DEAL_TYPE);
      typeStr   = (dealType == DEAL_TYPE_BUY) ? "buy_closed" : ((dealType == DEAL_TYPE_SELL) ? "sell_closed" : "other_closed");
      closePrice  = HistoryDealGetDouble(ticket, DEAL_PRICE);
      lotSize     = HistoryDealGetDouble(ticket, DEAL_VOLUME);
      profitLoss  = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      swap        = HistoryDealGetDouble(ticket, DEAL_SWAP);
      commission  = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      magicNumber = HistoryDealGetInteger(ticket, DEAL_MAGIC);
      comment     = HistoryDealGetString(ticket, DEAL_COMMENT);
      closeTime   = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);

      long posID = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
      if(HistorySelectByPosition(posID))
        {
         int dealsTotal = HistoryDealsTotal();
         for(int i = 0; i < dealsTotal; i++)
           {
            ulong dticket = HistoryDealGetTicket(i);
            if(HistoryDealGetInteger(dticket, DEAL_ENTRY) == DEAL_ENTRY_IN)
              { entryPrice = HistoryDealGetDouble(dticket, DEAL_PRICE); openTime = (datetime)HistoryDealGetInteger(dticket, DEAL_TIME); break; }
           }
         int ordersTotal = HistoryOrdersTotal();
         for(int i = ordersTotal - 1; i >= 0; i--)
           {
            ulong oticket = HistoryOrderGetTicket(i);
            if(HistoryOrderGetInteger(oticket, ORDER_POSITION_ID) == posID)
              { slPrice = HistoryOrderGetDouble(oticket, ORDER_SL); tpPrice = HistoryOrderGetDouble(oticket, ORDER_TP); break; }
           }
        }
     }
   else if(eventType == "pending_order")
     {
      if(!HistoryOrderSelect(ticket)) return;
      symbol    = HistoryOrderGetString(ticket, ORDER_SYMBOL);
      dealType  = HistoryOrderGetInteger(ticket, ORDER_TYPE);
      if(dealType == ORDER_TYPE_BUY_LIMIT)       typeStr = "buy_limit";
      else if(dealType == ORDER_TYPE_SELL_LIMIT)  typeStr = "sell_limit";
      else if(dealType == ORDER_TYPE_BUY_STOP)    typeStr = "buy_stop";
      else if(dealType == ORDER_TYPE_SELL_STOP)   typeStr = "sell_stop";
      else                                         typeStr = "unknown_pending";
      entryPrice  = HistoryOrderGetDouble(ticket, ORDER_PRICE_OPEN);
      slPrice     = HistoryOrderGetDouble(ticket, ORDER_SL);
      tpPrice     = HistoryOrderGetDouble(ticket, ORDER_TP);
      closePrice  = 0;
      lotSize     = HistoryOrderGetDouble(ticket, ORDER_VOLUME_INITIAL);
      openTime    = (datetime)HistoryOrderGetInteger(ticket, ORDER_TIME_SETUP);
      closeTime   = 0;
      profitLoss  = 0; swap = 0; commission = 0;
      magicNumber = HistoryOrderGetInteger(ticket, ORDER_MAGIC);
      comment     = HistoryOrderGetString(ticket, ORDER_COMMENT);
     }

   string openTimeStr  = (openTime  > 0) ? TimeToString(openTime,  TIME_DATE | TIME_SECONDS) : "";
   string closeTimeStr = (closeTime > 0) ? TimeToString(closeTime, TIME_DATE | TIME_SECONDS) : "";
   StringReplace(openTimeStr,  ".", "-");
   StringReplace(closeTimeStr, ".", "-");

   string json = "{";
   json += "\"ticket_id\": \""   + IntegerToString(ticket)       + "\",";
   json += "\"symbol\": \""      + symbol                        + "\",";
   json += "\"type\": \""        + typeStr                       + "\",";
   json += "\"entry_price\": "   + DoubleToString(entryPrice, 5) + ",";
   json += "\"close_price\": "   + DoubleToString(closePrice, 5) + ",";
   json += "\"sl_price\": "      + DoubleToString(slPrice, 5)    + ",";
   json += "\"tp_price\": "      + DoubleToString(tpPrice, 5)    + ",";
   json += "\"lot_size\": "      + DoubleToString(lotSize, 2)    + ",";
   json += "\"profit_loss\": "   + DoubleToString(profitLoss, 2) + ",";
   json += "\"swap\": "          + DoubleToString(swap, 2)       + ",";
   json += "\"commission\": "    + DoubleToString(commission, 2) + ",";
   if(openTimeStr  != "") json += "\"open_time\": \""  + openTimeStr  + "\",";
   if(closeTimeStr != "") json += "\"close_time\": \"" + closeTimeStr + "\",";
   json += "\"magic_number\": \"" + IntegerToString(magicNumber) + "\",";
   StringReplace(comment, "\"", "\\\"");
   json += "\"comment\": \"" + comment + "\"";
   json += "}";

   char   post[], result_web[];
   string headers = "Content-Type: application/json\r\nX-Webhook-Token: " + InpWebhookToken + "\r\n";
   StringToCharArray(json, post, 0, WHOLE_ARRAY, CP_UTF8);
   int post_size = ArraySize(post);
   if(post_size > 0) ArrayResize(post, post_size - 1);

   Print("Sending JSON: ", json);
   int resCode = WebRequest("POST", InpWebhookURL, headers, 3000, post, result_web, headers);
   if(resCode == 200 || resCode == 201)
      Print("Webhook OK: Trade ", ticket, " berhasil dikirim.");
   else
      Print("Webhook GAGAL. HTTP Code: ", resCode, ". Error: ", GetLastError());
  }

//=====================================================================
// [6] EA EVENT HANDLERS (MERGED)
//=====================================================================
datetime g_last_bar = 0;

int OnInit()
  {
   // Inisialisasi Risk Panel
   if(!ExtPanel.Create(0, "Jurnal Tradingku - Risk Panel", 0, 20, 30, 300, 420)) return INIT_FAILED;
   ExtPanel.Run();
   Print("Jurnal Tradingku EA v2.00 Ready. Webhook: ", InpWebhookURL);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   ExtPanel.Destroy(reason);
   Print("Jurnal Tradingku EA Stopped.");
  }

void OnTick()
  {
   ExtPanel.UpdateStats();
   datetime cur = iTime(_Symbol, _Period, 0);
   if(cur != g_last_bar) { g_last_bar = cur; CheckCutLoss(); }
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest      &request,
                        const MqlTradeResult       &result)
  {
   // Rekam closed trade ke jurnal
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
     {
      ulong ticket = trans.deal;
      if(HistoryDealSelect(ticket))
        {
         long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
         if(entry == DEAL_ENTRY_OUT)
            SendTradeDataToWebhook(ticket, "deal_close");
        }
     }

   // Rekam pending order ke jurnal
   if(trans.type == TRADE_TRANSACTION_HISTORY_ADD)
     {
      ulong order_ticket = trans.order;
      if(HistoryOrderSelect(order_ticket))
        {
         long orderType = HistoryOrderGetInteger(order_ticket, ORDER_TYPE);
         if(orderType == ORDER_TYPE_BUY_LIMIT  || orderType == ORDER_TYPE_SELL_LIMIT ||
            orderType == ORDER_TYPE_BUY_STOP   || orderType == ORDER_TYPE_SELL_STOP)
           { Sleep(100); SendTradeDataToWebhook(order_ticket, "pending_order"); }
        }
     }
  }

void OnChartEvent(const int id, const long &lp, const double &dp, const string &sp)
  { ExtPanel.ChartEvent(id, lp, dp, sp); }
//+------------------------------------------------------------------+
