//+------------------------------------------------------------------+
//|                                        AutoSnD_RiskPanel.mq4     |
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

//=====================================================================
// MT4 CTrade Wrapper
//=====================================================================
class CTradeMT4 {
public:
   bool Buy(double vol,string sym,double price,double sl,double tp,string comment){
      RefreshRates();
      int tk=OrderSend(sym,OP_BUY,vol,Ask,10,sl,tp,comment,0,0,clrBlue);
      return tk>0;
   }
   bool Sell(double vol,string sym,double price,double sl,double tp,string comment){
      RefreshRates();
      int tk=OrderSend(sym,OP_SELL,vol,Bid,10,sl,tp,comment,0,0,clrRed);
      return tk>0;
   }
   bool BuyLimit(double vol,double price,string sym,double sl,double tp,int tt,datetime expr,string comment){
      RefreshRates();
      int tk=OrderSend(sym,OP_BUYLIMIT,vol,price,10,sl,tp,comment,0,expr,clrBlue);
      return tk>0;
   }
   bool SellLimit(double vol,double price,string sym,double sl,double tp,int tt,datetime expr,string comment){
      RefreshRates();
      int tk=OrderSend(sym,OP_SELLLIMIT,vol,price,10,sl,tp,comment,0,expr,clrRed);
      return tk>0;
   }
   bool BuyStop(double vol,double price,string sym,double sl,double tp,int tt,datetime expr,string comment){
      RefreshRates();
      int tk=OrderSend(sym,OP_BUYSTOP,vol,price,10,sl,tp,comment,0,expr,clrBlue);
      return tk>0;
   }
   bool SellStop(double vol,double price,string sym,double sl,double tp,int tt,datetime expr,string comment){
      RefreshRates();
      int tk=OrderSend(sym,OP_SELLSTOP,vol,price,10,sl,tp,comment,0,expr,clrRed);
      return tk>0;
   }
   bool PositionClose(int ticket,int slippage=10){
      if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES)){
         RefreshRates();
         if(OrderType()==OP_BUY)  return OrderClose(ticket,OrderLots(),MarketInfo(OrderSymbol(),MODE_BID),slippage,clrWhite);
         if(OrderType()==OP_SELL) return OrderClose(ticket,OrderLots(),MarketInfo(OrderSymbol(),MODE_ASK),slippage,clrWhite);
      }
      return false;
   }
   bool OrderDelete(int ticket){
      if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
         if(OrderType()>OP_SELL) return ::OrderDelete(ticket,clrWhite);
      return false;
   }
};
CTradeMT4 ExtTrade;

//=====================================================================
// [1] INPUT PARAMETERS
//=====================================================================
input string  _s1_="=== Risk Panel & Webhook ===";
input string  InpWebhookURL   = "http://jurnaltradingku.my.id/api/webhook/trading-log";
input string  InpWebhookToken = "";
input int     InpResyncDays   = 365;

input string  _s2_="=== Auto Close Friday ===";
input bool    InpEnableAutoCloseFriday  = false;
input int     InpAutoCloseMinutesBefore = 15;

input string  _s3_="=== Auto SnD Trading Logic ===";
input bool    InpEnableAutoSnD   = false;
input int     InpPivotLB         = 5;
input int     InpOriginLookback  = 50;
input double  InpBufferPoints    = 20.0;
input int     InpHistoryBars     = 600;
input bool    InpShowBOS         = true;
input color   InpDemandColor     = C'0,160,0';
input color   InpSupplyColor     = C'190,0,0';
input bool    InpShowMitigated   = true;
input color   InpMitColor        = clrGray;         // Warna Border Zona Termitigasi
input bool    InpShowZones       = true;            // Tampilkan Zona SnD Aktif
input bool    InpShowRbdDbr      = true;          // Tampilkan Zona Reversal (RBD/DBR)
input bool    InpShowRbrDbd      = true;          // Tampilkan Zona Continuation (RBR/DBD)
input bool    InpAutoTradeRbrDbd = false;         // Auto-Trade Zona Continuation
input color   InpContColor       = clrLightBlue;  // Warna Border Zona Continuation
input int     InpBaseMaxCandles  = 3;             // Max Base Candles utk Continuation
input color   InpBOSBull         = clrDodgerBlue;   // Warna Bullish BOS
input color   InpBOSBear         = clrOrangeRed;    // Warna Bearish BOS
input color   InpGoldenZoneColor = clrGold;



input string  _s5_="=== Momentum Indicator ===";
input int     InpEarlySignalSeconds = 10;
input bool    InpEnableAutoMomentum = false;
input double  InpMomentumRR         = 0.61;
input double  InpBodyPercentage     = 0.75;
input double  InpWickPercentage     = 0.10;
input int     InpATRPeriod          = 14;
input double  InpATRMultiplier      = 1.5;
input int     InpMomMaxCandlesAfterBase = 2;

input string  _s6_="=== Profit Protection (Step Trailing SL) ===";
input bool    InpEnableProfitProtect = false; // Enable Step Profit Protection
input double  InpStep1Pct = 50.0;             // Step 1: Pindah SL ke Entry (Breakeven) saat profit mencapai X% dari TP
input double  InpStep2Pct = 90.0;             // Step 2: Pindah SL ke 50% profit saat mencapai X% dari TP

//=====================================================================
// ZONE STRUCT & GLOBALS
//=====================================================================
enum ENUM_ZONE_TYPE { ZONE_RBD_DBR, ZONE_RBR_DBD };

struct ZoneData {
   string   rect_name, lbl_name, lbl_top, lbl_btm;
   bool     is_demand;
   double   top, btm;
   datetime start_time, end_time;
   bool     active;
   ENUM_ZONE_TYPE type;
};
#define MAX_ZONES 300
ZoneData g_zones[MAX_ZONES];
int      g_zone_count=0, g_obj_id=0;
double   g_last_ph=0, g_last_pl=0;
datetime g_last_ph_time=0, g_last_pl_time=0;
double   g_old_last_ph=0, g_old_last_pl=0;
datetime g_marked_ph_time=0, g_marked_pl_time=0;
datetime g_last_processed_bar=0;

bool     g_is_scanning_history=false;
datetime g_traded_zones[];
int      g_active_tickets[];
int      g_last_history_total=0;

bool IsZoneTraded(datetime t){int s=ArraySize(g_traded_zones);for(int i=0;i<s;i++)if(g_traded_zones[i]==t)return true;return false;}
void MarkZoneTraded(datetime t){int s=ArraySize(g_traded_zones);ArrayResize(g_traded_zones,s+1);g_traded_zones[s]=t;}
string NextID(){return IntegerToString(++g_obj_id);}

//=====================================================================
// [2] LOT CALCULATION
//=====================================================================
double CalcLotSize(double risk,double entry,double sl,string symbol){
   double diff=MathAbs(entry-sl); if(diff==0) return 0;
   double ts=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   double tv=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE);
   double vmin=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
   double vstep=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
   double vmax=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
   if(ts==0||tv==0) return -1;
   double lot=risk/((diff/ts)*tv);
   double lotn=MathFloor(lot/vstep)*vstep;
   if(lotn<vmin&&lot>0) return -2;
   if(lotn>vmax) lotn=vmax;
   return lotn;
}

