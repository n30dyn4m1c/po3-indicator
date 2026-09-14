//+------------------------------------------------------------------+
//|                                             PO3_Kihon_Mailer.mq5 |
//|                                                                  |
//|  The kihon suchi timetable, as an email rather than as a panel.  |
//|                                                                  |
//|  PO3_Levels.mq5 draws this same timetable in its third block,    |
//|  which is the right place to read it from while you are at the   |
//|  chart. This is for when you are not: load it, it sends the      |
//|  week's kihon suchi candle opens to the address the terminal is  |
//|  configured with, and then it does nothing further until you     |
//|  ask again. It draws nothing and it places no orders.            |
//|                                                                  |
//|  It is an INDICATOR rather than an Expert Advisor for two        |
//|  reasons: a chart holds only one EA, and putting this in that    |
//|  slot would mean unloading whatever is trading there to send an  |
//|  email; and an indicator needs no Algo Trading permission, which |
//|  a thing that only ever sends text has no business asking for.   |
//|                                                                  |
//|  Every number, count and projection in it comes out of           |
//|  PO3_Kihon.mqh - the same functions the panel draws from - so    |
//|  the mail and the chart cannot disagree about when a candle      |
//|  opens.                                                          |
//|                                                                  |
//|  WHAT IT NEEDS FROM THE TERMINAL                                 |
//|                                                                  |
//|    Tools > Options > Email, filled in and ticked. MQL5 has no    |
//|    say in who the mail goes to: SendMail() sends to the "To"     |
//|    address in that dialog and there is no argument to override   |
//|    it. Put the calendar's address there.                         |
//+------------------------------------------------------------------+
#property copyright "PO3 Levels"
#property version   "1.00"
#property description "Emails the Ichimoku kihon suchi timetable for gold: every 9, 17, 26 and"
#property description "33 candle open this week on D1 down to M15, in server time and UTC, with"
#property description "the instants two or more timeframes share called out separately."
#property description "Monday to Friday only, and Friday's London session dropped. Sends and stops."
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include "PO3_Kihon.mqh"

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input group "What goes in the mail";
//--- The week list is the point of the thing: five timeframes counted from one
//--- week open, so their times can be read against each other. The today list
//--- is a convenience for a mail sent mid-session and is empty by definition on
//--- a Sunday, when the day it would describe has not started.
input bool InpMailWeek     = true;    // This week's kihon candles, D1 down to M15
input bool InpMailDay      = true;    // Also what is still ahead today
//--- Off by default because the mail is a diary and a diary is about what has
//--- not happened yet. On for the fuller reading: what the market did at the
//--- last number is the only evidence there is about the next one.
input bool InpMailPassed   = false;   // Include the numbers already gone
input bool InpMailCompound = true;    // Include the compound numbers (33)
//--- Two timeframes arriving at one instant is the agreement the timetable is
//--- for, and a week list is twenty rows where the confluences are usually
//--- four or five. Set 0 to leave the section out.
input int  InpConfluence   = 2;       // Call out an instant shared by this many timeframes

input group "Filters";
input bool InpWeekdaysOnly  = true;   // Monday to Friday only
input bool InpFriSkipLondon = true;   // Drop Friday's London session
input bool InpAnySymbol     = false;  // Allow a chart that is not gold

input group "Sessions";
//--- Every window below is given in ITS OWN CITY'S clock, and converted with
//--- that city's own daylight saving rule: London by the UK's dates, New York
//--- by the United States', Tokyo by neither because Japan keeps none. That is
//--- the only way a session window stays put. Written in UTC instead, London
//--- would wander by an hour in March and New York by an hour in November, and
//--- for three weeks each spring the two would be wrong in opposite
//--- directions - which is exactly the stretch of the year the overlap
//--- matters most.
//---
//--- The London window does double duty: it is both the session a row is
//--- labelled with and the one Friday is cleared of, so the two cannot come to
//--- mean different things. If London Open means the narrower open to you -
//--- the first three hours rather than the whole session - set the close to 11
//--- and both follow.
input int  InpTokyoOpen     = 9;      // Tokyo opens (hour, Tokyo time)
input int  InpTokyoClose    = 18;     // Tokyo closes (hour, Tokyo time)
input int  InpLondonOpen    = 8;      // London Open starts (hour, London time)
input int  InpLondonClose   = 17;     // London Open ends (hour, London time)
input int  InpNyOpen        = 8;      // New York opens (hour, New York time)
input int  InpNyClose       = 17;     // New York closes (hour, New York time)

