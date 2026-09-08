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
//|  It also counts candles from the market open and marks the kihon |
//|  suchi numbers on that count - time levels the way the grid is   |
//|  price levels. The numbers, and why each one is what it is, live |
//|  in PO3_Kihon.mqh. The panel counts the same open on H1, M30,    |
//|  M15, M5 and M1 at once, so the timeframes can be read against   |
//|  each other. Nothing here acts on those numbers; they mark where |
//|  a turn is due, not that one is happening.                       |
//|                                                                  |
//|  Verified against the PO3 workbook's Gold sheet, 14 Mar 2025:    |
//|    2187  around 2900 -> 2799.36 .. 3083.67   (row 35, x128..141) |
//|    6561  around 2950 -> 2755.62 .. 3149.28   (row 39, x42..48)   |
//|   19683  around 2950 -> 2755.62 .. 3149.28   (row 40, x14..16)   |
//+------------------------------------------------------------------+
#property copyright "PO3 Levels"
#property version   "1.33"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- Quoted, not angled: MetaEditor resolves this against the folder holding
//--- this file, so PO3_Kihon.mqh sits beside the indicator and there is no
//--- separate Include folder step to forget.
#include "PO3_Kihon.mqh"

input group "Grid";
input double InpScale     = 1.0;   // Scale divisor (1 = whole numbers, 100 = workbook 2dp)
input int    InpEachSide  = 3;     // Levels each side of price
//--- The fine grids sit within a few dollars of price, which is exactly where
//--- the candles are. Drawn behind them they are invisible at the one place
//--- they matter, so the default is in front. Set true for the older look.
input bool   InpLinesBehind = false; // Draw lines behind the candles

input group "Labels";
input bool   InpShowLabels  = true; // Write the PO3 number on each line
input int    InpLabelMinPO3 = 3;    // Label only levels of PO3 >= this
input int    InpFontSize    = 7;    // Label text size
input int    InpLabelShift  = 0;    // Label shift right, in bars (0 = at the last bar)

input group "Candle countdown";
//--- The countdown rides the developing candle rather than sitting in a corner,
//--- so the time left is read in the same glance as the candle it belongs to.
//--- It is anchored to that candle's time and to the current price, so it
//--- travels with both. See UpdateClock.
input bool   InpShowClock   = true;         // Show time left on the current candle
input int    InpClockShift  = 1;            // Bars right of the developing candle (0 = beside it)
input int    InpClockGapPts = 0;            // Vertical offset from price, in points (+ up)
input int    InpClockSize   = 8;            // Text size
input color  InpClockColor  = clrLime;      // Text colour

input group "Session timer";
//--- Wall-clock time this chart has been open, for capping screen time. It
//--- starts when the indicator loads and survives a timeframe or input change;
//--- only reloading the indicator or the chart resets it. See OnInit / OnDeinit.
input bool             InpShowSession    = true;                 // Show time spent on this chart
input ENUM_BASE_CORNER InpSessionCorner  = CORNER_RIGHT_UPPER;   // Corner
input int              InpSessionX       = 12;                   // Distance from corner, X
input int              InpSessionY       = 40;                   // Distance from corner, Y
input int              InpSessionSize    = 10;                   // Text size
input color            InpSessionColor   = clrSilver;            // Text colour
input int              InpSessionLimitMin = 0;                   // Minutes on chart before it turns red (0 = off)
input color            InpSessionOverColor = clrTomato;          // Text colour once over the limit

input group "Candle count";
//--- Ichimoku's counting rule, not a zero-based index: the candle the count
//--- starts on is candle 1, so a 26 count spans 26 candles inclusive. That is
//--- what makes the compound numbers overlap by one. See PO3_Kihon.mqh.
//---
//--- The anchor set here feeds both the on-chart marks and the panel, so the
//--- two can never disagree about where the count started. Each has its own
//--- show/hide switch below.
input bool              InpShowCount   = true;              // Draw the count on the chart
input ENUM_KIHON_ANCHOR InpCountAnchor = KIHON_ANCHOR_DAY;  // Count from
input int               InpAnchorHour  = 8;                 // Custom anchor, hour (server)
input int               InpAnchorMin   = 0;                 // Custom anchor, minute (server)
input bool              InpMarkOpen    = true;              // Line on the candle the count starts at
input color             InpOpenColor   = clrDimGray;        // Open line colour

input group "Kihon suchi";
//--- The numbers are time levels the way the PO3 grid is price levels. Marked
//--- on the chart timeframe only; the panel below carries the rest.
input bool  InpMarkKihon     = true;             // Mark the kihon suchi candles
input bool  InpKihonCompound = true;             // Include the compound numbers (33 and up)
input bool  InpKihonLines    = true;             // Vertical line on each marked candle
input color InpKihonSimple   = clrDeepSkyBlue;   // 9, 17, 26      - colour
input color InpKihonComp     = clrMediumOrchid;  // 33 and up      - colour
input int   InpKihonSize     = 8;                // Marker text size
input int   InpKihonGapPts   = 0;                // Marker offset from the candle low, in points
input bool  InpNumberAll     = false;            // Number every candle, not just the kihon ones