//=====================================================================
// [3] CUT LOSS & FRIDAY MONITOR
//=====================================================================


bool IsBullishMomentum(int index = 1) {
   double atr = iATR(Symbol(), Period(), InpATRPeriod, index);
   if(atr <= 0) return false;
   
   double high = iHigh(Symbol(), Period(), index);
   double low  = iLow(Symbol(), Period(), index);
   double open = iOpen(Symbol(), Period(), index);
   double close= iClose(Symbol(), Period(), index);
   
   double totalLength = high - low;
   if(totalLength <= 0) return false;
   if(totalLength <= atr * InpATRMultiplier) return false;
   
   if(close <= open) return false;
   double bodyLength = close - open;
   if(bodyLength < totalLength * InpBodyPercentage) return false;
   
   double lowerWick = open - low;
   if(lowerWick > totalLength * InpWickPercentage) return false;
   
   return true;
}

bool IsBearishMomentum(int index = 1) {
   double atr = iATR(Symbol(), Period(), InpATRPeriod, index);
   if(atr <= 0) return false;
   
   double high = iHigh(Symbol(), Period(), index);
   double low  = iLow(Symbol(), Period(), index);
   double open = iOpen(Symbol(), Period(), index);
   double close= iClose(Symbol(), Period(), index);
   
   double totalLength = high - low;
   if(totalLength <= 0) return false;
   if(totalLength <= atr * InpATRMultiplier) return false;
   
   if(open <= close) return false;
   double bodyLength = open - close;
   if(bodyLength < totalLength * InpBodyPercentage) return false;
   
   double upperWick = high - open;
   if(upperWick > totalLength * InpWickPercentage) return false;
   
   return true;
}

void DrawMomentumArrow(bool isBullish, int index) {
   datetime t = iTime(Symbol(), Period(), index);
   double high = iHigh(Symbol(), Period(), index);
   double low  = iLow(Symbol(), Period(), index);
   double range = high - low;
   string objName = (isBullish ? "MomUp_" : "MomDn_") + TimeToString(t);
   
   double price = isBullish ? (low - (range * 0.2)) : (high + (range * 0.2));
   
   if(ObjectFind(0, objName) >= 0) {
      ObjectMove(0, objName, 0, t, price);
      return;
   }
   
   if(isBullish) {
      ObjectCreate(0, objName, OBJ_ARROW_UP, 0, t, price);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrLime);
   } else {
      ObjectCreate(0, objName, OBJ_ARROW_DOWN, 0, t, price);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
   }
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
}

void ScanHistoricalMomentum() {
   int total = iBars(Symbol(), Period());
   int start = MathMin(InpHistoryBars, total - 2);
   for(int i = start; i >= 1; i--) {
      if(IsBullishMomentum(i)) DrawMomentumArrow(true, i);
      else if(IsBearishMomentum(i)) DrawMomentumArrow(false, i);
   }
}

bool IsMomentumAfterBase(bool isBullish, int shift, double &out_sl_level) {
   datetime candle_time = iTime(Symbol(), Period(), shift);
   double   pt          = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   
   for(int i = 0; i < g_zone_count; i++) {
      if(!g_zones[i].active)                    continue;
      if(g_zones[i].type != ZONE_RBR_DBD)       continue;
      if(isBullish  && !g_zones[i].is_demand)   continue;
      if(!isBullish &&  g_zones[i].is_demand)   continue;
      if(g_zones[i].end_time >= candle_time)    continue;
      
      int end_bar    = iBarShift(Symbol(), Period(), g_zones[i].end_time);
      int distance   = end_bar - shift;
      
      if(distance >= 1 && distance <= InpMomMaxCandlesAfterBase) {
         out_sl_level = isBullish 
                      ? (g_zones[i].btm - InpBufferPoints * pt)
                      : (g_zones[i].top + InpBufferPoints * pt);
         return true;
      }
   }
   return false;
}

void CheckProfitProtection() {
   if(!InpEnableProfitProtect) return;
   int digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderType() > OP_SELL) continue;
      
      int    ticket = OrderTicket();
      double entry  = OrderOpenPrice();
      double tp     = OrderTakeProfit();
      double sl     = OrderStopLoss();
      bool   isBuy  = (OrderType() == OP_BUY);
      
      if(tp == 0) continue;
      double tpDist = MathAbs(tp - entry);
      if(tpDist <= 0) continue;
      
      double curPrice = isBuy ? Bid : Ask;
      double progress = isBuy ? (curPrice - entry) / tpDist * 100.0 : (entry - curPrice) / tpDist * 100.0;
      if(progress <= 0) continue;
      
      double newSL = sl;
      if(progress >= InpStep2Pct) {
         double targetSL = isBuy ? NormalizeDouble(entry + tpDist * 0.5, digits) : NormalizeDouble(entry - tpDist * 0.5, digits);
         if(isBuy  && targetSL > newSL) newSL = targetSL;
         if(!isBuy && (newSL == 0 || targetSL < newSL)) newSL = targetSL;
      } else if(progress >= InpStep1Pct) {
         double targetSL = NormalizeDouble(entry, digits);
         if(isBuy  && targetSL > newSL) newSL = targetSL;
         if(!isBuy && (newSL == 0 || targetSL < newSL)) newSL = targetSL;
      }
      
      if(MathAbs(newSL - sl) > SymbolInfoDouble(Symbol(), SYMBOL_POINT) * 0.5) {
         string stage = (progress >= InpStep2Pct) ? "Step2(50%Profit)" : "Step1(Breakeven)";
         if(OrderModify(ticket, entry, newSL, tp, 0, clrNONE))
            Print("ProfitProtect [", stage, "] Ticket:", ticket, " NewSL:", DoubleToString(newSL, digits), " Progress:", DoubleToString(progress, 1), "%");
         else
            Print("ProfitProtect: Gagal modify SL ticket:", ticket, " Error:", GetLastError());
      }
   }
}

