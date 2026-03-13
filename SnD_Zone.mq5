//+------------------------------------------------------------------+
//|                                                  SnD_Zones.mq5  |
//|         Supply & Demand + Liquidity Detection (Indicator)        |
//|                                    Copyright 2026, Antigravity   |
//+------------------------------------------------------------------+
#property copyright "Antigravity"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//=====================================================================
// INPUTS
//=====================================================================
input group "--- Supply & Demand Logic ---"
input int    InpPivotLB        = 5;     // Pivot Lookback (bars kiri & kanan)
input int    InpOriginLookback = 50;    // Traceback max candle untuk base
input int    InpHistoryBars    = 600;   // Jumlah bar histori yang discan

input group "--- Display ---"
input bool   InpShowMitigated  = false; // Tampilkan Zona Termitigasi
input bool   InpShowBOS        = true;  // Tampilkan Garis Break of Structure

input group "--- Liquidity Settings ---"
input double InpEQHLThreshold  = 0.1;  // Equal H/L Threshold (%)
input bool   InpShowLiqLabels  = false; // Tampilkan Label Likuiditas (EQH/EQL/IDM/Sweep)
input bool   InpLabelsCompact  = false; // Compact Labels (simbol saja)

input group "--- Probability Filter ---"
input bool   InpOnlyIDMZones   = false; // Hanya tampilkan Zona yang ada IDM

input group "--- Colors ---"
input color  InpDemandColor    = C'0,160,0';   // Warna Zona Demand
input color  InpSupplyColor    = C'190,0,0';   // Warna Zona Supply
input color  InpMitColor       = clrGray;       // Warna Zona Mitigated
input color  InpBOSBull        = clrDodgerBlue; // Warna Bullish BOS
input color  InpBOSBear        = clrOrangeRed;  // Warna Bearish BOS
input color  InpUltraColor     = clrGold;       // Warna Zona Ultra (IDM)

#define COL_EQH    clrTomato
#define COL_EQL    clrLimeGreen
#define COL_IDM    clrAqua
#define COL_SWEEP  clrOrchid

//=====================================================================
// ZONE STRUCT
//=====================================================================
struct ZoneData
  {
   string   rect_name;
   string   lbl_name;
   string   lbl_top;    // label harga garis atas
   string   lbl_btm;    // label harga garis bawah
   bool     is_demand;
   double   top;
   double   btm;
   datetime start_time;
   bool     active;
   bool     has_idm;
   bool     is_ultra;
  };

#define MAX_ZONES    300
#define MAX_LIQ_LVL  10

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

double   g_ph_levels[MAX_LIQ_LVL];
datetime g_ph_times [MAX_LIQ_LVL];
int      g_ph_count = 0;

double   g_pl_levels[MAX_LIQ_LVL];
datetime g_pl_times [MAX_LIQ_LVL];
int      g_pl_count = 0;

//=====================================================================
// HELPERS
//=====================================================================
bool IsNearEQ(double a, double b)
  { if(b==0) return false; return (MathAbs(a-b)/b*100.0) <= InpEQHLThreshold; }

string NextID() { return IntegerToString(++g_obj_id); }

void PushPH(double price, datetime t)
  {
   if(g_ph_count >= MAX_LIQ_LVL)
     { for(int i=0;i<MAX_LIQ_LVL-1;i++){g_ph_levels[i]=g_ph_levels[i+1];g_ph_times[i]=g_ph_times[i+1];} g_ph_count=MAX_LIQ_LVL-1; }
   g_ph_levels[g_ph_count]=price; g_ph_times[g_ph_count]=t; g_ph_count++;
  }

void PushPL(double price, datetime t)
  {
   if(g_pl_count >= MAX_LIQ_LVL)
     { for(int i=0;i<MAX_LIQ_LVL-1;i++){g_pl_levels[i]=g_pl_levels[i+1];g_pl_times[i]=g_pl_times[i+1];} g_pl_count=MAX_LIQ_LVL-1; }
   g_pl_levels[g_pl_count]=price; g_pl_times[g_pl_count]=t; g_pl_count++;
  }

//=====================================================================
// PIVOT DETECTION
//=====================================================================
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

int FindDemandBase(int shift)
  { for(int i=shift+1;i<=shift+InpOriginLookback;i++) if(iClose(_Symbol,_Period,i)<iOpen(_Symbol,_Period,i)) return i; return -1; }

int FindSupplyBase(int shift)
  { for(int i=shift+1;i<=shift+InpOriginLookback;i++) if(iClose(_Symbol,_Period,i)>iOpen(_Symbol,_Period,i)) return i; return -1; }

