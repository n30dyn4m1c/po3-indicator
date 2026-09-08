//+------------------------------------------------------------------+
//|                                                    PO3_Kihon.mqh |
//|                                                                  |
//|  Kihon suchi, Ichimoku's basic time numbers, and the candle      |
//|  count they are read against.                                    |
//|                                                                  |
//|  The count is inclusive at both ends: the candle you start from  |
//|  is candle 1, not candle 0. That one convention is the whole of  |
//|  the arithmetic below, so it is worth stating plainly. Two       |
//|  17-spans laid end to end do not make 34, because the last       |
//|  candle of the first span IS the first candle of the second:     |
//|  17 + 17 - 1 = 33. Every compound number is built that way, by   |
//|  chaining simple spans that share their turning candle.          |
//|                                                                  |
//|  THE SIMPLE NUMBERS (tanjun kihon suchi) - 9, 17, 26             |
//|                                                                  |
//|    9   ichi-moku, the span the Tenkan is built on                |
//|    17  9 + 9 - 1                                                 |
//|    26  GIVEN, not derived. The Kijun span and the cloud          |
//|        displacement, and historically a month of trading days    |
//|        under the six-day week Japan kept when this was written.  |
//|        It is the one number the overlap rule does not produce -  |
//|        see the note below.                                       |
//|                                                                  |
//|  THE COMPOUND NUMBERS (fukugo kihon suchi)                       |
//|                                                                  |
//|    33   17 + 17 - 1                                              |
//|    42   26 + 17 - 1                                              |
//|    51   26 + 26 - 1                                              |
//|    65   33 + 33 - 1        (four 17s chained)                    |
//|    76   26 + 26 + 26 - 2   (also 51 + 26 - 1)                    |
//|    129  65 + 65 - 1                                              |
//|    172  65 + 42 + 42 + 26 - 3                                    |
//|    226  76 + 76 + 76 - 2                                         |
//|    257  129 + 129 - 1                                            |
//|                                                                  |
//|  26 is the exception, not 172. Every compound above chains       |
//|  simple spans sharing a candle, so k spans subtract k-1. 26 does |
//|  not come out that way: three 9s chained give 9+9+9-2 = 25, and  |
//|  17+9-1 is 25 as well. Reaching 26 needs either a plain 9+17     |
//|  with no shared candle or 9+9+9-1 with one overlap too few, and  |
//|  neither is the rule. That is expected - 26 is one of the three  |
//|  SIMPLE numbers, and a simple number is a given, not a result.   |
//|  It is a calendar figure that the rule then builds on.           |
//|                                                                  |
//|  An earlier version of this file claimed 172 was the outlier and |
//|  wrote it as the plain sum 65 + 65 + 42. That sum is right, but  |
//|  172 chains perfectly well as 65 + 42 + 42 + 26 - 3: four spans, |
//|  three shared candles. 172 obeys the rule. 26 is the one that    |
//|  does not, and it is the one that never claimed to.              |
//|                                                                  |
//|  Above 257 the series keeps doubling - 257 + 257 - 1 = 513 - but |
//|  a number that large has no meaning on an intraday chart, where  |
//|  even 257 M1 candles is only a little over four hours. The list  |
//|  stops where the classical one stops.                            |
//|                                                                  |
//|  What the numbers are FOR: they are candidate turning points in  |
//|  time, not in price. Counting from a swing, or from the session  |
//|  open, candle 9, 17, 26, 33 and so on are where a move is due to |
//|  change character. They say nothing about direction. Read them   |
//|  against the PO3 grid in PO3_Core.mqh: a kihon suchi candle      |
//|  landing on a 27 or 81 level is time and price agreeing, which   |
//|  is the only reason both files are in this project.              |
//|                                                                  |
//|  Kept apart from any one program, for the same reason            |
//|  PO3_Core.mqh is: the indicator and the EA must not drift onto   |
//|  different numbers.                                              |
//+------------------------------------------------------------------+
#ifndef __PO3_KIHON_MQH__
#define __PO3_KIHON_MQH__