void CheckContinuationZone(int shift) {
   bool is_bull_rally = IsBullishMomentum(shift);
   bool is_bear_drop  = IsBearishMomentum(shift);
   if(!is_bull_rally && !is_bear_drop) return;
   
   double leg_out_range = iHigh(Symbol(), Period(), shift) - iLow(Symbol(), Period(), shift);
   int best_base_start = -1;
   int best_base_end = -1;
   
   for(int k=1; k<=InpBaseMaxCandles; k++) {
      int idx_leg_in = shift + k + 1;
      bool leg_in_valid = is_bull_rally ? (iClose(Symbol(),Period(),idx_leg_in) > iOpen(Symbol(),Period(),idx_leg_in))
                                        : (iClose(Symbol(),Period(),idx_leg_in) < iOpen(Symbol(),Period(),idx_leg_in));
      if(!leg_in_valid) continue;
      
      bool valid_base = true;
      double max_h = 0, min_l = 999999;
      for(int b=1; b<=k; b++) {
         int b_idx = shift + b;
         double h = iHigh(Symbol(), Period(), b_idx);
         double l = iLow(Symbol(), Period(), b_idx);
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
         if(iHigh(Symbol(), Period(), i) > top) top = iHigh(Symbol(), Period(), i);
         if(iLow(Symbol(), Period(), i) < btm) btm = iLow(Symbol(), Period(), i);
      }
      datetime st = iTime(Symbol(), Period(), best_base_start);
      for(int z=0; z<g_zone_count; z++) {
         if(g_zones[z].start_time == st && g_zones[z].type == ZONE_RBR_DBD) return;
      }
      datetime et = iTime(Symbol(), Period(), best_base_end);
      DrawZone(is_bull_rally, top, btm, st, ZONE_RBR_DBD, et);
   }
}
void CheckCutLoss(){
   double bid=MarketInfo(Symbol(),MODE_BID);
   double ask=MarketInfo(Symbol(),MODE_ASK);
   int total=OrdersTotal();
   for(int i=total-1;i>=0;i--){
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol()) continue;
      if(OrderType()>OP_SELL) continue;
      string comment=OrderComment();
      if(StringFind(comment,"RP_CL_")<0 && StringFind(comment,"SND_CL_")<0) continue;
      int idx=StringFind(comment,"CL_"); if(idx<0) continue;
      double cut=StringToDouble(StringSubstr(comment,idx+3));
      if(cut==0) continue;
      bool is_buy=(OrderType()==OP_BUY);
      bool do_cut=is_buy?(bid<=cut):(ask>=cut);
      if(do_cut){
         Print(">>> Cut Loss TRIGGERED! Ticket:",OrderTicket()," Comment:",comment," Cut:",cut);
         ExtTrade.PositionClose(OrderTicket(),10);
      }
   }
}

void CheckAutoCloseFriday(){
   if(!InpEnableAutoCloseFriday) return;
   if(DayOfWeek()!=5) return;
   int cur_sec=TimeHour(TimeCurrent())*3600+TimeMinute(TimeCurrent())*60+TimeSeconds(TimeCurrent());
   int trig_sec=86399-(InpAutoCloseMinutesBefore*60);
   if(cur_sec>=trig_sec){
      bool done=false;
      for(int i=OrdersTotal()-1;i>=0;i--){
         if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
         if(OrderSymbol()!=Symbol()) continue;
         if(OrderType()<=OP_SELL) ExtTrade.PositionClose(OrderTicket());
         else ExtTrade.OrderDelete(OrderTicket());
         done=true;
      }
      if(done) Print("Auto Close Friday triggered at:",TimeCurrent());
   }
}

//=====================================================================
// [4] RISK PANEL CLASS
//=====================================================================
class CRiskPanel : public CAppDialog {
public:
   CLabel  m_lbl_balance,m_lbl_risk,m_lbl_entry,m_lbl_sl;
   CLabel  m_lbl_ratio,m_lbl_lot,m_lbl_status;
   CLabel  m_lbl_pair,m_lbl_spread,m_lbl_clock;
   CEdit   m_edt_risk,m_edt_entry,m_edt_sl,m_edt_ratio;
   CButton m_btn_place,m_btn_cancel,m_btn_cutloss,m_btn_risk_mode;
   CButton m_btn_buy_mkt,m_btn_sell_mkt,m_btn_close_all;
   bool    m_cl_active, m_risk_in_percent;

   bool MkLabel(CLabel &l,string n,string t,int x1,int y1,int x2,int y2,int fs=7){
      if(!l.Create(m_chart_id,m_name+n,m_subwin,x1,y1,x2,y2)) return false;
      l.Text(t); l.FontSize(fs); return Add(l);
   }
   bool MkEdit(CEdit &e,string n,string t,int x1,int y1,int x2,int y2,int fs=7){
      if(!e.Create(m_chart_id,m_name+n,m_subwin,x1,y1,x2,y2)) return false;
      e.Text(t); e.FontSize(fs); return Add(e);
   }
   bool MkButton(CButton &b,string n,string t,int x1,int y1,int x2,int y2,int fs=7){
      if(!b.Create(m_chart_id,m_name+n,m_subwin,x1,y1,x2,y2)) return false;
      b.Text(t); b.FontSize(fs); return Add(b);
   }
   void SetStatus(string t){m_lbl_status.Text("Status: "+t);}
   bool IsCent(){string c=AccountInfoString(ACCOUNT_CURRENCY);return StringFind(c,"USC")>=0||StringFind(c,"ent")>=0;}
   string AccCurr(){return IsCent()?"USD":AccountInfoString(ACCOUNT_CURRENCY);}

