import sys

with open("z.metatrader/AutoSnD_RiskPanel.mq4", "r", encoding="utf-8") as f:
    text = f.read()

# 1. Remove Fibo globals
old_fibo_globals = """double   g_fibo_origin_bullish=0, g_fibo_origin_bearish=0;
datetime g_fibo_origin_bull_time=0, g_fibo_origin_bear_time=0;
bool     g_fibo_bull_pending=false, g_fibo_bear_pending=false;
int      g_pending_bull_zone_idx=-1, g_pending_bear_zone_idx=-1;"""
text = text.replace(old_fibo_globals, "")

# 2. Extract out CheckFiboAndTrade and CheckFVGAndTrade
start_marker = "bool CheckFiboAndTrade"
end_marker = "void ProcessBar(int shift){"
if start_marker in text and end_marker in text:
    before = text[:text.find(start_marker)]
    after = text[text.find(end_marker):]
    text = before + "\n" + after

# 3. Clean up ProcessBar internals regarding FVG and Fibo
old_process_bar = """   bool bull_fvg=iLow(Symbol(),Period(),shift)>iHigh(Symbol(),Period(),shift+2);
   bool bear_fvg=iHigh(Symbol(),Period(),shift)<iLow(Symbol(),Period(),shift+2);
   double cls=iClose(Symbol(),Period(),shift);
   bool bull_bos=bull_fvg&&g_last_ph>0&&cls>g_last_ph&&g_last_ph_time!=g_marked_ph_time;
   bool bear_bos=bear_fvg&&g_last_pl>0&&cls<g_last_pl&&g_last_pl_time!=g_marked_pl_time;
   if(bull_bos){
      g_marked_ph_time=g_last_ph_time;
      DrawBOS(true,g_last_ph,g_last_ph_time,iTime(Symbol(),Period(),shift));
      
      int base=FindDemandBase(shift);
      if(base!=-1){
         DrawZone(true,iHigh(Symbol(),Period(),base),iLow(Symbol(),Period(),base),iTime(Symbol(),Period(),base));
         g_pending_bull_zone_idx=g_zone_count-1;
         CheckFVGAndTrade(shift,g_pending_bull_zone_idx);
         
      }
   }
   if(bear_bos){
      g_marked_pl_time=g_last_pl_time;
      DrawBOS(false,g_last_pl,g_last_pl_time,iTime(Symbol(),Period(),shift));
      
      int base=FindSupplyBase(shift);
      if(base!=-1){
         DrawZone(false,iHigh(Symbol(),Period(),base),iLow(Symbol(),Period(),base),iTime(Symbol(),Period(),base));
         g_pending_bear_zone_idx=g_zone_count-1;
         CheckFVGAndTrade(shift,g_pending_bear_zone_idx);
         
      }
   }
   
   if(g_fibo_bull_pending&&ph>0&&g_last_ph_time>g_fibo_origin_bull_time)
      if(CheckFiboAndTrade(g_fibo_origin_bullish,g_last_ph,g_fibo_origin_bull_time,g_pending_bull_zone_idx))
         {g_fibo_bull_pending=false;g_pending_bull_zone_idx=-1;}
   if(g_fibo_bear_pending&&pl>0&&g_last_pl_time>g_fibo_origin_bear_time)
      if(CheckFiboAndTrade(g_last_pl,g_fibo_origin_bearish,g_fibo_origin_bear_time,g_pending_bear_zone_idx))
         {g_fibo_bear_pending=false;g_pending_bear_zone_idx=-1;}
         
   CheckFVGAndTrade(shift,g_pending_bull_zone_idx);
   CheckFVGAndTrade(shift,g_pending_bear_zone_idx);
   CheckContinuationZone(shift);
   CheckMitigation(shift);"""

new_process_bar = """   double cls=iClose(Symbol(),Period(),shift);
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
   CheckMitigation(shift);"""

if old_process_bar in text:
    text = text.replace(old_process_bar, new_process_bar)


# 4. Inject Missing Momentum Functions before CheckCutLoss
momentum_functions = """
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

"""
text = text.replace("bool IsMomentumAfterBase(", momentum_functions + "bool IsMomentumAfterBase(")

with open("z.metatrader/AutoSnD_RiskPanel.mq4", "w", encoding="utf-8") as f:
    f.write(text)

print("Patching complete.")
