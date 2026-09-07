//+------------------------------------------------------------------+
//|                                                  PO3_Scalper.mq5 |
//|                                                                  |
//|  A two-track scalper for the PO3 grid on gold.                   |
//|                                                                  |
//|  The rule is one sentence: a candle wicks into a PO3 level and   |
//|  closes back off it, so trade the other way, take profit at the  |
//|  next level of that same grid, and stop out past the end of the  |
//|  wick.                                                           |
//|                                                                  |
//|  It runs that rule twice, on two grids at two speeds:            |
//|                                                                  |
//|      9 grid    M1 candles    levels $9 apart    target $9 out    |
//|      27 grid   M5 candles    levels $27 apart   target $27 out   |
//|                                                                  |
//|  Each track keeps its own bar clock, its own ATR, its own magic  |
//|  number and its own cooldown, so neither can shadow the other.   |
//|  The timeframes are read from the symbol directly, so the EA is  |
//|  indifferent to the chart period it is dropped on.               |
//|                                                                  |
//|  Both cases of a rejection behave the same way. Price that turns |
//|  just short of a level and price that pokes through and closes   |
//|  back under it differ only in whether the extreme got past the   |
//|  level; the entry rule is "reached it, closed back off it"       |
//|  either way. InpMaxOvershootATR draws the line past which the    |
//|  level really did break rather than being swept.                 |
//|                                                                  |
//|  Powers of three nest, so every 27 level is also a 9 level and a |
//|  27 range holds three 9 cells reading as discount, equilibrium   |
//|  and premium. A 27 level is the stronger of the two and          |
//|  generally holds its first test, turning into support only once  |
//|  price has closed decisively above it. That structure is read    |
//|  and logged on every signal. Two of the three filters that can    |
//|  act on it are on: trade only toward the equilibrium of the 27    |
//|  range, and do not fade a 27 level price has just closed          |
//|  decisively through. The chop veto is left off so its cost can be |
//|  measured against a run that already has the other two.           |
//|                                                                  |
//|  Levels come from PO3_Core.mqh, the same maths PO3_Levels.mq5    |
//|  draws with, so the EA cannot end up trading a different grid    |
//|  from the one on the chart.                                      |
//+------------------------------------------------------------------+
#property copyright "PO3 Scalper"
#property version   "1.00"
#property description "Fades long-wicked rejections of the PO3 grid on gold: 9 levels on M1, 27 levels on M5."

#include <Trade\Trade.mqh>
//--- Quoted, not angled: MetaEditor resolves this against the folder holding
//--- this file, so PO3_Core.mqh sits beside the EA and there is no separate
//--- Include folder step to forget. Angle brackets would look only in
//--- MQL5/Include and fail with "file 'Include\PO3_Core.mqh' not found".
#include "PO3_Core.mqh"

input group "Symbol and size";
//--- Contract size and tick value are read from the symbol rather than assumed,
//--- so sizing is right whether #GOLDm is quoted at 10 or 100 oz per lot.
input string InpSymbolFilter    = "GOLD";      // Trade only if the symbol name contains this
input long   InpMagic           = 903000;      // Magic base (see the note on numbering below)
input double InpLot             = 0.1;         // Lots per leg (XM micro minimum is 0.1)
input double InpScale           = 1.0;         // Scale divisor (1 = whole numbers)

input group "Track A - PO3 9 levels";
input bool            InpOn9        = true;         // Trade the 9 grid
input ENUM_TIMEFRAMES InpTf9        = PERIOD_M1;    // Candles to read
input int             InpTolMinPts9 = 20;           // Zone floor, in points
input int             InpMinRange9  = 15;           // Ignore candles smaller than this, in points
input int             InpSLBufPts9  = 15;           // Stop past the wick end, floor in points
input int             InpTPLevels9  = 1;            // Target this many 9 levels away
input int             InpCooldown9  = 5;            // Bars before the same level can be retaken the same way
input int             InpMaxDay9    = 0;            // Cap setups per day (0 = no cap)

input group "Track B - PO3 27 levels";
input bool            InpOn27        = true;        // Trade the 27 grid
input ENUM_TIMEFRAMES InpTf27        = PERIOD_M5;   // Candles to read
input int             InpTolMinPts27 = 40;          // Zone floor, in points
input int             InpMinRange27  = 40;          // Ignore candles smaller than this, in points
input int             InpSLBufPts27  = 30;          // Stop past the wick end, floor in points
input int             InpTPLevels27  = 1;           // Target this many 27 levels away
input int             InpCooldown27  = 3;           // Bars before the same level can be retaken the same way
input int             InpMaxDay27    = 0;           // Cap setups per day (0 = no cap)

input group "Rejection shape (both tracks)";
//--- These are all ratios, so they carry across the two grids unchanged. Only
//--- the figures quoted in points or bars are split per track above.
input double InpTolATR          = 0.25;     // Zone around a level, in ATR
input double InpTolMaxFrac      = 0.25;     // Zone ceiling, as a fraction of that track's grid
input double InpWickPct         = 50.0;     // Rejecting wick, as a % of the candle range
input double InpMaxBodyPct      = 45.0;     // Largest body, as a % of the candle range
//--- Wick included, a candle taller than one 9 cell has covered the whole
//--- distance the trade was going to make. Fading it puts the stop further away
//--- than the target, so the setup is not worth taking at any shape. The cap is
//--- the 9 grid on BOTH tracks: it is a statement about how volatile the market
//--- has become, not about which grid is being traded.
input double InpMaxRangeP9      = 1.0;      // Ignore candles taller than this many 9 grids ($9), 0 = off
input double InpCloseBufATR     = 0.05;     // Close must clear the level by this much ATR
input double InpMaxOvershootATR = 1.20;     // Past this much ATR beyond the level it broke, not swept (0 = no cap)