input group "Candle count panel";
//--- A ladder of calendar periods, each counted in the candles that divide it:
//--- the year in months, weeks and days, the month in days, H4s and H1s, the
//--- week in H4s and H1s, the day in H1 down to M1. Every block carries its own
//--- anchor. What you read for is agreement - one row on a kihon number is a
//--- small turn due, several blocks landing together is a bigger one.
input bool             InpShowPanel   = true;               // Show the count panel
input bool             InpShowYear    = true;               // Year block    - MN1, W1, D1
input bool             InpShowMonth   = true;               // Month block   - D1, H4, H1
input bool             InpShowWeek    = true;               // Week block    - H4, H1
input bool             InpShowDay     = true;               // Day block     - H1 to M1
//--- Mid left. The vertical centre is worked out from the chart height and the
//--- number of rows rather than set as a fixed Y, because both change - the day
//--- block grows and shrinks with the chart period, and a Y that centred a
//--- 19-row panel would sit low on a 13-row one.
input ENUM_BASE_CORNER InpPanelCorner = CORNER_LEFT_UPPER;  // Corner
input bool             InpPanelMiddle = true;               // Centre it vertically (ignores Y)
input int              InpPanelX      = 12;                 // Distance from corner, X
input int              InpPanelY      = 20;                 // Distance from corner, Y (when not centred)
input int              InpPanelSize   = 9;                  // Text size

//--- A solid block behind the rows. Over candles, unbacked text is legible
//--- only where the chart happens to be empty, which is not something you can
//--- rely on while reading a count.
input bool             InpPanelBox    = true;               // Solid block behind the panel
input color            InpPanelBg     = C'18,18,24';        // Block colour
input color            InpPanelBorder = clrDimGray;         // Block border colour
input color            InpPanelColor  = clrSilver;          // Text colour
input color            InpPanelHit    = clrLime;            // Colour of a row standing ON a kihon number
input color            InpPanelNear   = clrOrange;          // Colour of a row within reach of one
input int              InpPanelNearTol = 2;                 // How many candles either side counts as near

input group "PO3 levels to show";
//--- Every grid is on by default: the model is the whole nest of powers, and a
//--- level's strength is meant to be read from how many grids agree on it, which
//--- is only visible with all of them drawn. Untick the fine ones for a quieter
//--- chart; the levels that remain do not move.
input bool  InpUse_3     = true;               // 3      - show
input color InpCol_3     = clrGray;            // 3      - colour
input bool  InpUse_9     = true;               // 9      - show
input color InpCol_9     = clrDarkGray;        // 9      - colour
input bool  InpUse_27    = true;               // 27     - show
input color InpCol_27    = clrCadetBlue;       // 27     - colour
input bool  InpUse_81    = true;               // 81     - show
input color InpCol_81    = clrSteelBlue;       // 81     - colour
input bool  InpUse_243   = true;               // 243    - show
input color InpCol_243   = clrMediumSeaGreen;  // 243    - colour
input bool  InpUse_729   = true;               // 729    - show
input color InpCol_729   = clrDarkOrange;      // 729    - colour
input bool  InpUse_2187  = true;               // 2187   - show
input color InpCol_2187  = clrGoldenrod;       // 2187   - colour
input bool  InpUse_6561  = true;               // 6561   - show
input color InpCol_6561  = clrOrangeRed;       // 6561   - colour
input bool  InpUse_19683 = true;               // 19683  - show
input color InpCol_19683 = clrCrimson;         // 19683  - colour

#define PO3_PREFIX  "PO3_"
//--- Level lines and their labels share a sub-prefix so the redraw sweep can
//--- take them alone. The countdown is an OBJ_TEXT too, and a sweep by type
//--- over the whole prefix would delete it on every rebuild.
#define PO3_LEVEL   "PO3_L"
//--- Markers are swept and redrawn as a block whenever the count moves; the
//--- panel rows are rewritten in place. Separate sub-prefixes so the marker
//--- sweep cannot take the panel with it.
#define PO3_KMARK   "PO3_KM"
#define PO3_KPANEL  "PO3_KP"
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

//--- Session timer. The start time lives in a terminal global variable keyed by
//--- chart id, so it outlives the OnInit/OnDeinit cycle that a timeframe or
//--- input change triggers. On such a change OnDeinit leaves g_gvCarry set and
//--- the next OnInit adopts the stored start instead of restarting. g_gvAlerted
//--- flags that the over-limit alert has already fired for this session.
//--- Candle count. Markers only move when a candle closes or the anchor rolls
//--- over, so they are rebuilt on a change rather than on every timer tick.
datetime g_kAnchor = 0;
int      g_kCount  = 0;
bool     g_kDirty  = true;

//--- Panel gate. Nothing the panel prints can change except on a minute
//--- boundary: M1 is the finest thing counted and every coarser timeframe's
//--- boundary is minute-aligned, as are the day, week, month and year rollovers
//--- in the block titles. So the whole panel is rebuilt once a minute rather
//--- than on every tick, which is what it was doing.
//---
//--- g_pUnknown holds the gate open while any row still reads "no data". A
//--- row resolves when its history finishes loading, which does NOT happen on
//--- a minute boundary, so latching on the clock alone would leave the panel
//--- showing "no data" until the next minute arrived. Its own dirty flag, not
//--- g_kDirty: UpdateCount clears that one before UpdatePanel ever sees it.
datetime g_pLast    = 0;
bool     g_pUnknown = true;
bool     g_pDirty   = true;
//--- A centred panel has to move when the window does, and a resize is not a
//--- minute boundary. ChartGetInteger is a local read, so checking it every
//--- pass costs nothing next to the rebuild it usually prevents.
int      g_pHeight  = 0;