//--- 3 simple + 9 compound. The simple ones come first and the whole list is
//--- ascending, so a scan can stop early and the first KIHON_SIMPLE entries
//--- are exactly the simple numbers.
#define KIHON_SIMPLE   3
#define KIHON_COUNT    12

const int KihonNumbers[KIHON_COUNT] =
  {
   9, 17, 26,                                   // simple
   33, 42, 51, 65, 76, 129, 172, 226, 257       // compound
  };

//+------------------------------------------------------------------+
//| Is n a kihon suchi number, and which kind.                       |
//|                                                                  |
//| The compound flag is a filter, not a separate list: pass false   |
//| and only 9, 17 and 26 answer true, which is the quiet chart.     |
//+------------------------------------------------------------------+
bool KihonIs(const int n, const bool withCompound = true)
  {
   int last = withCompound ? KIHON_COUNT : KIHON_SIMPLE;
   for(int i = 0; i < last; i++)
     {
      if(KihonNumbers[i] == n)
         return(true);
      if(KihonNumbers[i] > n)               // ascending, so no point going on
         break;
     }
   return(false);
  }

//--- a number is simple when it is one of the first KIHON_SIMPLE entries
bool KihonIsSimple(const int n)
  {
   return(KihonIs(n, false));
  }

//+------------------------------------------------------------------+
//| The next kihon suchi number strictly above n, or 0 past the end. |
//|                                                                  |
//| Strictly above, so standing ON 26 tells you 33 is next rather    |
//| than repeating the number you are already on.                    |
//+------------------------------------------------------------------+
int KihonNext(const int n, const bool withCompound = true)
  {
   int last = withCompound ? KIHON_COUNT : KIHON_SIMPLE;
   for(int i = 0; i < last; i++)
      if(KihonNumbers[i] > n)
         return(KihonNumbers[i]);
   return(0);
  }

//--- the last kihon suchi number at or below n, or 0 below the first
int KihonAtOrBelow(const int n, const bool withCompound = true)
  {
   int last = withCompound ? KIHON_COUNT : KIHON_SIMPLE;
   int best = 0;
   for(int i = 0; i < last; i++)
      if(KihonNumbers[i] <= n)
         best = KihonNumbers[i];
      else
         break;
   return(best);
  }

//+------------------------------------------------------------------+
//| Signed distance from n to the NEAREST kihon suchi number.        |
//|                                                                  |
//| 0 means n is one. Negative means the number is still ahead: 7    |
//| returns -2, two candles short of 9. Positive means it has just   |
//| gone by: 11 returns +2, two candles past 9.                      |
//|                                                                  |
//| The sign convention is n minus the number, so it reads the way   |
//| the chart does - a count running up towards a level shows a      |
//| negative gap closing to zero, then goes positive as it leaves.   |
//|                                                                  |
//| Nearest, not next, because either side matters. A count two      |
//| candles PAST 26 is as much "around 26" as one two candles short  |
//| of it, and a turn that was due at 26 is not cancelled by the     |
//| candle after it.                                                 |
//+------------------------------------------------------------------+
int KihonOffset(const int n, const bool withCompound = true)
  {
   int last = withCompound ? KIHON_COUNT : KIHON_SIMPLE;
   int best = n - KihonNumbers[0];

   for(int i = 1; i < last; i++)
     {
      int d  = n - KihonNumbers[i];
      int ad = (d    < 0) ? -d    : d;
      int ab = (best < 0) ? -best : best;
      if(ad < ab)
         best = d;
     }
   return(best);
  }

//+------------------------------------------------------------------+
//| Where the candle count starts.                                   |
//+------------------------------------------------------------------+
enum ENUM_KIHON_ANCHOR
  {
   KIHON_ANCHOR_DAY   = 0,  // Day open (the D1 candle)
   KIHON_ANCHOR_WEEK  = 1,  // Week open
   KIHON_ANCHOR_MONTH = 2,  // Month open (the 1st)
   KIHON_ANCHOR_YEAR  = 3,  // Year open (1 January)
   KIHON_ANCHOR_TIME  = 4   // Custom time of day (server)
  };