input group "Stop and target (both tracks)";
input double InpSLBufATR        = 0.35;     // Stop past the wick end, in ATR
input double InpMinRR           = 1.0;      // Skip the setup if the target is worth less than this many stops

input group "Runner leg (second position)";
//--- XM will not part-close 0.1 lots, since the 0.05 remainder is under the
//--- minimum. A second target therefore needs a second position, which doubles
//--- the risk on any setup stopped before the first target - hence off here.
input bool   InpRunner          = false;    // Open a second leg for a further target
input int    InpRunnerExtra     = 1;        // Runner aims this many extra levels out
input bool   InpRunnerBE        = true;     // Move the runner to break-even once the first leg closes
input int    InpBEOffsetPts     = 10;       // Break-even offset, in points

input group "Filters";
input int    InpMaxSpreadPts    = 40;       // Skip if the spread is wider than this
input int    InpStartHour       = 8;        // Trading window, first hour (server time)
input int    InpEndHour         = 21;       // Trading window, last hour (exclusive)
input bool   InpAllowOpposite   = false;    // Let one track open against the other track's open trade

input group "PO3 structure";
//--- A 27 level is the stronger one and generally holds its first test, and
//--- only acts as support once price has closed decisively above it. The state
//--- is computed from bar history on every signal and written to the log
//--- whether or not it is being used to veto anything.
//---
//--- Two of the three are on. The premium/discount rule only ever bites on the
//--- 9 track: a 27 level IS a range boundary, so a rejection of one is always
//--- read from the premium or discount side that suits it, and the filter is a
//--- no-op on track B by construction. The chop veto is the one left off, so
//--- its cost can be measured against a run that already has the other two.
input int    InpStateBars       = 300;      // Bars of history the level state is read from
input double InpFlipBufATR      = 0.30;     // A close this far past a level flips its state
input int    InpRetestBars      = 30;       // A flip this recent makes the next touch a retest
input bool   InpUseStateFilter  = true;     // Skip setups that fight a recently flipped 27 level
input int    InpMaxFlips        = 0;        // Skip levels chopped through more than this many times (0 = off)
input bool   InpUsePDFilter     = true;     // Only trade toward the equilibrium of the 27 range

input group "Protection";
//--- A market order being accepted is not the same as its stop being attached.
//--- On market execution, which XM uses on several account types, a broker may
//--- strip SL and TP from the order and expect a separate modify - so the stop
//--- is read back off the position and repaired, and the position is closed if
//--- it cannot be protected at all. A scalper with no stop is the one failure
//--- worth spending a round trip to rule out.
input bool   InpVerifyStops     = true;     // Read the stop back off the position, repair or close
input int    InpSendRetries     = 2;        // Retries on a requote or a moved price
//--- Entries stop at the end of the window, but nothing closed a position, so a
//--- Friday afternoon trade rode the weekend. A gap does not respect a stop, it
//--- jumps it, and gold gaps far further than any stop this EA sets.
input int    InpFridayFlatten   = 20;       // Flatten and stop trading at this hour on Friday, server time (-1 = off)

input group "Display and logging";
input bool   InpPanel           = true;     // Chart panel
input bool   InpMarkTrades      = true;     // Mark signal candles on the chart
input bool   InpVerbose         = true;     // Log rejected setups and why

#define EA_PREFIX  "PO3EA_"
#define GRID_9     9
#define GRID_27    27
#define TRACKS     2

//--- Magic numbering. Each track owns a block of two: the entry leg and its
//--- runner. Track A takes base+0 and base+1, track B base+10 and base+11, so
//--- the two blocks stay apart however the base is set.
#define MAGIC_A    0
#define MAGIC_B    10

//--- The level state, read back from bar history rather than kept in memory.
//--- Stateless means a restart, a recompile or a timeframe change cannot leave
//--- the EA holding a stale view of a level it has not seen trade.
struct LevelState
  {
   int      touches;        // times the zone was tested, before the signal bar
   int      flips;          // decisive closes that changed side
   int      barsSinceFlip;  // -1 if it never flipped in the window
   bool     priceAbove;     // last decisive close was above the level
  };

struct Track
  {
   string          name;
   bool            on;
   long            grid;
   ENUM_TIMEFRAMES tf;
   long            magic;       // entry leg; the runner takes magic + 1
   int             atr;
   datetime        lastBar;
   int             tolMinPts;
   int             minRangePts;
   int             slBufPts;
   int             tpLevels;
   int             cooldown;
   int             maxDay;
   //--- cooldown and daily cap, per track
   double          lastLevel;
   int             lastDir;
   datetime        lastSignal;
   int             today;
   int             todayCount;
  };

CTrade g_trade;
Track  g_tr[TRACKS];
double g_lot  = 0.1;
double g_tick = 0.0;

//+------------------------------------------------------------------+
//| An order price has to land on the broker's tick size. Level      |
//| prices are exact grid figures, so this moves them at most half a |
//| tick, but sending 4374.0 to a symbol quoting in 0.01 steps is    |
//| only safe because the rounding is done here rather than assumed. |
//+------------------------------------------------------------------+
double ToTick(const double price)
  {
   if(g_tick <= 0.0)
      return(NormalizeDouble(price, _Digits));
   return(NormalizeDouble(MathRound(price / g_tick) * g_tick, _Digits));
  }

//--- a is further along in direction dir than b
bool Beyond(const double a, const double b, const int dir)
  {
   return(dir > 0 ? (a > b + PO3_ON_TOL) : (a < b - PO3_ON_TOL));
  }

//+------------------------------------------------------------------+
//| The broker's minimum distance between price and a stop or limit. |
//| Some feeds report zero here and apply a dynamic distance instead, |
//| so the spread is used as the floor.                              |
//+------------------------------------------------------------------+
double MinStopDist()
  {
   long   pts  = (long)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double dist = pts * _Point;
   double sprd = (SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                  - SymbolInfoDouble(_Symbol, SYMBOL_BID));
   return(MathMax(dist, sprd * 2.0));
  }