   double AdjRisk(){
      double r=StringToDouble(m_edt_risk.Text());
      double balance=AccountInfoDouble(ACCOUNT_BALANCE);
      if(m_risk_in_percent) return balance*(r/100.0);
      return IsCent()?(r*100.0):r;
   }
   void UpdateBalance(){double b=AccountInfoDouble(ACCOUNT_BALANCE);if(IsCent())b/=100.0;m_lbl_balance.Text("Balance: "+AccCurr()+" "+DoubleToString(b,2));}
   void UpdateLot(){
      double r=StringToDouble(m_edt_risk.Text()),e=StringToDouble(m_edt_entry.Text()),s=StringToDouble(m_edt_sl.Text());
      if(r<=0||e<=0||s<=0||e==s){m_lbl_lot.Text("Lot Size: --");return;}
      double lot=CalcLotSize(AdjRisk(),e,s,Symbol());
      m_lbl_lot.Text(lot>0?"Lot Size: "+DoubleToString(lot,2):"Lot Size: --");
   }
   void UpdateClock(datetime barTime){
      MqlDateTime loc; TimeToStruct(TimeLocal(),loc);
      int sec_left=(int)(barTime+Period()*60-TimeCurrent());
      if(sec_left<0) sec_left=0;
      m_lbl_clock.Text(StringFormat("LOC %02d:%02d | BAR %02d:%02d",loc.hour,loc.min,sec_left/60,sec_left%60));
   }
   bool ValidStopLevel(double entry,double sl,bool is_buy){
      long pts=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL);
      if(pts==0) return true;
      double mind=pts*SymbolInfoDouble(Symbol(),SYMBOL_POINT);
      if(is_buy&&sl>=entry-mind){SetStatus("SL terlalu dekat! Min:"+IntegerToString((int)pts)+"pts");return false;}
      if(!is_buy&&sl<=entry+mind){SetStatus("SL terlalu dekat! Min:"+IntegerToString((int)pts)+"pts");return false;}
      return true;
   }
   void OnCancelBtn(){m_edt_entry.Text("");m_edt_sl.Text("");m_lbl_lot.Text("Lot Size: --");SetStatus("Dibatalkan.");}
   void OnCutLoss(){m_cl_active=!m_cl_active;m_btn_cutloss.Text(m_cl_active?"CL: ON":"CL: OFF");SetStatus(m_cl_active?"Cut Loss ON":"Cut Loss OFF");}
   void OnRiskModeToggle(){
      m_risk_in_percent=!m_risk_in_percent;
      m_btn_risk_mode.Text(m_risk_in_percent?" % ":" $ ");
      m_lbl_risk.Text(m_risk_in_percent?"Risk (%):":"Risk ($):");
      UpdateLot();
   }
   void OnPlace(){
      double risk=StringToDouble(m_edt_risk.Text()),entry=StringToDouble(m_edt_entry.Text()),sl=StringToDouble(m_edt_sl.Text());
      if(risk<=0||entry<=0||sl<=0||entry==sl) return;
      int digits=(int)SymbolInfoInteger(Symbol(),SYMBOL_DIGITS);
      entry=NormalizeDouble(entry,digits); sl=NormalizeDouble(sl,digits);
      bool is_buy=entry>sl;
      if(!ValidStopLevel(entry,sl,is_buy)) return;
      double lot=CalcLotSize(AdjRisk(),entry,sl,Symbol());
      if(lot<=0) return;
      RefreshRates();
      double ask=Ask,bid=Bid;
      double diff=MathAbs(entry-sl);
      double mult=StringToDouble(m_edt_ratio.Text()); if(mult<=0) mult=2.0;
      double tp=0; bool result=false;
      if(m_cl_active){
         double backup=is_buy?NormalizeDouble(entry-diff*2.0,digits):NormalizeDouble(entry+diff*2.0,digits);
         string clc="RP_CL_"+DoubleToString(sl,digits);
         if(is_buy){tp=NormalizeDouble(entry+diff*mult,digits);result=(entry<ask)?ExtTrade.BuyLimit(lot,entry,Symbol(),backup,tp,0,0,clc):ExtTrade.BuyStop(lot,entry,Symbol(),backup,tp,0,0,clc);}
         else      {tp=NormalizeDouble(entry-diff*mult,digits);result=(entry>bid)?ExtTrade.SellLimit(lot,entry,Symbol(),backup,tp,0,0,clc):ExtTrade.SellStop(lot,entry,Symbol(),backup,tp,0,0,clc);}
      } else {
         if(is_buy){tp=NormalizeDouble(entry+diff*mult,digits);result=(entry<ask)?ExtTrade.BuyLimit(lot,entry,Symbol(),sl,tp,0,0,"RP"):ExtTrade.BuyStop(lot,entry,Symbol(),sl,tp,0,0,"RP");}
         else      {tp=NormalizeDouble(entry-diff*mult,digits);result=(entry>bid)?ExtTrade.SellLimit(lot,entry,Symbol(),sl,tp,0,0,"RP"):ExtTrade.SellStop(lot,entry,Symbol(),sl,tp,0,0,"RP");}
      }
      SetStatus(result?"Order Manual Dipasang":"Gagal Pasang Order");
   }
   void OnBuyMarket(){ExecuteMarketOrder(true);}
   void OnSellMarket(){ExecuteMarketOrder(false);}
   void OnCloseAll(){
      int count=0;
      for(int i=OrdersTotal()-1;i>=0;i--){
         if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
         if(OrderSymbol()!=Symbol()) continue;
         if(OrderType()<=OP_SELL){ExtTrade.PositionClose(OrderTicket());count++;}
         else{ExtTrade.OrderDelete(OrderTicket());count++;}
      }
      SetStatus(count>0?"Tertutup "+IntegerToString(count)+" order":"Tidak ada order aktif.");
   }
   void ExecuteMarketOrder(bool is_buy){
      double risk=StringToDouble(m_edt_risk.Text()),sl=StringToDouble(m_edt_sl.Text());
      if(risk<=0||sl<=0){SetStatus("Isi Risk & SL");return;}
      RefreshRates();
      double entry=is_buy?Ask:Bid;
      if(is_buy&&sl>=entry){SetStatus("SL Buy harus < Harga");return;}
      if(!is_buy&&sl<=entry){SetStatus("SL Sell harus > Harga");return;}
      int digits=(int)SymbolInfoInteger(Symbol(),SYMBOL_DIGITS);
      entry=NormalizeDouble(entry,digits); sl=NormalizeDouble(sl,digits);
      if(!ValidStopLevel(entry,sl,is_buy)) return;
      double lot=CalcLotSize(AdjRisk(),entry,sl,Symbol());
      if(lot<=0) return;
      double diff=MathAbs(entry-sl);
      double mult=StringToDouble(m_edt_ratio.Text()); if(mult<=0) mult=2.0;
      double tp=is_buy?NormalizeDouble(entry+diff*mult,digits):NormalizeDouble(entry-diff*mult,digits);
      string comm=m_cl_active?("RP_CL_"+DoubleToString(sl,digits)):"RP_MKT";
      double hard_sl=sl;
      if(m_cl_active) hard_sl=is_buy?NormalizeDouble(entry-diff*2.0,digits):NormalizeDouble(entry+diff*2.0,digits);
      bool result=is_buy?ExtTrade.Buy(lot,Symbol(),entry,hard_sl,tp,comm):ExtTrade.Sell(lot,Symbol(),entry,hard_sl,tp,comm);
      SetStatus(result?("Order "+(is_buy?"BUY":"SELL")+" MKT Dipasang"):"Gagal Pasang Order");
   }
   void OnInput(){UpdateLot();}
   void UpdateStats(){m_lbl_pair.Text(Symbol());UpdateBalance();}

   CRiskPanel(){m_cl_active=false;m_risk_in_percent=false;}
   virtual bool Create(const long chart,const string name,const int sw,const int x1,const int y1,const int x2,const int y2){
      if(!CAppDialog::Create(chart,name,sw,x1,y1,x2,y2)) return false;
      int lx=18,rx=267,rh=30,ch=22,bh=28,y=15,lbl=75,gap=12,ex=lx+lbl+gap;
      if(!MkLabel(m_lbl_pair,  "LPair", Symbol(),              lx,y,lx+80,y+ch,8)) return false;
      if(!MkLabel(m_lbl_spread,"LSpr",  InpEnableAutoSnD?"AUTO:ON":"AUTO:OFF",lx+85,y,rx,y+ch,8)) return false;
      y+=ch+5;
      if(!MkLabel(m_lbl_balance,"Bal","Balance: --",lx,y,rx,y+ch,8)) return false;
      y+=ch+15;
      if(!MkLabel(m_lbl_risk,"LR","Risk ($):",lx,y,ex-gap,y+ch)) return false;
      if(!MkEdit(m_edt_risk,"ER","0.5",ex,y,rx-50,y+ch)) return false;
      if(!MkButton(m_btn_risk_mode,"BRM"," $ ",rx-45,y,rx,y+ch)) return false;
      y+=rh;
      if(!MkLabel(m_lbl_entry,"LE","Entry:",lx,y,ex-gap,y+ch)) return false;
      if(!MkEdit(m_edt_entry,"EE","",ex,y,rx,y+ch)) return false;
      y+=rh;
      if(!MkLabel(m_lbl_sl,"LS","Stop Loss:",lx,y,ex-gap,y+ch)) return false;
      if(!MkEdit(m_edt_sl,"ES","",ex,y,rx,y+ch)) return false;
      y+=rh;
      if(!MkLabel(m_lbl_ratio,"LRt","RR Ratio:",lx,y,ex-gap,y+ch)) return false;
      if(!MkEdit(m_edt_ratio,"ERt","2.0",ex,y,rx,y+ch)) return false;
      y+=rh;
      if(!MkLabel(m_lbl_lot,"LL","Lot Size: --",lx,y,rx,y+ch,8)) return false;
      y+=ch+20;
      int bww=(rx-lx-10)/2;
      if(!MkButton(m_btn_cutloss,"BCL","CL: OFF",lx,y,lx+bww,y+bh)) return false;
      if(!MkButton(m_btn_cancel,"BC","CAN. EDIT",lx+bww+10,y,rx,y+bh)) return false;
      y+=bh+10;
      if(!MkButton(m_btn_place,"BP","PLACE LIMIT ORDER",lx,y,rx,y+bh,8)) return false;
      m_btn_place.ColorBackground(C'30,144,255'); m_btn_place.Color(clrWhite);
      y+=bh+10;
      if(!MkButton(m_btn_buy_mkt,"BBM","BUY MKT",lx,y,lx+bww,y+bh,8)) return false;
      m_btn_buy_mkt.ColorBackground(C'0,130,80'); m_btn_buy_mkt.Color(clrWhite);
      if(!MkButton(m_btn_sell_mkt,"BSM","SELL MKT",lx+bww+10,y,rx,y+bh,8)) return false;
      m_btn_sell_mkt.ColorBackground(C'176,0,32'); m_btn_sell_mkt.Color(clrWhite);
      y+=bh+10;
      if(!MkButton(m_btn_close_all,"BCAll","CLOSE ALL POSITIONS",lx,y,rx,y+bh,8)) return false;
      m_btn_close_all.ColorBackground(C'50,50,50'); m_btn_close_all.Color(clrWhite);
      y+=bh+15;
      if(!MkLabel(m_lbl_status,"LSt","Status: AutoSnD Ready",lx,y,rx,y+ch)) return false;
      y+=ch+5;
      if(!MkLabel(m_lbl_clock,"LClk","LOC --:-- | BAR --:--",lx,y,rx,y+ch,8)) return false;
      m_lbl_clock.Color(clrDodgerBlue);
      return true;
   }
   virtual bool OnEvent(const int id,const long &lp,const double &dp,const string &sp){
      if(id==CHARTEVENT_CUSTOM+ON_CLICK){
         if(lp==m_btn_place.Id())    {OnPlace();         return true;}
         if(lp==m_btn_cancel.Id())   {OnCancelBtn();     return true;}
         if(lp==m_btn_cutloss.Id())  {OnCutLoss();       return true;}
         if(lp==m_btn_risk_mode.Id()){OnRiskModeToggle();return true;}
         if(lp==m_btn_buy_mkt.Id())  {OnBuyMarket();     return true;}
         if(lp==m_btn_sell_mkt.Id()) {OnSellMarket();    return true;}
         if(lp==m_btn_close_all.Id()){OnCloseAll();      return true;}
      }
      if(id==CHARTEVENT_CUSTOM+ON_END_EDIT){
         if(lp==m_edt_risk.Id()||lp==m_edt_entry.Id()||lp==m_edt_sl.Id()||lp==m_edt_ratio.Id()){OnInput();return true;}
      }
      return CAppDialog::OnEvent(id,lp,dp,sp);
   }
};
CRiskPanel ExtPanel;