input group "Sending";
input bool   InpSendMail  = true;     // Send it by email
input bool   InpWriteFile = true;     // Also write it to MQL5/Files
//--- Loading it is the request. It waits for the history it needs, sends once,
//--- and then sits idle - so the way to send another is to reload it, or press
//--- the key below.
input bool   InpOnLoad    = true;     // Send as soon as the history is ready
input bool   InpWeekly    = false;    // Send again when a new week opens
input string InpHotkey    = "M";      // Press this on the chart to send again ("" for none)

//+------------------------------------------------------------------+
//| One line of the timetable.                                       |
//|                                                                  |
//| srv is the candle's OPEN in server time, which is the clock the  |
//| terminal stamps every bar with and the one the chart panel       |
//| prints. Everything else in the mail is derived from it.          |
//|                                                                  |
//| proj says the time was projected rather than read off a bar that |
//| exists, and is the difference between a time you can hold the    |
//| broker to and an estimate. state is 0 gone by, 1 running now,    |
//| 2 still ahead.                                                   |
//+------------------------------------------------------------------+
struct MailRow
  {
   ENUM_TIMEFRAMES   tf;
   int               num;
   datetime          srv;
   bool              proj;
   int               state;
  };

//--- Set once per send, in MailFire, and read all through the build. Seconds
//--- the trade server runs ahead of UTC.
long     g_off  = 0;

//--- The week anchor the last mail went out on, so InpWeekly can tell a new
//--- week from another tick of the same one.
datetime g_sent = 0;

//--- Retry budget for the history. The timer ticks once a second; a minute is
//--- long enough for five timeframes to arrive and short enough that a chart
//--- that is never going to produce them stops asking.
int      g_tries = 0;
#define MAIL_TRIES 60

//--- Set when the load send has finished with, either because it went or
//--- because it ran out of patience. Kept apart from g_sent because the two
//--- answer different questions: this one is "stop trying", g_sent is "which
//--- week went out", and a failed send must not leave a week anchor behind
//--- that the weekly check would then read as a week already sent.
bool     g_done = false;

//+------------------------------------------------------------------+
//| How far the trade server runs ahead of UTC, in seconds.          |
//|                                                                  |
//| TimeTradeServer rather than TimeCurrent, and the distinction is  |
//| the whole reason this function has a comment. TimeCurrent is the |
//| time of the last quote, so on a closed market it is stuck at     |
//| Friday's close - and a mail written on Sunday would work out the |
//| offset as two days. TimeTradeServer is calculated rather than    |
//| quoted and keeps running through the weekend, which is exactly   |
//| when this is meant to be used.                                   |
//|                                                                  |
//| Rounded to the minute. The two clocks are read a moment apart    |
//| and no broker offset has ever been a matter of seconds.          |
//+------------------------------------------------------------------+
long MailServerOffset()
  {
   long d = (long)TimeTradeServer() - (long)TimeGMT();

   //--- Rounded half away from zero, so a -7199 does not become -119 minutes.
   long m = (d >= 0) ? (d + 30) / 60 : (d - 30) / 60;

   return(m * 60);
  }

//--- server time to UTC, and the ISO 8601 spelling a calendar will take
datetime MailUtc(const datetime srv)
  {
   return((datetime)((long)srv - g_off));
  }

string MailIso(const datetime utc)
  {
   MqlDateTime st;
   TimeToStruct(utc, st);

   return(StringFormat("%04d-%02d-%02dT%02d:%02d:%02dZ",
                       st.year, st.mon, st.day, st.hour, st.min, st.sec));
  }

//--- the offset written the way a timezone is, "+03:00"
string MailOffsetText()
  {
   long m = g_off / 60;
   string sign = (m < 0) ? "-" : "+";
   if(m < 0)
      m = -m;

   return(StringFormat("%s%02d:%02d", sign, (int)(m / 60), (int)(m % 60)));
  }

//+------------------------------------------------------------------+
//| 01:00 UTC on the last Sunday of a month.                         |
//|                                                                  |
//| Both months this is ever asked about - March and October - have  |
//| 31 days, so the walk back can start at the 31st without checking |
//| the month length.                                                |
//+------------------------------------------------------------------+
datetime MailLastSunday(const int year, const int mon)
  {
   MqlDateTime st;
   ZeroMemory(st);

   st.year = year;
   st.mon  = mon;
   st.day  = 31;
   st.hour = 1;

   datetime t = StructToTime(st);

   MqlDateTime back;
   TimeToStruct(t, back);

   //--- day_of_week is 0 on a Sunday, so this is a no-op when the 31st already
   //--- is one and otherwise steps back the few days to the one before it.
   return((datetime)((long)t - (long)back.day_of_week * 86400));
  }

