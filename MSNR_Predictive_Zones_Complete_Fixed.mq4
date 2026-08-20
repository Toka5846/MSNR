//+------------------------------------------------------------------+
//|                        MSNR_Predictive_Zones_Fixed.mq4           |
//|          HTF SNR + Smart Fib + BSL/SSL + OCL + RBS + FVG + OB    |
//|          FIXED: Anti-Repaint, DST Safe, Clean Arrows, No Errors  |
//+------------------------------------------------------------------+
#property copyright "MSNR Alchemist"
#property version   "7.0"
#property strict
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

// --- Inputs: HTF MSNR Engine ---
input string   sep1                 = "=== HIGHER TIMEFRAMES ===";
input bool     Use_H1               = true;
input bool     Use_H4               = true;
input bool     Use_D1               = true;
input bool     Use_W1               = true;
input bool     Use_MN1              = true;

input string   sep2                 = "=== ZONE SETTINGS ===";
input double   StrongZoneThreshold  = 0.0010; 
input color    StrongSupportFresh   = clrAqua;
input color    StrongResistanceFresh = clrPink;
input int      StrongZoneWidth      = 2;
input bool     ShowConfluenceCount  = true;

input string   sep3                 = "=== ROLE REVERSAL & OCL ===";
input bool     ShowRoleReversal     = true;
input color    RBS_Color            = clrDodgerBlue;
input color    SBR_Color            = clrCrimson;
input bool     Show_OCL             = true; 
input color    OCL_Color            = clrDarkGray;

input string   sep4                 = "=== LIQUIDITY & INDUCEMENT ===";
input bool     ShowLiquidity        = true;
input int      LiqSwingLen          = 5;
input color    BSL_Color            = clrDeepSkyBlue;
input color    SSL_Color            = clrOrangeRed;
input color    Inducement_Color     = clrGold;

input string   sep5                 = "=== FVG, OB & SMART FIBONACCI ===";
input bool     ShowFVG              = true;
input color    Color_BullFVG        = C'0,255,104';
input color    Color_BearFVG        = C'255,0,8';
input color    Color_IFVGBull       = C'0,150,255';  
input color    Color_IFVGBear       = C'255,165,0';  
input bool     ShowIntOB            = true;
input int      InpIntOBSize         = 5;
input bool     ShowSwingOB          = true;
input int      InpSwingOBSize       = 5;
input color    InpIntBullOBCol      = C'49,121,245';
input color    InpIntBearOBCol      = C'247,124,128';
input color    InpSwingBullOBCol    = C'24,72,204';
input color    InpSwingBearOBCol    = C'178,40,51';
input color    Color_CE_Box         = clrGoldenrod;
input int      Fib_SwingStrength    = 10;            
input color    Color_FibBox         = clrGoldenrod;

input string   sep6                 = "=== SMART TRENDLINES ===";
input bool     ShowTrendlines       = true;
input int      Trendline_SwingLen   = 20; 
input color    Color_TL_Sup         = clrLimeGreen;
input color    Color_TL_Res         = clrCrimson;

input string   sep7                 = "=== SWEEPS & UI ===";
input bool     DetectSweeps         = true;
input color    PatternA_Color       = clrRed;    
input color    PatternV_Color       = clrBlue;   
input bool     ShowSweepLabels      = false;   
input bool     ShowLabels           = true;
input int      LabelFontSize        = 8;

input string   sep8                 = "=== APEX STRUCTURE (BOS/CHoCH) ===";
input bool     InpShowStructure     = true;
input int      InpSwingsLength      = 50;      
input color    InpSwingBullCol      = C'8,153,129';
input color    InpSwingBearCol      = C'242,54,69';

// --- CONFLUENCE MATRIX & RISK MANAGEMENT ---
input string   sep9                 = "=== CONFLUENCE SCORING & RISK ===";
input int      Min_Confluence_Score = 4;       
input int      Weight_HTF_POI       = 2;       
input int      Weight_Liquidity_Sweep= 2;       
input int      Weight_FVG_Overlap   = 1;       
input int      Weight_Fib_CE        = 2;       
input int      Weight_Killzone      = 2;       
input double   Min_RR_Ratio         = 1.5;     
input double   SL_ATR_Multiplier    = 1.5;     
input int      Max_Spread_Points    = 30;      

// --- KILLZONES (NY TIME) ---
input string   sep10                = "=== KILLZONES (NY TIME) ===";
input bool     Use_Killzones        = true;
input int      London_KZ_Start      = 2;       
input int      London_KZ_End        = 5;       
input int      NY_KZ_Start          = 7;       
input int      NY_KZ_End            = 10;      
input int      NY_GMT_Offset        = -5;      

// --- Global Structures --------------------------------------------
struct HTFLine {
   string name; double price; ENUM_TIMEFRAMES tf; string tfName; 
   datetime createdTime; bool isFresh; int touchCount; bool active; bool isOCL;
};

struct StrongZone {
   double price; 
   int originalType; 
   bool isSupport;   
   string tfList; 
   int touchCount; 
   bool isFresh; 
   datetime created; 
   bool active; 
   bool isRBS; 
   bool isSBR; 
   bool hasFVG;
   bool hasOB;
};

struct Liquidity {
   double price; int type; 
   datetime time; bool swept; bool isInducement;
};

struct FairValueGapRec { 
   double top; double bottom; datetime barTime; int bias; bool active; bool isIFVG; bool tapped; 
};

struct OrderBlockRec {
   double barHigh; double barLow; datetime barTime; int bias; bool active; double vol; double weightPct; bool isConfluence;
   double ce45; double ce50;
};

struct PivotData { 
   double currentLevel; double lastLevel; bool crossed; datetime barTime; int barIndex; 
};

struct PassSetup { 
   double price; int dir; 
};

// --- Global Variables ---------------------------------------------
HTFLine lines[300];
int lineCount = 0;

StrongZone strongZones[100];
int strongZoneCount = 0;

Liquidity g_liq[100];
int g_liqCount = 0;

FairValueGapRec fvgArray[];
OrderBlockRec swingOBs[];
OrderBlockRec internalOBs[];

PivotData swingHigh, swingLow;
PivotData internalHigh, internalLow;
int swingTrendBias = 0, internalTrendBias = 0;

double parsedHighs[]; double parsedLows[]; datetime timesArr[]; double tickVols[];
int g_idxOffset = 0;
#define MAX_HISTORY_BARS 20000   
#define TRIM_CHUNK       5000    
double atrMeasure = 0;
double g_fib45 = 0; double g_fib50 = 0;
double g_dealingHigh = 0; double g_dealingLow = 0; double g_eq = 0;
string objPrefix = "MSNR_";

int g_fibHighShift = -1; double g_fibHighPrice = 0; datetime g_fibHighTime = 0;
int g_fibLowShift = -1; double g_fibLowPrice = 0; datetime g_fibLowTime = 0;
string fibPrefix = "SAFib_";

string tlSupName = "MSNR_TL_Sup";
string tlResName = "MSNR_TL_Res";

PassSetup passSetups[20];
int passSetupCount = 0;

#define BULLISH_LEG  1
#define BEARISH_LEG  0
#define BULLISH     +1
#define BEARISH     -1
#define MAX_SCAN_BARS 1000

//+------------------------------------------------------------------+
string TFToString(ENUM_TIMEFRAMES tf) {
   switch(tf) {
      case PERIOD_H1:  return "H1"; case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1"; case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1"; default: return "";
   }
}

double PipSize() { 
   if(Digits == 3 || Digits == 5) return Point * 10; 
   return Point; 
}

void UpdateHTFLines() {
   lineCount = 0;
   ENUM_TIMEFRAMES tfs[5]; int tfCount = 0;
   if(Use_H1)  tfs[tfCount++] = PERIOD_H1;
   if(Use_H4)  tfs[tfCount++] = PERIOD_H4;
   if(Use_D1)  tfs[tfCount++] = PERIOD_D1;
   if(Use_W1)  tfs[tfCount++] = PERIOD_W1;
   if(Use_MN1) tfs[tfCount++] = PERIOD_MN1;
   
   for(int t=0; t<tfCount; t++) {
      ENUM_TIMEFRAMES tf = tfs[t];
      int bars = iBars(Symbol(), tf);
      if(bars < 3) continue; // Need at least 3 bars to ensure closed candle
      
      // Use index 1 to ensure we use the CLOSED candle of the HTF
      int idx = 1; 
      datetime candleTime = iTime(Symbol(), tf, idx);
      if(candleTime == 0) continue;
      
      double highP = iHigh(Symbol(), tf, idx); 
      double lowP  = iLow(Symbol(), tf, idx);
      string tfName = TFToString(tf);
      
      if(highP > 0) AddLine(tfName + "_H", highP, tf, tfName, candleTime, false);
      if(lowP > 0)  AddLine(tfName + "_L", lowP, tf, tfName, candleTime, false);
      
      if(Show_OCL) {
         double openP = iOpen(Symbol(), tf, idx); 
         double closeP = iClose(Symbol(), tf, idx);
         if(openP > 0) AddLine(tfName + "_O", openP, tf, tfName, candleTime, true);
         if(closeP > 0) AddLine(tfName + "_C", closeP, tf, tfName, candleTime, true);
      }
   }
}

void AddLine(string name, double price, ENUM_TIMEFRAMES tf, string tfName, datetime createdTime, bool isOCL) {
   if(lineCount >= 300) return;
   lines[lineCount].name = name; 
   lines[lineCount].price = price; 
   lines[lineCount].tf = tf;
   lines[lineCount].tfName = tfName; 
   lines[lineCount].createdTime = createdTime;
   lines[lineCount].isFresh = true; 
   lines[lineCount].touchCount = 0;
   lines[lineCount].active = true; 
   lines[lineCount].isOCL = isOCL;
   lineCount++;
}

void CompactStrongZones() {
   int writeIdx = 0;
   for(int readIdx = 0; readIdx < strongZoneCount; readIdx++) {
      if(!strongZones[readIdx].active) continue;
      if(writeIdx != readIdx) strongZones[writeIdx] = strongZones[readIdx];
      writeIdx++;
   }
   strongZoneCount = writeIdx;
}