//--- open positions carrying this magic on this symbol
int LegCount(const long magic)
  {
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol
         && PositionGetInteger(POSITION_MAGIC) == magic)
         n++;
     }
   return(n);
  }

//--- direction of any position this EA holds: +1 long, -1 short, 0 flat
int OpenDirection()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      long m = PositionGetInteger(POSITION_MAGIC);
      for(int k = 0; k < TRACKS; k++)
         if(m == g_tr[k].magic || m == g_tr[k].magic + 1)
            return(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1);
     }
   return(0);
  }

//+------------------------------------------------------------------+
//| Read a level's history: how often it has been tested, how often  |
//| price has closed decisively through it, and which side price     |
//| settled on last.                                                 |
//|                                                                  |
//| The signal bar itself is excluded, so `touches` counts the tests |
//| that came before this one and a first touch reads as zero.       |
//+------------------------------------------------------------------+
void ReadLevelState(const double level, const double tol, const double atr,
                    const MqlRates &r[], const int bars, LevelState &st)
  {
   st.touches       = 0;
   st.flips         = 0;
   st.barsSinceFlip = -1;
   st.priceAbove    = false;

   double buf  = MathMax(InpFlipBufATR * atr, _Point);
   int    side = 0;

   //--- oldest to newest, stopping before the signal bar at index 1
   for(int i = bars - 1; i >= 2; i--)
     {
      if(r[i].high >= level - tol && r[i].low <= level + tol)
         st.touches++;

      int s = 0;
      if(r[i].close > level + buf)
         s = 1;
      else
         if(r[i].close < level - buf)
            s = -1;

      if(s != 0)
        {
         if(side != 0 && s != side)
           {
            st.flips++;
            st.barsSinceFlip = i;   // series index, so this is "bars ago"
           }
         side = s;
        }
     }
   st.priceAbove = (side > 0);
  }

//+------------------------------------------------------------------+
//| Does this candle reject the level in direction dir?              |
//|                                                                  |
//| dir -1 is a rejection from below: the high reached the level and |
//| the close came back under it, leaving the wick above. dir +1 is  |
//| the mirror. The reach test uses the zone, so a candle that turns |
//| just short of the level counts the same as one that pokes        |
//| through - which is the point, since both are the same rejection. |
//+------------------------------------------------------------------+
bool Rejects(const MqlRates &b, const Track &t, const double level, const int dir,
             const double tol, const double atr, string &why, bool &nearMiss)
  {
   //--- Most candles are refused because they were nowhere near a level, and on
   //--- M1 that is nearly all of them. Only a candle that got the location right
   //--- and then failed on its size or shape is worth a line in the log, so the
   //--- tests are ordered location first and the flag is raised once they pass.
   nearMiss = false;

   double range = b.high - b.low;
   if(range <= 0.0)
     { why = "zero range"; return(false); }
   if(range < t.minRangePts * _Point)
     { why = "candle under the minimum range"; return(false); }

   double reach = (dir < 0) ? b.high : b.low;
   double buf   = InpCloseBufATR * atr;

   if(dir < 0)
     {
      if(reach < level - tol)
        { why = "high never reached the zone"; return(false); }
      if(b.close >= level - buf)
        { why = "close did not clear back under the level"; return(false); }
      if(InpMaxOvershootATR > 0.0 && reach > level + InpMaxOvershootATR * atr)
        { why = "high went past the level far enough to be a break, not a sweep"; return(false); }
     }
   else
     {
      if(reach > level + tol)
        { why = "low never reached the zone"; return(false); }
      if(b.close <= level + buf)
        { why = "close did not clear back over the level"; return(false); }
      if(InpMaxOvershootATR > 0.0 && reach < level - InpMaxOvershootATR * atr)
        { why = "low went past the level far enough to be a break, not a sweep"; return(false); }
     }

   //--- Location is right: this candle did reach the level and close back off
   //--- it. Anything refused past here is a real near miss.
   nearMiss = true;

   //--- Wick included, a candle taller than one 9 cell has covered the whole
   //--- distance the trade was going to make.
   if(InpMaxRangeP9 > 0.0)
     {
      double maxRange = InpMaxRangeP9 * PO3Step(GRID_9, InpScale);
      if(range > maxRange)
        {
         why = StringFormat("candle is %.2f tall, over the %.2f cap - too volatile to fade",
                            range, maxRange);
         return(false);
        }
     }

   //--- the wick is the whole signal: a long one against the level, and a body
   //--- small enough that the candle reads as a rejection rather than a trend bar
   double body = MathAbs(b.close - b.open);
   double wick = (dir < 0) ? (b.high - MathMax(b.open, b.close))
                           : (MathMin(b.open, b.close) - b.low);

   if(wick < InpWickPct / 100.0 * range)
     { why = StringFormat("wick is %.0f%% of the candle, under the %.0f%% needed",
                          wick / range * 100.0, InpWickPct); return(false); }
   if(body > InpMaxBodyPct / 100.0 * range)
     { why = StringFormat("body is %.0f%% of the candle, over the %.0f%% allowed",
                          body / range * 100.0, InpMaxBodyPct); return(false); }

   why = "";
   return(true);
  }

//+------------------------------------------------------------------+
//| Step a target out until it is a workable distance from price and |
//| past any earlier target.                                         |
//+------------------------------------------------------------------+
double PushTarget(double tp, const double px, const int dir, const long grid,
                  const double minDist, const double past, const bool hasPast)
  {
   for(int guard = 0; guard < 8; guard++)
     {
      //--- Wrong side matters as much as too close: if price ran past the
      //--- target between the candle closing and the order going in, the
      //--- distance test alone would happily accept a target behind us.
      bool wrongSide = !Beyond(tp, px, dir);
      bool tooClose  = (MathAbs(px - tp) < minDist);
      bool notPast   = (hasPast && !Beyond(tp, past, dir));
      if(!wrongSide && !tooClose && !notPast)
         break;
      tp = PO3StepFrom(tp, grid, dir, 1, InpScale);
     }
   return(tp);
  }