//+------------------------------------------------------------------+
//| London's offset from UTC at that instant, in seconds.            |
//|                                                                  |
//| Worked out rather than configured. The session window below is   |
//| given in London time because "the London session" is a statement |
//| about London's clock, and London's clock moves twice a year - so |
//| a window converted once at load would be an hour out for half of |
//| the year. BST runs from 01:00 UTC on the last Sunday of March to |
//| 01:00 UTC on the last Sunday of October.                         |
//+------------------------------------------------------------------+
int MailLondonOffset(const datetime utc)
  {
   MqlDateTime st;
   TimeToStruct(utc, st);

   datetime from = MailLastSunday(st.year, 3);
   datetime to   = MailLastSunday(st.year, 10);

   return((utc >= from && utc < to) ? 3600 : 0);
  }

//+------------------------------------------------------------------+
//| The nth Sunday of a month, at a given hour UTC.                  |
//|                                                                  |
//| The United States moves its clocks on ordinal Sundays rather     |
//| than the last one, so this counts forward from the 1st where     |
//| MailLastSunday counts back from the 31st.                        |
//+------------------------------------------------------------------+
datetime MailNthSunday(const int year, const int mon, const int nth,
                       const int hour)
  {
   MqlDateTime st;
   ZeroMemory(st);

   st.year = year;
   st.mon  = mon;
   st.day  = 1;
   st.hour = hour;

   datetime t = StructToTime(st);

   MqlDateTime first;
   TimeToStruct(t, first);

   //--- day_of_week is 0 on a Sunday, so a month starting on one needs no
   //--- step at all and any other needs the days left to the coming Sunday.
   int step = (first.day_of_week == 0) ? 0 : (7 - first.day_of_week);

   return((datetime)((long)t + (long)(step + 7 * (nth - 1)) * 86400));
  }

//+------------------------------------------------------------------+
//| New York's offset from UTC at that instant, in seconds.          |
//|                                                                  |
//| The United States changes on different dates from the UK - two   |
//| or three weeks earlier in the spring and a week later in the     |
//| autumn - and for those weeks the London-New York overlap is an   |
//| hour off where it usually sits. A session table that used one    |
//| rule for both cities would mislabel every row in them.           |
//|                                                                  |
//| EDT from 02:00 local on the second Sunday of March, which is     |
//| 07:00 UTC while the clock is still EST, to 02:00 local on the    |
//| first Sunday of November, which is 06:00 UTC while it is still   |
//| EDT.                                                             |
//+------------------------------------------------------------------+
int MailNyOffset(const datetime utc)
  {
   MqlDateTime st;
   TimeToStruct(utc, st);

   datetime from = MailNthSunday(st.year, 3, 2, 7);
   datetime to   = MailNthSunday(st.year, 11, 1, 6);

   return((utc >= from && utc < to) ? -4 * 3600 : -5 * 3600);
  }

//+------------------------------------------------------------------+
//| Is this hour inside a session window.                            |
//|                                                                  |
//| Half open at the close, so a candle opening exactly on it is the |
//| first one after the session rather than the last one in it.      |
//| A window whose close is below its open runs through midnight and |
//| is read the other way round, which is not the default for any of |
//| the three but is what a Tokyo window set the usual 23:00-08:00   |
//| way would need.                                                  |
//+------------------------------------------------------------------+
bool MailInWindow(const int hour, const int from, const int to)
  {
   if(from == to)
      return(false);

   if(from < to)
      return(hour >= from && hour < to);

   return(hour >= from || hour < to);
  }

//+------------------------------------------------------------------+
//| Which session or sessions this candle opens in.                  |
//|                                                                  |
//| Sessions overlap and the overlap is the part worth knowing: the  |
//| London-New York hours are where the volume is, and a kihon       |
//| candle landing in them is a different proposition from the same  |
//| number landing in a thin Tokyo hour. So a row can carry two      |
//| names, joined, rather than being forced into one bucket.         |
//|                                                                  |
//| Tokyo is UTC+9 the whole year round. Japan has kept no daylight  |
//| saving since 1951, so there is no rule to apply and none is.     |
//+------------------------------------------------------------------+
string MailSession(const datetime srv)
  {
   datetime utc = MailUtc(srv);

   MqlDateTime t;
   TimeToStruct((datetime)((long)utc + 9 * 3600), t);

   MqlDateTime l;
   TimeToStruct((datetime)((long)utc + MailLondonOffset(utc)), l);

   MqlDateTime n;
   TimeToStruct((datetime)((long)utc + MailNyOffset(utc)), n);

   string out = "";

   if(MailInWindow(t.hour, InpTokyoOpen, InpTokyoClose))
      out += "Tokyo";

   if(MailInWindow(l.hour, InpLondonOpen, InpLondonClose))
      out += ((out == "") ? "" : "+") + "LondonOpen";

   if(MailInWindow(n.hour, InpNyOpen, InpNyClose))
      out += ((out == "") ? "" : "+") + "NewYork";

   //--- Not an error and not a gap in the table. Gold trades around the clock,
   //--- and the hours between the New York close and the Tokyo open are real
   //--- hours in which real candles open - they just belong to no session.
   return((out == "") ? "-" : out);
  }