string   g_gvStart      = "";
string   g_gvCarry      = "";
string   g_gvAlerted    = "";
datetime g_sessionStart = 0;

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
//| Start, or adopt, the session timer.                              |
//|                                                                  |
//| MT5 tears the indicator down and rebuilds it on a timeframe or   |
//| input change, so a start time held in a plain variable would     |
//| reset every time the chart period was switched. It lives in a    |
//| terminal global instead, keyed by chart id. OnDeinit sets the    |
//| carry flag for exactly the reasons that should not reset the     |
//| count, so its presence here means "adopt the stored start". A    |
//| crash never runs OnDeinit, so the flag is absent and the count   |
//| starts clean, which is what you want after a crash anyway.       |
//+------------------------------------------------------------------+
void SessionInit()
  {
   string base = "PO3_Session_" + IntegerToString(ChartID());
   g_gvStart   = base;
   g_gvCarry   = base + "_carry";
   g_gvAlerted = base + "_alert";

   bool carry = GlobalVariableCheck(g_gvCarry) && GlobalVariableCheck(g_gvStart);
   GlobalVariableDel(g_gvCarry);

   if(!carry)
     {
      GlobalVariableSet(g_gvStart, (double)TimeLocal());
      GlobalVariableDel(g_gvAlerted);
     }

   g_sessionStart = (datetime)(long)GlobalVariableGet(g_gvStart);
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpScale <= 0.0)
     {
      Print("PO3 Levels: scale divisor must be greater than zero.");
      return(INIT_PARAMETERS_INCORRECT);
     }

   SessionInit();

   //--- Before the early return below, so a chart with no grid ticked still
   //--- gets its candle count rebuilt on an input change.
   g_kAnchor  = 0;
   g_kCount   = 0;
   g_kDirty   = true;
   g_pLast    = 0;
   g_pUnknown = true;
   g_pDirty   = true;
   g_pHeight  = 0;

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
      Print("PO3 Levels: no PO3 number ticked, no levels will be drawn.");
      IndicatorSetString(INDICATOR_SHORTNAME, "PO3 (none ticked)");
      g_dirty = true;
      EventSetTimer(1);          // the countdown is independent of the levels
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

   EventSetTimer(1);                    // one-second countdown
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();

   //--- A timeframe or input change keeps the session clock running; anything
   //--- that genuinely reloads the indicator or the chart ends it.
   if(reason == REASON_CHARTCHANGE || reason == REASON_PARAMETERS)
      GlobalVariableSet(g_gvCarry, 1.0);
   else
     {
      GlobalVariableDel(g_gvStart);
      GlobalVariableDel(g_gvCarry);
      GlobalVariableDel(g_gvAlerted);
     }

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
   string name  = PO3_LEVEL + IntegerToString(raw);

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

   //--- Every label shares one time anchor, so the fine grids can pile digits on
   //--- top of each other: 3 puts levels $3 apart, far closer than a line of
   //--- text is tall. The threshold thins them - raise it to label the stronger
   //--- grids only, at the cost of not being able to name the lines it hides.
   if(!InpShowLabels || g_po3[idx] < InpLabelMinPO3)
      return;

   //--- The label carries the owning PO3 number, so a merged level reads as the
   //--- strongest grid that produced it, matching the colour it was given.
   string tname = PO3_LEVEL + "T" + IntegerToString(raw);

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
   //--- Only the level objects. A blanket delete by prefix would take the
   //--- countdown text with it on every redraw, and the clock would flicker
   //--- out whenever price crossed a grid cell.
   ObjectsDeleteAll(0, PO3_LEVEL, -1, OBJ_HLINE);
   ObjectsDeleteAll(0, PO3_LEVEL, -1, OBJ_TEXT);

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
//| A timeframe's short name, "M15" rather than "PERIOD_M15".        |
//+------------------------------------------------------------------+
string TfNameOf(const ENUM_TIMEFRAMES tf)
  {
   return(StringSubstr(EnumToString(tf), 7));
  }

//--- the chart's own timeframe
string TfName()
  {
   return(TfNameOf((ENUM_TIMEFRAMES)_Period));
  }

//+------------------------------------------------------------------+
//| A span of seconds in units that suit its size: mm:ss under an    |
//| hour, hh:mm:ss above it, and days once past one. The candle      |
//| countdown and the session timer both format through here, so     |
//| M15 reads 14:59 while an hour on the chart reads 01:00:00.       |
//+------------------------------------------------------------------+
string HMS(const long secs)
  {
   long s = (secs > 0) ? secs : 0;
   long d = s / 86400; s -= d * 86400;
   long h = s / 3600;  s -= h * 3600;
   long m = s / 60;    s -= m * 60;

   if(d > 0)
      return(StringFormat("%dd %02d:%02d:%02d", (int)d, (int)h, (int)m, (int)s));
   if(h > 0)
      return(StringFormat("%02d:%02d:%02d", (int)h, (int)m, (int)s));
   return(StringFormat("%02d:%02d", (int)m, (int)s));
  }

//+------------------------------------------------------------------+
//| The anchor that suits a screen corner, for the session timer.    |
//+------------------------------------------------------------------+
ENUM_ANCHOR_POINT AnchorFor(const ENUM_BASE_CORNER c)
  {
   //--- Match the anchor to the corner so X and Y always measure inward. A
   //--- fixed right anchor would push the text off the left edge of the chart
   //--- as soon as someone chose a left corner.
   switch(c)
     {
      case CORNER_LEFT_UPPER:  return(ANCHOR_LEFT_UPPER);
      case CORNER_LEFT_LOWER:  return(ANCHOR_LEFT_LOWER);
      case CORNER_RIGHT_LOWER: return(ANCHOR_RIGHT_LOWER);
      default:                 return(ANCHOR_RIGHT_UPPER);
     }
  }