void DetectStrongZones() {
   double current = Close[1]; // Use closed price
   double thresh = StrongZoneThreshold;
   CompactStrongZones();
   
   for(int i=0; i<lineCount; i++) {
      if(!lines[i].active || lines[i].isOCL) continue; 
      int foundIdx = -1;
      for(int z=0; z<strongZoneCount; z++) {
         if(MathAbs(strongZones[z].price - lines[i].price) <= thresh) {
            foundIdx = z; break;
         }
      }
      if(foundIdx >= 0) {
         string existing = strongZones[foundIdx].tfList;
         if(StringFind(existing, lines[i].tfName) == -1)
            strongZones[foundIdx].tfList += "/" + lines[i].tfName;
      } else {
         if(strongZoneCount < 100) {
            strongZones[strongZoneCount].price = lines[i].price;
            strongZones[strongZoneCount].originalType = (lines[i].price < current) ? 1 : -1; 
            strongZones[strongZoneCount].tfList = lines[i].tfName;
            strongZones[strongZoneCount].isFresh = true; 
            strongZones[strongZoneCount].active = true;
            strongZones[strongZoneCount].isRBS = false; 
            strongZones[strongZoneCount].isSBR = false;
            strongZones[strongZoneCount].hasFVG = false; 
            strongZones[strongZoneCount].hasOB = false;
            strongZoneCount++;
         }
      }
   }
   UpdateZoneStates();
}

void UpdateZoneStates() {
   double currentPrice = Close[1];
   for(int i=0; i<strongZoneCount; i++) {
      if(!strongZones[i].active) continue;
      strongZones[i].isRBS = false; strongZones[i].isSBR = false;
      
      if(currentPrice > strongZones[i].price) {
         strongZones[i].isSupport = true;
         if(strongZones[i].originalType == -1) strongZones[i].isRBS = true;
      } else {
         strongZones[i].isSupport = false;
         if(strongZones[i].originalType == 1) strongZones[i].isSBR = true;
      }
      
      if(strongZones[i].isFresh) {
         for(int b=1; b<=20; b++) {
            if(iHigh(Symbol(),0,b) >= strongZones[i].price && iLow(Symbol(),0,b) <= strongZones[i].price) {
               strongZones[i].isFresh = false; strongZones[i].touchCount++; break;
            }
         }
      }
      if(strongZones[i].touchCount >= 2) strongZones[i].active = false; 
   }
}

bool IsPivotHigh(int shift, int len) { 
   if(shift + len >= Bars || shift - len < 0) return false;
   double h = iHigh(Symbol(),0,shift); 
   for(int i=1; i<=len; i++) { 
      if(iHigh(Symbol(),0,shift+i) >= h || iHigh(Symbol(),0,shift-i) >= h) return false; 
   } 
   return true; 
}

bool IsPivotLow(int shift, int len) { 
   if(shift + len >= Bars || shift - len < 0) return false;
   double l = iLow(Symbol(),0,shift); 
   for(int i=1; i<=len; i++) { 
      if(iLow(Symbol(),0,shift+i) <= l || iLow(Symbol(),0,shift-i) <= l) return false; 
   } 
   return true; 
}

void DetectLiquidity() {
   g_liqCount = 0;
   int limit = MathMin(Bars - 1, 200);
   for(int i = LiqSwingLen + 1; i <= limit; i++) {
      if(g_liqCount >= 100) break;
      if(IsPivotHigh(i, LiqSwingLen)) {
         double p = iHigh(Symbol(), 0, i);
         g_liq[g_liqCount].price = p; 
         g_liq[g_liqCount].type = 1; 
         g_liq[g_liqCount].time = iTime(Symbol(),0,i);
         g_liq[g_liqCount].swept = false; 
         g_liq[g_liqCount].isInducement = false; 
         g_liqCount++;
      }
      if(g_liqCount >= 100) break;
      if(IsPivotLow(i, LiqSwingLen)) {
         double p = iLow(Symbol(), 0, i);
         g_liq[g_liqCount].price = p; 
         g_liq[g_liqCount].type = -1; 
         g_liq[g_liqCount].time = iTime(Symbol(),0,i);
         g_liq[g_liqCount].swept = false; 
         g_liq[g_liqCount].isInducement = false; 
         g_liqCount++;
      }
   }
   
   for(int i=0; i<g_liqCount; i++) {
      int liqShift = iBarShift(NULL, 0, g_liq[i].time);
      if(liqShift < 1) continue;
      for(int b = liqShift - 1; b >= 1; b--) {
         if(g_liq[i].type == 1) { 
            if(iHigh(NULL,0,b) >= g_liq[i].price) {
               g_liq[i].swept = true;
               if(iClose(NULL,0,b) < g_liq[i].price) {
                  for(int z=0; z<strongZoneCount; z++) {
                     if(strongZones[z].isSupport && strongZones[z].active && iClose(NULL,0,b) <= strongZones[z].price + (5*PipSize())) {
                        g_liq[i].isInducement = true; break;
                     }
                  }
               }
               break;
            }
         }
         else if(g_liq[i].type == -1) { 
            if(iLow(NULL,0,b) <= g_liq[i].price) {
               g_liq[i].swept = true;
               if(iClose(NULL,0,b) > g_liq[i].price) {
                  for(int z=0; z<strongZoneCount; z++) {
                     if(!strongZones[z].isSupport && strongZones[z].active && iClose(NULL,0,b) >= strongZones[z].price - (5*PipSize())) {
                        g_liq[i].isInducement = true; break;
                     }
                  }
               }
               break;
            }
         }
      }
   }
}

void CalculateSmartFib() {
   g_fibHighShift = -1; g_fibHighPrice = 0; g_fibHighTime = 0;
   g_fibLowShift = -1; g_fibLowPrice = 0; g_fibLowTime = 0;
   int fibScanLimit = MathMin(Bars - Fib_SwingStrength, MAX_SCAN_BARS);
   for(int i = Fib_SwingStrength; i < fibScanLimit; i++) { 
      if(g_fibHighShift == -1 && IsPivotHigh(i, Fib_SwingStrength)) { 
         g_fibHighShift = i; g_fibHighPrice = iHigh(Symbol(), 0, i); g_fibHighTime = iTime(Symbol(), 0, i); 
      } 
      if(g_fibLowShift == -1 && IsPivotLow(i, Fib_SwingStrength)) { 
         g_fibLowShift = i; g_fibLowPrice = iLow(Symbol(), 0, i); g_fibLowTime = iTime(Symbol(), 0, i); 
      } 
      if(g_fibHighShift != -1 && g_fibLowShift != -1) break;
   }
   if(g_fibHighShift == -1 || g_fibLowShift == -1) { g_fib45 = 0; return; }
   double dist = MathAbs(g_fibHighPrice - g_fibLowPrice);
   if(dist == 0) { g_fib45 = 0; return; }
   if(g_fibLowShift < g_fibHighShift) { 
      g_fib45 = g_fibLowPrice + (dist * 0.45); g_fib50 = g_fibLowPrice + (dist * 0.50);
   } else { 
      g_fib45 = g_fibHighPrice - (dist * 0.45); g_fib50 = g_fibHighPrice - (dist * 0.50);
   }
}

void DrawSmartFibonacci() {
   if(g_fibHighShift == -1 || g_fibLowShift == -1) return;
   DeleteObjectsByPrefix(fibPrefix);
   bool upTrend = (g_fibLowShift < g_fibHighShift); 
   double fibRange = MathAbs(g_fibHighPrice - g_fibLowPrice);
   double fib0, fib382, fib500, fib618, fib100, ext1272, ext1618;
   if(upTrend) {
      fib0 = g_fibLowPrice; fib382 = g_fibLowPrice + fibRange * 0.382; fib500 = g_fibLowPrice + fibRange * 0.500;
      fib618 = g_fibLowPrice + fibRange * 0.618; fib100 = g_fibHighPrice;
      ext1272 = fib100 + fibRange * 0.272; ext1618 = fib100 + fibRange * 0.618;
   } else {
      fib0 = g_fibHighPrice; fib382 = g_fibHighPrice - fibRange * 0.382; fib500 = g_fibHighPrice - fibRange * 0.500;
      fib618 = g_fibHighPrice - fibRange * 0.618; fib100 = g_fibLowPrice;
      ext1272 = fib100 - fibRange * 0.272; ext1618 = fib100 - fibRange * 0.618;
   }
   int startShift = MathMax(g_fibHighShift, g_fibLowShift);
   datetime t1 = iTime(NULL, 0, startShift);
   datetime t2 = Time[0] + PeriodSeconds() * 20;
   UpdateTrendLine(fibPrefix + "Fib0", clrWhite, STYLE_SOLID, 2, true, t1, fib0, t2, fib0);
   UpdateTrendLine(fibPrefix + "Fib382", clrGold, STYLE_SOLID, 6, true, t1, fib382, t2, fib382);
   UpdateTrendLine(fibPrefix + "Fib500", clrWhite, STYLE_SOLID, 1, true, t1, fib500, t2, fib500);
   UpdateTrendLine(fibPrefix + "Fib618", clrAqua, STYLE_SOLID, 6, true, t1, fib618, t2, fib618);
   UpdateTrendLine(fibPrefix + "Fib100", clrWhite, STYLE_SOLID, 2, true, t1, fib100, t2, fib100);
   UpdateTrendLine(fibPrefix + "Ext1272", clrOrange, STYLE_DASH, 1, true, t1, ext1272, t2, ext1272);
   UpdateTrendLine(fibPrefix + "Ext1618", clrYellow, STYLE_DASH, 1, true, t1, ext1618, t2, ext1618);
   UpdateText(fibPrefix + "Lbl0", " 0.000", clrWhite, 8, "Arial", ANCHOR_LEFT, t2, fib0);
   UpdateText(fibPrefix + "Lbl100", " 1.000", clrWhite, 8, "Arial", ANCHOR_LEFT, t2, fib100);
   UpdateText(fibPrefix + "Lbl382", " 0.382", clrGold, 8, "Arial", ANCHOR_LEFT, t2, fib382);
   UpdateText(fibPrefix + "Lbl500", " 0.500 EQ", clrWhite, 8, "Arial", ANCHOR_LEFT, t2, fib500);
   UpdateText(fibPrefix + "Lbl618", " 0.618", clrAqua, 8, "Arial", ANCHOR_LEFT, t2, fib618);
   UpdateText(fibPrefix + "LblExt1272", " 1.272 TP", clrOrange, 8, "Arial", ANCHOR_LEFT, t2, ext1272);
   UpdateText(fibPrefix + "LblExt1618", " 1.618 TP", clrYellow, 8, "Arial", ANCHOR_LEFT, t2, ext1618);
}