//=====================================================================
// [5] JOURNAL WEBHOOK (MT4 Polling)
//=====================================================================
void SendTradeDataToWebhook(int ticket,string eventType){
   if(InpWebhookURL==""||InpWebhookToken=="") return;
   string symbol="",typeStr="",comment="";
   double entryPrice=0,closePrice=0,slPrice=0,tpPrice=0,lotSize=0,profitLoss=0,swap=0,commission=0;
   long magicNumber=0; datetime openTime=0,closeTime=0;
   int mode=(eventType=="deal_close"||eventType=="pending_cancel")?MODE_HISTORY:MODE_TRADES;
   if(!OrderSelect(ticket,SELECT_BY_TICKET,mode)) return;
   symbol=OrderSymbol();
   int ot=OrderType();
   if(eventType=="deal_close"||eventType=="pending_cancel"){
      if(ot==OP_BUY) typeStr="buy_closed";
      else if(ot==OP_SELL) typeStr="sell_closed";
      else typeStr="pending_cancel";
   } else {
      if(ot==OP_BUY) typeStr="buy";
      else if(ot==OP_SELL) typeStr="sell";
      else if(ot==OP_BUYLIMIT) typeStr="buy_limit";
      else if(ot==OP_SELLLIMIT) typeStr="sell_limit";
      else if(ot==OP_BUYSTOP) typeStr="buy_stop";
      else if(ot==OP_SELLSTOP) typeStr="sell_stop";
   }
   if(eventType=="balance"){
      typeStr=(OrderProfit()>=0)?"deposit":"withdrawal";
      profitLoss=OrderProfit(); comment=OrderComment();
      openTime=OrderOpenTime(); closeTime=openTime; symbol="";
   } else {
      entryPrice=OrderOpenPrice(); closePrice=OrderClosePrice();
      slPrice=OrderStopLoss(); tpPrice=OrderTakeProfit();
      lotSize=OrderLots(); profitLoss=OrderProfit();
      swap=OrderSwap(); commission=OrderCommission();
      magicNumber=OrderMagicNumber(); comment=OrderComment();
      openTime=OrderOpenTime(); closeTime=OrderCloseTime();
   }
   string oTS=(openTime>0)?TimeToString(openTime,TIME_DATE|TIME_SECONDS):"";
   string cTS=(closeTime>0)?TimeToString(closeTime,TIME_DATE|TIME_SECONDS):"";
   StringReplace(oTS,".","-"); StringReplace(cTS,".","-");
   string accLogin=IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN));
   string accServer=AccountInfoString(ACCOUNT_SERVER);
   string accountName=accLogin+" - "+accServer;
   StringReplace(accountName,"\"","\\\"");
   string accCurr=AccountInfoString(ACCOUNT_CURRENCY); StringToLower(accCurr);
   double div=(StringFind(accCurr,"c")>=0)?100.0:1.0;
   string json="{";
   json+="\"account_name\": \""+accountName+"\",";
   json+="\"ticket_id\": \""+IntegerToString(ticket)+"\", \"symbol\": \""+symbol+"\", \"type\": \""+typeStr+"\",";
   json+="\"entry_price\": "+DoubleToString(entryPrice,5)+", \"close_price\": "+DoubleToString(closePrice,5)+",";
   json+="\"sl_price\": "+DoubleToString(slPrice,5)+", \"tp_price\": "+DoubleToString(tpPrice,5)+",";
   json+="\"lot_size\": "+DoubleToString(lotSize,2)+", \"profit_loss\": "+DoubleToString(profitLoss/div,2)+",";
   json+="\"swap\": "+DoubleToString(swap/div,2)+", \"commission\": "+DoubleToString(commission/div,2)+",";
   if(oTS!="") json+="\"open_time\": \""+oTS+"\",";
   if(cTS!="") json+="\"close_time\": \""+cTS+"\",";
   json+="\"magic_number\": \""+IntegerToString((int)magicNumber)+"\",";
   StringReplace(comment,"\"","\\\""); json+="\"comment\": \""+comment+"\",";
   json+="\"balance\": "+DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE)/div,2)+"}";
   string headers="Content-Type: application/json\r\nX-Webhook-Token: "+InpWebhookToken+"\r\n";
   char post[],resW[]; StringToCharArray(json,post,0,WHOLE_ARRAY,CP_UTF8);
   int ps=ArraySize(post); if(ps>0) ArrayResize(post,ps-1);
   string resHeaders;
   int res=WebRequest("POST",InpWebhookURL,headers,3000,post,resW,resHeaders);
   if(res==-1){int err=GetLastError();if(err==4060)Print("WEBHOOK BLOCKED!");else Print("WEBHOOK ERROR! Code:",err);}
}