//+------------------------------------------------------------------+
//| Does this candle open belong in the mail.                        |
//|                                                                  |
//| Two cuts, and they are made on two different clocks on purpose.  |
//|                                                                  |
//| Monday to Friday is judged in SERVER time, because that is the   |
//| clock the candle is stamped in and the one the chart panel       |
//| prints - a row dropped here is a row you can see was dropped.    |
//| On the usual gold broker, at UTC+2 or UTC+3, the trading week    |
//| already starts on a server Monday, which is the offset's whole   |
//| point.                                                           |
//|                                                                  |
//| Friday's London session is judged in LONDON time, because that   |
//| is what the words mean.                                          |
//+------------------------------------------------------------------+
bool MailKeep(const datetime srv)
  {
   if(srv <= 0)
      return(false);

   MqlDateTime st;
   TimeToStruct(srv, st);

   if(InpWeekdaysOnly && (st.day_of_week == 0 || st.day_of_week == 6))
      return(false);

   if(InpFriSkipLondon)
     {
      datetime utc = MailUtc(srv);
      datetime lon = (datetime)((long)utc + MailLondonOffset(utc));

      MqlDateTime lt;
      TimeToStruct(lon, lt);

      //--- Half open: a candle opening exactly at the close is the first one
      //--- after the session, not the last one in it.
      if(lt.day_of_week == 5 && lt.hour >= InpLondonOpen && lt.hour < InpLondonClose)
         return(false);
     }

   return(true);
  }

//+------------------------------------------------------------------+
//| The week open the mail is about, and whether it is a week that   |
//| has not started yet.                                             |
//|                                                                  |
//| This is the part a Sunday run turns on. iTime(W1, 0) is the      |
//| newest weekly bar, and on a Sunday afternoon that is the week    |
//| that has just FINISHED - so a mail built from it straight would  |
//| be last week's timetable, every row of it already gone.          |
//|                                                                  |
//| So: if it is the weekend in server time and that bar opened      |
//| before this weekend began, the week it covers is over and the    |
//| one worth writing about is the next. Its open is that bar plus   |
//| seven days, which is where the next weekly candle starts.        |
//|                                                                  |
//| The test is written that way round - "opened before this         |
//| weekend" rather than "it is the weekend" - because a broker      |
//| quoting from Sunday evening has ALREADY opened the new weekly    |
//| bar by the time some Sunday runs happen, and stepping that on    |
//| another seven days would skip a week.                            |
//|                                                                  |
//| A week that has not started has no candles in it to read, so     |
//| every row it produces is a projection from the open itself.      |
//+------------------------------------------------------------------+
datetime MailWeekAnchor(bool &fresh)
  {
   fresh = false;

   datetime wk = iTime(_Symbol, PERIOD_W1, 0);
   if(wk <= 0)
      return(0);

   datetime now = TimeTradeServer();

   MqlDateTime st;
   TimeToStruct(now, st);

   if(st.day_of_week != 0 && st.day_of_week != 6)
      return(wk);                              // mid-week: the bar is the week

   //--- Midnight at the start of this weekend, server time: today's midnight
   //--- on a Saturday, yesterday's on a Sunday.
   long mid = (long)now - ((long)now % 86400);
   long sat = mid - ((st.day_of_week == 0) ? 86400 : 0);

   if((long)wk <= sat)
     {
      fresh = true;
      return((datetime)((long)wk + 7 * 86400));
     }

   return(wk);                                 // the new week is already open
  }