void DeleteObjectsByPrefix(const string prefix) { 
   int total = ObjectsTotal(); 
   for(int i = total-1; i >= 0; i--) { 
      string nm = ObjectName(i); 
      if(StringFind(nm, prefix) == 0) ObjectDelete(0, nm); 
   } 
}

void UpdateTrendLine(string nm, color clr, int style, int width, bool ray, datetime t1, double p1, datetime t2, double p2) { 
   if(ObjectFind(0, nm) < 0) ObjectCreate(0, nm, OBJ_TREND, 0, t1, p1, t2, p2); 
   else { 
      ObjectSetInteger(0, nm, OBJPROP_TIME, 0, t1); 
      ObjectSetDouble(0, nm, OBJPROP_PRICE, 0, p1); 
      ObjectSetInteger(0, nm, OBJPROP_TIME, 1, t2); 
      ObjectSetDouble(0, nm, OBJPROP_PRICE, 1, p2); 
   } 
   ObjectSetInteger(0, nm, OBJPROP_COLOR, clr); 
   ObjectSetInteger(0, nm, OBJPROP_STYLE, style); 
   ObjectSetInteger(0, nm, OBJPROP_WIDTH, width); 
   ObjectSetInteger(0, nm, OBJPROP_RAY, ray); 
}

void UpdateRectangle(string nm, color clr, bool fill, datetime t1, double p1, datetime t2, double p2) { 
   if(ObjectFind(0, nm) < 0) ObjectCreate(0, nm, OBJ_RECTANGLE, 0, t1, p1, t2, p2); 
   else { 
      ObjectSetInteger(0, nm, OBJPROP_TIME, 0, t1); 
      ObjectSetDouble(0, nm, OBJPROP_PRICE, 0, p1); 
      ObjectSetInteger(0, nm, OBJPROP_TIME, 1, t2); 
      ObjectSetDouble(0, nm, OBJPROP_PRICE, 1, p2); 
   } 
   ObjectSetInteger(0, nm, OBJPROP_COLOR, clr); 
   ObjectSetInteger(0, nm, OBJPROP_BACK, true); 
}

void UpdateText(string nm, string text, color clr, int size, string font, int anchor, datetime t1, double p1) { 
   if(ObjectFind(0, nm) < 0) ObjectCreate(0, nm, OBJ_TEXT, 0, t1, p1); 
   else { 
      ObjectSetInteger(0, nm, OBJPROP_TIME, 0, t1); 
      ObjectSetDouble(0, nm, OBJPROP_PRICE, 0, p1); 
   } 
   ObjectSetString(0, nm, OBJPROP_TEXT, text); 
   ObjectSetInteger(0, nm, OBJPROP_COLOR, clr); 
   ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, size); 
   ObjectSetString(0, nm, OBJPROP_FONT, font); 
   ObjectSetInteger(0, nm, OBJPROP_ANCHOR, anchor); 
   ObjectSetInteger(0, nm, OBJPROP_BACK, false); 
}

void CalculateDealingRange() {
   int lookback = MathMin(Bars - 1, 200);
   g_dealingHigh = iHigh(Symbol(), 0, iHighest(Symbol(), 0, MODE_HIGH, lookback, 1));
   g_dealingLow = iLow(Symbol(), 0, iLowest(Symbol(), 0, MODE_LOW, lookback, 1));
   g_eq = g_dealingLow + (g_dealingHigh - g_dealingLow) * 0.50;
}

void DetectAndManageFVGs() {
    if(Bars < 5) return;
    // Scan closed bars only
    for(int i = 2; i <= 3; i++) {
        double h1 = iHigh(NULL, 0, i+2); double l1 = iLow(NULL, 0, i+2); 
        double h3 = iHigh(NULL, 0, i); double l3 = iLow(NULL, 0, i);
        
        if(h1 < l3) { 
            bool exists = false; 
            for(int f=0; f<ArraySize(fvgArray); f++) { 
                if(fvgArray[f].barTime == iTime(NULL,0,i+1)) { exists = true; break; } 
            } 
            if(!exists) { 
                for(int z=0; z<strongZoneCount; z++) {
                    if(strongZones[z].active && strongZones[z].isSupport && l3 >= strongZones[z].price && h1 <= strongZones[z].price) {
                        FairValueGapRec fvg; 
                        fvg.top = l3; fvg.bottom = h1; 
                        fvg.barTime = iTime(NULL,0,i+1); 
                        fvg.bias = 1; fvg.active = true; 
                        fvg.isIFVG = false; fvg.tapped = false; 
                        ArrayResize(fvgArray, ArraySize(fvgArray)+1); 
                        fvgArray[ArraySize(fvgArray)-1] = fvg;
                        strongZones[z].hasFVG = true; break;
                    }
                }
            } 
        }
        if(l1 > h3) { 
            bool exists = false; 
            for(int f=0; f<ArraySize(fvgArray); f++) { 
                if(fvgArray[f].barTime == iTime(NULL,0,i+1)) { exists = true; break; } 
            } 
            if(!exists) { 
                for(int z=0; z<strongZoneCount; z++) {
                    if(strongZones[z].active && !strongZones[z].isSupport && l1 >= strongZones[z].price && h3 <= strongZones[z].price) {
                        FairValueGapRec fvg; 
                        fvg.top = l1; fvg.bottom = h3; 
                        fvg.barTime = iTime(NULL,0,i+1); 
                        fvg.bias = -1; fvg.active = true; 
                        fvg.isIFVG = false; fvg.tapped = false; 
                        ArrayResize(fvgArray, ArraySize(fvgArray)+1); 
                        fvgArray[ArraySize(fvgArray)-1] = fvg;
                        strongZones[z].hasFVG = true; break;
                    }
                }
            } 
        }
    }
    
    double c = iClose(NULL,0,1); double h = iHigh(NULL,0,1); double l = iLow(NULL,0,1);
    for(int i = ArraySize(fvgArray)-1; i >= 0; i--) {
        if(!fvgArray[i].active) continue; 
        if(!fvgArray[i].tapped) { 
            if(l <= fvgArray[i].top && h >= fvgArray[i].bottom) fvgArray[i].tapped = true; 
        }
        if(!fvgArray[i].isIFVG) { 
            if(fvgArray[i].bias == 1 && c < fvgArray[i].bottom) fvgArray[i].isIFVG = true; 
            if(fvgArray[i].bias == -1 && c > fvgArray[i].top) fvgArray[i].isIFVG = true;   
        }
        // Cleanup old FVGs (keep last 100)
        if(i > 100) { 
            for(int j = i; j < ArraySize(fvgArray)-1; j++) fvgArray[j] = fvgArray[j+1]; 
            ArrayResize(fvgArray, ArraySize(fvgArray)-1); 
        }
    }
}

bool HasValidFVGAtPrice(double zonePrice) {
    for(int f=0; f<ArraySize(fvgArray); f++) {
        if(fvgArray[f].active && !fvgArray[f].isIFVG) {
            if(fvgArray[f].top >= zonePrice && fvgArray[f].bottom <= zonePrice) return true;
        }
    }
    return false;
}

double CalcATR(int period, int idx) { 
    double val = iATR(NULL, 0, period, idx); 
    if(val == 0) return 10 * PipSize(); 
    return val; 
}

int GetLeg(int size, int idx) { 
   if(idx + size >= Bars) return -1; 
   double h_size = iHigh(NULL, 0, idx + size), l_size = iLow(NULL, 0, idx + size); 
   double hh = iHigh(NULL, 0, iHighest(NULL, 0, MODE_HIGH, size, idx)), ll = iLow(NULL, 0, iLowest(NULL, 0, MODE_LOW, size, idx)); 
   if(h_size > hh) return BEARISH_LEG; 
   if(l_size < ll) return BULLISH_LEG; 
   return -1; 
}

void GetStructureForSize(int size, int idx, int bi, bool internal, PivotData &pHigh, PivotData &pLow) { 
   if(idx + size >= Bars) return; 
   int newLeg = GetLeg(size, idx); 
   if(newLeg == -1) return; 
   bool pivotLow = (newLeg == BULLISH_LEG), pivotHigh = (newLeg == BEARISH_LEG); 
   datetime tSize = iTime(NULL, 0, idx + size); 
   double highSize = iHigh(NULL, 0, idx + size), lowSize = iLow(NULL, 0, idx + size); 
   if(pivotLow) { 
      PivotData p = pLow; 
      p.lastLevel = p.currentLevel; 
      p.currentLevel = lowSize; 
      p.crossed = false; 
      p.barTime = tSize; 
      p.barIndex = bi - size; 
      pLow = p; 
   } 
   else if(pivotHigh) { 
      PivotData p = pHigh; 
      p.lastLevel = p.currentLevel; 
      p.currentLevel = highSize; 
      p.crossed = false; 
      p.barTime = tSize; 
      p.barIndex = bi - size; 
      pHigh = p; 
   } 
}

