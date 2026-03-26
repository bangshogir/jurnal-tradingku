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

input group "--- Probability Filter ---"
input color  InpDemandColor    = C'0,160,0';   // Warna Zona Demand
input color  InpSupplyColor    = C'190,0,0';   // Warna Zona Supply
input color  InpMitColor       = clrGray;       // Warna Zona Mitigated
input color  InpBOSBull        = clrDodgerBlue; // Warna Bullish BOS
input color  InpBOSBear        = clrOrangeRed;  // Warna Bearish BOS

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

//=====================================================================
// HELPERS
//=====================================================================
string NextID() { return IntegerToString(++g_obj_id); }

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
void DrawZone(bool is_demand, double top, double btm, datetime start_time)
  {
   if(g_zone_count >= MAX_ZONES) return;
   color col_use = is_demand ? InpDemandColor : InpSupplyColor;
   string uid=NextID(), rname="SnD_Z_"+uid, lname="SnD_ZL_"+uid;

   if(ObjectCreate(0,rname,OBJ_RECTANGLE,0,start_time,top,D'2099.12.31',btm))
     {
      ObjectSetInteger(0,rname,OBJPROP_COLOR,col_use); ObjectSetInteger(0,rname,OBJPROP_FILL,true);
      ObjectSetInteger(0,rname,OBJPROP_BACK,true); ObjectSetInteger(0,rname,OBJPROP_SELECTABLE,false);
      ObjectSetString(0,rname,OBJPROP_TOOLTIP,(is_demand?"Demand":"Supply")+" | Top:"+DoubleToString(top,_Digits)+" Btm:"+DoubleToString(btm,_Digits));
     }
   if(ObjectCreate(0,lname,OBJ_TEXT,0,start_time,top))
     {
      string lbl = is_demand?" Origin Demand":" Origin Supply";
      ObjectSetString(0,lname,OBJPROP_TEXT,lbl);
      ObjectSetInteger(0,lname,OBJPROP_COLOR,col_use);
      ObjectSetInteger(0,lname,OBJPROP_FONTSIZE,7); ObjectSetInteger(0,lname,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,lname,OBJPROP_BACK,true);
     }

   // Label harga atas & bawah zona
   string ptop="SnD_PT_"+uid, pbtm="SnD_PB_"+uid;
   color  price_col = col_use;
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
   g_zones[g_zone_count].active     = true;
   g_zone_count++;
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

      if(mit) MitigateZone(i,bt);
     }
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