//+------------------------------------------------------------------+
//| Where candle k of this timeframe opens, counted from the anchor. |
//|                                                                  |
//| Three cases, and the flags say which. A candle that has printed  |
//| has its time read off the bar - exact, with the session breaks   |
//| and the holidays already in it. A candle past the count is       |
//| stepped forward from the developing one. A week that has not     |
//| started has no developing candle either, so the walk starts at   |
//| the anchor itself, which is candle 1 under inclusive counting.   |
//+------------------------------------------------------------------+
datetime MailWhen(const ENUM_TIMEFRAMES tf, const int k, const int c,
                  const datetime anchor, bool &proj, int &state)
  {
   int secs = PeriodSeconds(tf);

   if(c <= 0)                                  // the window has not opened yet
     {
      proj  = true;
      state = 2;
      return(SchedProject(_Symbol, anchor, k - 1, secs));
     }

   if(k <= c)
     {
      proj  = false;
      state = (k == c) ? 1 : 0;
      return(iTime(_Symbol, tf, c - k));
     }

   proj  = true;
   state = 2;
   return(SchedProject(_Symbol, iTime(_Symbol, tf, 0), k - c, secs));
  }

//--- the kihon numbers this mail is listing, 9 to 33 or 9 to 26
int MailLastNumber()
  {
   return(KihonAtOrBelow(SCH_LAST, InpMailCompound));
  }

//+------------------------------------------------------------------+
//| Append one timeframe's numbers to the list.                      |
//|                                                                  |
//| Rows are filtered as they are built rather than afterwards, so a |
//| timeframe whose every candle falls in Friday's London session    |
//| contributes nothing at all instead of an empty heading.          |
//+------------------------------------------------------------------+
void MailAddWeek(const ENUM_TIMEFRAMES tf, const datetime anchor,
                 const bool fresh, MailRow &rows[])
  {
   int c    = fresh ? 0 : KihonCount(_Symbol, tf, anchor);
   int last = InpMailCompound ? KIHON_COUNT : KIHON_SIMPLE;

   //--- A live week whose count is not known yet is history still arriving.
   //--- Nothing can be said about it, and MailReady holds the send back until
   //--- it can be, so this is only ever reached on a timeframe that failed.
   if(!fresh && c <= 0)
      return;

   for(int i = 0; i < last; i++)
     {
      int k = KihonNumbers[i];
      if(k < SCH_FIRST || k > SCH_LAST)
         continue;

      MailRow r;
      r.tf  = tf;
      r.num = k;
      r.srv = MailWhen(tf, k, c, anchor, r.proj, r.state);

      if(r.state == 0 && !InpMailPassed)
         continue;
      if(!MailKeep(r.srv))
         continue;

      int n = ArraySize(rows);
      ArrayResize(rows, n + 1);
      rows[n] = r;
     }
  }

//+------------------------------------------------------------------+
//| The same, for the numbers still ahead today.                     |
//|                                                                  |
//| Strictly forward-looking and bounded by the day rather than by   |
//| the number window: a row is here because its candle opens before |
//| the day is out, not because it was near enough in the list.      |
//+------------------------------------------------------------------+
void MailAddDay(const ENUM_TIMEFRAMES tf, const datetime day, MailRow &rows[])
  {
   int c = KihonCount(_Symbol, tf, day);
   if(c <= 0)
      return;

   int      last = InpMailCompound ? KIHON_COUNT : KIHON_SIMPLE;
   datetime end  = (datetime)((long)day + 86400);
   datetime cur  = iTime(_Symbol, tf, 0);
   int      secs = PeriodSeconds(tf);

   for(int i = 0; i < last; i++)
     {
      int k = KihonNumbers[i];
      if(k < SCH_FIRST || k <= c)
         continue;                             // below the window, or gone by
      if(k > SCH_LAST)
         break;                                // ascending, so nothing after it

      datetime when = SchedProject(_Symbol, cur, k - c, secs);
      if(when <= 0 || when >= end)
         continue;                             // opens after today is out
      if(!MailKeep(when))
         continue;

      MailRow r;
      r.tf    = tf;
      r.num   = k;
      r.srv   = when;
      r.proj  = true;
      r.state = 2;

      int n = ArraySize(rows);
      ArrayResize(rows, n + 1);
      rows[n] = r;
     }
  }

//--- Earliest first. Insertion sort: the list is twenty-odd rows and already
//--- nearly ordered, being built one ascending timeframe at a time.
void MailSort(MailRow &rows[])
  {
   int n = ArraySize(rows);

   for(int i = 1; i < n; i++)
     {
      MailRow key = rows[i];
      int     j   = i - 1;

      while(j >= 0 && (long)rows[j].srv > (long)key.srv)
        {
         rows[j + 1] = rows[j];
         j--;
        }

      rows[j + 1] = key;
     }
  }

//--- one row, as a fixed-width line
string MailLine(const MailRow &r)
  {
   return(StringFormat("%-4s %3d  %-21s %s %-15s  %s  %-9s  %s",
                       TfNameOf(r.tf), r.num,
                       MailIso(MailUtc(r.srv)),
                       r.proj ? "~" : " ",
                       SchedWhen(r.srv),
                       (r.state == 0) ? "done" : ((r.state == 1) ? "NOW " : "due "),
                       r.proj ? "projected" : "exact",
                       MailSession(r.srv)));
  }