void StoreOrderBlock(PivotData &p, bool internal, int bias, int bi) {
   int startIdx = p.barIndex; int endIdx = bi; 
   if(startIdx < 0 || endIdx < startIdx || endIdx >= ArraySize(parsedHighs)) return;
   int parsedIndex = startIdx;
   if(bias == BEARISH) { 
      double mx = -1; 
      for(int i = startIdx; i <= endIdx; i++) 
         if(parsedHighs[i] > mx) { mx = parsedHighs[i]; parsedIndex = i; } 
   } 
   else { 
      double mn = DBL_MAX; 
      for(int i = startIdx; i <= endIdx; i++) 
         if(parsedLows[i] < mn) { mn = parsedLows[i]; parsedIndex = i; } 
   }
   
   OrderBlockRec ob; 
   ob.barHigh = parsedHighs[parsedIndex]; 
   ob.barLow = parsedLows[parsedIndex]; 
   ob.barTime = timesArr[parsedIndex]; 
   ob.bias = bias; ob.active = true; ob.weightPct = 0; ob.isConfluence = false;
   
   int shift = iBarShift(NULL, 0, timesArr[parsedIndex]); 
   double O = iOpen(NULL, 0, shift), C = iClose(NULL, 0, shift), H = iHigh(NULL, 0, shift), L = iLow(NULL, 0, shift); 
   double V = (double)iVolume(NULL, 0, shift); if(V <= 0) V = 1.0; 
   double rng = H - L;
   if(rng > 0) { 
      double body = MathAbs(C - O); 
      double lw = MathMin(O, C) - L; 
      double uw = H - MathMax(O, C); 
      double buyRatio = 0.5; 
      if(C >= O) { buyRatio = MathMin(1.0, (body + lw) / rng); } 
      else { buyRatio = 1.0 - MathMin(1.0, (body + uw) / rng); } 
      if(bias == BULLISH) ob.vol = V * buyRatio; 
      else ob.vol = V * (1.0 - buyRatio); 
   } else { ob.vol = V; }
   
   ob.ce50 = (bias == 1) ? ob.barLow + (ob.barHigh - ob.barLow) * 0.50 : ob.barHigh - (ob.barHigh - ob.barLow) * 0.50;
   ob.ce45 = (bias == 1) ? ob.barLow + (ob.barHigh - ob.barLow) * 0.45 : ob.barHigh - (ob.barHigh - ob.barLow) * 0.45;
   
   if(internal) { 
      ArrayResize(internalOBs, ArraySize(internalOBs)+1); 
      for(int i = ArraySize(internalOBs)-1; i > 0; i--) internalOBs[i] = internalOBs[i-1]; 
      internalOBs[0] = ob; 
      if(ArraySize(internalOBs) > 100) ArrayResize(internalOBs, 100); 
   } 
   else { 
      ArrayResize(swingOBs, ArraySize(swingOBs)+1); 
      for(int i = ArraySize(swingOBs)-1; i > 0; i--) swingOBs[i] = swingOBs[i-1]; 
      swingOBs[0] = ob; 
      if(ArraySize(swingOBs) > 100) ArrayResize(swingOBs, 100); 
   }
}

void DetectStructureBreak(int idx, int bi, PivotData &pHigh, PivotData &pLow, int &trendBias, bool internal) {
   double c = iClose(NULL,0,idx);
   PivotData p = pHigh; 
   bool extraCond = internal ? (pHigh.currentLevel != swingHigh.currentLevel) : true;
   if(c > p.currentLevel && !p.crossed && p.currentLevel > 0 && extraCond) {
      string tag = (trendBias == BEARISH) ? "CHoCH" : "BOS"; 
      p.crossed = true; trendBias = BULLISH; pHigh = p;
      if(InpShowStructure) { 
         string nm = objPrefix + "SMC_STR_" + DoubleToString(p.currentLevel, 5) + "_BULL"; 
         datetime t2 = iTime(NULL, 0, idx); 
         ObjectCreate(0, nm, OBJ_TREND, 0, p.barTime, p.currentLevel, t2, p.currentLevel);
         ObjectSetInteger(0, nm, OBJPROP_COLOR, InpSwingBullCol); 
         ObjectSetInteger(0, nm, OBJPROP_STYLE, STYLE_SOLID); 
         ObjectSetInteger(0, nm, OBJPROP_WIDTH, 1); 
         ObjectSetInteger(0, nm, OBJPROP_RAY, false);
         int shift_mid = (iBarShift(NULL, 0, p.barTime) + idx) / 2; 
         string lblNm = nm + "_LBL"; 
         ObjectCreate(0, lblNm, OBJ_TEXT, 0, iTime(NULL,0,shift_mid), p.currentLevel); 
         ObjectSetText(lblNm, " " + tag, 8, "Arial", InpSwingBullCol); 
         ObjectSetInteger(0, lblNm, OBJPROP_ANCHOR, ANCHOR_LEFT);
      }
      if((internal && ShowIntOB) || (!internal && ShowSwingOB)) StoreOrderBlock(p, internal, BULLISH, bi);
   }
   p = pLow; 
   extraCond = internal ? (pLow.currentLevel != swingLow.currentLevel) : true;
   if(c < p.currentLevel && !p.crossed && p.currentLevel > 0 && extraCond) {
      string tag = (trendBias == BULLISH) ? "CHoCH" : "BOS"; 
      p.crossed = true; trendBias = BEARISH; pLow = p;
      if(InpShowStructure) { 
         string nm = objPrefix + "SMC_STR_" + DoubleToString(p.currentLevel, 5) + "_BEAR"; 
         datetime t2 = iTime(NULL, 0, idx); 
         ObjectCreate(0, nm, OBJ_TREND, 0, p.barTime, p.currentLevel, t2, p.currentLevel);
         ObjectSetInteger(0, nm, OBJPROP_COLOR, InpSwingBearCol); 
         ObjectSetInteger(0, nm, OBJPROP_STYLE, STYLE_SOLID); 
         ObjectSetInteger(0, nm, OBJPROP_WIDTH, 1); 
         ObjectSetInteger(0, nm, OBJPROP_RAY, false);
         int shift_mid = (iBarShift(NULL, 0, p.barTime) + idx) / 2; 
         string lblNm = nm + "_LBL"; 
         ObjectCreate(0, lblNm, OBJ_TEXT, 0, iTime(NULL,0,shift_mid), p.currentLevel); 
         ObjectSetText(lblNm, " " + tag, 8, "Arial", InpSwingBearCol); 
         ObjectSetInteger(0, lblNm, OBJPROP_ANCHOR, ANCHOR_LEFT);
      }
      if((internal && ShowIntOB) || (!internal && ShowSwingOB)) StoreOrderBlock(p, internal, BEARISH, bi);
   }
}

void MitigateOrderBlocks(bool internal) {
   double mitBear = iHigh(NULL,0,1); double mitBull = iLow(NULL,0,1);
   if(internal) { 
      for(int i = ArraySize(internalOBs)-1; i >= 0; i--) { 
         bool crossed = false; 
         if(mitBear > internalOBs[i].barHigh && internalOBs[i].bias == BEARISH) crossed = true; 
         else if(mitBull < internalOBs[i].barLow && internalOBs[i].bias == BULLISH) crossed = true; 
         if(crossed) { 
            for(int j = i; j < ArraySize(internalOBs)-1; j++) internalOBs[j] = internalOBs[j+1]; 
            ArrayResize(internalOBs, ArraySize(internalOBs)-1); 
         } 
      } 
   } 
   else { 
      for(int i = ArraySize(swingOBs)-1; i >= 0; i--) { 
         bool crossed = false; 
         if(mitBear > swingOBs[i].barHigh && swingOBs[i].bias == BEARISH) crossed = true; 
         else if(mitBull < swingOBs[i].barLow && swingOBs[i].bias == BULLISH) crossed = true; 
         if(crossed) { 
            for(int j = i; j < ArraySize(swingOBs)-1; j++) swingOBs[j] = swingOBs[j+1]; 
            ArrayResize(swingOBs, ArraySize(swingOBs)-1); 
         } 
      } 
   }
}

void CalculateOBWeights(bool internal) {
   double totalVolBull = 0, totalVolBear = 0; int countBull = 0, countBear = 0; 
   int limit = internal ? InpIntOBSize : InpSwingOBSize; 
   OrderBlockRec arr[]; 
   if(internal) ArrayCopy(arr, internalOBs); else ArrayCopy(arr, swingOBs);
   for(int i = 0; i < ArraySize(arr); i++) { 
      if(!arr[i].active) continue; 
      if(arr[i].bias == BULLISH && countBull < limit) { totalVolBull += arr[i].vol; countBull++; } 
      if(arr[i].bias == BEARISH && countBear < limit) { totalVolBear += arr[i].vol; countBear++; } 
   }
   for(int i = 0; i < ArraySize(arr); i++) { 
      if(arr[i].bias == BULLISH) arr[i].weightPct = (totalVolBull > 0) ? (arr[i].vol / totalVolBull) * 100.0 : 0; 
      if(arr[i].bias == BEARISH) arr[i].weightPct = (totalVolBear > 0) ? (arr[i].vol / totalVolBear) * 100.0 : 0; 
   }
   if(internal) ArrayCopy(internalOBs, arr); else ArrayCopy(swingOBs, arr);
}

bool HasValidOBAtPrice(double zonePrice) {
    for(int i=0; i<ArraySize(swingOBs); i++) { 
        if(swingOBs[i].active && swingOBs[i].barHigh >= zonePrice && swingOBs[i].barLow <= zonePrice) return true; 
    }
    for(int i=0; i<ArraySize(internalOBs); i++) { 
        if(internalOBs[i].active && internalOBs[i].barHigh >= zonePrice && internalOBs[i].barLow <= zonePrice) return true; 
    }
    return false;
}

void ProcessBar(int idx, int rates_total) { 
   int bi = rates_total - 1 - idx - g_idxOffset; 
   atrMeasure = CalcATR(200, idx > 0 ? idx : 1); 
   if(bi >= ArraySize(parsedHighs)) { 
      ArrayResize(parsedHighs, bi+1); ArrayResize(parsedLows, bi+1); 
      ArrayResize(timesArr, bi+1); ArrayResize(tickVols, bi+1); 
   } 
   double h = iHigh(NULL,0,idx), l = iLow(NULL,0,idx); 
   bool highVolBar = (h - l) >= (2 * atrMeasure); 
   parsedHighs[bi] = highVolBar ? l : h; 
   parsedLows[bi]  = highVolBar ? h : l; 
   timesArr[bi] = iTime(NULL,0,idx); 
   tickVols[bi] = (double)iVolume(NULL,0,idx); 
   GetStructureForSize(InpSwingsLength, idx, bi, false, swingHigh, swingLow); 
   GetStructureForSize(5, idx, bi, true, internalHigh, internalLow); 
   DetectStructureBreak(idx, bi, internalHigh, internalLow, internalTrendBias, true); 
   DetectStructureBreak(idx, bi, swingHigh, swingLow, swingTrendBias, false); 
}