//=====================================================================
// DRAWING
//=====================================================================
void DrawLiqLabel(string txt_full, string txt_compact, color col, double price, datetime t, bool above)
  {
   if(!InpShowLiqLabels) return;
   string name = "SnD_LL_" + NextID();
   string txt  = InpLabelsCompact ? txt_compact : txt_full;
   if(ObjectCreate(0,name,OBJ_TEXT,0,t,price))
     {
      ObjectSetString(0,name,OBJPROP_TEXT,txt);
      ObjectSetInteger(0,name,OBJPROP_COLOR,col);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
      double off = SymbolInfoDouble(_Symbol,SYMBOL_POINT)*15;
      ObjectMove(0,name,0,t,above?price+off:price-off);
     }
  }

void DrawZone(bool is_demand, double top, double btm, datetime start_time)
  {
   if(g_zone_count >= MAX_ZONES) return;
   bool  hidden  = InpOnlyIDMZones;
   color col_use = hidden ? clrNONE : (is_demand ? InpDemandColor : InpSupplyColor);
   string uid=NextID(), rname="SnD_Z_"+uid, lname="SnD_ZL_"+uid;

   if(ObjectCreate(0,rname,OBJ_RECTANGLE,0,start_time,top,D'2099.12.31',btm))
     {
      if(hidden) { ObjectSetInteger(0,rname,OBJPROP_COLOR,clrGray); ObjectSetInteger(0,rname,OBJPROP_FILL,false); }
      else       { ObjectSetInteger(0,rname,OBJPROP_COLOR,col_use); ObjectSetInteger(0,rname,OBJPROP_FILL,true); }
      ObjectSetInteger(0,rname,OBJPROP_BACK,true); ObjectSetInteger(0,rname,OBJPROP_SELECTABLE,false);
      ObjectSetString(0,rname,OBJPROP_TOOLTIP,(is_demand?"Demand":"Supply")+" | Top:"+DoubleToString(top,_Digits)+" Btm:"+DoubleToString(btm,_Digits));
     }
   if(ObjectCreate(0,lname,OBJ_TEXT,0,start_time,top))
     {
      string lbl = hidden ? "" : (is_demand?" Origin Demand":" Origin Supply");
      ObjectSetString(0,lname,OBJPROP_TEXT,lbl);
      ObjectSetInteger(0,lname,OBJPROP_COLOR,hidden?clrNONE:col_use);
      ObjectSetInteger(0,lname,OBJPROP_FONTSIZE,7); ObjectSetInteger(0,lname,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,lname,OBJPROP_BACK,true);
     }

   // Label harga atas & bawah zona
   string ptop="SnD_PT_"+uid, pbtm="SnD_PB_"+uid;
   color  price_col = hidden ? clrNONE : col_use;
   if(ObjectCreate(0,ptop,OBJ_TEXT,0,start_time,top))
     {
      ObjectSetString(0,ptop,OBJPROP_TEXT," "+DoubleToString(top,_Digits));
      ObjectSetInteger(0,ptop,OBJPROP_COLOR,price_col);
      ObjectSetInteger(0,ptop,OBJPROP_FONTSIZE,8);
      ObjectSetInteger(0,ptop,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0,ptop,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,ptop,OBJPROP_BACK,true);
     }
   if(ObjectCreate(0,pbtm,OBJ_TEXT,0,start_time,btm))
     {
      ObjectSetString(0,pbtm,OBJPROP_TEXT," "+DoubleToString(btm,_Digits));
      ObjectSetInteger(0,pbtm,OBJPROP_COLOR,price_col);
      ObjectSetInteger(0,pbtm,OBJPROP_FONTSIZE,8);
      ObjectSetInteger(0,pbtm,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0,pbtm,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,pbtm,OBJPROP_BACK,true);
     }

   g_zones[g_zone_count].rect_name  = rname;
   g_zones[g_zone_count].lbl_name   = lname;
   g_zones[g_zone_count].lbl_top    = ptop;
   g_zones[g_zone_count].lbl_btm    = pbtm;
   g_zones[g_zone_count].is_demand  = is_demand;
   g_zones[g_zone_count].top        = top;
   g_zones[g_zone_count].btm        = btm;
   g_zones[g_zone_count].start_time = start_time;
   g_zones[g_zone_count].active     = true;
   g_zones[g_zone_count].has_idm    = false;
   g_zones[g_zone_count].is_ultra   = false;
   g_zone_count++;
  }