#define MAIL_HEAD "TF   NUM  UTC                     SERVER           WHEN  SOURCE     SESSION"

//+------------------------------------------------------------------+
//| How the list falls across the three sessions.                    |
//|                                                                  |
//| One line, and it is the first thing worth reading: a week whose  |
//| kihon candles are nearly all Tokyo hours is a different week to  |
//| plan than one stacked into the London-New York overlap, and the  |
//| table underneath takes a minute to see that in.                  |
//|                                                                  |
//| A candle in an overlap is counted under both names, so these do  |
//| not add up to the number of rows and are not meant to.           |
//+------------------------------------------------------------------+
string MailTally(const MailRow &rows[])
  {
   int tokyo = 0, london = 0, ny = 0, none = 0;

   for(int i = 0; i < ArraySize(rows); i++)
     {
      string ses = MailSession(rows[i].srv);

      if(ses == "-")
        {
         none++;
         continue;
        }

      if(StringFind(ses, "Tokyo") >= 0)
         tokyo++;
      if(StringFind(ses, "LondonOpen") >= 0)
         london++;
      if(StringFind(ses, "NewYork") >= 0)
         ny++;
     }

   return(StringFormat("  Tokyo %d, LondonOpen %d, NewYork %d, outside any %d"
                       "  (an overlap counts in both)\n",
                       tokyo, london, ny, none));
  }

//+------------------------------------------------------------------+
//| The instants two or more timeframes share.                       |
//|                                                                  |
//| The whole reason the week list counts all five timeframes from   |
//| ONE anchor: an H4 9 and an H1 26 at the same minute are two      |
//| counts arriving together, which is a different event from either |
//| of them arriving alone. Twenty rows is a wall; the four or five  |
//| instants that repeat in it are the reading.                      |
//|                                                                  |
//| Equality is exact. These are candle opens on nested timeframes,  |
//| so two that agree agree to the minute or are not the same        |
//| instant at all.                                                  |
//+------------------------------------------------------------------+
string MailConfluence(const MailRow &rows[])
  {
   int n = ArraySize(rows);
   if(InpConfluence < 2 || n < 2)
      return("");

   string out  = "";
   int    hits = 0;
   int    i    = 0;

   while(i < n)
     {
      int j = i;
      while(j < n && rows[j].srv == rows[i].srv)
         j++;

      if(j - i >= InpConfluence)
        {
         string tfs = "";
         for(int k = i; k < j; k++)
            tfs += StringFormat("%s%s %d", (k > i) ? ", " : "",
                                TfNameOf(rows[k].tf), rows[k].num);

         out += StringFormat("%-21s %s %-15s  %-20s  %s\n",
                             MailIso(MailUtc(rows[i].srv)),
                             rows[i].proj ? "~" : " ",
                             SchedWhen(rows[i].srv),
                             MailSession(rows[i].srv), tfs);
         hits++;
        }

      i = j;
     }

   if(hits == 0)
      return("CONFLUENCE\n  none - no instant in the list is shared by "
             + (string)InpConfluence + " timeframes\n");

   return("CONFLUENCE  " + (string)InpConfluence + "+ timeframes on one instant\n"
          + "UTC                     SERVER            SESSION               TIMEFRAMES\n"
          + out);
  }