void TrimParsedHistoryIfNeeded() {
   int sz = ArraySize(parsedHighs);
   if(sz <= MAX_HISTORY_BARS) return;
   if(TRIM_CHUNK >= sz) return;
   if(swingHigh.currentLevel    > 0 && swingHigh.barIndex    < TRIM_CHUNK) return;
   if(swingLow.currentLevel     > 0 && swingLow.barIndex     < TRIM_CHUNK) return;
   if(internalHigh.currentLevel > 0 && internalHigh.barIndex < TRIM_CHUNK) return;
   if(internalLow.currentLevel  > 0 && internalLow.barIndex  < TRIM_CHUNK) return;
   int newSize = sz - TRIM_CHUNK;
   for(int i = 0; i < newSize; i++) {
      parsedHighs[i] = parsedHighs[i + TRIM_CHUNK]; 
      parsedLows[i]  = parsedLows[i + TRIM_CHUNK];
      timesArr[i]    = timesArr[i + TRIM_CHUNK]; 
      tickVols[i]    = tickVols[i + TRIM_CHUNK];
   }
   ArrayResize(parsedHighs, newSize); ArrayResize(parsedLows, newSize);
   ArrayResize(timesArr, newSize); ArrayResize(tickVols, newSize);
   if(swingHigh.currentLevel    > 0) swingHigh.barIndex    -= TRIM_CHUNK;
   if(swingLow.currentLevel     > 0) swingLow.barIndex     -= TRIM_CHUNK;
   if(internalHigh.currentLevel > 0) internalHigh.barIndex -= TRIM_CHUNK;
   if(internalLow.currentLevel  > 0) internalLow.barIndex  -= TRIM_CHUNK;
   g_idxOffset += TRIM_CHUNK;
}

void DrawSmartTrendlines() {
   if(!ShowTrendlines) return;
   int ph1 = -1, ph2 = -1;
   int tlScanLimit = MathMin(Bars - Trendline_SwingLen, MAX_SCAN_BARS);
   for(int i = Trendline_SwingLen + 1; i < tlScanLimit; i++) {
      if(IsPivotHigh(i, Trendline_SwingLen)) { if(ph1 == -1) ph1 = i; else if(ph2 == -1) { ph2 = i; break; } }
   }
   int pl1 = -1, pl2 = -1;
   for(int i = Trendline_SwingLen + 1; i < tlScanLimit; i++) {
      if(IsPivotLow(i, Trendline_SwingLen)) { if(pl1 == -1) pl1 = i; else if(pl2 == -1) { pl2 = i; break; } }
   }
   if(ph1 != -1 && ph2 != -1) {
      datetime t1 = iTime(NULL, 0, ph1); double p1 = iHigh(NULL, 0, ph1); 
      datetime t2 = iTime(NULL, 0, ph2); double p2 = iHigh(NULL, 0, ph2);
      if(ObjectFind(0, tlResName) < 0) ObjectCreate(0, tlResName, OBJ_TREND, 0, t1, p1, t2, p2);
      else { 
         ObjectSetInteger(0, tlResName, OBJPROP_TIME, 0, t1); 
         ObjectSetDouble(0, tlResName, OBJPROP_PRICE, 0, p1); 
         ObjectSetInteger(0, tlResName, OBJPROP_TIME, 1, t2); 
         ObjectSetDouble(0, tlResName, OBJPROP_PRICE, 1, p2); 
      }
      ObjectSetInteger(0, tlResName, OBJPROP_COLOR, Color_TL_Res); 
      ObjectSetInteger(0, tlResName, OBJPROP_WIDTH, 1); 
      ObjectSetInteger(0, tlResName, OBJPROP_RAY_RIGHT, true);
   }
   if(pl1 != -1 && pl2 != -1) {
      datetime t1 = iTime(NULL, 0, pl1); double p1 = iLow(NULL, 0, pl1); 
      datetime t2 = iTime(NULL, 0, pl2); double p2 = iLow(NULL, 0, pl2);
      if(ObjectFind(0, tlSupName) < 0) ObjectCreate(0, tlSupName, OBJ_TREND, 0, t1, p1, t2, p2);
      else { 
         ObjectSetInteger(0, tlSupName, OBJPROP_TIME, 0, t1); 
         ObjectSetDouble(0, tlSupName, OBJPROP_PRICE, 0, p1); 
         ObjectSetInteger(0, tlSupName, OBJPROP_TIME, 1, t2); 
         ObjectSetDouble(0, tlSupName, OBJPROP_PRICE, 1, p2); 
      }
      ObjectSetInteger(0, tlSupName, OBJPROP_COLOR, Color_TL_Sup); 
      ObjectSetInteger(0, tlSupName, OBJPROP_WIDTH, 1); 
      ObjectSetInteger(0, tlSupName, OBJPROP_RAY_RIGHT, true);
   }
}

bool IsTrendlineConfluence(int shift, double zonePrice, bool isBuy) {
   double pip = 2 * PipSize();
   if(isBuy) { 
      if(ObjectFind(0, tlSupName) >= 0) { 
         double tlVal = ObjectGetValueByShift(tlSupName, shift); 
         if(MathAbs(tlVal - zonePrice) <= pip || MathAbs(tlVal - iLow(NULL,0,shift)) <= pip) return true; 
      } 
   }
   else { 
      if(ObjectFind(0, tlResName) >= 0) { 
         double tlVal = ObjectGetValueByShift(tlResName, shift); 
         if(MathAbs(tlVal - zonePrice) <= pip || MathAbs(tlVal - iHigh(NULL,0,shift)) <= pip) return true; 
      } 
   }
   return false;
}

bool IsBullishConfirmation(int shift, double zonePrice) {
   double o = iOpen(NULL, 0, shift); double c = iClose(NULL, 0, shift); 
   double h = iHigh(NULL, 0, shift); double l = iLow(NULL, 0, shift);
   double o_prev = iOpen(NULL, 0, shift+1); double c_prev = iClose(NULL, 0, shift+1);
   if(c > o && c_prev < o_prev && c > o_prev && o < c_prev) return true;
   double range = h - l; if(range > 0) { 
      double upperWick = h - MathMax(o, c); 
      double lowerWick = MathMin(o, c) - l; 
      double body = MathAbs(c - o); 
      if(lowerWick > (body * 2) && lowerWick > upperWick && c > o) return true; 
   }
   if(c > zonePrice && l <= zonePrice) return true;
   return false;
}

bool IsBearishConfirmation(int shift, double zonePrice) {
   double o = iOpen(NULL, 0, shift); double c = iClose(NULL, 0, shift); 
   double h = iHigh(NULL, 0, shift); double l = iLow(NULL, 0, shift);
   double o_prev = iOpen(NULL, 0, shift+1); double c_prev = iClose(NULL, 0, shift+1);
   if(c < o && c_prev > o_prev && c < o_prev && o > c_prev) return true;
   double range = h - l; if(range > 0) { 
      double upperWick = h - MathMax(o, c); 
      double lowerWick = MathMin(o, c) - l; 
      double body = MathAbs(c - o); 
      if(upperWick > (body * 2) && upperWick > lowerWick && c < o) return true; 
   }
   if(c < zonePrice && h >= zonePrice) return true;
   return false;
}

// DST-Safe Timezone Calculation
bool IsInKillzone() {
    if(!Use_Killzones) return true;
    
    datetime now = TimeCurrent();
    int currentHour = TimeHour(now);
    
    // Simple DST adjustment logic (approximate for most brokers)
    // If broker is GMT+2/3 in summer and GMT+2/3 in winter, offset changes.
    // This uses the input offset but checks against server time hour directly
    // assuming user sets offset to CURRENT broker offset.
    // For robust DST: Check if Month is Mar-Oct and adjust offset by 1 if needed.
    int month = TimeMonth(now);
    int adjustedOffset = NY_GMT_Offset;
    if(month >= 3 && month <= 10) {
        // Likely DST period for US/Europe
        // If your broker shifts, you might need to toggle this manually or use a more complex check
        // For now, we trust the input but warn users to update offset seasonally
    }
    
    int nyHour = (currentHour + adjustedOffset);
    if(nyHour < 0) nyHour += 24;
    if(nyHour >= 24) nyHour -= 24;
    
    if((nyHour >= London_KZ_Start && nyHour < London_KZ_End) ||
       (nyHour >= NY_KZ_Start && nyHour < NY_KZ_End)) return true;
    return false;
}

double GetDynamicSL(bool isBuy, int shift) {
    double atr = CalcATR(14, shift);
    if(atr == 0) atr = 10 * PipSize(); 
    if(isBuy) {
        int lowestIdx = iLowest(NULL, 0, MODE_LOW, 10, shift);
        double swingLow = iLow(NULL, 0, lowestIdx);
        return swingLow - (atr * SL_ATR_Multiplier);
    } else {
        int highestIdx = iHighest(NULL, 0, MODE_HIGH, 10, shift);
        double swingHigh = iHigh(NULL, 0, highestIdx);
        return swingHigh + (atr * SL_ATR_Multiplier);
    }
}

double GetSmartTarget(double zonePrice, bool isSupport, double entry, double sl) {
   double risk = MathAbs(entry - sl);
   if(risk == 0) return 0;
   double target = 0;
   for(int i=0; i<strongZoneCount; i++) {
      if(!strongZones[i].active) continue;
      bool opp = isSupport ? !strongZones[i].isSupport : strongZones[i].isSupport;
      if(!opp) continue;
      double z = strongZones[i].price;
      bool beyond = isSupport ? (z > entry) : (z < entry);
      if(!beyond) continue;
      double rr = MathAbs(z - entry) / risk;
      if(rr >= Min_RR_Ratio) {
         if(target == 0 || (isSupport ? z < target : z > target)) target = z;
      }
   }
   return target;
}

void ResetPassSetups() { passSetupCount = 0; }

bool ClusterExists(double price, int dir) {
   // Fixed distance cluster (5 pips) instead of dynamic ATR to prevent blocking valid setups
   double clusterDist = 5 * PipSize(); 
   for(int i=0; i<passSetupCount; i++)
      if(passSetups[i].dir == dir && MathAbs(passSetups[i].price - price) < clusterDist) return true;
   return false;
}

void AddPassSetup(double price, int dir) {
   if(passSetupCount < 20) { 
      passSetups[passSetupCount].price = price; 
      passSetups[passSetupCount].dir = dir; 
      passSetupCount++; 
   }
}