//--- Ceiling on how many candles a count will chase. Past 257 every count
//--- reads the same - there is no kihon number above it - so an exact figure
//--- buys nothing, while getting one forces the history to load: a year anchor
//--- on M1 is a third of a million candles, asked for once a second by the
//--- panel. Beyond this the count reports "too far" instead. Deliberately far
//--- above 257 so a legitimate deep count, a week of M1 at around 7200, is
//--- still counted exactly.
#define KIHON_SPAN_CAP  20000

//+------------------------------------------------------------------+
//| Midnight on the first day of the current server month, or of     |
//| the current server year.                                         |
//|                                                                  |
//| Built from the calendar rather than from a bar. There is no      |
//| yearly candle to read a year off, and the monthly candle would   |
//| only tell you what the calendar already does. Counts against     |
//| these therefore start at the first candle that OPENS inside the  |
//| period: a weekly candle straddling New Year belongs to the old   |
//| year, which is the same rule the day and week anchors follow.    |
//+------------------------------------------------------------------+
datetime KihonPeriodOpen(const bool year)
  {
   MqlDateTime st;
   TimeToStruct(TimeCurrent(), st);

   if(year)
      st.mon = 1;
   st.day  = 1;
   st.hour = 0;
   st.min  = 0;
   st.sec  = 0;

   //--- day_of_week and day_of_year are ignored by StructToTime, so the
   //--- stale values left in the struct cannot move the result
   return(StructToTime(st));
  }

//+------------------------------------------------------------------+
//| The time the count starts from.                                  |
//|                                                                  |
//| Day and week open come from the D1 and W1 bars themselves, so    |
//| they follow the broker's own day boundary rather than a guess at |
//| it - on a five-decimal broker rolling at 00:00 server that is    |
//| midnight, on a New York close broker it is not, and the bar      |
//| knows which.                                                     |
//|                                                                  |
//| A custom time is today's date at that hour and minute, rolled    |
//| back a day if it has not come round yet, and then CLAMPED to the |
//| day open. The clamp is the part worth explaining: without it, an |
//| 08:00 London anchor read at 03:00 on Monday would roll back to   |
//| 08:00 on FRIDAY and count the whole weekend gap. Clamping means  |
//| a session anchor never counts across a day boundary - before     |
//| the session opens you get the count from the day open, and the   |
//| moment it opens the count restarts from there.                   |
//+------------------------------------------------------------------+
datetime KihonAnchor(const string sym, const ENUM_KIHON_ANCHOR mode,
                     const int hour = 0, const int minute = 0)
  {
   datetime day = iTime(sym, PERIOD_D1, 0);

   if(mode == KIHON_ANCHOR_WEEK)
      return(iTime(sym, PERIOD_W1, 0));
   if(mode == KIHON_ANCHOR_MONTH)
      return(KihonPeriodOpen(false));
   if(mode == KIHON_ANCHOR_YEAR)
      return(KihonPeriodOpen(true));
   if(mode == KIHON_ANCHOR_DAY || day == 0)
      return(day);

   //--- Midnight of the current server day, then the wanted time of day. The
   //--- arithmetic is done in long rather than on datetime: a datetime is
   //--- unsigned, so an intermediate that goes below zero would wrap to the
   //--- far end of the epoch instead of clamping.
   long now = (long)TimeCurrent();
   long mid = now - (now % 86400);
   long h   = (hour   < 0) ? 0 : (hour   > 23 ? 23 : hour);
   long m   = (minute < 0) ? 0 : (minute > 59 ? 59 : minute);
   long at  = mid + h * 3600 + m * 60;

   if(at > now)
      at -= 86400;                    // that time of day has not come round yet

   return((datetime)at < day ? day : (datetime)at);
  }