//+------------------------------------------------------------------+
//| Mark the signal candle, so a trade on the chart can be read back |
//| against the level and the wick that produced it.                 |
//+------------------------------------------------------------------+
void MarkSignal(const Track &t, const datetime when, const double at,
                const int dir, const double level)
  {
   if(!InpMarkTrades)
      return;

   string name = EA_PREFIX + t.name + IntegerToString((long)when);
   ObjectCreate(0, name, OBJ_ARROW, 0, when, at);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, dir > 0 ? 233 : 234);
   ObjectSetInteger(0, name, OBJPROP_COLOR, dir > 0 ? clrDodgerBlue : clrTomato);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_TOOLTIP,
                   StringFormat("PO3 %I64d  %s at %s",
                                t.grid, dir > 0 ? "long" : "short",
                                DoubleToString(level, 2)));
  }

//+------------------------------------------------------------------+
//| Once the first leg is gone the runner is riding free, so pull    |
//| its stop to break-even.                                          |
//|                                                                  |
//| Read entirely from open positions, with nothing remembered       |
//| between ticks: the first leg being absent while the runner is    |
//| still open IS the first target having filled, because a stop     |
//| would have taken both legs together.                             |
//+------------------------------------------------------------------+
void ManageRunner(const Track &t)
  {
   if(!InpRunner || !InpRunnerBE)
      return;
   if(LegCount(t.magic) > 0 || LegCount(t.magic + 1) == 0)
      return;

   double minDist = MinStopDist();

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !PositionSelectByTicket(tk))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol
         || PositionGetInteger(POSITION_MAGIC) != t.magic + 1)
         continue;

      bool   isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      int    dir   = isBuy ? 1 : -1;
      double open  = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl    = PositionGetDouble(POSITION_SL);
      double tp    = PositionGetDouble(POSITION_TP);
      double be    = ToTick(open + dir * InpBEOffsetPts * _Point);

      //--- only ever tighten
      if(sl != 0.0 && !Beyond(be, sl, dir))
         continue;

      //--- and only if price has left room for the stop to be accepted
      double now = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(MathAbs(now - be) < minDist || !Beyond(now, be, dir))
         continue;

      if(g_trade.PositionModify(tk, be, tp))
         PrintFormat("PO3 %I64d: first leg closed, runner #%I64u stop to break-even %s",
                     t.grid, tk, DoubleToString(be, _Digits));
     }
  }

//+------------------------------------------------------------------+
//| The cooldown outlives the EA.                                    |
//|                                                                  |
//| Recompiling, changing an input or restarting the terminal tears  |
//| the EA down and builds it again, and a cooldown held in a plain  |
//| variable would be lost with it - so the level just traded could  |
//| be taken again on the very next candle. It lives in terminal     |
//| global variables instead, keyed by symbol and magic rather than  |
//| by chart, so it survives the chart being closed and reopened     |
//| too. The same trick PO3_Levels.mq5 uses for its session timer.   |
//+------------------------------------------------------------------+
string CooldownKey(const Track &t, const string suffix)
  {
   return(EA_PREFIX + _Symbol + "_" + IntegerToString(t.magic) + suffix);
  }

void LoadCooldown(Track &t)
  {
   string kl = CooldownKey(t, "_lvl");
   string kt = CooldownKey(t, "_time");
   if(!GlobalVariableCheck(kl) || !GlobalVariableCheck(kt))
      return;

   //--- the direction rides in the sign, so one number carries both
   double signedLevel = GlobalVariableGet(kl);
   t.lastLevel  = MathAbs(signedLevel);
   t.lastDir    = (signedLevel < 0.0) ? -1 : 1;
   t.lastSignal = (datetime)GlobalVariableGet(kt);

   PrintFormat("PO3 %I64d: picked the cooldown back up - last was a %s at %s on %s.",
               t.grid, t.lastDir > 0 ? "long" : "short",
               DoubleToString(t.lastLevel, 2),
               TimeToString(t.lastSignal, TIME_DATE | TIME_MINUTES));
  }

void SaveCooldown(const Track &t)
  {
   GlobalVariableSet(CooldownKey(t, "_lvl"),  t.lastLevel * t.lastDir);
   GlobalVariableSet(CooldownKey(t, "_time"), (double)t.lastSignal);
  }

//--- inside the trading window, wrapping windows included
bool InWindow()
  {
   if(InpStartHour == InpEndHour)
      return(true);
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(InpStartHour < InpEndHour)
      return(dt.hour >= InpStartHour && dt.hour < InpEndHour);
   return(dt.hour >= InpStartHour || dt.hour < InpEndHour);
  }

//--- day rollover for this track's setup cap
bool DayCapReached(Track &t)
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day != t.today)
     {
      t.today      = dt.day;
      t.todayCount = 0;
     }
   return(t.maxDay > 0 && t.todayCount >= t.maxDay);
  }

//--- the most recently opened position carrying this magic
ulong NewestPosition(const long magic)
  {
   ulong    best = 0;
   datetime when = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !PositionSelectByTicket(tk))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol
         || PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      if(t >= when)
        { when = t; best = tk; }
     }
   return(best);
  }

//--- failures worth trying again: the price moved under us, not a bad request
bool IsTransient(const uint code)
  {
   return(code == TRADE_RETCODE_REQUOTE
          || code == TRADE_RETCODE_PRICE_CHANGED
          || code == TRADE_RETCODE_PRICE_OFF
          || code == TRADE_RETCODE_TIMEOUT
          || code == TRADE_RETCODE_CONNECTION);
  }