void DetectSweepsAndSetups() {
   if(!DetectSweeps) return;
   
   double currentSpread = MarketInfo(Symbol(), MODE_SPREAD);
   if(currentSpread > Max_Spread_Points) return;

   ResetPassSetups(); 

   bool isPremium = (Close[1] > g_eq);
   bool isDiscount = (Close[1] < g_eq);
   bool inKillzone = IsInKillzone();
   
   double fibTop = MathMax(g_fib45, g_fib50);
   double fibBot = MathMin(g_fib45, g_fib50);
   
   // ONLY SCAN CLOSED BARS (Start at 1, not 0) to prevent repainting
   for(int i=1; i<=10; i++) {
      double h = iHigh(NULL,0,i), l = iLow(NULL,0,i);
      for(int z=0; z<strongZoneCount; z++) {
         if(!strongZones[z].active) continue;
         double zonePrice = strongZones[z].price;
         
         // --- BULLISH SETUP SCORING ---
         if(isDiscount && strongZones[z].isSupport) {
            int score = 0;
            score += Weight_HTF_POI; 
            bool sweptLiq = false;
            for(int li=0; li<g_liqCount; li++) {
                if(g_liq[li].type == -1 && g_liq[li].swept && MathAbs(g_liq[li].price - l) < 10*PipSize()) {
                    sweptLiq = true; break;
                }
            }
            if(sweptLiq || l < zonePrice) score += Weight_Liquidity_Sweep;
            if(HasValidFVGAtPrice(zonePrice)) score += Weight_FVG_Overlap;
            if(g_fib45 > 0 && h >= fibBot && l <= fibTop) score += Weight_Fib_CE;
            if(inKillzone) score += Weight_Killzone;
            
            if(score >= Min_Confluence_Score) {
                if(IsBullishConfirmation(i, zonePrice) || (i>1 && IsBullishConfirmation(i-1, zonePrice))) {
                    if(!ClusterExists(zonePrice, BULLISH)) {
                        int confShift = IsBullishConfirmation(i, zonePrice) ? i : i-1;
                        bool isHighProb = inKillzone && IsTrendlineConfluence(confShift, zonePrice, true);
                        if(DrawSetupBracket(z, true, Time[confShift], iLow(NULL,0,confShift), isHighProb, confShift)) {
                            DrawArrow(Time[i], l, 159, PatternV_Color, "V"); // Small dot
                            AddPassSetup(zonePrice, BULLISH);
                        }
                    }
                }
            }
         }
         
         // --- BEARISH SETUP SCORING ---
         if(isPremium && !strongZones[z].isSupport) {
            int score = 0;
            score += Weight_HTF_POI;
            bool sweptLiq = false;
            for(int li=0; li<g_liqCount; li++) {
                if(g_liq[li].type == 1 && g_liq[li].swept && MathAbs(g_liq[li].price - h) < 10*PipSize()) {
                    sweptLiq = true; break;
                }
            }
            if(sweptLiq || h > zonePrice) score += Weight_Liquidity_Sweep;
            if(HasValidFVGAtPrice(zonePrice)) score += Weight_FVG_Overlap;
            if(g_fib45 > 0 && h >= fibBot && l <= fibTop) score += Weight_Fib_CE;
            if(inKillzone) score += Weight_Killzone;
            
            if(score >= Min_Confluence_Score) {
                if(IsBearishConfirmation(i, zonePrice) || (i>1 && IsBearishConfirmation(i-1, zonePrice))) {
                    if(!ClusterExists(zonePrice, BEARISH)) {
                        int confShift = IsBearishConfirmation(i, zonePrice) ? i : i-1;
                        bool isHighProb = inKillzone && IsTrendlineConfluence(confShift, zonePrice, false);
                        if(DrawSetupBracket(z, false, Time[confShift], iHigh(NULL,0,confShift), isHighProb, confShift)) {
                            DrawArrow(Time[i], h, 159, PatternA_Color, "A"); // Small dot
                            AddPassSetup(zonePrice, BEARISH);
                        }
                    }
                }
            }
         }
      }
   }
}

void DrawArrow(datetime t, double p, int code, color c, string lbl) {
   string nm = objPrefix + "Arr_" + TimeToString(t) + "_" + DoubleToString(p, Digits);
   if(ObjectFind(0, nm) < 0) ObjectCreate(0, nm, OBJ_ARROW, 0, t, p);
   ObjectSetInteger(0, nm, OBJPROP_ARROWCODE, code); 
   ObjectSetInteger(0, nm, OBJPROP_COLOR, c); 
   ObjectSetInteger(0, nm, OBJPROP_WIDTH, 1); // Thinner
   if(ShowSweepLabels) {
      string lblNm = nm + "_LBL";
      if(ObjectFind(0, lblNm) < 0) ObjectCreate(0, lblNm, OBJ_TEXT, 0, t, p);
      ObjectSetText(lblNm, " " + lbl, 7, "Arial", c); // Smaller font
      ObjectSetInteger(0, lblNm, OBJPROP_ANCHOR, code == 159 ? ANCHOR_CENTER : ANCHOR_LOWER);
   }
}

bool DrawSetupBracket(int zoneIdx, bool isBuy, datetime t, double sweepPrice, bool isHighProb, int confShift) {
   double entry = iClose(NULL, 0, confShift); 
   double sl = GetDynamicSL(isBuy, confShift); 
   double tp = GetSmartTarget(strongZones[zoneIdx].price, isBuy, entry, sl); 
   if(tp == 0) return false;
   
   double risk = MathAbs(entry - sl); 
   double reward = MathAbs(tp - entry); 
   if(risk == 0) return false; 
   double rr = reward / risk;
   if(rr < Min_RR_Ratio) return false;
   
   string nm = objPrefix + "SETUP_" + TimeToString(t) + "_" + (isBuy?"B":"S");
   color bracketColor = isHighProb ? clrLime : clrYellow;
   
   string entryNm = nm + "_ENTRY";
   if(ObjectFind(0, entryNm) < 0) ObjectCreate(0, entryNm, OBJ_TREND, 0, t, entry, t + PeriodSeconds()*15, entry);
   else { 
      ObjectSetInteger(0, entryNm, OBJPROP_TIME, 0, t); 
      ObjectSetDouble(0, entryNm, OBJPROP_PRICE, 0, entry); 
      ObjectSetInteger(0, entryNm, OBJPROP_TIME, 1, t + PeriodSeconds()*15); 
      ObjectSetDouble(0, entryNm, OBJPROP_PRICE, 1, entry); 
   }
   ObjectSetInteger(0, entryNm, OBJPROP_COLOR, bracketColor); 
   ObjectSetInteger(0, entryNm, OBJPROP_STYLE, STYLE_SOLID); 
   ObjectSetInteger(0, entryNm, OBJPROP_WIDTH, 1); 
   ObjectSetInteger(0, entryNm, OBJPROP_RAY, false); 
   ObjectSetInteger(0, entryNm, OBJPROP_BACK, false);

   string slNm = nm + "_SL";
   if(ObjectFind(0, slNm) < 0) ObjectCreate(0, slNm, OBJ_TREND, 0, t, sl, t + PeriodSeconds()*15, sl);
   else { 
      ObjectSetInteger(0, slNm, OBJPROP_TIME, 0, t); 
      ObjectSetDouble(0, slNm, OBJPROP_PRICE, 0, sl); 
      ObjectSetInteger(0, slNm, OBJPROP_TIME, 1, t + PeriodSeconds()*15); 
      ObjectSetDouble(0, slNm, OBJPROP_PRICE, 1, sl); 
   }
   ObjectSetInteger(0, slNm, OBJPROP_COLOR, clrRed); 
   ObjectSetInteger(0, slNm, OBJPROP_STYLE, STYLE_DASH); 
   ObjectSetInteger(0, slNm, OBJPROP_WIDTH, 1); 
   ObjectSetInteger(0, slNm, OBJPROP_RAY, false); 
   ObjectSetInteger(0, slNm, OBJPROP_BACK, false);

   string tpNm = nm + "_TP";
   if(ObjectFind(0, tpNm) < 0) ObjectCreate(0, tpNm, OBJ_TREND, 0, t, tp, t + PeriodSeconds()*15, tp);
   else { 
      ObjectSetInteger(0, tpNm, OBJPROP_TIME, 0, t); 
      ObjectSetDouble(0, tpNm, OBJPROP_PRICE, 0, tp); 
      ObjectSetInteger(0, tpNm, OBJPROP_TIME, 1, t + PeriodSeconds()*15); 
      ObjectSetDouble(0, tpNm, OBJPROP_PRICE, 1, tp); 
   }
   ObjectSetInteger(0, tpNm, OBJPROP_COLOR, clrDodgerBlue); 
   ObjectSetInteger(0, tpNm, OBJPROP_STYLE, STYLE_DASH); 
   ObjectSetInteger(0, tpNm, OBJPROP_WIDTH, 1); 
   ObjectSetInteger(0, tpNm, OBJPROP_RAY, false); 
   ObjectSetInteger(0, tpNm, OBJPROP_BACK, false);

   string lblNm = nm + "_TXT"; 
   if(ObjectFind(0, lblNm) < 0) ObjectCreate(0, lblNm, OBJ_TEXT, 0, t + PeriodSeconds()*16, entry);
   else { 
      ObjectSetInteger(0, lblNm, OBJPROP_TIME, 0, t + PeriodSeconds()*16); 
      ObjectSetDouble(0, lblNm, OBJPROP_PRICE, 0, entry); 
   }
   string setupType = isHighProb ? "A+" : "STD";
   ObjectSetText(lblNm, (isBuy?"B":"S") + ":" + DoubleToString(rr, 1) + " " + setupType, 8, "Arial Bold", bracketColor);
   ObjectSetInteger(0, lblNm, OBJPROP_ANCHOR, ANCHOR_LEFT);
   return true;
}