//+------------------------------------------------------------------+
//| How many candles of this timeframe have printed since the        |
//| anchor, on the inclusive rule: the candle at the anchor is 1, so |
//| the developing candle carries the number this returns. Bar       |
//| indices run unbroken, so candle 1 sits at shift (count - 1).     |
//|                                                                  |
//| Returns 0 when the answer is not known yet - history still       |
//| loading, or the anchor older than the bars this chart holds -    |
//| so a caller can tell "nothing to show" from "candle zero", which |
//| does not exist under inclusive counting. Returns -1 when the     |
//| anchor is further back than KIHON_SPAN_CAP periods, which is a   |
//| refusal rather than a failure: the count is knowable, it is just |
//| not worth the history load to know it exactly.                   |
//|                                                                  |
//| Bars() over the window rather than iBarShift() on the anchor.    |
//| The difference shows up whenever the anchor lands in a gap: a    |
//| day opening at 00:00 whose first M1 candle is 00:01 has no       |
//| candle at the anchor, and iBarShift with exact=false answers     |
//| with the nearest EARLIER bar, which is last night's close. That  |
//| would put candle 1 on the wrong side of the open and shift every |
//| kihon mark by one. Bars() counts open times inside the window,   |
//| so a candle before the anchor is simply not in it.               |
//+------------------------------------------------------------------+
int KihonCount(const string sym, const ENUM_TIMEFRAMES tf, const datetime anchor)
  {
   if(anchor <= 0)
      return(0);

   datetime cur = iTime(sym, tf, 0);
   if(cur == 0)
      return(0);                       // history not ready on this timeframe
   if(anchor >= cur)
      return(1);                       // anchor falls inside the developing candle

   //--- Estimate the span before asking for the bars. Bars() over a window
   //--- this side of the cap is cheap; over a year of M1 it drags that whole
   //--- history in. The estimate is from elapsed time, so it ignores weekends
   //--- and overstates - which is the safe direction for a cost guard.
   int secs = PeriodSeconds(tf);
   if(secs > 0 && ((long)TimeCurrent() - (long)anchor) / secs > KIHON_SPAN_CAP)
      return(-1);

   //--- inclusive of both ends, and the developing candle's open time is
   //--- always at or before now, so it is the last one counted
   int n = Bars(sym, tf, anchor, TimeCurrent());
   return(n > 0 ? n : 0);
  }

//+------------------------------------------------------------------+
//| Where the current nested count restarts.                         |
//|                                                                  |
//| A count can be run inside another one: count H1 candles from the |
//| day open, and start the M1 count over at every H1 candle that is |
//| itself a kihon suchi number. Within one day that puts the resets |
//| at H1 candle 1, 9 and 17 - 26 needs a longer day than there is.  |
//| The finer count then answers "how far into this phase of the     |
//| session are we", instead of a number that only grows.            |
//|                                                                  |
//| Returns the open time of the candle the finer count restarts at, |
//| and sets segNo to that candle's number in the coarse count. Zero |
//| and segNo 0 when the coarse count is not known yet.              |
//|                                                                  |
//| Note that the reset happens AT the kihon candle, not after it:   |
//| on H1 candle 9 the segment starts at that same candle's open, so |
//| the M1 count reads 1 as the ninth hour opens.                    |
//+------------------------------------------------------------------+
datetime KihonSegmentStart(const string sym, const ENUM_TIMEFRAMES tf,
                           const datetime anchor, const bool withCompound,
                           int &segNo)
  {
   segNo = 0;

   int c = KihonCount(sym, tf, anchor);
   if(c <= 0)
      return(0);

   //--- Below the first kihon number the segment is the whole span so far, so
   //--- it starts at candle 1 - the anchor candle itself.
   segNo = KihonAtOrBelow(c, withCompound);
   if(segNo < 1)
      segNo = 1;

   //--- candle number segNo sits this far back from the developing candle
   return(iTime(sym, tf, c - segNo));
  }

#endif // __PO3_KIHON_MQH__