//+------------------------------------------------------------------+
//| Time left on the developing candle, printed beside that candle.  |
//|                                                                  |
//| Anchored to the open time of bar 0 and to the current price, so  |
//| the text tracks the candle as the chart scrolls and rides price  |
//| as it moves, instead of parking in a corner away from the bar it |
//| describes.                                                       |
//|                                                                  |
//| MN1 is nominal: PeriodSeconds() calls a month 30 days, so the    |
//| monthly countdown is approximate. Every other timeframe is exact.|
//+------------------------------------------------------------------+
void UpdateClock()
  {
   string name = PO3_PREFIX + "CLOCK";

   if(!InpShowClock)
     {
      ObjectDelete(0, name);
      return;
     }

   datetime open  = iTime (_Symbol, _Period, 0);
   double   price = iClose(_Symbol, _Period, 0);
   if(open == 0 || price <= 0.0)
      return;                                   // history not ready yet

   long left = (long)(open + PeriodSeconds()) - (long)TimeCurrent();

   //--- Shift is in bars, so the gap to the candle holds at every zoom level.
   //--- Signed arithmetic before the cast: a negative shift on an unsigned
   //--- datetime would wrap and throw the text to the far end of the chart.
   long     bars = (long)PeriodSeconds() * InpClockShift;
   datetime at   = (datetime)MathMax(0, (long)open + bars);

   //--- Past the last bar the text has to read rightwards, into the empty
   //--- space; at or behind it, ending at the anchor keeps the text off the
   //--- candles and, with chart shift off, on screen.
   ENUM_ANCHOR_POINT anchor = (InpClockShift > 0) ? ANCHOR_LEFT : ANCHOR_RIGHT;

   ObjectCreate(0, name, OBJ_TEXT, 0, at, price);

   ObjectSetInteger(0, name, OBJPROP_TIME,       at);
   ObjectSetDouble (0, name, OBJPROP_PRICE,      price + InpClockGapPts * _Point);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR,     anchor);
   ObjectSetString (0, name, OBJPROP_TEXT,       TfName() + "  " + HMS(left));
   ObjectSetInteger(0, name, OBJPROP_COLOR,      InpClockColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,   (int)MathMax(6, MathMin(24, InpClockSize)));
   ObjectSetInteger(0, name, OBJPROP_BACK,       false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED,   false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
  }

//+------------------------------------------------------------------+
//| Wall-clock time this chart has been open. Counts through closed  |
//| markets and weekends, since the point is screen time, not        |
//| session time, and turns red once a set number of minutes is up.  |
//+------------------------------------------------------------------+
void UpdateSession()
  {
   string name = PO3_PREFIX + "SESSION";

   if(!InpShowSession || g_sessionStart == 0)
     {
      ObjectDelete(0, name);
      return;
     }

   long elapsed = (long)TimeLocal() - (long)g_sessionStart;
   if(elapsed < 0)
      elapsed = 0;                               // local clock stepped back

   long  limit = (long)InpSessionLimitMin * 60;
   bool  over  = (limit > 0 && elapsed >= limit);

   //--- One alert the moment the budget is spent. The flag is a terminal global
   //--- so switching timeframe mid-session does not make it fire a second time.
   if(over && !GlobalVariableCheck(g_gvAlerted))
     {
      GlobalVariableSet(g_gvAlerted, 1.0);
      Alert(_Symbol, ": ", InpSessionLimitMin, " minutes on the chart.");
     }

   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER,     InpSessionCorner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  InpSessionX);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  InpSessionY);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR,     AnchorFor(InpSessionCorner));
   ObjectSetString (0, name, OBJPROP_TEXT,       "On chart  " + HMS(elapsed));
   ObjectSetInteger(0, name, OBJPROP_COLOR,      over ? InpSessionOverColor : InpSessionColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,   (int)MathMax(6, MathMin(24, InpSessionSize)));
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED,   false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
  }

//+------------------------------------------------------------------+
//| The candle count, and the kihon suchi numbers marked on it.      |
//|                                                                  |
//| Counting is inclusive at both ends, which is the Ichimoku rule   |
//| and the reason the compound numbers overlap by one candle: the   |
//| candle sitting at the anchor is candle 1, so the developing      |
//| candle is (shift of the anchor) + 1. PO3_Kihon.mqh has the       |
//| numbers themselves and where each one comes from.                |
//+------------------------------------------------------------------+

//--- The panel is a ladder of calendar periods, each counted in the candles
//--- that divide it sensibly: months, weeks and days make up a year; days and
//--- H4s and H1s make up a month; H4s and H1s make up a week; and H1 down to
//--- M5 makes up a day. Every block carries its OWN anchor, which is the whole
//--- point - a week count from the day open would read 1 forever. The lists
//--- are fixed rather than inputs so no block can be pointed at a period its
//--- timeframe does not divide.
//---
//--- The year, month and week blocks are FIXED. They are the same counts
//--- whatever period the chart is on, so switching timeframe must not change
//--- what they say - a week is 26 H1 candles in whether you are looking at M1
//--- or D1, and a row that came and went with the chart period could not be
//--- read across a timeframe change.
//---
//--- The day block is the opposite: it runs from H1 down to the CHART's own
//--- period and stops there, because detail finer than the candles in front of
//--- you is a count of something you cannot see. See KihonDayList.
//---
//--- M1 is missing from that ladder on purpose, on every chart period. The M1
//--- row is ALWAYS the nested one, which restarts at each kihon suchi H1 candle
//--- rather than running the whole day - see the nested row in UpdatePanel. A
//--- plain M1 row beside it would read "past 257" from mid-morning on and say
//--- nothing for the rest of the session.
const ENUM_TIMEFRAMES g_kpYear[3]  = { PERIOD_MN1, PERIOD_W1,  PERIOD_D1 };
const ENUM_TIMEFRAMES g_kpMonth[3] = { PERIOD_D1,  PERIOD_H4,  PERIOD_H1 };
const ENUM_TIMEFRAMES g_kpWeek[2]  = { PERIOD_H4,  PERIOD_H1 };
const ENUM_TIMEFRAMES g_kpDay[4]   = { PERIOD_H1,  PERIOD_M30, PERIOD_M15,
                                       PERIOD_M5 };