//+------------------------------------------------------------------+
//| Send one leg, trying again if the price moved.                   |
//|                                                                  |
//| The stop and target are absolute prices rather than distances,   |
//| so a retry at a new price still aims at the same PO3 levels. A   |
//| rejection that is not transient is not retried: the request      |
//| itself was wrong, and repeating it only repeats the error.       |
//+------------------------------------------------------------------+
bool SendWithRetry(const int dir, const double sl, const double tp,
                   const string tag, const long magic, const string what)
  {
   g_trade.SetExpertMagicNumber(magic);

   int tries = 1 + MathMax(0, InpSendRetries);
   for(int i = 0; i < tries; i++)
     {
      bool ok = (dir > 0) ? g_trade.Buy (g_lot, _Symbol, 0.0, sl, tp, tag)
                          : g_trade.Sell(g_lot, _Symbol, 0.0, sl, tp, tag);
      if(ok)
         return(true);

      uint code = g_trade.ResultRetcode();
      if(!IsTransient(code) || i == tries - 1)
        {
         PrintFormat("PO3: %s rejected, %d %s%s", what, code,
                     g_trade.ResultRetcodeDescription(),
                     IsTransient(code) ? " - out of retries" : "");
         return(false);
        }

      PrintFormat("PO3: %s got %d %s, trying again (%d of %d)", what, code,
                  g_trade.ResultRetcodeDescription(), i + 1, tries - 1);
      Sleep(300);
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Read the stop back off the position, and insist on one.          |
//|                                                                  |
//| An accepted order is not an attached stop. If the broker dropped |
//| it, put it on; if it cannot be put on, close the position -      |
//| being flat is a known loss and being naked is not a bounded one. |
//+------------------------------------------------------------------+
void EnsureProtected(const long magic, const double sl, const double tp)
  {
   if(!InpVerifyStops)
      return;

   ulong tk = NewestPosition(magic);
   if(tk == 0)
     {
      PrintFormat("PO3: order for magic %I64d was accepted but no position "
                  "carries that magic - check the trade tab.", magic);
      return;
     }

   for(int i = 0; i < 3; i++)
     {
      if(!PositionSelectByTicket(tk))
         return;
      if(PositionGetDouble(POSITION_SL) != 0.0)
        {
         if(i > 0)
            PrintFormat("PO3: stop attached to #%I64u on attempt %d.", tk, i + 1);
         return;
        }

      PrintFormat("PO3: #%I64u came back with no stop - attaching %s.",
                  tk, DoubleToString(sl, _Digits));
      g_trade.PositionModify(tk, sl, tp);
      Sleep(300);
     }

   if(PositionSelectByTicket(tk) && PositionGetDouble(POSITION_SL) == 0.0)
     {
      PrintFormat("PO3: #%I64u could not be given a stop. Closing it rather "
                  "than leaving it unprotected.", tk);
      if(!g_trade.PositionClose(tk))
         PrintFormat("PO3: AND THE CLOSE FAILED, %d %s - #%I64u is open with no "
                     "stop, close it by hand.",
                     g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription(), tk);
     }
  }

//--- close every position this EA owns; returns how many it took
int CloseAllEA(const string reason)
  {
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !PositionSelectByTicket(tk))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      long m = PositionGetInteger(POSITION_MAGIC);
      bool mine = false;
      for(int k = 0; k < TRACKS; k++)
         if(m == g_tr[k].magic || m == g_tr[k].magic + 1)
            mine = true;
      if(!mine)
         continue;

      if(g_trade.PositionClose(tk))
        {
         closed++;
         PrintFormat("PO3: closed #%I64u - %s.", tk, reason);
        }
      else
        {
         //--- A close that keeps failing is worth saying, but not on every tick
         //--- for the rest of the session.
         static datetime moaned = 0;
         if(TimeCurrent() - moaned >= 60)
           {
            moaned = TimeCurrent();
            PrintFormat("PO3: could not close #%I64u for %s, %d %s - still trying.",
                        tk, reason, g_trade.ResultRetcode(),
                        g_trade.ResultRetcodeDescription());
           }
        }
     }
   return(closed);
  }

//--- past the Friday cutoff, where a held position would face the weekend gap
bool PastFridayCutoff()
  {
   if(InpFridayFlatten < 0)
      return(false);
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return(dt.day_of_week == 5 && dt.hour >= InpFridayFlatten);
  }