//+------------------------------------------------------------------+
//| The mail itself.                                                 |
//|                                                                  |
//| Written to be read twice: once by a person skimming it on a      |
//| phone, and once by whatever puts it in a calendar. Hence both    |
//| clocks on every row - the UTC stamp is unambiguous and needs no  |
//| knowledge of the broker, the server stamp is what the chart      |
//| panel shows and what you would check it against.                 |
//|                                                                  |
//| The preamble states the offset it converted with, because that   |
//| is the one number a reader cannot recover from the rows and the  |
//| one that would silently poison every UTC stamp if it were wrong. |
//+------------------------------------------------------------------+
string MailBody(const datetime anchor, const bool fresh,
                MailRow &week[], MailRow &today[])
  {
   string s = "PO3 KIHON SUCHI TIMETABLE\n\n";

   s += StringFormat("symbol      %s\n", _Symbol);
   s += StringFormat("week open   %s server%s\n", SchedWhen(anchor),
                     fresh ? "  (the week ahead - it has not opened yet)" : "");
   s += StringFormat("            %s\n", MailIso(MailUtc(anchor)));
   s += StringFormat("written     %s server\n", SchedWhen(TimeTradeServer()));
   s += StringFormat("server-utc  %s\n", MailOffsetText());
   s += StringFormat("numbers     %d to %d\n", SCH_FIRST, MailLastNumber());

   s += "filters     ";
   s += InpWeekdaysOnly ? "Monday to Friday only" : "every day the symbol trades";
   if(InpFriSkipLondon)
      s += StringFormat("; Friday %02d:00-%02d:00 London dropped",
                        InpLondonOpen, InpLondonClose);
   s += "\n";

   s += StringFormat("sessions    Tokyo %02d:00-%02d:00 Tokyo, "
                     "LondonOpen %02d:00-%02d:00 London, "
                     "NewYork %02d:00-%02d:00 New York\n\n",
                     InpTokyoOpen, InpTokyoClose,
                     InpLondonOpen, InpLondonClose,
                     InpNyOpen, InpNyClose);

   s += "Every time is a candle OPEN. A ~ marks a projected time: that candle has\n"
        "not printed yet, so its open is stepped forward from the last one that\n"
        "did, skipping the days the symbol does not trade. Projections do not\n"
        "know the broker's daily maintenance break, so one crossing several days\n"
        "drifts by roughly that break per day crossed.\n\n"
        "The UTC column was converted with the offset above, read at the moment\n"
        "this was written. A row on the far side of a daylight saving change is\n"
        "out by an hour; the server column is the one the chart will agree with.\n\n"
        "The session column is worked out in each city's own clock, on that\n"
        "city's own daylight saving dates - London on the UK's, New York on the\n"
        "United States', Tokyo on none, because Japan keeps none. A candle in an\n"
        "overlap carries both names. A dash is a candle opening in none of the\n"
        "three, which on gold is an ordinary thing for it to do.\n\n";

   if(InpMailWeek)
     {
      s += StringFormat("WEEK  %d to %d counted from the week open, D1 down to M15\n",
                        SCH_FIRST, MailLastNumber());

      if(ArraySize(week) == 0)
         s += "  none left after the filters\n";
      else
        {
         s += MAIL_HEAD;
         s += "\n";
         for(int i = 0; i < ArraySize(week); i++)
            s += MailLine(week[i]) + "\n";

         s += "\n";
         s += MailTally(week);
        }

      s += "\n";

      string conf = MailConfluence(week);
      if(conf != "")
         s += conf + "\n";
     }

   if(InpMailDay)
     {
      s += "TODAY  still ahead, H1 down to M15\n";

      if(fresh)
         s += "  nothing - the week in this mail has not opened yet\n";
      else
         if(ArraySize(today) == 0)
            s += "  none left today after the filters\n";
         else
           {
            s += MAIL_HEAD;
            s += "\n";
            for(int i = 0; i < ArraySize(today); i++)
               s += MailLine(today[i]) + "\n";

            s += "\n";
            s += MailTally(today);
           }

      s += "\n";
     }

   s += "The count is arithmetic, not a signal. It says where a turn is due, never\n"
        "that one is happening and never which way.\n";

   return(s);
  }

//+------------------------------------------------------------------+
//| Is there enough history to say anything true.                    |
//|                                                                  |
//| Asked of every timeframe the mail will quote, because a mail     |
//| that went out with M15 missing would be a timetable with a hole  |
//| in it that nothing in the text would admit to. A week that has   |
//| not started needs no history at all - there is nothing in it to  |
//| read - so it is ready the moment the weekly bar is.              |
//+------------------------------------------------------------------+
bool MailReady(const datetime anchor, const bool fresh)
  {
   if(anchor <= 0)
      return(false);
   if(fresh)
      return(true);

   for(int i = 0; i < ArraySize(g_schWeek); i++)
      if(KihonCount(_Symbol, g_schWeek[i], anchor) <= 0)
         return(false);

   return(true);
  }

