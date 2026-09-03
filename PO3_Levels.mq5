//+------------------------------------------------------------------+
//|                                                   PO3_Levels.mq5 |
//|                                                                  |
//|  Draws PO3 (power of three) levels around the current price.     |
//|                                                                  |
//|  Every PO3 number from 3 to 19683 has its own checkbox and its   |
//|  own colour. Tick as many as you like; the chart refreshes on    |
//|  the selection. Width and style follow the magnitude, so the     |
//|  bigger numbers read as the stronger levels:                     |
//|        3, 9, 27          thin, dotted                            |
//|        81, 243           thin, solid                             |
//|        729, 2187         medium, solid                           |
//|        6561, 19683       thick, solid                            |
//|                                                                  |
//|  Levels come from the workbook's "All PO3" sheet, which is       |
//|  multiplier x 3^power for powers 1..15, divided by the scale     |
//|  divisor.                                                        |
//|                                                                  |
//|  Scale 1 gives whole numbers and is the default: gold levels     |
//|  land on 4374, 4455, 4536 and so on, the sheet's raw figures     |
//|  with nothing to divide. Scale 100 gives the workbook's          |
//|  two-decimal gold form (2799.36, 3542.94).                       |
//|                                                                  |
//|  The two agree. A level m x 3^n / 100 is a whole number only     |
//|  when 100 divides m, because 3^n shares no factor with 100, and  |
//|  m = 100k reduces to k x 3^n. So the scale 1 grid IS exactly the |
//|  whole-number subset of the scale 100 grid: choosing whole       |
//|  numbers drops the fractional levels, it does not move any.      |
//|                                                                  |
//|  Powers of three nest: 27 is a multiple of 9, so every 27 level  |
//|  sits exactly on a 9 level. Ticking both would stack duplicate   |
//|  objects on the same price, so a level is drawn ONCE and belongs |
//|  to the HIGHEST ticked PO3 number that lands on it, taking that  |
//|  number's colour and label. That is the sheet's own rule, "The   |
//|  higher the power, stronger the level". Gold at 4374 divides by  |
//|  every number from 3 to 2187, so it is labelled 2187.            |
//|                                                                  |
//|  Verified against the PO3 workbook's Gold sheet, 14 Mar 2025:    |
//|    2187  around 2900 -> 2799.36 .. 3083.67   (row 35, x128..141) |
//|    6561  around 2950 -> 2755.62 .. 3149.28   (row 39, x42..48)   |
//|   19683  around 2950 -> 2755.62 .. 3149.28   (row 40, x14..16)   |
//+------------------------------------------------------------------+
#property copyright "PO3 Levels"
#property version   "1.30"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

input group "Grid";
input double InpScale     = 1.0;   // Scale divisor (1 = whole numbers, 100 = workbook 2dp)
input int    InpEachSide  = 3;     // Levels each side of price
//--- The fine grids sit within a few dollars of price, which is exactly where
//--- the candles are. Drawn behind them they are invisible at the one place
//--- they matter, so the default is in front. Set true for the older look.
input bool   InpLinesBehind = false; // Draw lines behind the candles

input group "Labels";
input bool   InpShowLabels  = true; // Write the PO3 number on each line
input int    InpLabelMinPO3 = 243;  // Label only levels of PO3 >= this
input int    InpFontSize    = 7;    // Label text size
input int    InpLabelShift  = 0;    // Label shift right, in bars (0 = at the last bar)

input group "PO3 levels to show";
input bool  InpUse_3     = false;              // 3      - show
input color InpCol_3     = clrGray;            // 3      - colour
input bool  InpUse_9     = false;              // 9      - show
input color InpCol_9     = clrDarkGray;        // 9      - colour
input bool  InpUse_27    = false;              // 27     - show
input color InpCol_27    = clrCadetBlue;       // 27     - colour
input bool  InpUse_81    = false;              // 81     - show
input color InpCol_81    = clrSteelBlue;       // 81     - colour
input bool  InpUse_243   = true;               // 243    - show
input color InpCol_243   = clrMediumSeaGreen;  // 243    - colour
input bool  InpUse_729   = true;               // 729    - show
input color InpCol_729   = clrDarkOrange;      // 729    - colour
input bool  InpUse_2187  = true;               // 2187   - show
input color InpCol_2187  = clrGoldenrod;       // 2187   - colour
input bool  InpUse_6561  = false;              // 6561   - show
input color InpCol_6561  = clrOrangeRed;       // 6561   - colour
input bool  InpUse_19683 = false;              // 19683  - show
input color InpCol_19683 = clrCrimson;         // 19683  - colour

#define PO3_PREFIX  "PO3_"
#define PO3_COUNT   9

//--- resolved table, built in OnInit, ascending by PO3 number
int             g_po3[PO3_COUNT];
color           g_col[PO3_COUNT];
int             g_wid[PO3_COUNT];
ENUM_LINE_STYLE g_sty[PO3_COUNT];
int             g_n      = 0;
long            g_finest = 0;
int             g_each   = 3;