void InitialHistorySync(){
   if(InpResyncDays<=0||InpWebhookURL=="") return;
   datetime from=TimeCurrent()-(InpResyncDays*86400);
   int histTotal=OrdersHistoryTotal();
   for(int i=0;i<histTotal;i++){
      if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)) continue;
      int ot=OrderType(); datetime ct=OrderCloseTime();
      if(ct<from&&ct!=0) continue;
      if(ot==6) SendTradeDataToWebhook(OrderTicket(),"balance");
      else if(ot<=OP_SELL) SendTradeDataToWebhook(OrderTicket(),"deal_close");
      else SendTradeDataToWebhook(OrderTicket(),"pending_cancel");
   }
   ArrayResize(g_active_tickets,0);
   for(int i=0;i<OrdersTotal();i++){
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      int sz=ArraySize(g_active_tickets); ArrayResize(g_active_tickets,sz+1);
      g_active_tickets[sz]=OrderTicket();
      int ot=OrderType();
      if(ot<=OP_SELL) SendTradeDataToWebhook(OrderTicket(),"deal_open");
      else SendTradeDataToWebhook(OrderTicket(),"pending_order");
   }
   g_last_history_total=OrdersHistoryTotal();
}

void PollTradeEvents(){
   int cur[];
   for(int i=0;i<OrdersTotal();i++){
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      int tk=OrderTicket();
      int s=ArraySize(cur); ArrayResize(cur,s+1); cur[s]=tk;
      bool found=false;
      for(int j=0;j<ArraySize(g_active_tickets);j++) if(g_active_tickets[j]==tk){found=true;break;}
      if(!found){
         if(OrderType()<=OP_SELL) SendTradeDataToWebhook(tk,"deal_open");
         else SendTradeDataToWebhook(tk,"pending_order");
      }
   }
   for(int i=0;i<ArraySize(g_active_tickets);i++){
      int old=g_active_tickets[i]; bool found=false;
      for(int j=0;j<ArraySize(cur);j++) if(cur[j]==old){found=true;break;}
      if(!found&&OrderSelect(old,SELECT_BY_TICKET,MODE_HISTORY)){
         if(OrderType()<=OP_SELL) SendTradeDataToWebhook(old,"deal_close");
         else SendTradeDataToWebhook(old,"pending_cancel");
      }
   }
   int histTotal=OrdersHistoryTotal();
   if(histTotal>g_last_history_total){
      for(int i=g_last_history_total;i<histTotal;i++){
         if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)&&OrderType()==6)
            SendTradeDataToWebhook(OrderTicket(),"balance");
      }
      g_last_history_total=histTotal;
   }
   ArrayResize(g_active_tickets,ArraySize(cur));
   for(int i=0;i<ArraySize(cur);i++) g_active_tickets[i]=cur[i];
}

//=====================================================================
// [6] AUTO SND TRADING ENGINE
//=====================================================================
void DrawZone(bool is_demand, double top, double btm, datetime start_time, ENUM_ZONE_TYPE ztype = ZONE_RBD_DBR, datetime end_time = 0){
   if(g_zone_count>=MAX_ZONES) return;
   if(end_time == 0) end_time = start_time;
   color col_use=(ztype == ZONE_RBR_DBD) ? InpContColor : (is_demand?InpDemandColor:InpSupplyColor);
   string uid=NextID(),rname="SnD_Z_"+uid,lname="SnD_ZL_"+uid;
   if(InpShowZones)
     {
      if(ObjectCreate(0,rname,OBJ_RECTANGLE,0,start_time,top,D'2099.12.31',btm))
        { ObjectSetInteger(0,rname,OBJPROP_COLOR,col_use); ObjectSetInteger(0,rname,OBJPROP_FILL,true); ObjectSetInteger(0,rname,OBJPROP_BACK,true); ObjectSetInteger(0,rname,OBJPROP_SELECTABLE,false); ObjectSetString(0,rname,OBJPROP_TOOLTIP,(is_demand?"Demand":"Supply")+" | Top:"+DoubleToString(top,_Digits)+" Btm:"+DoubleToString(btm,_Digits)); }
      if(ObjectCreate(0,lname,OBJ_TEXT,0,start_time,top))
        { ObjectSetString(0,lname,OBJPROP_TEXT,is_demand?" Origin Demand":" Origin Supply"); ObjectSetInteger(0,lname,OBJPROP_COLOR,col_use); ObjectSetInteger(0,lname,OBJPROP_FONTSIZE,6); ObjectSetInteger(0,lname,OBJPROP_ANCHOR,ANCHOR_CENTER); ObjectSetInteger(0,lname,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,lname,OBJPROP_BACK,true); }
      string ptop="SnD_PT_"+uid, pbtm="SnD_PB_"+uid;
      if(ObjectCreate(0,ptop,OBJ_TEXT,0,start_time,top)) { ObjectSetString(0,ptop,OBJPROP_TEXT,DoubleToString(top,_Digits)); ObjectSetInteger(0,ptop,OBJPROP_COLOR,col_use); ObjectSetInteger(0,ptop,OBJPROP_FONTSIZE,6); ObjectSetInteger(0,ptop,OBJPROP_ANCHOR,ANCHOR_LOWER); ObjectSetInteger(0,ptop,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,ptop,OBJPROP_BACK,true); }
      if(ObjectCreate(0,pbtm,OBJ_TEXT,0,start_time,btm)) { ObjectSetString(0,pbtm,OBJPROP_TEXT,DoubleToString(btm,_Digits)); ObjectSetInteger(0,pbtm,OBJPROP_COLOR,col_use); ObjectSetInteger(0,pbtm,OBJPROP_FONTSIZE,6); ObjectSetInteger(0,pbtm,OBJPROP_ANCHOR,ANCHOR_UPPER); ObjectSetInteger(0,pbtm,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,pbtm,OBJPROP_BACK,true); }
     }
   g_zones[g_zone_count].rect_name=rname; g_zones[g_zone_count].lbl_name=lname; g_zones[g_zone_count].lbl_top="SnD_PT_"+uid; g_zones[g_zone_count].lbl_btm="SnD_PB_"+uid;
   g_zones[g_zone_count].is_demand=is_demand;g_zones[g_zone_count].top=top;g_zones[g_zone_count].btm=btm;g_zones[g_zone_count].start_time=start_time;
   g_zones[g_zone_count].end_time=end_time; g_zones[g_zone_count].type=ztype;
   g_zones[g_zone_count].active=true; g_zone_count++;
}


