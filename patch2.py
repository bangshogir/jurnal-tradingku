import re

with open("z.metatrader/AutoSnD_RiskPanel.mq4", "r", encoding="utf-8") as f:
    text = f.read()

# 1. Strip out CheckFiboAndTrade completely
text = re.sub(r'bool CheckFiboAndTrade\(.*?\{.*?(?=\nvoid CheckFVGAndTrade|\nbool CheckFVGAndTrade|\nvoid ProcessBar)', '', text, flags=re.DOTALL)

# 2. Strip out CheckFVGAndTrade completely
text = re.sub(r'bool CheckFVGAndTrade\(.*?\{.*?(?=\nvoid ProcessBar|\nvoid CheckMitigation)', '', text, flags=re.DOTALL)

# 3. Completely rewrite ProcessBar down to CheckMitigation
new_process_bar = """void ProcessBar(int shift){
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
}"""

# Re-write ProcessBar
text = re.sub(r'void ProcessBar\(int shift\)\{.*?(?=\nvoid CheckMitigation)', new_process_bar + "\n", text, flags=re.DOTALL)

with open("z.metatrader/AutoSnD_RiskPanel.mq4", "w", encoding="utf-8") as f:
    f.write(text)

print("ProcessBar and legacy filters patched.")