//--- Rebuild only when price crosses into a new grid cell or a new bar opens,
//--- not on every tick. The new-bar check keeps labels pinned to the right edge.
long     g_anchor   = LONG_MIN;
datetime g_lastTime = 0;
bool     g_dirty    = true;
bool     g_logged   = false;

//+------------------------------------------------------------------+
//| Whole levels print without decimals, so a scale 1 gold level     |
//| reads 4374 rather than 4374.00.                                  |
//+------------------------------------------------------------------+
string PriceText(const double price)
  {
   int dig = (MathAbs(price - MathRound(price)) < 1e-9)
             ? 0 : (int)MathMax(_Digits, 2);
   return(DoubleToString(price, dig));
  }

//+------------------------------------------------------------------+
//| Register one ticked PO3 number. Each checkbox is a distinct      |
//| number, so nothing can collide and no selection can be silently  |
//| dropped the way a free-choice slot could.                        |
//+------------------------------------------------------------------+
void AddPO3(const bool on, const int po3, const color col)
  {
   if(!on || g_n >= PO3_COUNT)
      return;

   g_po3[g_n] = po3;
   g_col[g_n] = col;
   g_wid[g_n] = (po3 >= 6561) ? 3 : (po3 >= 729) ? 2 : 1;
   //--- MT5 renders a non-solid style only at width 1, which is where the
   //--- dotted small grids sit anyway
   g_sty[g_n] = (po3 <= 27) ? STYLE_DOT : STYLE_SOLID;
   g_n++;
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpScale <= 0.0)
     {
      Print("PO3 Levels: scale divisor must be greater than zero.");
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_n = 0;                                  // ascending, so g_po3[0] is finest
   AddPO3(InpUse_3,     3,     InpCol_3);
   AddPO3(InpUse_9,     9,     InpCol_9);
   AddPO3(InpUse_27,    27,    InpCol_27);
   AddPO3(InpUse_81,    81,    InpCol_81);
   AddPO3(InpUse_243,   243,   InpCol_243);
   AddPO3(InpUse_729,   729,   InpCol_729);
   AddPO3(InpUse_2187,  2187,  InpCol_2187);
   AddPO3(InpUse_6561,  6561,  InpCol_6561);
   AddPO3(InpUse_19683, 19683, InpCol_19683);

   if(g_n == 0)
     {
      Print("PO3 Levels: no PO3 number ticked, nothing will be drawn.");
      IndicatorSetString(INDICATOR_SHORTNAME, "PO3 (none ticked)");
      g_dirty = true;
      return(INIT_SUCCEEDED);
     }

   //--- Freeze guard. The clamp alone caps nine ticked grids at 1800 candidate
   //--- levels, which MT5 handles. Deliberately no further trim on top: quietly
   //--- rewriting the count would make the input mean something other than what
   //--- it says, and the warning would sit in a log nobody is watching.
   g_each = (int)MathMax(1, MathMin(100, InpEachSide));

   //--- Powers of three nest, so the finest ticked grid's cell boundaries are a
   //--- superset of every coarser one. Tracking its cell is enough to know when
   //--- any ticked level would move.
   g_finest = g_po3[0];

   string names = "";
   for(int i = 0; i < g_n; i++)
     {
      names += (i > 0 ? " + " : "") + IntegerToString(g_po3[i]);
      PrintFormat("PO3 Levels: active %d of %d = PO3 %d, step %s, %d each side.",
                  i + 1, g_n, g_po3[i],
                  PriceText((double)g_po3[i] / InpScale), g_each);
     }
   IndicatorSetString(INDICATOR_SHORTNAME, "PO3 " + names);

   g_anchor   = LONG_MIN;
   g_lastTime = 0;
   g_dirty    = true;
   g_logged   = false;
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, PO3_PREFIX, -1, -1);
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Draw one level. "raw" is the workbook's own integer, m * 3^n,    |
//| so it doubles as a unique object name and keeps the arithmetic   |
//| exact: the divide happens once, at the end. Accumulating         |
//| m * 21.87 in doubles would drift off the sheet value.            |
//|                                                                  |
//| Deliberately NOT run through NormalizeDouble. The division       |
//| already yields the nearest double to the workbook figure, so     |
//| rounding can only move it away: on a feed quoting _Digits 1,     |
//| NormalizeDouble(5314.41, 1) would put the line at 5314.4.        |
//+------------------------------------------------------------------+
void DrawLevel(const long raw, const int idx, const datetime labelTime)
  {
   double price = (double)raw / InpScale;
   string name  = PO3_PREFIX + IntegerToString(raw);

   //--- a failed create means the object survived the sweep, so fall through
   //    and restyle it rather than leaving it on stale settings
   ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);

   ObjectSetDouble (0, name, OBJPROP_PRICE,      price);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      g_col[idx]);
   ObjectSetInteger(0, name, OBJPROP_STYLE,      g_sty[idx]);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,      g_wid[idx]);
   ObjectSetInteger(0, name, OBJPROP_BACK,       InpLinesBehind);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED,   false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
   ObjectSetString (0, name, OBJPROP_TOOLTIP,
                    StringFormat("%s   %d x %I64d",
                                 PriceText(price),
                                 g_po3[idx], raw / (long)g_po3[idx]));

   //--- Every label shares one time anchor, so labelling the fine grids too
   //--- would pile digits on top of each other: ticking 3 puts levels $3 apart,
   //--- far closer than a line of text is tall. Label the stronger grids only.
   if(!InpShowLabels || g_po3[idx] < InpLabelMinPO3)
      return;

   //--- The label carries the owning PO3 number, so a merged level reads as the
   //--- strongest grid that produced it, matching the colour it was given.
   string tname = PO3_PREFIX + "T" + IntegerToString(raw);

   ObjectCreate(0, tname, OBJ_TEXT, 0, labelTime, price);

   ObjectSetInteger(0, tname, OBJPROP_TIME,       labelTime);
   ObjectSetDouble (0, tname, OBJPROP_PRICE,      price);
   ObjectSetString (0, tname, OBJPROP_TEXT,       IntegerToString(g_po3[idx]));
   ObjectSetInteger(0, tname, OBJPROP_COLOR,      g_col[idx]);
   ObjectSetInteger(0, tname, OBJPROP_FONTSIZE,   (int)MathMax(5, MathMin(20, InpFontSize)));
   //--- anchored right-lower: the text sits just above the line and ends at the
   //    anchor bar, so it stays on screen even with chart shift switched off
   ObjectSetInteger(0, tname, OBJPROP_ANCHOR,     ANCHOR_RIGHT_LOWER);
   ObjectSetInteger(0, tname, OBJPROP_BACK,       false);
   ObjectSetInteger(0, tname, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, tname, OBJPROP_SELECTED,   false);
   ObjectSetInteger(0, tname, OBJPROP_HIDDEN,     true);
  }