void DrawBOS(bool is_bull,double price,datetime x1,datetime x2){
   if(!InpShowBOS) return;
   color col=is_bull?InpBOSBull:InpBOSBear;
   string uid=NextID(),ln="SnD_B_"+uid,lb="SnD_BL_"+uid;
   if(ObjectCreate(0,ln,OBJ_TREND,0,x1,price,x2,price)){ObjectSetInteger(0,ln,OBJPROP_COLOR,col);ObjectSetInteger(0,ln,OBJPROP_STYLE,STYLE_DASH);ObjectSetInteger(0,ln,OBJPROP_RAY_RIGHT,false);ObjectSetInteger(0,ln,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,ln,OBJPROP_BACK,true);}
   datetime mid=(datetime)(((long)x1+(long)x2)/2);
   if(ObjectCreate(0,lb,OBJ_TEXT,0,mid,price)){ObjectSetString(0,lb,OBJPROP_TEXT,"BOS");ObjectSetInteger(0,lb,OBJPROP_COLOR,col);ObjectSetInteger(0,lb,OBJPROP_FONTSIZE,6);ObjectSetInteger(0,lb,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,lb,OBJPROP_BACK,true);}
}

void MitigateZone(int idx,datetime t){
   g_zones[idx].active=false;
   ObjectDelete(0,g_zones[idx].lbl_name);ObjectDelete(0,g_zones[idx].lbl_top);ObjectDelete(0,g_zones[idx].lbl_btm);
   if(InpShowMitigated){ObjectSetInteger(0,g_zones[idx].rect_name,OBJPROP_TIME,1,t);ObjectSetInteger(0,g_zones[idx].rect_name,OBJPROP_COLOR,InpMitColor);ObjectSetInteger(0,g_zones[idx].rect_name,OBJPROP_FILL,false);}
   else ObjectDelete(0,g_zones[idx].rect_name);
}

void UpdateZoneLabelsTime(datetime t){
   for(int i=0;i<g_zone_count;i++) if(g_zones[i].active){
      datetime mid=(datetime)(((long)g_zones[i].start_time+(long)t)/2);
      ObjectMove(0,g_zones[i].lbl_name,0,mid,(g_zones[i].top+g_zones[i].btm)/2.0);
      ObjectMove(0,g_zones[i].lbl_top,0,mid,g_zones[i].top);
      ObjectMove(0,g_zones[i].lbl_btm,0,mid,g_zones[i].btm);
   }
}

double GetPivotHigh(int lb,int shift){
   if(shift+2*lb>=iBars(Symbol(),Period())) return 0;
   double c=iHigh(Symbol(),Period(),shift+lb);
   for(int i=shift;i<=shift+2*lb;i++){if(i==shift+lb) continue;if(iHigh(Symbol(),Period(),i)>=c) return 0;}
   return c;
}
double GetPivotLow(int lb,int shift){
   if(shift+2*lb>=iBars(Symbol(),Period())) return 0;
   double c=iLow(Symbol(),Period(),shift+lb);
   for(int i=shift;i<=shift+2*lb;i++){if(i==shift+lb) continue;if(iLow(Symbol(),Period(),i)<=c) return 0;}
   return c;
}
int FindDemandBase(int shift){for(int i=shift+1;i<=shift+InpOriginLookback;i++) if(iClose(Symbol(),Period(),i)<iOpen(Symbol(),Period(),i)) return i;return -1;}
int FindSupplyBase(int shift){for(int i=shift+1;i<=shift+InpOriginLookback;i++) if(iClose(Symbol(),Period(),i)>iOpen(Symbol(),Period(),i)) return i;return -1;}

void CheckMitigation(int shift){
   double l=iLow(Symbol(),Period(),shift),h=iHigh(Symbol(),Period(),shift);
   datetime bt=iTime(Symbol(),Period(),shift);
   for(int i=g_zone_count-1;i>=0;i--){
      if(!g_zones[i].active||bt<=g_zones[i].start_time) continue;
      bool mit=g_zones[i].is_demand?(l<=g_zones[i].top):(h>=g_zones[i].btm);
      if(mit) MitigateZone(i,bt);
   }
}

void ExecuteAutoTrade(bool isDemand,double zoneTop,double zoneBtm,datetime zoneTime){
   if(g_is_scanning_history) return;
   if(!InpEnableAutoSnD) return;
   if(IsZoneTraded(zoneTime)) return;
   double risk=StringToDouble(ExtPanel.m_edt_risk.Text());
   if(risk<=0) return;
   int digits=(int)SymbolInfoInteger(Symbol(),SYMBOL_DIGITS);
   double pt=SymbolInfoDouble(Symbol(),SYMBOL_POINT);
   double entryPrice=isDemand?zoneTop:zoneBtm;
   double stopLoss=isDemand?(zoneBtm-InpBufferPoints*pt):(zoneTop+InpBufferPoints*pt);
   entryPrice=NormalizeDouble(entryPrice,digits); stopLoss=NormalizeDouble(stopLoss,digits);
   double lot=CalcLotSize(ExtPanel.AdjRisk(),entryPrice,stopLoss,Symbol());
   if(lot<=0) return;
   double mult=StringToDouble(ExtPanel.m_edt_ratio.Text()); if(mult<=0) mult=2.0;
   double diff=MathAbs(entryPrice-stopLoss);
   double tpPrice=isDemand?(entryPrice+diff*mult):(entryPrice-diff*mult);
   tpPrice=NormalizeDouble(tpPrice,digits);
   string comm="SND_AUTO";
   double backupSL=stopLoss;
   if(ExtPanel.m_cl_active){comm="SND_CL_"+DoubleToString(stopLoss,digits);backupSL=isDemand?NormalizeDouble(entryPrice-diff*2.0,digits):NormalizeDouble(entryPrice+diff*2.0,digits);}
   bool result=isDemand?ExtTrade.BuyLimit(lot,entryPrice,Symbol(),backupSL,tpPrice,0,0,comm):ExtTrade.SellLimit(lot,entryPrice,Symbol(),backupSL,tpPrice,0,0,comm);
   if(result){MarkZoneTraded(zoneTime);Print("AutoSnD Executed: ",(isDemand?"BuyLimit":"SellLimit")," Entry:",entryPrice," SL:",stopLoss," TP:",tpPrice);}
}


void ProcessBar(int shift){
   g_old_last_ph=g_last_ph; g_old_last_pl=g_last_pl;
   double ph=GetPivotHigh(InpPivotLB,shift);
   if(ph>0){datetime t=iTime(Symbol(),Period(),shift+InpPivotLB);g_last_ph=ph;g_last_ph_time=t;}
   double pl=GetPivotLow(InpPivotLB,shift);
   if(pl>0){datetime t=iTime(Symbol(),Period(),shift+InpPivotLB);g_last_pl=pl;g_last_pl_time=t;}
   double cls=iClose(Symbol(),Period(),shift);
   bool bull_bos=g_last_ph>0&&cls>g_last_ph&&g_last_ph_time!=g_marked_ph_time;
   bool bear_bos=g_last_pl>0&&cls<g_last_pl&&g_last_pl_time!=g_marked_pl_time;
   if(bull_bos){
      g_marked_ph_time=g_last_ph_time;
      DrawBOS(true,g_last_ph,g_last_ph_time,iTime(Symbol(),Period(),shift));
      
      int base=FindDemandBase(shift);
      if(base!=-1){
         DrawZone(true,iHigh(Symbol(),Period(),base),iLow(Symbol(),Period(),base),iTime(Symbol(),Period(),base));
      }
   }
   if(bear_bos){
      g_marked_pl_time=g_last_pl_time;
      DrawBOS(false,g_last_pl,g_last_pl_time,iTime(Symbol(),Period(),shift));
      
      int base=FindSupplyBase(shift);
      if(base!=-1){
         DrawZone(false,iHigh(Symbol(),Period(),base),iLow(Symbol(),Period(),base),iTime(Symbol(),Period(),base));
      }
   }
   CheckContinuationZone(shift);
   CheckMitigation(shift);
}