//--- Four blocks, their titles and the blank lines between them. Rows are
//--- built into a fixed array and the unused tail deleted, so switching a
//--- block off cannot leave an orphaned row behind on the chart.
#define KP_MAX_ROWS   24

//--- Ceiling on plain candle numbers. A whole day of M1 is 1440 labels, which
//--- is both unreadable and a real drag on redraw, so only the most recent run
//--- is numbered. The kihon markers are never capped - there are at most twelve
//--- of them, and they are the ones worth seeing at the left edge.
#define KP_LABEL_CAP  300

//+------------------------------------------------------------------+
//| One marked candle: an optional vertical line through it and its  |
//| number printed under the low.                                    |
//|                                                                  |
//| Anchored to the candle's own time, so the marks stay on their    |
//| candles as the chart scrolls, and to that candle's low, so the   |
//| numbers sit clear of the body rather than across it.             |
//+------------------------------------------------------------------+
void DrawCountMark(const string id, const int shift, const string text,
                   const color col, const bool line, const int size)
  {
   if(shift < 0 || shift >= Bars(_Symbol, _Period))
      return;                                   // off the loaded history

   datetime when = iTime(_Symbol, _Period, shift);
   double   low  = iLow (_Symbol, _Period, shift);
   if(when == 0 || low <= 0.0)
      return;

   if(line)
     {
      string vname = PO3_KMARK + "V" + id;

      ObjectCreate(0, vname, OBJ_VLINE, 0, when, 0);

      ObjectSetInteger(0, vname, OBJPROP_TIME,       when);
      ObjectSetInteger(0, vname, OBJPROP_COLOR,      col);
      ObjectSetInteger(0, vname, OBJPROP_STYLE,      STYLE_DOT);
      ObjectSetInteger(0, vname, OBJPROP_WIDTH,      1);
      //--- behind the candles: a time marker that hides the candle it marks
      //--- has defeated itself
      ObjectSetInteger(0, vname, OBJPROP_BACK,       true);
      ObjectSetInteger(0, vname, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, vname, OBJPROP_SELECTED,   false);
      ObjectSetInteger(0, vname, OBJPROP_HIDDEN,     true);
      ObjectSetString (0, vname, OBJPROP_TOOLTIP,
                       StringFormat("candle %s   %s", text,
                                    TimeToString(when, TIME_DATE | TIME_MINUTES)));
     }

   string tname = PO3_KMARK + "T" + id;

   ObjectCreate(0, tname, OBJ_TEXT, 0, when, low);

   ObjectSetInteger(0, tname, OBJPROP_TIME,       when);
   ObjectSetDouble (0, tname, OBJPROP_PRICE,      low - InpKihonGapPts * _Point);
   ObjectSetString (0, tname, OBJPROP_TEXT,       text);
   ObjectSetInteger(0, tname, OBJPROP_COLOR,      col);
   ObjectSetInteger(0, tname, OBJPROP_FONTSIZE,   size);
   //--- upper anchor hangs the number below the low, clear of the wick
   ObjectSetInteger(0, tname, OBJPROP_ANCHOR,     ANCHOR_UPPER);
   ObjectSetInteger(0, tname, OBJPROP_BACK,       false);
   ObjectSetInteger(0, tname, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, tname, OBJPROP_SELECTED,   false);
   ObjectSetInteger(0, tname, OBJPROP_HIDDEN,     true);
  }