//+------------------------------------------------------------------+
//| Collect every ticked grid's window around price, merge levels    |
//| that land on the same price under the highest PO3 number, draw.  |
//+------------------------------------------------------------------+
void Rebuild(const double price, const datetime labelTime)
  {
   ObjectsDeleteAll(0, PO3_PREFIX, -1, -1);

   if(g_n <= 0)
     {
      ChartRedraw();
      return;
     }

   long raws[];
   int  owner[];
   int  cap = g_n * 2 * g_each;
   ArrayResize(raws,  cap);
   ArrayResize(owner, cap);
   int n = 0;

   for(int s = 0; s < g_n; s++)
     {
      long po3 = (long)g_po3[s];

      //--- The epsilon matters. A price sitting exactly on a level, e.g. 2952.45
      //--- with PO3 2187, divides to 134.99999999999997 rather than 135, so a
      //--- bare floor() would anchor one level too low and shift the window down.
      long m0 = (long)MathFloor(price * InpScale / (double)po3 + 1e-9);

      for(long m = m0 - g_each + 1; m <= m0 + g_each; m++)
        {
         if(m <= 0)                     // zero anchor and negatives are not prices
            continue;

         long raw = m * po3;
         int  idx = -1;
         for(int i = 0; i < n; i++)
            if(raws[i] == raw)
              { idx = i; break; }

         if(idx < 0)
           {
            if(n >= cap)
               continue;
            raws[n]  = raw;
            owner[n] = s;
            n++;
           }
         else
            if(g_po3[s] > g_po3[owner[idx]])   // stronger number owns the level
               owner[idx] = s;
        }
     }

   for(int i = 0; i < n; i++)
      DrawLevel(raws[i], owner[i], labelTime);

   //--- Once per load, report what each grid actually contributed after the
   //--- merge. A grid showing 0 was outbid on every level; a grid showing a
   //--- count that you cannot see on the chart is a visibility problem, not a
   //--- selection one. Ctrl+B lists the objects by name to confirm.
   if(!g_logged)
     {
      g_logged = true;
      for(int s = 0; s < g_n; s++)
        {
         int c = 0;
         for(int i = 0; i < n; i++)
            if(owner[i] == s)
               c++;
         PrintFormat("PO3 Levels: PO3 %d drew %d line(s) after merging.",
                     g_po3[s], c);
        }
     }

   ChartRedraw();
  }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(rates_total <= 0 || g_n <= 0)
      return(rates_total);

   ArraySetAsSeries(close, false);      // index 0 = oldest, so the last is current
   ArraySetAsSeries(time,  false);

   double   price = close[rates_total - 1];
   datetime last  = time[rates_total - 1];
   if(price <= 0.0)
      return(rates_total);

   datetime labelTime = last + (datetime)(PeriodSeconds() * InpLabelShift);

   long m0 = (long)MathFloor(price * InpScale / (double)g_finest + 1e-9);

   if(g_dirty || m0 != g_anchor || last != g_lastTime)
     {
      Rebuild(price, labelTime);
      g_anchor   = m0;
      g_lastTime = last;
      g_dirty    = false;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