void UpgradeToUltra(int idx)
  {
   g_zones[idx].has_idm=true; g_zones[idx].is_ultra=true;
   string lbl = g_zones[idx].is_demand?" \xE2\xAD\x90 Origin Demand":" \xE2\xAD\x90 Origin Supply";
   ObjectSetInteger(0,g_zones[idx].rect_name,OBJPROP_COLOR,InpUltraColor); ObjectSetInteger(0,g_zones[idx].rect_name,OBJPROP_FILL,true);
   ObjectSetString(0,g_zones[idx].lbl_name,OBJPROP_TEXT,lbl); ObjectSetInteger(0,g_zones[idx].lbl_name,OBJPROP_COLOR,InpUltraColor);
   ObjectSetInteger(0,g_zones[idx].lbl_top,OBJPROP_COLOR,InpUltraColor);
   ObjectSetInteger(0,g_zones[idx].lbl_btm,OBJPROP_COLOR,InpUltraColor);
  }

void DrawBOS(bool is_bull, double price, datetime x1, datetime x2)
  {
   color col=is_bull?InpBOSBull:InpBOSBear;
   string uid=NextID(),ln="SnD_B_"+uid,lb="SnD_BL_"+uid;
   if(ObjectCreate(0,ln,OBJ_TREND,0,x1,price,x2,price))
     { ObjectSetInteger(0,ln,OBJPROP_COLOR,col); ObjectSetInteger(0,ln,OBJPROP_STYLE,STYLE_DASH); ObjectSetInteger(0,ln,OBJPROP_RAY_RIGHT,false); ObjectSetInteger(0,ln,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,ln,OBJPROP_BACK,true); }
   datetime mid=(datetime)(((long)x1+(long)x2)/2);
   if(ObjectCreate(0,lb,OBJ_TEXT,0,mid,price))
     { ObjectSetString(0,lb,OBJPROP_TEXT,"BOS"); ObjectSetInteger(0,lb,OBJPROP_COLOR,col); ObjectSetInteger(0,lb,OBJPROP_FONTSIZE,8); ObjectSetInteger(0,lb,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,lb,OBJPROP_BACK,true); }
  }

void MitigateZone(int idx, datetime t)
  {
   g_zones[idx].active=false;
   if(InpShowMitigated)
     {
      ObjectSetInteger(0,g_zones[idx].rect_name,OBJPROP_COLOR,InpMitColor); ObjectSetInteger(0,g_zones[idx].rect_name,OBJPROP_FILL,false);
      ObjectMove(0,g_zones[idx].rect_name,1,t,g_zones[idx].btm);
      
      // Sembunyikan semua label (asal/nama, harga atas, harga bawah) jika zona termitigasi
      ObjectDelete(0,g_zones[idx].lbl_name);
      ObjectDelete(0,g_zones[idx].lbl_top);
      ObjectDelete(0,g_zones[idx].lbl_btm);
     }
   else
     {
      ObjectDelete(0,g_zones[idx].rect_name);
      ObjectDelete(0,g_zones[idx].lbl_name);
      ObjectDelete(0,g_zones[idx].lbl_top);
      ObjectDelete(0,g_zones[idx].lbl_btm);
     }
  }

//=====================================================================
// DETECTION LOGIC
//=====================================================================
void UpdateZoneLabelsTime(datetime t)
  {
   for(int i=0;i<g_zone_count;i++)
     {
      if(g_zones[i].active)
        {
         ObjectMove(0,g_zones[i].lbl_top,0,t,g_zones[i].top);
         ObjectMove(0,g_zones[i].lbl_btm,0,t,g_zones[i].btm);
        }
     }
  }

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

void CheckEQHL(bool is_ph, double price, datetime t)
  {
   if(!InpShowLiqLabels) return;
   if(is_ph) { for(int k=g_ph_count-1;k>=MathMax(0,g_ph_count-5);k--) if(IsNearEQ(price,g_ph_levels[k])){DrawLiqLabel("$$ EQH","$$",COL_EQH,price,t,true);break;} }
   else       { for(int k=g_pl_count-1;k>=MathMax(0,g_pl_count-5);k--) if(IsNearEQ(price,g_pl_levels[k])){DrawLiqLabel("$$ EQL","$$",COL_EQL,price,t,false);break;} }
  }