//+------------------------------------------------------------------+
//| Rebuild the on-chart marks, but only when they would move.       |
//|                                                                  |
//| The count changes exactly when a candle closes or the anchor     |
//| rolls into a new day, so a sweep-and-redraw on every timer tick  |
//| would rebuild an identical set of objects once a second and      |
//| flicker while doing it.                                          |
//+------------------------------------------------------------------+
void UpdateCount()
  {
   datetime anchor = InpShowCount
                     ? KihonAnchor(_Symbol, InpCountAnchor, InpAnchorHour, InpAnchorMin)
                     : 0;
   int count = InpShowCount ? KihonCount(_Symbol, _Period, anchor) : 0;

   if(!g_kDirty && anchor == g_kAnchor && count == g_kCount)
      return;

   g_kAnchor = anchor;
   g_kCount  = count;
   g_kDirty  = false;

   ObjectsDeleteAll(0, PO3_KMARK, -1, -1);

   if(count <= 0)
     {
      ChartRedraw();
      return;
     }

   int size   = (int)MathMax(5, MathMin(20, InpKihonSize));
   int aShift = count - 1;                      // candle 1 lives here

   if(InpMarkOpen)
      DrawCountMark("OPEN", aShift, "1", InpOpenColor, true, size);

   if(InpMarkKihon)
      for(int i = 0; i < KIHON_COUNT; i++)
        {
         if(!InpKihonCompound && i >= KIHON_SIMPLE)
            break;

         int k = KihonNumbers[i];
         if(k > count)                          // not reached yet
            break;

         DrawCountMark("K" + IntegerToString(k), aShift - (k - 1),
                       IntegerToString(k),
                       (i < KIHON_SIMPLE) ? InpKihonSimple : InpKihonComp,
                       InpKihonLines, size);
        }

   //--- Plain numbers on the rest. Drawn after the kihon marks and skipping
   //--- them, so a kihon candle keeps its own colour instead of being
   //--- overwritten by a neutral label of the same number.
   if(InpNumberAll)
     {
      int first = (count > KP_LABEL_CAP) ? count - KP_LABEL_CAP + 1 : 1;

      for(int k = first; k <= count; k++)
        {
         if(k == 1 && InpMarkOpen)
            continue;
         if(InpMarkKihon && KihonIs(k, InpKihonCompound))
            continue;

         DrawCountMark("N" + IntegerToString(k), aShift - (k - 1),
                       IntegerToString(k), InpPanelColor, false,
                       (int)MathMax(5, size - 1));
        }
     }

   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| One panel row: a timeframe's count against its block's anchor,   |
//| and what it owes the next kihon suchi number.                    |
//|                                                                  |
//| "no data" and "too far" are different answers. The first means   |
//| the history is not there to count; the second means the count    |
//| was refused because the anchor is further back than              |
//| KIHON_SPAN_CAP periods, where the exact figure would cost a      |
//| large history load to say something "past 257" already says.     |
//+------------------------------------------------------------------+
string PanelRow(const ENUM_TIMEFRAMES tf, const datetime anchor, color &col,
                const string label = "")
  {
   int    c = KihonCount(_Symbol, tf, anchor);
   string tail;

   if(c < 0)
      tail = "too far";                        // refused, and it will stay refused
   else
      if(c == 0)
        {
         tail = "no data";
         //--- History still arriving. Hold the panel's gate open so the row is
         //--- rewritten the moment it resolves, rather than at the next minute.
         g_pUnknown = true;
        }
      else
        {
         //--- Distance to the nearest number, either side. Zero is standing on
         //--- one; within the tolerance is close enough to say so, and the sign
         //--- says which way - "-2" is two candles short, "+2" two candles past.
         int off = KihonOffset(c, InpKihonCompound);
         int tol = (int)MathMax(0, MathMin(8, InpPanelNearTol));
         int mag = (off < 0) ? -off : off;

         if(off == 0)
           {
            tail = "KIHON";
            col  = InpPanelHit;
           }
         else
            if(mag <= tol)
              {
               //--- Sign written by hand rather than with %+d, so the text
               //--- cannot depend on how the format handles a signed zero or
               //--- a locale. off is non-zero here by the branch above.
               tail = "KIHON " + ((off > 0) ? "+" : "-") + IntegerToString(mag);
               col  = InpPanelNear;
              }
            else
              {
               //--- Past the last number there is nothing left to count to, so
               //--- say that rather than print a countdown to nowhere. The last
               //--- number is the last of the ACTIVE list: with the compounds
               //--- switched off the series ends at 26, not at 257.
               int last = (InpKihonCompound ? KIHON_COUNT : KIHON_SIMPLE) - 1;
               int nx   = KihonNext(c, InpKihonCompound);
               tail = (nx == 0)
                      ? "past " + IntegerToString(KihonNumbers[last])
                      : StringFormat("%d in %d", nx, nx - c);
              }
        }

   //--- The tail is padded to a fixed width so every row is the same length.
   //--- From a right-hand corner the labels are right-anchored, and ragged
   //--- rows would step the timeframe column in and out.
   return(StringFormat("%s %-5s %5s  %-12s",
                       (tf == (ENUM_TIMEFRAMES)_Period) ? ">" : " ",
                       (label == "") ? TfNameOf(tf) : label,
                       (c > 0) ? IntegerToString(c) : "-",
                       tail));
  }

//+------------------------------------------------------------------+
//| The intraday ladder for this chart: H1 down to the chart's own   |
//| period, and no finer.                                            |
//|                                                                  |
//| Selected by period LENGTH rather than by position in the table,  |
//| so a broker's non-standard period - M10, M20 - lands in the      |
//| right place instead of falling through. H1 is always kept: on an |
//| H4 or daily chart every intraday row would otherwise be finer    |
//| than the chart and the block would come out empty, when the hour |
//| count is exactly what you would still want from it there.        |
//+------------------------------------------------------------------+
int KihonDayList(ENUM_TIMEFRAMES &out[])
  {
   int chart = PeriodSeconds();
   int n     = 0;

   ArrayResize(out, ArraySize(g_kpDay));

   for(int i = 0; i < ArraySize(g_kpDay); i++)
      if(i == 0 || PeriodSeconds(g_kpDay[i]) >= chart)
        {
         out[n] = g_kpDay[i];
         n++;
        }

   ArrayResize(out, n);
   return(n);
  }

//--- Breathing room between the text and the edge of the block behind it
#define KP_PAD  6

//+------------------------------------------------------------------+
//| Width of the widest row, in pixels.                              |
//|                                                                  |
//| Measured rather than estimated from the character count: the     |
//| block has to fit whatever font MetaTrader actually resolved, and |
//| a block cut short of its text is worse than no block at all.     |
//| TextSetFont takes tenths of a point when the size is negative,   |
//| which is what OBJPROP_FONTSIZE is quoted in.                     |
//|                                                                  |
//| The estimate is only a fallback for TextGetSize coming back      |
//| empty, and it is deliberately generous - too wide is invisible,  |
//| too narrow is not.                                               |
//+------------------------------------------------------------------+
int PanelWidth(const string &txt[], const int n, const int size)
  {
   int wmax = 0;

   TextSetFont("Consolas", -size * 10, 0, 0);

   //--- TextGetSize writes back through uint references, so the locals have to
   //--- be uint - an int argument will not bind and does not compile.
   for(int i = 0; i < n; i++)
     {
      uint w = 0, h = 0;
      if(TextGetSize(txt[i], w, h) && (int)w > wmax)
         wmax = (int)w;
     }

   if(wmax <= 0)
     {
      int longest = 0;
      for(int i = 0; i < n; i++)
         longest = (int)MathMax(longest, StringLen(txt[i]));
      wmax = (int)(longest * size * 0.7) + 8;
     }

   return(wmax);
  }

//--- One row onto the end, or nothing if the panel is already full
void PanelPush(string &txt[], color &clr[], int &n,
               const string text, const color col)
  {
   if(n >= KP_MAX_ROWS)
      return;

   txt[n] = text;
   clr[n] = col;
   n++;
  }

//+------------------------------------------------------------------+
//| Append one block - a blank line, a title, then its rows.         |
//|                                                                  |
//| The whole block is dropped rather than truncated when it will    |
//| not fit, so the panel never shows a title with its rows missing. |
//+------------------------------------------------------------------+
void PanelAdd(const string title, const datetime anchor, const int fmt,
              const ENUM_TIMEFRAMES &tfs[],
              string &txt[], color &clr[], int &n)
  {
   int rows = ArraySize(tfs);
   if(n + rows + 2 > KP_MAX_ROWS)
      return;

   if(n > 0)                                    // spacer between blocks only
      PanelPush(txt, clr, n, "", InpPanelColor);

   PanelPush(txt, clr, n,
             (anchor > 0)
             ? StringFormat("%-6s from %s", title, TimeToString(anchor, fmt))
             : StringFormat("%-6s from -", title),
             InpPanelColor);

   for(int i = 0; i < rows; i++)
     {
      color col = InpPanelColor;
      string row = PanelRow(tfs[i], anchor, col);
      PanelPush(txt, clr, n, row, col);
     }
  }

//--- The rows the block has to cover. Held at module scope purely so PanelBox
//--- can measure them without UpdatePanel having to thread the array through.
string g_pTxt[KP_MAX_ROWS];
int    g_pRows = 0;

//+------------------------------------------------------------------+
//| The solid block behind the rows.                                 |
//|                                                                  |
//| A rectangle label rather than a rectangle: this is screen        |
//| furniture pinned to a corner, not something anchored to a price  |
//| and a time that would slide away as the chart scrolls.           |
//|                                                                  |
//| Drawn in front of the candles, not behind them. BACK would put   |
//| it under the price data, which is exactly the thing it is meant  |
//| to hide. It stays under the ROWS because it is created first and |
//| same-layer objects paint in creation order.                      |
//+------------------------------------------------------------------+
void PanelBox(const int n, const int top, const int size,
              const int lineH)
  {
   string name = PO3_KPANEL + "BG";

   if(!InpPanelBox || n <= 0)
     {
      ObjectDelete(0, name);
      return;
     }

   int w = PanelWidth(g_pTxt, g_pRows, size);

   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER,      InpPanelCorner);
   //--- The rows are laid out from InpPanelX and top, so the block starts one
   //--- padding earlier on each axis and carries two of them in each size.
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,   (int)MathMax(0, InpPanelX - KP_PAD));
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,   (int)MathMax(0, top - KP_PAD));
   ObjectSetInteger(0, name, OBJPROP_XSIZE,       w + 2 * KP_PAD);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,       n * lineH + 2 * KP_PAD);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,     InpPanelBg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR,       InpPanelBorder);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,       1);
   ObjectSetInteger(0, name, OBJPROP_BACK,        false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,  false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED,    false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,      true);
  }