//+------------------------------------------------------------------+
//| Open the setup: one leg to the next level of this track's grid,  |
//| optionally a second further out. Both legs share the one stop.   |
//+------------------------------------------------------------------+
bool Open(Track &t, const int dir, const double sl, const double tp1,
          const double tp2, const double level)
  {
   double px = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   string tag = StringFormat("PO3 %I64d %s %.0f", t.grid, dir > 0 ? "L" : "S", level);

   double need = 0.0;
   if(OrderCalcMargin(dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol,
                      g_lot * (InpRunner ? 2 : 1), px, need))
      if(need > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
        {
         PrintFormat("PO3 %I64d: skipped, margin needed %.2f exceeds free margin %.2f",
                     t.grid, need, AccountInfoDouble(ACCOUNT_MARGIN_FREE));
         return(false);
        }

   if(!SendWithRetry(dir, sl, tp1, tag, t.magic,
                     StringFormat("PO3 %I64d entry leg", t.grid)))
      return(false);
   EnsureProtected(t.magic, sl, tp1);

   if(InpRunner)
     {
      if(SendWithRetry(dir, sl, tp2, tag + " R", t.magic + 1,
                       StringFormat("PO3 %I64d runner leg", t.grid)))
         EnsureProtected(t.magic + 1, sl, tp2);
      else
         PrintFormat("PO3 %I64d: the entry leg stays open alone.", t.grid);
     }

   t.todayCount++;
   return(true);
  }

//+------------------------------------------------------------------+
//| One closed candle on this track, checked against the level its   |
//| wick reached.                                                    |
//+------------------------------------------------------------------+
void Scan(Track &t)
  {
   int bars = MathMax(60, InpStateBars + 5);
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, t.tf, 0, bars, r) < 10)
      return;
   bars = ArraySize(r);

   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   if(CopyBuffer(t.atr, 0, 0, 3, atrBuf) < 2)
      return;
   double atr = atrBuf[1];
   if(atr <= 0.0)
      return;

   //--- The zone is bounded by the grid it sits on. Left to ATR alone a volatile
   //--- session would open a zone wide enough for adjacent levels to overlap,
   //--- and every candle would be "at a level".
   double step = PO3Step(t.grid, InpScale);
   double tol  = MathMax(InpTolATR * atr, t.tolMinPts * _Point);
   tol = MathMin(tol, InpTolMaxFrac * step);

   MqlRates b = r[1];

   //--- Two candidates, no more: the level nearest the candle's high is the
   //--- only one its upper wick can be rejecting, and likewise the low.
   for(int k = 0; k < 2; k++)
     {
      int    dir   = (k == 0) ? -1 : 1;                       // -1 short, +1 long
      double level = PO3Nearest((dir < 0) ? b.high : b.low, t.grid, InpScale);

      string why      = "";
      bool   nearMiss = false;
      if(!Rejects(b, t, level, dir, tol, atr, why, nearMiss))
        {
         if(InpVerbose && nearMiss)
            PrintFormat("PO3 %I64d: %s at %s passed on - %s",
                        t.grid, dir > 0 ? "long" : "short",
                        DoubleToString(level, 2), why);
         continue;
        }

      //--- cooldown, so one level worked over by several candles is one trade
      if(MathAbs(level - t.lastLevel) <= PO3_ON_TOL && dir == t.lastDir
         && t.lastSignal > 0
         && (long)(b.time - t.lastSignal) < (long)t.cooldown * PeriodSeconds(t.tf))
        {
         if(InpVerbose)
            PrintFormat("PO3 %I64d: %s at %s passed on - inside the cooldown",
                        t.grid, dir > 0 ? "long" : "short", DoubleToString(level, 2));
         continue;
        }

      //--- Don't let one track open against a position the other track is
      //--- already holding: the two would sit on the same symbol cancelling
      //--- each other out while paying both spreads.
      int held = OpenDirection();
      if(!InpAllowOpposite && held != 0 && held != dir)
        {
         if(InpVerbose)
            PrintFormat("PO3 %I64d: %s at %s passed on - the other track is holding the opposite side",
                        t.grid, dir > 0 ? "long" : "short", DoubleToString(level, 2));
         continue;
        }

      //--- The 27 structure. Always read and always logged; only a filter when
      //--- the inputs say so. On track B the level being traded is the 27 level.
      double     l27  = PO3Nearest(level, GRID_27, InpScale);
      bool       on27 = PO3IsOn(level, GRID_27, InpScale);
      LevelState st;
      ReadLevelState(l27, tol, atr, r, bars, st);

      double pos = PO3RangePos(b.close, GRID_27, InpScale);
      double eq  = PO3RangeEQ(b.close, GRID_27, InpScale);

      PrintFormat("PO3 %I64d: %s wick at %s%s | 27 level %s is %s, %d prior touches, "
                  "%d flips%s | price at %.0f%% of its 27 range (EQ %s)",
                  t.grid,
                  dir > 0 ? "bullish" : "bearish",
                  DoubleToString(level, 2),
                  (t.grid == GRID_9 && on27) ? " (also a 27 level)" : "",
                  DoubleToString(l27, 2),
                  st.priceAbove ? "support" : "resistance",
                  st.touches, st.flips,
                  (st.barsSinceFlip >= 0 && st.barsSinceFlip <= InpRetestBars)
                     ? StringFormat(", flipped %d bars ago", st.barsSinceFlip) : "",
                  pos * 100.0, DoubleToString(eq, 2));

      if(InpMaxFlips > 0 && st.flips > InpMaxFlips)
        {
         if(InpVerbose)
            PrintFormat("PO3 %I64d: passed on - the 27 level has been chopped through %d times",
                        t.grid, st.flips);
         continue;
        }

      //--- A 27 level that has just flipped is expected to hold from its new
      //--- side, so a trade back through it is fighting the fresh break.
      if(InpUseStateFilter && on27
         && st.barsSinceFlip >= 0 && st.barsSinceFlip <= InpRetestBars)
        {
         bool fighting = (dir > 0) ? !st.priceAbove : st.priceAbove;
         if(fighting)
           {
            if(InpVerbose)
               PrintFormat("PO3 %I64d: passed on - it fights a 27 level that flipped recently", t.grid);
            continue;
           }
        }

      //--- Discount buys, premium sells: within a 27 range the three 9 cells
      //--- read as discount, equilibrium and premium, and a trade toward
      //--- equilibrium is the one the structure supports.
      if(InpUsePDFilter)
        {
         bool wrongHalf = (dir > 0) ? (pos > 0.5) : (pos < 0.5);
         if(wrongHalf)
           {
            if(InpVerbose)
               PrintFormat("PO3 %I64d: passed on - a %s away from equilibrium at %.0f%% of the 27 range",
                           t.grid, dir > 0 ? "long" : "short", pos * 100.0);
            continue;
           }
        }

      //--- Stop past the end of the wick. That price is where the rejection
      //--- stopped being a rejection, so it is the level the trade is wrong at.
      double px      = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                 : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double minDist = MinStopDist();
      double slBuf   = MathMax(InpSLBufATR * atr, t.slBufPts * _Point);
      double sl      = (dir > 0) ? b.low - slBuf : b.high + slBuf;

      //--- The stop has to be on the losing side of price and far enough from
      //--- it. A distance test alone would pass a stop that price has already
      //--- traded through, which the broker rejects as an invalid stop.
      double minSl = px - dir * minDist;
      if(!Beyond(sl, minSl, -dir))
         sl = minSl;
      sl = ToTick(sl);

      double tp1 = PO3StepFrom(level, t.grid, dir, MathMax(1, t.tpLevels), InpScale);
      tp1 = ToTick(PushTarget(tp1, px, dir, t.grid, minDist, 0.0, false));

      double risk   = MathAbs(px - sl);
      double reward = MathAbs(tp1 - px);
      if(risk <= 0.0 || reward < InpMinRR * risk)
        {
         PrintFormat("PO3 %I64d: passed on - target %s is %.2f against a %.2f stop, under the %.1f needed",
                     t.grid, DoubleToString(tp1, 2), reward, risk, InpMinRR);
         continue;
        }

      double tp2 = 0.0;
      if(InpRunner)
        {
         tp2 = PO3StepFrom(tp1, t.grid, dir, MathMax(1, InpRunnerExtra), InpScale);
         tp2 = ToTick(PushTarget(tp2, px, dir, t.grid, minDist, tp1, true));
        }

      PrintFormat("PO3 %I64d: %s %.2f lots at %s, stop %s (%.2f), target %s (%.2f, %.1fR)%s",
                  t.grid, dir > 0 ? "BUY" : "SELL", g_lot, DoubleToString(px, 2),
                  DoubleToString(sl, 2), risk, DoubleToString(tp1, 2), reward,
                  reward / risk,
                  InpRunner ? StringFormat(", runner to %s", DoubleToString(tp2, 2)) : "");

      if(Open(t, dir, sl, tp1, tp2, level))
        {
         t.lastLevel  = level;
         t.lastDir    = dir;
         t.lastSignal = b.time;
         SaveCooldown(t);
         MarkSignal(t, b.time, (dir > 0) ? b.low : b.high, dir, level);
        }
      return;   // one setup per candle
     }
  }