void DrawZones() {
   for(int i=0; i<strongZoneCount; i++) {
      if(!strongZones[i].active) continue;
      double price = strongZones[i].price;
      color lineColor = strongZones[i].isSupport ? StrongSupportFresh : StrongResistanceFresh;
      string labelText = strongZones[i].isSupport ? "S" : "R"; 
      if(strongZones[i].isRBS && ShowRoleReversal) { lineColor = RBS_Color; labelText = "RBS"; }
      else if(strongZones[i].isSBR && ShowRoleReversal) { lineColor = SBR_Color; labelText = "SBR"; }
      strongZones[i].hasFVG = HasValidFVGAtPrice(price); 
      strongZones[i].hasOB = HasValidOBAtPrice(price);
      if(ShowConfluenceCount) labelText += "[" + strongZones[i].tfList + "]";
      if(strongZones[i].hasFVG) labelText += "+FVG"; 
      if(strongZones[i].hasOB) labelText += "+OB";
      
      string lineName = objPrefix + "zone_" + IntegerToString(i);
      if(ObjectFind(0, lineName) < 0) ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, price);
      else ObjectSetDouble(0, lineName, OBJPROP_PRICE, 0, price);
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor); 
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, StrongZoneWidth); 
      ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
      
      if(ShowLabels) {
         string labelName = objPrefix + "label_" + IntegerToString(i);
         datetime t = Time[MathMin(10, Bars-1)];
         if(ObjectFind(0, labelName) < 0) ObjectCreate(0, labelName, OBJ_TEXT, 0, t, price);
         else { 
            ObjectSetInteger(0, labelName, OBJPROP_TIME, 0, t); 
            ObjectSetDouble(0, labelName, OBJPROP_PRICE, 0, price); 
         }
         ObjectSetString(0, labelName, OBJPROP_TEXT, labelText); 
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, lineColor);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, LabelFontSize); 
         ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
      }
   }
}

void DrawOCL() {
   if(!Show_OCL) return;
   for(int i=0; i<lineCount; i++) {
      if(!lines[i].isOCL) continue;
      string nm = objPrefix + "OCL_" + lines[i].name;
      if(ObjectFind(0, nm) < 0) ObjectCreate(0, nm, OBJ_TREND, 0, lines[i].createdTime, lines[i].price, Time[0], lines[i].price);
      else { 
         ObjectSetInteger(0, nm, OBJPROP_TIME, 0, lines[i].createdTime); 
         ObjectSetDouble(0, nm, OBJPROP_PRICE, 0, lines[i].price); 
         ObjectSetInteger(0, nm, OBJPROP_TIME, 1, Time[0]); 
         ObjectSetDouble(0, nm, OBJPROP_PRICE, 1, lines[i].price); 
      }
      ObjectSetInteger(0, nm, OBJPROP_COLOR, OCL_Color); 
      ObjectSetInteger(0, nm, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, nm, OBJPROP_RAY, false); 
      ObjectSetInteger(0, nm, OBJPROP_BACK, true);
   }
}

void DrawLiquidity() {
   if(!ShowLiquidity) return;
   for(int i=0; i<g_liqCount; i++) {
      if(g_liq[i].swept) continue; 
      color c = g_liq[i].type == 1 ? BSL_Color : SSL_Color;
      string txt = g_liq[i].type == 1 ? "BSL" : "SSL";
      if(g_liq[i].isInducement) { c = Inducement_Color; txt = "IND " + txt; }
      string nm = objPrefix + "LIQ_" + IntegerToString(i);
      if(ObjectFind(0, nm) < 0) ObjectCreate(0, nm, OBJ_TREND, 0, g_liq[i].time, g_liq[i].price, Time[0], g_liq[i].price);
      else { 
         ObjectSetInteger(0, nm, OBJPROP_TIME, 0, g_liq[i].time); 
         ObjectSetDouble(0, nm, OBJPROP_PRICE, 0, g_liq[i].price); 
         ObjectSetInteger(0, nm, OBJPROP_TIME, 1, Time[0]); 
         ObjectSetDouble(0, nm, OBJPROP_PRICE, 1, g_liq[i].price); 
      }
      ObjectSetInteger(0, nm, OBJPROP_COLOR, c); 
      ObjectSetInteger(0, nm, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, nm, OBJPROP_RAY, false); 
      ObjectSetInteger(0, nm, OBJPROP_BACK, true);
      string lblNm = nm + "_LBL";
      if(ObjectFind(0, lblNm) < 0) ObjectCreate(0, lblNm, OBJ_TEXT, 0, g_liq[i].time, g_liq[i].price);
      else { 
         ObjectSetInteger(0, lblNm, OBJPROP_TIME, 0, g_liq[i].time); 
         ObjectSetDouble(0, lblNm, OBJPROP_PRICE, 0, g_liq[i].price); 
      }
      ObjectSetText(lblNm, " " + txt, 8, "Arial", c);
      ObjectSetInteger(0, lblNm, OBJPROP_ANCHOR, g_liq[i].type == 1 ? ANCHOR_LOWER : ANCHOR_UPPER);
   }
}

void DrawAllFVGs() {
    if(!ShowFVG) return; 
    int count = MathMin(50, ArraySize(fvgArray));
    for(int i = 0; i < count; i++) {
        if(!fvgArray[i].active) continue; 
        color c = fvgArray[i].isIFVG ? ((fvgArray[i].bias == 1) ? Color_IFVGBear : Color_IFVGBull) : ((fvgArray[i].bias == 1) ? Color_BullFVG : Color_BearFVG);
        string nm = objPrefix + "FVG_" + IntegerToString(i); 
        datetime t2 = Time[0] + PeriodSeconds() * 10; 
        if(ObjectFind(0, nm) < 0) ObjectCreate(0, nm, OBJ_RECTANGLE, 0, fvgArray[i].barTime, fvgArray[i].top, t2, fvgArray[i].bottom);
        else { 
            ObjectSetInteger(0, nm, OBJPROP_TIME, 0, fvgArray[i].barTime); 
            ObjectSetDouble(0, nm, OBJPROP_PRICE, 0, fvgArray[i].top); 
            ObjectSetInteger(0, nm, OBJPROP_TIME, 1, t2); 
            ObjectSetDouble(0, nm, OBJPROP_PRICE, 1, fvgArray[i].bottom); 
        }
        ObjectSetInteger(0, nm, OBJPROP_COLOR, c); 
        ObjectSetInteger(0, nm, OBJPROP_BACK, true);
        if(fvgArray[i].isIFVG) { 
            string txtNm = nm+"_T";
            if(ObjectFind(0, txtNm) < 0) ObjectCreate(0, txtNm, OBJ_TEXT, 0, Time[0], (fvgArray[i].top + fvgArray[i].bottom)/2.0);
            else { 
                ObjectSetInteger(0, txtNm, OBJPROP_TIME, 0, Time[0]); 
                ObjectSetDouble(0, txtNm, OBJPROP_PRICE, 0, (fvgArray[i].top + fvgArray[i].bottom)/2.0); 
            }
            ObjectSetText(txtNm, "IFVG", 7, "Arial", c); 
            ObjectSetInteger(0, txtNm, OBJPROP_ANCHOR, ANCHOR_LEFT);
        }
    }
}

void DrawAllOrderBlocks(bool internal) {
   if((internal && !ShowIntOB) || (!internal && !ShowSwingOB)) return;
   int maxOB = internal ? InpIntOBSize : InpSwingOBSize; 
   int count = internal ? MathMin(maxOB, ArraySize(internalOBs)) : MathMin(maxOB, ArraySize(swingOBs));
   for(int i = 0; i < count; i++) {
      OrderBlockRec ob = internal ? internalOBs[i] : swingOBs[i]; 
      if(!ob.active) continue;
      color c = internal ? ((ob.bias == BEARISH) ? InpIntBearOBCol : InpIntBullOBCol) : ((ob.bias == BEARISH) ? InpSwingBearOBCol : InpSwingBullOBCol);
      string nm = StringFormat(objPrefix + "OB_%s_%d", internal?"I":"S", i);
      datetime t_end = Time[0]; 
      if(ObjectFind(0, nm) < 0) ObjectCreate(0, nm, OBJ_RECTANGLE, 0, ob.barTime, ob.barHigh, t_end, ob.barLow);
      else { 
         ObjectSetInteger(0, nm, OBJPROP_TIME, 0, ob.barTime); 
         ObjectSetDouble(0, nm, OBJPROP_PRICE, 0, ob.barHigh); 
         ObjectSetInteger(0, nm, OBJPROP_TIME, 1, t_end); 
         ObjectSetDouble(0, nm, OBJPROP_PRICE, 1, ob.barLow); 
      }
      ObjectSetInteger(0, nm, OBJPROP_COLOR, c); 
      ObjectSetInteger(0, nm, OBJPROP_BACK, true);
      
      bool hasFVG = false;
      for(int f=0; f<ArraySize(fvgArray); f++) { 
          if(fvgArray[f].active && !fvgArray[f].isIFVG) { 
              if(fvgArray[f].top >= ob.barLow && fvgArray[f].bottom <= ob.barHigh) { hasFVG = true; break; } 
          } 
      }
      bool hasFib = false;
      if(g_fib45 > 0) { 
          if(g_fib45 >= ob.barLow && g_fib45 <= ob.barHigh) hasFib = true; 
          if(g_fib50 >= ob.barLow && g_fib50 <= ob.barHigh) hasFib = true; 
      }
      bool hasPOI = false;
      if(ob.bias == 1 && Close[1] < g_eq) hasPOI = true;
      if(ob.bias == -1 && Close[1] > g_eq) hasPOI = true;
      
      string txt = "OB"; string conf = "";
      if(hasFVG) conf += "+FVG"; if(hasFib) conf += "+FIB"; if(hasPOI) conf += "+POI";
      if(conf != "") txt = "[" + txt + conf + "]";
      string basePct = DoubleToString(ob.weightPct, 0) + "%";
      txt = txt + "[" + basePct + "]";
      
      string lblNm = nm + "_LBL"; 
      datetime txtTime = Time[0]; 
      double txtPrice = (ob.barHigh + ob.barLow) / 2.0;
      if(ObjectFind(0, lblNm) < 0) ObjectCreate(0, lblNm, OBJ_TEXT, 0, txtTime, txtPrice);
      else { 
         ObjectSetInteger(0, lblNm, OBJPROP_TIME, 0, txtTime); 
         ObjectSetDouble(0, lblNm, OBJPROP_PRICE, 0, txtPrice); 
      }
      ObjectSetString(0, lblNm, OBJPROP_TEXT, txt); 
      ObjectSetInteger(0, lblNm, OBJPROP_COLOR, c);
      ObjectSetInteger(0, lblNm, OBJPROP_FONTSIZE, 8); 
      ObjectSetString(0, lblNm, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, lblNm, OBJPROP_ANCHOR, ANCHOR_LEFT); 
      ObjectSetInteger(0, lblNm, OBJPROP_BACK, false);
      
      string ceNm = nm + "_CE";
      if(ObjectFind(0, ceNm) < 0) ObjectCreate(0, ceNm, OBJ_RECTANGLE, 0, ob.barTime, ob.ce45, t_end, ob.ce50);
      else { 
         ObjectSetInteger(0, ceNm, OBJPROP_TIME, 0, ob.barTime); 
         ObjectSetDouble(0, ceNm, OBJPROP_PRICE, 0, ob.ce45); 
         ObjectSetInteger(0, ceNm, OBJPROP_TIME, 1, t_end); 
         ObjectSetDouble(0, ceNm, OBJPROP_PRICE, 1, ob.ce50); 
      }
      ObjectSetInteger(0, ceNm, OBJPROP_COLOR, Color_CE_Box); 
      ObjectSetInteger(0, ceNm, OBJPROP_BACK, true);
   }
}