void CheckIDM(bool is_ph, double price, datetime t)
  {
   for(int i=0;i<g_zone_count;i++)
     {
      if(!g_zones[i].active||g_zones[i].has_idm||t<=g_zones[i].start_time) continue;
      if(is_ph&&g_zones[i].is_demand&&price>g_zones[i].top&&g_old_last_ph>0&&price<g_old_last_ph)
        { UpgradeToUltra(i); DrawLiqLabel("IDM","\xE2\x97\x86",COL_IDM,price,t,true); }
      else if(!is_ph&&!g_zones[i].is_demand&&price<g_zones[i].btm&&g_old_last_pl>0&&price>g_old_last_pl)
        { UpgradeToUltra(i); DrawLiqLabel("IDM","\xE2\x97\x86",COL_IDM,price,t,false); }
     }
  }

void CheckSweeps(int shift)
  {
   if(!InpShowLiqLabels) return;
   double h=iHigh(_Symbol,_Period,shift), l=iLow(_Symbol,_Period,shift);
   datetime bt=iTime(_Symbol,_Period,shift);
   for(int k=g_ph_count-1;k>=0;k--)
     if(g_ph_times[k]<bt&&h>g_ph_levels[k])
       { DrawLiqLabel("\xE2\x9C\x97 Swept","\xE2\x9C\x97",COL_SWEEP,h,bt,true); for(int j=k;j<g_ph_count-1;j++){g_ph_levels[j]=g_ph_levels[j+1];g_ph_times[j]=g_ph_times[j+1];} g_ph_count--; break; }
   for(int k=g_pl_count-1;k>=0;k--)
     if(g_pl_times[k]<bt&&l<g_pl_levels[k])
       { DrawLiqLabel("\xE2\x9C\x97 Swept","\xE2\x9C\x97",COL_SWEEP,l,bt,false); for(int j=k;j<g_pl_count-1;j++){g_pl_levels[j]=g_pl_levels[j+1];g_pl_times[j]=g_pl_times[j+1];} g_pl_count--; break; }
  }

//=====================================================================
// CORE: PROCESS ONE BAR
//=====================================================================
void ProcessBar(int shift)
  {
   g_old_last_ph=g_last_ph; g_old_last_pl=g_last_pl;

   double ph=GetPivotHigh(InpPivotLB,shift);
   if(ph>0)
     {
      datetime t=iTime(_Symbol,_Period,shift+InpPivotLB);
      CheckEQHL(true,ph,t); CheckIDM(true,ph,t); PushPH(ph,t);
      g_last_ph=ph; g_last_ph_time=t;
     }

   double pl=GetPivotLow(InpPivotLB,shift);
   if(pl>0)
     {
      datetime t=iTime(_Symbol,_Period,shift+InpPivotLB);
      CheckEQHL(false,pl,t); CheckIDM(false,pl,t); PushPL(pl,t);
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
      if(InpShowBOS) DrawBOS(true,g_last_ph,g_last_ph_time,iTime(_Symbol,_Period,shift));
      int base=FindDemandBase(shift);
      if(base!=-1) DrawZone(true,iHigh(_Symbol,_Period,base),iLow(_Symbol,_Period,base),iTime(_Symbol,_Period,base));
     }

   if(bear_bos)
     {
      g_marked_pl_time=g_last_pl_time;
      if(InpShowBOS) DrawBOS(false,g_last_pl,g_last_pl_time,iTime(_Symbol,_Period,shift));
      int base=FindSupplyBase(shift);
      if(base!=-1) DrawZone(false,iHigh(_Symbol,_Period,base),iLow(_Symbol,_Period,base),iTime(_Symbol,_Period,base));
     }

   CheckSweeps(shift);
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
// INDICATOR EVENT HANDLERS
//=====================================================================
int OnInit()
  {
   ScanHistory();
   ChartRedraw(0);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   DeleteAllSnDObjects();
  }

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double   &open[],
                const double   &high[],
                const double   &low[],
                const double   &close[],
                const long     &tick_volume[],
                const long     &volume[],
                const int      &spread[])
  {
   // Bar baru terbentuk (candle sebelumnya baru tutup)
   if(prev_calculated > 0 && rates_total > prev_calculated)
      ProcessBar(1);

   // Update posisi teks harga ke candle terbaru agar selalu di ujung kanan area
   if(rates_total > 0)
     {
      datetime current_time = time[rates_total - 1]; // waktu candle paling ujung kanan (0 saat array as series)
      // Array time dari OnCalculate tidak berupa 'as series' secara default
      // Indeks rates_total - 1 adalah kebalikan dari as series = elemen paling baru.
      UpdateZoneLabelsTime(current_time);
     }

   return rates_total;
  }
//+------------------------------------------------------------------+