//--- one track's line on the panel
string TrackLine(const Track &t)
  {
   if(!t.on)
      return(StringFormat("%s  PO3 %-2I64d  off\n", t.name, t.grid));

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return(StringFormat("%s  PO3 %-2I64d  %-3s  %s < %s > %s   legs %d   today %d\n",
                       t.name, t.grid,
                       StringSubstr(EnumToString(t.tf), 7),
                       DoubleToString(PO3Floor(bid, t.grid, InpScale), 2),
                       DoubleToString(bid, 2),
                       DoubleToString(PO3Ceil(bid, t.grid, InpScale), 2),
                       LegCount(t.magic) + LegCount(t.magic + 1),
                       t.todayCount));
  }

//+------------------------------------------------------------------+
void Panel()
  {
   if(!InpPanel)
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double pos = PO3RangePos(bid, GRID_27, InpScale);
   string zone = (pos > 0.6) ? "premium" : (pos < 0.4) ? "discount" : "equilibrium";

   Comment(StringFormat(
      "PO3 Scalper   %s\n"
      "%s%s"
      "27 range  %s .. %s   EQ %s\n"
      "price is in %s, %.0f%% of the 27 range\n"
      "spread %d pts   %s",
      _Symbol,
      TrackLine(g_tr[0]), TrackLine(g_tr[1]),
      DoubleToString(PO3Floor(bid, GRID_27, InpScale), 2),
      DoubleToString(PO3Ceil (bid, GRID_27, InpScale), 2),
      DoubleToString(PO3RangeEQ(bid, GRID_27, InpScale), 2),
      zone, pos * 100.0,
      (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD),
      PastFridayCutoff() ? "flat for the weekend"
                         : (InWindow() ? "in the trading window"
                                       : "outside the trading window")));
  }