//=====================================================================
// [7] SCAN & UTILITY FUNCTIONS
//=====================================================================
void ScanHistory(){
   g_is_scanning_history=true;
   int total=iBars(Symbol(),Period());
   int start=MathMin(InpHistoryBars+InpPivotLB*2+InpOriginLookback,total-2);
   for(int i=start;i>=1;i--) ProcessBar(i);
   g_is_scanning_history=false;
}

void DeleteAllSnDObjects(){
   for(int i=ObjectsTotal()-1;i>=0;i--){
      string n=ObjectName(i);
      if(StringFind(n,"SnD_")==0) ObjectDelete(n);
   }
}


string GetTFString(){
   int p=Period();
   if(p==1)    return "M1";
   if(p==5)    return "M5";
   if(p==15)   return "M15";
   if(p==30)   return "M30";
   if(p==60)   return "H1";
   if(p==240)  return "H4";
   if(p==1440) return "D1";
   if(p==10080)return "W1";
   return "MN";
}

void ExecuteMomentumAutoTrade(bool isBullish, int shift, double customSL=0){
   if(!InpEnableAutoMomentum) return;
   int    digits=(int)SymbolInfoInteger(Symbol(),SYMBOL_DIGITS);
   double pt    =SymbolInfoDouble(Symbol(),SYMBOL_POINT);
   double high  =iHigh(Symbol(),Period(),shift);
   double low   =iLow (Symbol(),Period(),shift);

   double stopLoss;
   if(customSL>0)
      stopLoss=customSL;
   else
      stopLoss=isBullish
               ? NormalizeDouble(low  - InpBufferPoints*pt, digits)
               : NormalizeDouble(high + InpBufferPoints*pt, digits);

   double ask  =MarketInfo(Symbol(),MODE_ASK);
   double bid  =MarketInfo(Symbol(),MODE_BID);
   double entry=isBullish ? ask : bid;

   if(isBullish  && stopLoss>=entry){Print("AutoMomentum: SL BUY tdk valid:",stopLoss," >= entry:",entry); return;}
   if(!isBullish && stopLoss<=entry){Print("AutoMomentum: SL SELL tdk valid:",stopLoss," <= entry:",entry); return;}

   double riskAmount=ExtPanel.AdjRisk();
   if(riskAmount<=0){Print("AutoMomentum: Risk <= 0, cek panel."); return;}

   double lot=CalcLotSize(riskAmount,entry,stopLoss,Symbol());
   if(lot<=0){
      string msg="AutoMomentum: Lot tidak valid ("+DoubleToString(lot,2)+"). Cek Risk Panel atau jarak SL.";
      Print(msg); return;
   }

   double mult=InpMomentumRR>0 ? InpMomentumRR : StringToDouble(ExtPanel.m_edt_ratio.Text());
   if(mult<=0) mult=2.0;
   double diff=MathAbs(entry-stopLoss);
   double tp  =isBullish
               ? NormalizeDouble(entry+diff*mult,digits)
               : NormalizeDouble(entry-diff*mult,digits);

   double hardSL=stopLoss;
   string tfstr=GetTFString();
   string comm ="MOM_AUTO["+tfstr+"]";
   if(ExtPanel.m_cl_active){
      comm  ="MOM_AUTO|RP_CL_"+DoubleToString(stopLoss,digits)+"["+tfstr+"]";
      hardSL=isBullish
             ? NormalizeDouble(entry-diff*2.0,digits)
             : NormalizeDouble(entry+diff*2.0,digits);
   }

   bool result=isBullish
               ? ExtTrade.Buy (lot,Symbol(),entry,hardSL,tp,comm)
               : ExtTrade.Sell(lot,Symbol(),entry,hardSL,tp,comm);

   if(result) Print("MomentumAutoTrade: ",(isBullish?"BUY":"SELL")," Entry:",entry," SL:",hardSL," TP:",tp);
}

bool g_resync_done=false;

int OnInit(){
   ChartSetInteger(0,CHART_FOREGROUND,false);
   if(!ExtPanel.Create(0,"AutoSnD - Risk Panel",0,20,30,305,520)) return INIT_FAILED;
   ExtPanel.Run();
   ScanHistory();
   ScanHistoricalMomentum();
   g_last_processed_bar=iTime(Symbol(),Period(),0);
   Print("AutoSnD EA MT4 v3.00 Ready. Trading:",(InpEnableAutoSnD?"ON":"OFF"));
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason){
   DeleteAllSnDObjects();
   for(int i=ObjectsTotal()-1;i>=0;i--){
      string n=ObjectName(i);
      if(StringFind(n,"MomUp_")==0||StringFind(n,"MomDn_")==0) ObjectDelete(n);
   }
   ExtPanel.Destroy(reason);
}

void OnTick(){
   if(!g_resync_done){InitialHistorySync();g_resync_done=true;}
   PollTradeEvents();
   ExtPanel.UpdateStats();
   CheckCutLoss();
   CheckAutoCloseFriday();
   UpdateZoneLabelsTime(TimeCurrent());
   datetime currentBarTime=iTime(Symbol(),Period(),0);
   ExtPanel.UpdateClock(currentBarTime);
   if(currentBarTime!=g_last_processed_bar){
      ProcessBar(1);
      bool isBullMom=IsBullishMomentum(1);
      bool isBearMom=IsBearishMomentum(1);
       if(isBullMom){
         DrawMomentumArrow(true,1);
         double sl_zone=0;
         if(IsMomentumAfterBase(true,1,sl_zone)) ExecuteMomentumAutoTrade(true,1,sl_zone);
      }
      else if(isBearMom){
         DrawMomentumArrow(false,1);
         double sl_zone=0;
         if(IsMomentumAfterBase(false,1,sl_zone)) ExecuteMomentumAutoTrade(false,1,sl_zone);
      }
      g_last_processed_bar=currentBarTime;
   }
   // Early Signal (N detik sebelum close candle)
   if(InpEarlySignalSeconds>0){
      int sec_left=(int)(currentBarTime+Period()*60-TimeCurrent());
      if(sec_left>0&&sec_left<=InpEarlySignalSeconds){
         if(IsBullishMomentum(0)) DrawMomentumArrow(true,0);
         else if(IsBearishMomentum(0)) DrawMomentumArrow(false,0);
         else{
            ObjectDelete("MomUp_"+TimeToString(currentBarTime));
            ObjectDelete("MomDn_"+TimeToString(currentBarTime));
         }
      }
   }
}

void OnChartEvent(const int id,const long &lp,const double &dp,const string &sp)
   {ExtPanel.ChartEvent(id,lp,dp,sp);}
//+------------------------------------------------------------------+