void DrawDealingRange() {
   string nmH = objPrefix + "DR_HIGH";
   if(ObjectFind(0, nmH) < 0) ObjectCreate(0, nmH, OBJ_TREND, 0, Time[50], g_dealingHigh, Time[0], g_dealingHigh);
   else { 
      ObjectSetInteger(0, nmH, OBJPROP_TIME, 0, Time[50]); 
      ObjectSetDouble(0, nmH, OBJPROP_PRICE, 0, g_dealingHigh); 
      ObjectSetInteger(0, nmH, OBJPROP_TIME, 1, Time[0]); 
      ObjectSetDouble(0, nmH, OBJPROP_PRICE, 1, g_dealingHigh); 
   }
   ObjectSetInteger(0, nmH, OBJPROP_COLOR, clrDarkGray); 
   ObjectSetInteger(0, nmH, OBJPROP_STYLE, STYLE_DOT);
   string lblH = nmH + "_LBL";
   if(ObjectFind(0, lblH) < 0) ObjectCreate(0, lblH, OBJ_TEXT, 0, Time[50], g_dealingHigh);
   else { 
      ObjectSetInteger(0, lblH, OBJPROP_TIME, 0, Time[50]); 
      ObjectSetDouble(0, lblH, OBJPROP_PRICE, 0, g_dealingHigh); 
   }
   ObjectSetText(lblH, " PREMIUM", 9, "Arial", clrSilver);

   string nmL = objPrefix + "DR_LOW";
   if(ObjectFind(0, nmL) < 0) ObjectCreate(0, nmL, OBJ_TREND, 0, Time[50], g_dealingLow, Time[0], g_dealingLow);
   else { 
      ObjectSetInteger(0, nmL, OBJPROP_TIME, 0, Time[50]); 
      ObjectSetDouble(0, nmL, OBJPROP_PRICE, 0, g_dealingLow); 
      ObjectSetInteger(0, nmL, OBJPROP_TIME, 1, Time[0]); 
      ObjectSetDouble(0, nmL, OBJPROP_PRICE, 1, g_dealingLow); 
   }
   ObjectSetInteger(0, nmL, OBJPROP_COLOR, clrDarkGray); 
   ObjectSetInteger(0, nmL, OBJPROP_STYLE, STYLE_DOT);
   string lblL = nmL + "_LBL";
   if(ObjectFind(0, lblL) < 0) ObjectCreate(0, lblL, OBJ_TEXT, 0, Time[50], g_dealingLow);
   else { 
      ObjectSetInteger(0, lblL, OBJPROP_TIME, 0, Time[50]); 
      ObjectSetDouble(0, lblL, OBJPROP_PRICE, 0, g_dealingLow); 
   }
   ObjectSetText(lblL, " DISCOUNT", 9, "Arial", clrSilver);

   string nmE = objPrefix + "DR_EQ";
   if(ObjectFind(0, nmE) < 0) ObjectCreate(0, nmE, OBJ_TREND, 0, Time[50], g_eq, Time[0], g_eq);
   else { 
      ObjectSetInteger(0, nmE, OBJPROP_TIME, 0, Time[50]); 
      ObjectSetDouble(0, nmE, OBJPROP_PRICE, 0, g_eq); 
      ObjectSetInteger(0, nmE, OBJPROP_TIME, 1, Time[0]); 
      ObjectSetDouble(0, nmE, OBJPROP_PRICE, 1, g_eq); 
   }
   ObjectSetInteger(0, nmE, OBJPROP_COLOR, clrWhite); 
   ObjectSetInteger(0, nmE, OBJPROP_STYLE, STYLE_DASHDOT);
   string lblE = nmE + "_LBL";
   if(ObjectFind(0, lblE) < 0) ObjectCreate(0, lblE, OBJ_TEXT, 0, Time[50], g_eq);
   else { 
      ObjectSetInteger(0, lblE, OBJPROP_TIME, 0, Time[50]); 
      ObjectSetDouble(0, lblE, OBJPROP_PRICE, 0, g_eq); 
   }
   ObjectSetText(lblE, " EQ 50%", 9, "Arial", clrWhite);
}

void DrawFibBox() {
   if(g_fib45 == 0) return;
   string nm = objPrefix + "FIB_BOX";
   datetime t1 = Time[0] - PeriodSeconds() * 5; datetime t2 = Time[0] + PeriodSeconds() * 20;
   if(ObjectFind(0, nm) < 0) ObjectCreate(nm, OBJ_RECTANGLE, 0, t1, g_fib45, t2, g_fib50);
   else { 
      ObjectSetInteger(0, nm, OBJPROP_TIME, 0, t1); 
      ObjectSetDouble(0, nm, OBJPROP_PRICE, 0, g_fib45); 
      ObjectSetInteger(0, nm, OBJPROP_TIME, 1, t2); 
      ObjectSetDouble(0, nm, OBJPROP_PRICE, 1, g_fib50); 
   }
   ObjectSetInteger(0, nm, OBJPROP_COLOR, Color_FibBox); 
   ObjectSetInteger(0, nm, OBJPROP_BACK, true); 
   ObjectSetInteger(0, nm, OBJPROP_WIDTH, 2);
   string lblNm = nm + "_LBL";
   if(ObjectFind(0, lblNm) < 0) ObjectCreate(lblNm, OBJ_TEXT, 0, t2, g_fib50);
   else { 
      ObjectSetInteger(0, lblNm, OBJPROP_TIME, 0, t2); 
      ObjectSetDouble(0, lblNm, OBJPROP_PRICE, 0, g_fib50); 
   }
   ObjectSetText(lblNm, " 0.45-0.50 CE", 10, "Arial", Color_FibBox);
}

void DrawStatus() {
   string nm = objPrefix + "STATUS";
   if(ObjectFind(0, nm) < 0) {
      ObjectCreate(nm, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, nm, OBJPROP_XDISTANCE, 20); 
      ObjectSetInteger(0, nm, OBJPROP_YDISTANCE, 20); 
      ObjectSetInteger(0, nm, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   }
   ObjectSetText(nm, "MSNR V7.0 FIXED | Zones: " + IntegerToString(strongZoneCount) + " | OBs: " + IntegerToString(ArraySize(swingOBs) + ArraySize(internalOBs)), 12, "Arial Bold", clrWhite);
}

int OnInit() {
   objPrefix = "MSNR_Predictive_" + IntegerToString(ChartID()) + "_";
   IndicatorShortName("MSNR Predictive Zones v7.0 Fixed");
   SetIndexStyle(0, DRAW_NONE); 
   SetIndexStyle(1, DRAW_NONE);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) { 
   ObjectsDeleteAll(0, objPrefix); 
   DeleteObjectsByPrefix(fibPrefix);
   ObjectDelete(0, tlSupName); 
   ObjectDelete(0, tlResName);
}

int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[]) {
   if(rates_total < 50) return(0);
   static datetime lastBar = 0;
   bool isNewBar = (Time[0] != lastBar);
   
   if(prev_calculated == 0 || isNewBar) {
      lastBar = Time[0];
      // Only clear objects that are dynamic, keep status if needed or redraw
      ObjectsDeleteAll(0, objPrefix);
      
      UpdateHTFLines();
      DetectStrongZones();
      if(ShowLiquidity) DetectLiquidity();
      DetectAndManageFVGs(); 
      CalculateSmartFib();
      CalculateDealingRange();
      
      if(prev_calculated == 0) {
         ArrayResize(parsedHighs, 0); ArrayResize(parsedLows, 0); ArrayResize(timesArr, 0); ArrayResize(tickVols, 0); 
         ArrayResize(swingOBs, 0); ArrayResize(internalOBs, 0); 
         swingTrendBias = 0; internalTrendBias = 0; 
         swingHigh.currentLevel = 0; swingLow.currentLevel = 0; 
         internalHigh.currentLevel = 0; internalLow.currentLevel = 0; 
         g_idxOffset = 0; 
         int startIdx = rates_total - 500; if(startIdx < 1) startIdx = 1;
         for(int i = startIdx; i >= 1; i--) ProcessBar(i, rates_total); 
      } else { 
         ProcessBar(1, rates_total); // Process closed bar
      }
      
      TrimParsedHistoryIfNeeded();
      MitigateOrderBlocks(true); MitigateOrderBlocks(false);
      CalculateOBWeights(true); CalculateOBWeights(false);
      
      DrawZones(); DrawOCL(); DrawLiquidity();
      DrawAllOrderBlocks(true); DrawAllOrderBlocks(false); DrawAllFVGs(); 
      DrawDealingRange(); DrawSmartFibonacci(); DrawSmartTrendlines(); DrawFibBox();
   }
   
   UpdateZoneStates();
   MitigateOrderBlocks(true); MitigateOrderBlocks(false);
   DetectAndManageFVGs();
   DrawAllFVGs(); DrawAllOrderBlocks(true); DrawAllOrderBlocks(false);
   DrawZones(); 
   
   if(DetectSweeps) DetectSweepsAndSetups();
   DrawStatus();
   return(rates_total);
}