//+------------------------------------------------------------------+
void SetupTrack(Track &t, const string name, const bool on, const long grid,
                const ENUM_TIMEFRAMES tf, const long magic, const int tolMinPts,
                const int minRangePts, const int slBufPts, const int tpLevels,
                const int cooldown, const int maxDay)
  {
   t.name        = name;
   t.on          = on;
   t.grid        = grid;
   t.tf          = tf;
   t.magic       = magic;
   t.atr         = INVALID_HANDLE;
   t.lastBar     = 0;
   t.tolMinPts   = tolMinPts;
   t.minRangePts = minRangePts;
   t.slBufPts    = slBufPts;
   t.tpLevels    = tpLevels;
   t.cooldown    = cooldown;
   t.maxDay      = maxDay;
   t.lastLevel   = 0.0;
   t.lastDir     = 0;
   t.lastSignal  = 0;
   t.today       = -1;
   t.todayCount  = 0;
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   if(StringLen(InpSymbolFilter) > 0
      && StringFind(_Symbol, InpSymbolFilter) < 0)
     {
      PrintFormat("PO3 Scalper: %s does not contain \"%s\". The grids are $9 and $27 "
                  "apart, which are gold figures - clear the filter only if you mean to.",
                  _Symbol, InpSymbolFilter);
      return(INIT_PARAMETERS_INCORRECT);
     }

   SetupTrack(g_tr[0], "A", InpOn9,  GRID_9,  InpTf9,  InpMagic + MAGIC_A,
              InpTolMinPts9,  InpMinRange9,  InpSLBufPts9,  InpTPLevels9,
              InpCooldown9,  InpMaxDay9);
   SetupTrack(g_tr[1], "B", InpOn27, GRID_27, InpTf27, InpMagic + MAGIC_B,
              InpTolMinPts27, InpMinRange27, InpSLBufPts27, InpTPLevels27,
              InpCooldown27, InpMaxDay27);

   if(!g_tr[0].on && !g_tr[1].on)
     {
      Print("PO3 Scalper: both tracks are off, so there is nothing to trade.");
      return(INIT_PARAMETERS_INCORRECT);
     }

   for(int k = 0; k < TRACKS; k++)
     {
      if(!g_tr[k].on)
         continue;
      g_tr[k].atr = iATR(_Symbol, g_tr[k].tf, 14);
      if(g_tr[k].atr == INVALID_HANDLE)
        {
         PrintFormat("PO3 Scalper: could not create the ATR handle for track %s.", g_tr[k].name);
         return(INIT_FAILED);
        }
      //--- Adopt the candle already forming. Without this the first tick after
      //--- attaching reads as a new bar and the EA would trade off whatever
      //--- candle happened to have closed last, which nobody asked it to see.
      g_tr[k].lastBar = iTime(_Symbol, g_tr[k].tf, 0);

      LoadCooldown(g_tr[k]);
     }

   //--- Fail here rather than at the first order. A close-only or disabled
   //--- symbol produces a retcode at send time that reads like a code bug.
   if(!SymbolSelect(_Symbol, true))
     {
      PrintFormat("PO3 Scalper: %s could not be selected in Market Watch.", _Symbol);
      return(INIT_FAILED);
     }
   ENUM_SYMBOL_TRADE_MODE mode =
      (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(mode != SYMBOL_TRADE_MODE_FULL)
     {
      PrintFormat("PO3 Scalper: %s is not fully tradeable (%s). Nothing this EA "
                  "does will work until that changes.",
                  _Symbol, EnumToString(mode));
      return(INIT_FAILED);
     }

   g_tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   //--- Size is clamped to what the symbol will accept rather than assumed. On
   //--- an XM micro account the minimum is 0.1, but a broker asking for more is
   //--- honoured here instead of having every order rejected.
   double vmin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double vstep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   g_lot = InpLot;
   if(vstep > 0.0)
      g_lot = MathRound(g_lot / vstep) * vstep;
   g_lot = MathMax(vmin, MathMin(vmax, g_lot));
   if(MathAbs(g_lot - InpLot) > 1e-8)
      PrintFormat("PO3 Scalper: lot size %.2f adjusted to %.2f for this symbol "
                  "(min %.2f, step %.2f).", InpLot, g_lot, vmin, vstep);

   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.SetDeviationInPoints(20);
   g_trade.LogLevel(LOG_LEVEL_ERRORS);

   //--- The chart period is not used for anything, so say so rather than let it
   //--- look as though the EA inherited it.
   PrintFormat("PO3 Scalper: %s, %.2f lots per leg%s. "
               "Track A PO3 9 on %s ($%.2f grid), track B PO3 27 on %s ($%.2f grid). "
               "%s"
               "The chart timeframe is not read.",
               _Symbol, g_lot, InpRunner ? ", runner on" : ", single leg",
               g_tr[0].on ? StringSubstr(EnumToString(g_tr[0].tf), 7) : "off",
               PO3Step(GRID_9, InpScale),
               g_tr[1].on ? StringSubstr(EnumToString(g_tr[1].tf), 7) : "off",
               PO3Step(GRID_27, InpScale),
               InpMaxRangeP9 > 0.0
                  ? StringFormat("Candles taller than $%.2f are skipped as too volatile. ",
                                 InpMaxRangeP9 * PO3Step(GRID_9, InpScale))
                  : "The candle height cap is off. ");

   PrintFormat("PO3 Scalper: stops are %s; %s.",
               InpVerifyStops ? "read back off the position and repaired if the "
                                "broker dropped them"
                              : "NOT verified after the fill",
               InpFridayFlatten >= 0
                  ? StringFormat("open positions are closed at %02d:00 server time "
                                 "on Friday", InpFridayFlatten)
                  : "positions are left to ride the weekend");

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   for(int k = 0; k < TRACKS; k++)
      if(g_tr[k].atr != INVALID_HANDLE)
         IndicatorRelease(g_tr[k].atr);
   Comment("");
   //--- signal marks are left on the chart deliberately: they are the record of
   //--- what the EA saw, and a recompile should not wipe it
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   //--- Not gated on the track being on: switching a track off with a runner
   //--- already open would otherwise strand it without its break-even.
   for(int k = 0; k < TRACKS; k++)
      ManageRunner(g_tr[k]);

   Panel();

   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)
      || !MQLInfoInteger(MQL_TRADE_ALLOWED)
      || !AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
      return;

   //--- Before anything else on a Friday afternoon: be flat. A stop bounds a
   //--- loss only while the market is trading through it, and the weekend gap
   //--- opens past it rather than at it.
   if(PastFridayCutoff())
     {
      int held = 0;
      for(int k = 0; k < TRACKS; k++)
         held += LegCount(g_tr[k].magic) + LegCount(g_tr[k].magic + 1);
      if(held == 0)
         return;

      int shut = CloseAllEA("flat before the weekend");
      if(shut > 0)
         PrintFormat("PO3: past %02d:00 Friday, closed %d position(s) and stopped "
                     "opening until the new week.", InpFridayFlatten, shut);
      return;
     }

   bool window = InWindow();
   int  sprd   = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   bool wide   = (InpMaxSpreadPts > 0 && sprd > InpMaxSpreadPts);

   for(int k = 0; k < TRACKS; k++)
     {
      if(!g_tr[k].on)
         continue;

      //--- Each track keeps its own bar clock, so the M1 track is not held back
      //--- waiting on an M5 close and neither is tied to the chart period.
      datetime t = iTime(_Symbol, g_tr[k].tf, 0);
      if(t == 0 || t == g_tr[k].lastBar)
         continue;
      g_tr[k].lastBar = t;

      if(!window || DayCapReached(g_tr[k]))
         continue;

      if(wide)
        {
         if(InpVerbose)
            PrintFormat("PO3 %I64d: spread %d over the %d allowed, sitting out this candle.",
                        g_tr[k].grid, sprd, InpMaxSpreadPts);
         continue;
        }

      //--- one setup at a time per track, so a stop and its target belong to
      //--- one candle
      if(LegCount(g_tr[k].magic) > 0 || LegCount(g_tr[k].magic + 1) > 0)
         continue;

      Scan(g_tr[k]);
     }
  }
//+------------------------------------------------------------------+