//+------------------------------------------------------------------+
//| The count panel: a ladder of calendar periods, each counted in   |
//| the candles that divide it.                                      |
//|                                                                  |
//| Year in months, weeks and days; month in days, H4s and H1s; week |
//| in H4s and H1s; day in H1 down to M1. Every block has its own    |
//| anchor, so a row is always counting something its timeframe can  |
//| actually fill - a week counted in H1 reads 26 on Wednesday       |
//| morning, where a week counted from the day open would read 1.    |
//|                                                                  |
//| What you are reading for is agreement across the blocks. One row |
//| on a kihon number is a small turn due; the day, the week and the |
//| month all landing on one at the same candle is a bigger one.     |
//|                                                                  |
//| Rewritten in place rather than swept and rebuilt: the rows are   |
//| fixed names, so setting their text costs nothing and there is no |
//| window in which the panel is missing. Rows past the last one     |
//| used are deleted, which is what clears a block switched off.     |
//+------------------------------------------------------------------+
void UpdatePanel()
  {
   //--- The gate. Every count in the panel steps on a minute boundary, so
   //--- rebuilding between them writes the same 260-odd object properties over
   //--- again. m1 == 0 means M1 history is not there yet, which is not a state
   //--- worth latching, so it falls through and tries again.
   datetime m1 = iTime(_Symbol, PERIOD_M1, 0);
   int      ch = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);

   if(!g_pDirty && !g_pUnknown && m1 != 0 && m1 == g_pLast && ch == g_pHeight)
      return;

   g_pHeight  = ch;

   //--- A fresh load or an input change rebuilds the objects from scratch, so
   //--- the block is created BEFORE the rows again. Same-layer objects paint in
   //--- creation order, so a block created after them would cover them.
   bool fresh = g_pDirty;

   g_pLast    = m1;
   g_pDirty   = false;
   //--- Cleared before the rows are built; PanelRow sets it again for any row
   //--- that could not be counted, which holds the gate open for the next pass.
   g_pUnknown = false;

   string txt[KP_MAX_ROWS];
   color  clr[KP_MAX_ROWS];
   int    n = 0;

   if(InpShowPanel)
     {
      if(InpShowYear)
         PanelAdd("Year", KihonPeriodOpen(true), TIME_DATE,
                  g_kpYear, txt, clr, n);

      if(InpShowMonth)
         PanelAdd("Month", KihonPeriodOpen(false), TIME_DATE,
                  g_kpMonth, txt, clr, n);

      if(InpShowWeek)
         PanelAdd("Week", iTime(_Symbol, PERIOD_W1, 0), TIME_DATE,
                  g_kpWeek, txt, clr, n);

      //--- The day block follows the chart's own anchor when that anchor is a
      //--- custom session time, so the panel agrees with the marks drawn on the
      //--- chart instead of quietly counting from a different open. Every other
      //--- anchor mode belongs to one of the blocks above, so the day block
      //--- stays on the day open.
      if(InpShowDay)
        {
         bool     sess    = (InpCountAnchor == KIHON_ANCHOR_TIME);
         datetime dayOpen = sess ? KihonAnchor(_Symbol, InpCountAnchor,
                                               InpAnchorHour, InpAnchorMin)
                                 : iTime(_Symbol, PERIOD_D1, 0);

         ENUM_TIMEFRAMES day[];
         KihonDayList(day);

         PanelAdd(sess ? "Sess" : "Day", dayOpen, TIME_MINUTES,
                  day, txt, clr, n);

         //--- The nested M1 count. Running M1 across a whole day gives a number
         //--- that is past 257 by breakfast and says nothing after that, so it
         //--- restarts at every kihon suchi H1 candle instead - hour 1, then 9,
         //--- then 17. The label carries the hour it restarted at, because the
         //--- count on its own cannot tell you which phase of the day it is
         //--- measuring. Its own row rather than a member of the day list: the
         //--- rest of that block counts the day, this one counts the segment.
         int      seg  = 0;
         datetime from = KihonSegmentStart(_Symbol, PERIOD_H1, dayOpen,
                                           InpKihonCompound, seg);
         color    col  = InpPanelColor;
         string   row  = PanelRow(PERIOD_M1, from, col,
                                  "M1@" + ((seg > 0) ? IntegerToString(seg) : "-"));

         PanelPush(txt, clr, n, row, col);
        }
     }

   //--- Hand the built rows to PanelBox, which sizes the block to the widest
   for(int i = 0; i < n; i++)
      g_pTxt[i] = txt[i];
   g_pRows = n;

   int size  = (int)MathMax(6, MathMin(20, InpPanelSize));
   int lineH = (int)(size * 1.9) + 2;

   //--- Y grows away from the chosen corner, so from a lower corner the rows
   //--- stack upwards and have to be laid out bottom first to read in order.
   bool up = (InpPanelCorner == CORNER_LEFT_LOWER ||
              InpPanelCorner == CORNER_RIGHT_LOWER);

   //--- Centring works from whichever edge the corner names, so it lands in the
   //--- middle from an upper or a lower corner alike. Clamped at the padding so
   //--- a panel taller than the chart starts on screen rather than above it.
   int top = InpPanelY;
   if(InpPanelMiddle && ch > 0)
      top = (int)MathMax(KP_PAD, (ch - n * lineH) / 2);

   if(fresh)
      ObjectsDeleteAll(0, PO3_KPANEL, -1, -1);

   PanelBox(n, top, size, lineH);

   for(int r = 0; r < n; r++)
     {
      string name = PO3_KPANEL + IntegerToString(r);
      int    slot = up ? (n - 1 - r) : r;

      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

      ObjectSetInteger(0, name, OBJPROP_CORNER,     InpPanelCorner);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  InpPanelX);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  top + slot * lineH);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR,     AnchorFor(InpPanelCorner));
      ObjectSetString (0, name, OBJPROP_TEXT,       txt[r]);
      //--- fixed pitch, or the columns will not line up between rows
      ObjectSetString (0, name, OBJPROP_FONT,       "Consolas");
      ObjectSetInteger(0, name, OBJPROP_COLOR,      clr[r]);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE,   size);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTED,   false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
     }

   //--- Whatever the last layout left behind. Deleting only the tail means a
   //--- steady panel is never torn down and rebuilt, so it does not flicker.
   for(int r = n; r < KP_MAX_ROWS; r++)
      ObjectDelete(0, PO3_KPANEL + IntegerToString(r));
  }