//+------------------------------------------------------------------+
//| Build it and send it.                                            |
//|                                                                  |
//| The file is written whether or not the mail goes, and written    |
//| second. A terminal with no SMTP set up is the ordinary case for  |
//| a first run, and losing the timetable to a configuration dialog  |
//| would be a poor way to find that out.                            |
//+------------------------------------------------------------------+
bool MailFire()
  {
   g_off = MailServerOffset();

   bool     fresh  = false;
   datetime anchor = MailWeekAnchor(fresh);

   if(!MailReady(anchor, fresh))
      return(false);

   MailRow week[];
   MailRow today[];

   if(InpMailWeek)
     {
      for(int i = 0; i < ArraySize(g_schWeek); i++)
         MailAddWeek(g_schWeek[i], anchor, fresh, week);
      MailSort(week);
     }

   if(InpMailDay && !fresh)
     {
      datetime day = iTime(_Symbol, PERIOD_D1, 0);
      for(int i = 0; i < ArraySize(g_schDay); i++)
         MailAddDay(g_schDay[i], day, today);
      MailSort(today);
     }

   string body = MailBody(anchor, fresh, week, today);
   string subj = StringFormat("PO3 kihon %s - week of %s - %d times",
                              _Symbol, TimeToString(anchor, TIME_DATE),
                              ArraySize(week) + ArraySize(today));

   if(InpSendMail)
     {
      if(SendMail(subj, body))
         Print("PO3 kihon mailer: sent - ", subj);
      else
         Print("PO3 kihon mailer: SendMail failed, error ", GetLastError(),
               ". Check Tools > Options > Email is filled in and ticked.");
     }

   if(InpWriteFile)
     {
      //--- Dashes rather than the dots TimeToString uses, so the only dot in
      //--- the name is the one before the extension.
      string date = TimeToString(anchor, TIME_DATE);
      StringReplace(date, ".", "-");

      string name = StringFormat("PO3_Kihon_%s_%s.txt", _Symbol, date);

      int h = FileOpen(name, FILE_WRITE | FILE_TXT | FILE_ANSI);
      if(h == INVALID_HANDLE)
         Print("PO3 kihon mailer: could not write ", name,
               ", error ", GetLastError());
      else
        {
         FileWriteString(h, body);
         FileClose(h);
         Print("PO3 kihon mailer: written to MQL5/Files/", name);
        }
     }

   g_sent = anchor;
   return(true);
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   string sym = _Symbol;
   StringToUpper(sym);

   //--- The projection walk reads the symbol's own session table and the
   //--- number window is sized for a gold week. Neither is wrong on another
   //--- instrument, but nothing here has been checked against one, so it says
   //--- so rather than quietly producing a timetable for something else.
   if(!InpAnySymbol && StringFind(sym, "XAU") < 0 && StringFind(sym, "GOLD") < 0)
     {
      Print("PO3 kihon mailer: ", _Symbol, " is not gold. Load it on a gold "
            "chart, or tick \"Allow a chart that is not gold\".");
      return(INIT_FAILED);
     }

   g_tries = 0;
   g_sent  = 0;
   g_done  = false;

   //--- A timer rather than ticks, and this is the load-bearing choice in the
   //--- file. The mail is meant to be sent on a Sunday, when a gold chart gets
   //--- no ticks at all - an indicator waiting on OnCalculate would sit there
   //--- until the market opened and then send a timetable a day late.
   EventSetTimer(1);

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
  }

//+------------------------------------------------------------------+
//| The timer: wait for the history, send, then stand down.          |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(InpOnLoad && !g_done)
     {
      if(MailFire())
        {
         g_done = true;
         return;
        }

      if(++g_tries >= MAIL_TRIES)
        {
         Print("PO3 kihon mailer: gave up waiting for history on ", _Symbol,
               ". Open a D1, H4, H1, M30 and M15 chart on it, or reload this.");
         g_done = true;
        }

      return;
     }

   if(!InpWeekly)
      return;

   bool     fresh  = false;
   datetime anchor = MailWeekAnchor(fresh);

   if(anchor <= 0)
      return;

   //--- Nothing has gone out yet, so there is no week to compare against.
   //--- Adopt this one rather than sending it: with the load send switched
   //--- off, "weekly" has to mean the NEXT week open, or it would mean now.
   if(g_sent == 0)
     {
      g_sent = anchor;
      return;
     }

   //--- A new week is a different anchor, which is the only thing that can
   //--- make the timetable worth sending again unasked.
   if(anchor != g_sent)
      MailFire();
  }

//+------------------------------------------------------------------+
//| The hotkey: send it again now.                                   |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam,
                  const string &sparam)
  {
   if(id != CHARTEVENT_KEYDOWN || InpHotkey == "")
      return;

   //--- lparam is a virtual key code, and for a letter key that is its
   //--- upper-case character code.
   string want = InpHotkey;
   StringToUpper(want);

   if(StringGetCharacter(want, 0) != (ushort)lparam)
      return;

   if(!MailFire())
      Print("PO3 kihon mailer: not enough history yet on ", _Symbol);
  }

//+------------------------------------------------------------------+
//| Draws nothing. It is an indicator for the chart slot it does not |
//| take, not for anything it puts on the chart.                     |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[],
                const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
  {
   return(rates_total);
  }
//+------------------------------------------------------------------+