//+------------------------------------------------------------------+
//| Redraw the levels if price has crossed a grid cell or a new bar  |
//| opened. Shared by the tick and timer paths so a quiet market     |
//| still rolls the levels onto the new bar.                         |
//+------------------------------------------------------------------+
void RefreshLevels()
  {
   if(g_n <= 0)
      return;

   double   price = iClose(_Symbol, _Period, 0);
   datetime last  = iTime (_Symbol, _Period, 0);
   if(price <= 0.0 || last == 0)
      return;

   long m0 = (long)MathFloor(price * InpScale / (double)g_finest + 1e-9);

   if(g_dirty || m0 != g_anchor || last != g_lastTime)
     {
      Rebuild(price, last + (datetime)(PeriodSeconds() * InpLabelShift));
      g_anchor   = m0;
      g_lastTime = last;
      g_dirty    = false;
     }
  }

//+------------------------------------------------------------------+
//| Ticks are not guaranteed once a minute, so the clock runs off a  |
//| timer instead. Without it the countdown would sit frozen through |
//| a quiet session and read wrong.                                  |
//+------------------------------------------------------------------+
void OnTimer()
  {
   RefreshLevels();
   UpdateCount();
   UpdatePanel();
   UpdateClock();
   UpdateSession();
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
   if(rates_total <= 0)
      return(rates_total);

   //--- Deliberately NOT the panel or the session timer. Both are one-second
   //--- displays driven by OnTimer, and a tick tells them nothing a second of
   //--- wall clock does not - the panel's counts cannot move except on a minute
   //--- boundary. Leaving them here had every tick rewrite them. The clock
   //--- stays: it is anchored to price and rides it between seconds.
   RefreshLevels();
   UpdateCount();
   UpdateClock();

   return(rates_total);
  }
//+------------------------------------------------------------------+
