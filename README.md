# PO3 Levels & Kihon Suchi

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-MetaTrader%205-blue.svg)](https://www.metatrader5.com/)
[![Language](https://img.shields.io/badge/Language-MQL5-orange.svg)](https://www.mql5.com/)
[![Also](https://img.shields.io/badge/Also-Pine%20Script%20v5-green.svg)](https://www.tradingview.com/pine-script-docs/)

**MetaTrader 5 indicator that reads gold in price and in time: Power of Three (PO3) support and resistance levels, with a checkbox per PO3 number from 3 to 19683, and Ichimoku kihon suchi counts of the candles since the year, month, week and day opened. Ships as a TradingView Pine v5 port of the same indicator, and with an Expert Advisor that scalps rejections of the 9 and 27 grids.**

**Price.** Levels are multiples of powers of three — 3, 9, 27, 81, 243, 729,
2187, 6561, 19683 — drawn around current price. Nothing is fitted, optimised or
inferred from price action: a level either is a multiple of a power of three or
it is not.

**Time.** The same chart counts candles from the market open and marks the
kihon suchi numbers — 9, 17, 26, 33, 42, 51, 65, 76, 129, 172, 226, 257 — on
that count. These are Ichimoku's basic time numbers: candles at which a move is
due to change character. They are levels in time the way the grid is levels in
price, and they are just as unfitted — a candle either is the 26th since the
open or it is not.

The point of having both is where they meet. A kihon suchi candle printing on a
27 or 81 level is time and price agreeing, and neither half was tuned to make
that happen.

The MT5 indicator draws lines, text and counts only. It places no orders and
reads no account state, and nothing in it acts on the numbers it counts.

`PO3_Scalper.mq5` is the exception to "places no orders": it is an EA, and it
trades. The indicator it ships beside is unchanged and still draws only.

Based on the Power of Three / Goldbach level model taught by **Hopiplaka**, and
on the time theory (*jikan ron*) of Goichi Hosoda's Ichimoku Kinko Hyo.

## Features

- One checkbox per PO3 number from 3 to 19683, each with its own colour
- Levels drawn around current price, a configurable count each side
- Overlapping levels merge and take the highest PO3 number that lands on them
- Width and style follow magnitude, so stronger levels read as stronger lines
- PO3 number written on each line, with a threshold to keep fine grids unlabelled
- Whole-number levels by default on gold; a scale divisor switches to the two-decimal form
- Countdown to the current candle's close beside that candle, in units that follow the chart timeframe
- Candle count from the market open, with the kihon suchi numbers marked on the chart
- A panel counting the year, month, week and day, each in the candles that divide it
- A nested M1 count that restarts at every kihon suchi H1 candle
- A second block beside that panel, counting M15, M5 and M1 inside any H4 or H1 candle standing on a kihon number
- Session timer for capping screen time, unaffected by switching timeframe
- Redraws only when price crosses a grid cell or a new bar opens, not on every tick

## How the levels are built

A level is `multiplier x 3^power`, divided by a scale divisor.

**Whole numbers (scale 1, the default).** Gold levels land on 3402, 3483,
4374, 4617 and so on — the raw figures, nothing divided. Gold trading at 4374
is sitting on `2187 x 2`.

**Two decimals (scale 100).** The same model in the form the source workbook
tabulates for gold: 2799.36, 2952.45, 3542.94.

The two do not disagree. A level `m x 3^n / 100` is a whole number only when
100 divides `m`, because `3^n` shares no factor with 100 — and `m = 100k`
reduces to `k x 3^n`. **The scale-1 grid is exactly the whole-number subset of
the scale-100 grid.** Choosing whole numbers drops the fractional levels; it
moves none of them.

### Overlap: the highest PO3 number owns the level

Powers of three nest. 27 is a multiple of 9, so every 27 level sits exactly on
a 9 level. Ticking both would stack two objects on one price, with the colour
decided by whichever drew last.

Instead each price is drawn once and belongs to the **highest** ticked PO3
number that lands on it. Gold at 4374 divides by every number from 3 to 2187,
so it is drawn and labelled as 2187.

Each ticked grid gets its own window of *Levels each side of price* above and
below, so at the default of 3 both the 9 and the 27 grid offer six lines. With
both ticked at 4374, twelve candidates merge into ten distinct prices:

| Price | In the window of | Drawn as |
|-------|------------------|----------|
| 4320 | 27 | 27 |
| 4347 | 27 | 27 |
| 4356 | 9 | 9 |
| 4365 | 9 | 9 |
| **4374** | 9 and 27 | **27** |
| 4383 | 9 | 9 |
| 4392 | 9 | 9 |
| 4401 | 9 and 27 | 27 |
| 4428 | 27 | 27 |
| 4455 | 27 | 27 |

4347 and 4428 are multiples of 9 as well, but they fall outside the 9 grid's
own window, so only the 27 grid offers them — a grid's window is its own, and
the merge only settles prices two windows both reach.

Ownership is order-independent — a number gives the same result whichever
checkbox order it is registered in.

## Files

```text
PO3_Core.mqh            Shared PO3 level maths, used by the EA
PO3_Kihon.mqh           Kihon suchi numbers and the candle count, used by the indicator
PO3_Levels.mq5          MetaTrader 5 indicator, whole-number PO3 grids by checkbox
PO3_Scalper.mq5         MetaTrader 5 Expert Advisor, scalps rejections of the 9 and 27 grids
PO3_Levels.pine         TradingView Pine v5, a port of the MT5 indicator with both headers inlined
```

**`PO3_Levels.pine` is the same indicator, not a companion to it.** It draws
the same grids from the same arithmetic and counts the same candles, so the two
charts agree line for line. Pine has no `#include`, so it carries its own copy
of both headers inlined rather than referencing them — which is the one place
the repo has the same maths written twice, and the reason the Pine file opens
by naming what it is a port of.

An earlier Pine file, `PO3_Gold_Levels.pine`, drew a fixed list of 34 decimal
levels transcribed from the workbook's gold sheet instead of computing them. It
was replaced by the port and is in the git history if you want it back.

## Install

**MetaTrader 5**

1. MetaEditor or MT5 → File → Open Data Folder
2. Copy **both** `PO3_Levels.mq5` and `PO3_Kihon.mqh` into `MQL5/Indicators/` —
   they must sit in the same folder, and the header is not optional
3. Open it in MetaEditor and compile with `F7`
4. In MT5: Navigator → Indicators → refresh → drag onto a gold chart

For the EA, additionally:

1. Copy **both** `PO3_Scalper.mq5` and `PO3_Core.mqh` into `MQL5/Experts/` —
   they must sit in the same folder, and the header is not optional
2. Open the `.mq5` in MetaEditor and compile it with `F7`
3. Enable **Algo Trading** in MT5, then drag the EA onto a `#GOLDm` chart
4. Any chart timeframe will do. The EA reads M1 and M5 from the symbol itself
   and never looks at the period it was dropped on

Rename the `.mq5` if you like; MQL5 does not care what the file is called. The
header's name *does* matter, because the `#include` names it.

> `file '...\PO3_Kihon.mqh' not found` means `PO3_Kihon.mqh` is not in the same
> folder as the `.mq5` — likewise `PO3_Core.mqh` for the EA. That is the only
> thing either error means. MetaEditor names the folder it looked in, so
> `Indicators\PO3_Kihon.mqh` not found is telling you it looked in
> `MQL5/Indicators/` and the header was not there. Copy it and recompile;
> nothing needs configuring.

Changing the input list between versions means removing the indicator from the
chart and re-adding it, since MT5 caches inputs per chart.

**TradingView**

Open Pine Editor, paste `PO3_Levels.pine`, save, then Add to chart. There is no
second file to copy: Pine has no `#include`, so both headers are already inside
it. What the platform changes is covered under
[PO3 Levels on TradingView](#po3-levels-on-tradingview).

## PO3 Levels (indicator)

### Inputs

| Input | Default | Notes |
|-------|---------|-------|
| Scale divisor | `1.0` | `1` for whole numbers, `100` for the workbook's two-decimal gold form |
| Levels each side of price | `3` | Applies per ticked grid; clamped to 1–100 |
| Draw lines behind the candles | `false` | Fine grids sit where the candles are, so the default draws in front |
| Write the PO3 number on each line | `true` | |
| Label only levels of PO3 >= | `3` | Everything is labelled; every label shares one time anchor, so raise this if the fine grids stack digits |
| Label text size | `7` | Clamped to 5–20 |
| Label shift right, in bars | `0` | `0` anchors at the last bar, always on screen |
| Show 3 … Show 19683 | all on | One checkbox and one colour per PO3 number; untick the fine grids for a quieter chart |
| Show time left on the current candle | `true` | Printed beside the developing candle, level with price |
| Bars right of the developing candle | `1` | `0` puts it beside the candle, ending at it; needs chart shift on to sit further right |
| Vertical offset from price, in points | `0` | Positive lifts the text above price |
| Text size | `8` | Sized to sit among the candles without crowding them; clamped to 6-24 |
| Text colour | `clrLime` | |
| Show time spent on this chart | `true` | The session timer, in a screen corner |
| Corner (session) | `CORNER_RIGHT_UPPER` | |
| Distance from corner, X / Y (session) | `12` / `40` | |
| Text size (session) | `10` | |
| Text colour (session) | `clrSilver` | |
| Minutes on chart before it turns red | `0` | `0` is off; otherwise the timer recolours and alerts once when the budget is spent |
| Text colour once over the limit | `clrTomato` | |
| Draw the count on the chart | `true` | The open line and the kihon suchi marks |
| Count from | `Day open` | Day open, week open, month open, year open, or a custom time of day (server). Drives the on-chart marks; the panel carries its own anchors |
| Custom anchor, hour / minute | `8` / `0` | Only read when *Count from* is the custom time |
| Line on the candle the count starts at | `true` | |
| Open line colour | `clrDimGray` | |
| Mark the kihon suchi candles | `true` | |
| Include the compound numbers (33 and up) | `true` | Untick for 9, 17 and 26 only |
| Vertical line on each marked candle | `true` | Drawn behind the candles |
| 9, 17, 26 — colour | `clrDeepSkyBlue` | The simple numbers |
| 33 and up — colour | `clrMediumOrchid` | The compound numbers |
| Marker text size | `8` | Clamped to 5–20 |
| Marker offset from the candle low, in points | `0` | Positive pushes the number further below the low |
| Number every candle, not just the kihon ones | `false` | Capped at the most recent 300 candles |
| Show the count panel | `true` | |
| Year block — MN1, W1, D1 | `true` | Months, weeks and trading days since 1 January |
| Month block — D1, H4, H1 | `true` | Since the 1st |
| Week block — H4, H1, M30 | `true` | Since the week open |
| Day block — H1 to chart | `true` | Runs from H1 down to the chart's own period, plus the nested M1 row. Titled `Sess` and anchored to *Count from* when that is the custom time |
| Corner (panel) | `CORNER_LEFT_UPPER` | Rows stack downward from an upper corner, upward from a lower one |
| Centre it vertically | `true` | Worked out from chart height and row count; ignores Y |
| Distance from corner, X / Y (panel) | `12` / `20` | Y applies only when *Centre it vertically* is off |
| Text size (panel) | `9` | Clamped to 6–20 |
| Solid block behind the panel | `true` | Sized to the widest row, drawn in front of the candles |
| Block colour | `C'18,18,24'` | |
| Block border colour | `clrDimGray` | |
| Text colour (panel) | `clrSilver` | |
| Colour of a row standing ON a kihon number | `clrLime` | |
| Colour of a row within reach of one | `clrOrange` | |
| How many candles either side counts as near | `2` | Clamped to 0–8; `0` switches the orange state off |
| Show the kihon segment panel | `true` | The block beside the count panel: M15, M5 and M1 inside a kihon H4 or H1 candle |
| Segments inside a kihon H4 candle | `true` | Checked against the month and week anchors |
| Segments inside a kihon H1 candle | `true` | Checked against the month, week and day anchors |
| Gap between the two blocks, in pixels | `8` | Its only placement input — it follows the count panel's corner, centring and X |

Width and style are derived from magnitude: 3/9/27 thin dotted, 81/243 thin
solid, 729/2187 medium, 6561/19683 thick.

The Experts log prints the resolved selection and the line count each grid
contributed after merging, so a grid that draws nothing can be told apart from
one that draws lines you cannot see.

### Candle countdown

The counter shows the chart timeframe and the time left on the current candle,
in units that follow the period — `M15  14:59` counting down minutes and
seconds, `H4  03:59:59`, `D1  23:59:59`, `W1  6d 23:59:59`. It runs off a
one-second timer rather than incoming ticks, so it keeps counting through a
quiet session instead of freezing between trades.

It sits next to the developing candle, anchored to that candle's time and to
the current price, so it travels with the candle as the chart scrolls and rides
price as it moves — the time left is read in the same glance as the candle it
belongs to. *Bars right of the developing candle* moves it; past the last bar
the text reads rightwards into the empty space, and at `0` or behind it the
text ends at the anchor, which keeps it on screen with chart shift switched
off.

### Session timer

`On chart  01:23:45` is wall-clock time since the indicator loaded — how long
you have been looking at this chart. It is for capping screen time, so it counts
straight through closed markets and weekends rather than tracking a trading
session.

**Switching timeframe does not reset it.** MT5 reloads the indicator on every
period change, so the start time is kept in a terminal global variable keyed by
the chart and picked back up on reload. It restarts only when the indicator or
the chart is genuinely reloaded — removed and re-added, recompiled, or the chart
closed and reopened. A crash restarts it too, by design. Changing the chart
symbol keeps it running, since it is the same chart.

Set *Minutes on chart before it turns red* to a limit and the timer recolours
once you pass it and raises one alert. `0` leaves it a plain always-on clock.

### Candle count and kihon suchi

The count answers one question: how many candles have printed since the market
opened. It is Ichimoku's time count, so it is **inclusive at both ends** — the
candle sitting at the open is candle 1, not candle 0. That single convention is
what makes the compound numbers overlap by one, and it is why the count here
will read one higher than a plain zero-based bar index.

*Count from* sets the anchor for the marks drawn on the chart; the panel below
carries its own anchor per block. **Day open** and **week open** come from the
D1 and W1 bars themselves, so they follow the broker's own day boundary rather
than a guess at it. **Month open** and **year open** are built from the
calendar — there is no yearly candle to read a year off — so counts against
them start at the first candle that *opens* inside the period: a weekly candle
straddling New Year belongs to the old year. **Custom time of day** is a
session open — today's date at
the hour and minute you set, rolled back a day if that time has not come round
yet, and then clamped to the day open. The clamp is the part worth knowing: an
08:00 London anchor read at 03:00 on a Monday would otherwise roll back to
08:00 on *Friday* and count the whole weekend through. Clamped, a session
anchor never counts across a day boundary — before the session opens you get
the count from the day open, and the moment it opens the count restarts there.

#### The numbers

Kihon suchi (基本数値) are Ichimoku's basic time numbers: candles at which a
move is due to change character. They say nothing about direction. There are
three simple ones and nine compounds, and every compound is built by chaining
simple spans that **share their turning candle** — two 17s joined make 33, not
34, because the last candle of the first span is the first candle of the second.

| | Number | Built from |
|---|---|---|
| **Simple** | 9 | *ichi-moku*, the Tenkan span |
| | 17 | 9 + 9 − 1 |
| | 26 | **Given, not derived** — the Kijun span, and a month of trading days under the old six-day week |
| **Compound** | 33 | 17 + 17 − 1 |
| | 42 | 26 + 17 − 1 |
| | 51 | 26 + 26 − 1 |
| | 65 | 33 + 33 − 1 (four 17s chained) |
| | 76 | 26 + 26 + 26 − 2, also 51 + 26 − 1 |
| | 129 | 65 + 65 − 1 |
| | 172 | 65 + 42 + 42 + 26 − 3 |
| | 226 | 76 + 76 + 76 − 2 |
| | 257 | 129 + 129 − 1 |

**26 is the exception, not 172.** Every compound chains simple spans that share
a candle, so *k* spans subtract *k*−1. 26 does not come out that way: three 9s
chained give 9+9+9−2 = **25**, and 17+9−1 is **25** as well. Reaching 26 needs
either a plain 9+17 with no shared candle, or 9+9+9−1 with one overlap too few
— and neither is the rule. That is expected: 26 is one of the three *simple*
numbers, and a simple number is a given, not a result. It is a calendar figure
the rule then builds on.

The series keeps doubling past 257 — 257 + 257 − 1 = 513 — but a number that
large has no use on an intraday chart, where even 257 M1 candles is only a
little over four hours. The list stops where the classical one stops.

Simple and compound are coloured differently and *Include the compound numbers*
turns the compounds off, which leaves 9, 17 and 26 on a much quieter chart.

#### The panel

The panel is a ladder of calendar periods, each counted in the candles that
divide it. This is an M15 chart on Tuesday 8 September at 10:22:

```text
Year   from 2026.01.01
  MN1       9  KS
  W1       37  42 in 5
  D1      174  KS +2

Month  from 2026.09.01
  D1        6  9 in 3
  H4       33  KS
  H1      131  KS +2

Week   from 2026.09.07
  H4        9  KS
  H1       35  KS +2
  M30      69  76 in 7

Day    from 00:00
  H1       11  KS +2
  M30      21  26 in 5
> M15      42  KS
  M1@9    143  172 in 29
```

Every block carries **its own anchor** — a week counted from the day open would
read 1 forever. `>` flags the chart's own timeframe, and blocks can be switched
off individually.

The one block that listens to *Count from* is the day block, and only when that
input is set to the custom time of day. Then it counts from your session open
rather than the broker's midnight, and its title changes to `Sess` to say so —
`Sess from 08:00`. On every other setting of *Count from* the block is the
broker's day, whatever anchor the on-chart marks are using.

**M30 sits on the week** because that is where it fits. A trading week is 240
M30 candles, so the count runs through eleven of the twelve numbers and stops
just short of 257 — it never runs off the end of the list. It is the closest
fit of any row in the panel; the week in H4 only reaches 30, using three.

**Year, month and week are fixed.** They say the same thing whatever period the
chart is on, which is what makes them readable across a timeframe change — a
week is a week in H1 candles whether you are looking at M1 or D1.

**The day block follows the chart.** It runs from H1 down to the chart's own
period and stops: on M15 you get H1, M30, M15; on M5 that plus M5. Detail finer
than the candles in front of you is a count of something you cannot see. H1 is
always kept, so an H4 or daily chart still gets the hour count rather than an
empty block. The `M1@` row is always there, on every period — it is the one row
carrying information none of the others do.

**A kihon candle is often kihon on several timeframes at once.** The compound
chain 9 → 17 → 33 → 65 → 129 → 257 is each number doubled less one, and under
inclusive counting halving the timeframe maps a count `c` to `2c − 1` exactly.
So the moment H1 reads 9, M30 reads 17 and M15 reads 33 — all three `KS` and
lime together. That is arithmetic, not confirmation: three rows agreeing
because they are the same instant counted three ways is not the same as the
week and the month agreeing with the day.

#### Reading a row

Each row is the count, then its standing against the nearest kihon suchi
number. `KS` is that phrase abbreviated — it is the only thing in a row that
repeats, and spelling it out made the counts, which are the reading, the
quieter half of the line:

| Tail | Colour | Meaning |
|---|---|---|
| `KS` | **lime** | The count is standing on one right now |
| `KS -2` | **orange** | Two candles short of one |
| `KS +2` | **orange** | Two candles past one |
| `42 in 6` | plain | Six candles until 42 |
| `past 257` | plain | Beyond the last number; nothing left to count to |
| `no data` | plain | The history is not there to count |
| `too far` | plain | The count was *refused* — see below |

The sign reads the way the chart does: a count running up towards a number
shows a negative gap closing to zero, then goes positive as it leaves. The
window is **nearest**, not next, deliberately — a count two candles past 26 is
as much "around 26" as one two candles short of it, and a turn that was due at
26 is not cancelled by the candle after it. Set the tolerance to `0` if you
only want the exact hits.

`no data` and `too far` are different answers. The second means the anchor is
further back than 20,000 periods of that timeframe, where getting an exact
figure would drag a large history in to say something `past 257` already says.

The day counts are trading candles, not calendar units — the year's `D1` row is
trading days, not the day of the year.

#### The nested M1 count

`M1@1` is the odd one out. Run across a whole day, an M1 count is past 257 by
breakfast and says nothing for the rest of the session. So it **restarts at
every kihon suchi H1 candle** instead: at H1 candle 1, again at H1 candle 9,
again at H1 candle 17. A day is not long enough to reach 26.

The reset lands *on* the kihon candle, not after it — as the ninth hour opens,
the M1 count reads 1. The label carries the hour it restarted at, because the
count alone cannot tell you which phase of the day it is measuring: `M1@9 143`
is 143 minutes into the second phase of the day, not 143 minutes into the day.

This is the general nesting rule — a fine count restarting at each kihon candle
of a coarse one — and `KihonSegmentStart()` in `PO3_Kihon.mqh` implements it for
any pair of timeframes. The count panel uses it for M1 inside H1 only; the
block beside it nests one step further, and differently — see the next
section.

#### Inside the kihon candle: the segment block

The nesting rule above stops at the hour. A second block, standing beside the
count panel, carries it one step further — into the candle itself.

When an H4 or an H1 count stands **on** a number — one of the lime rows — the
candle carrying that number *is* a kihon candle, and it is a kihon candle for
its whole length: four hours, or one. The panel beside it tells you that hour
is due a turn; it cannot tell you where in the hour you are. So this block
counts the candles **inside** that candle, from its open:

```text
Year   from 2026.01.01       Kihon Suchi segments
  MN1       9  KS            H4     from 08:00
  W1       37  42 in 5         M15      10  KS +1
  D1      174  KS +2           M5       29  33 in 4
                               M1      143  172 in 29
Month  from 2026.09.01
  D1        6  9 in 3
  H4       33  KS
  H1      131  KS +2

Week   from 2026.09.07
  H4        9  KS
  H1       35  KS +2
  M30      69  76 in 7

Day    from 00:00
  H1       11  KS +2
  M30      21  26 in 5
> M15      42  KS
  M1@9    143  172 in 29
```

Two blocks, not one — each with its own background and border, sharing a top
edge and a row pitch. This is the same 10:22 snapshot as above. The `H4` block
is open because `H4 33 KS` in the month block and `H4 9 KS` in the week block
are lime; no H1 count is on a number — 131, 35 and 11 are each two past one —
so there is no H1 block, and there would be one the moment any of those three
landed.

**Everything in the block counts from the candle, and nothing from a
calendar.** The header reads `H4 from 08:00` and every row under it is measured
from that open: 10 M15 candles, 29 M5, 143 M1 into *this* H4. The month and
week anchors decide only whether the block opens; they take no further part,
and no figure in it is a count since a day, week or month open. Those counts
are the panel beside it, which carries them in full.

It is the same shape as a block title in that panel — what, then the open
everything under it counts from. The only difference is that here the open
belongs to a candle rather than a calendar period.

The header is lime because the candle it names is the hit. The rows below it
are ordinary count rows and colour themselves on their own counts, against the
same numbers and the same tolerance as everything else — `M15 10` is orange, one
candle past 9, while `M5 29` is four short of 33 and plain.

**The same candle can be counted twice at two different numbers**, and this is
the clearest illustration of the split. The count panel's day block reads
`M15 42 KS`, lime; the segment reads `M15 10 KS +1`. Both are the developing
10:15 candle. The H4 opened at 08:00, which is 32 M15 candles into the day, and
42 − 32 = 10. The day says this candle is due a turn in the session; the
segment says it is one candle past due inside the hit H4. Neither number is
wrong, and each block only ever shows its own.

**What counts as a hit.** An H4 is checked against the month and week anchors,
an H1 against the month, week and day. Any one of them landing on a number
opens the block. H4 gets no day anchor because a trading day holds six H4
candles, so a day-anchored H4 count stops at 6 and could never reach 9. These
are read from the anchors directly, so the block says the same thing whether or
not you have the row that would show the hit switched on.

**The M1 row can repeat the `M1@` row, and that is not a bug.** Above, both
read 143: the hit H4 opened at 08:00, and 08:00 is also H1 candle 9, so the
nested M1 count and the segment M1 count start at the same candle. They agree
whenever a kihon H1 candle opens a kihon H4, which is when the two counts are
genuinely measuring the same thing.

**Which rows you get depends on what fits.** A row appears only when at least
one kihon number is reachable inside the candle — nine of it have to fit, or
the row could never say anything but a countdown:

| Segment | Rows | Counts to | Numbers in range |
|---|---|---|---|
| Inside an H4 | M15, M5, M1 | 16, 48, 240 | 9 / 42 / 226 |
| Inside an H1 | M5, M1 | 12, 60 | 9 / 51 |

**M15 is in the H4 box and not the H1 box** for that reason, not by choice.
Sixteen M15 candles fit in an H4, so 9 is in reach and the row can land on it.
Four fit in an H1, where the row would read `9 in 5`, then `9 in 4`, and be
gone before it ever arrived. It is the same rule that keeps the day anchor off
the H4 count, applied at the other end of the nesting: do not count what cannot
reach a number.

The short reaches are the point, not a shortcoming. What these rows measure is
how far into the kihon candle the market has come, and the numbers that fit
inside it are the only ones that can mean anything there.

**It has no position of its own.** It takes the count panel's corner and its
top edge and stands one gap further along — to the right of it from a left
corner, to the left of it from a right corner, always on the side away from the
chart edge. Its X is the count panel's *measured* width, so the two blocks
cannot overlap however wide the rows get, and moving the count panel moves
both. The gap input is the only thing to set.

The section reads `none` most of the time — an H4 or H1 count is on a number
for a handful of candles in a session. It keeps its title rather than vanishing
so the space stays accounted for, and it is read off the anchors directly, so
it says the same thing whether or not you have the block that would show that
row switched on.

**A caution.** The count is arithmetic, not a signal. It tells you where a turn
is *due*, never that one is happening and never which way. Nothing in the
indicator acts on these numbers, and the EA does not read them.

## PO3 Scalper (Expert Advisor)

`PO3_Scalper.mq5` trades one rule: **a candle wicks into a PO3 level and closes
back off it, so trade the other way, take profit at the next level of that same
grid, and stop out past the end of the wick.**

It runs that rule twice, on two grids at two speeds:

| Track | Grid | Candles | Spacing on gold | Target |
|-------|------|---------|-----------------|--------|
| A | PO3 9 | M1 | $9 | the next 9 level |
| B | PO3 27 | M5 | $27 | the next 27 level |

Each track keeps its own bar clock, its own ATR, its own magic number and its
own cooldown, so neither can shadow the other. The finer 3 grid is not traded:
$3 on gold is inside the noise, and much of it inside the spread.

### The two rejections are one rule

Price that turns just short of a level and price that pokes through and closes
back under it differ only in whether the extreme got past the level. The entry
test is "reached it, closed back off it" either way, so both are the same
signal and both take the same trade:

| | Entry | Stop | Target | |
|---|---|---|---|---|
| Reverses before the level | 4381.80 | 4383.11 | 4374.00 | 6.0R |
| Breaks over, then reverses | 4382.30 | 4383.91 | 4374.00 | 5.2R |

*A bearish M1 rejection of the 9 level at 4383, ATR $0.60.*

`Past this much ATR beyond the level it broke, not swept` draws the line past
which the level genuinely broke rather than being swept, and no trade is taken.

### The candle has a floor and a ceiling

Under the floor there is no rejection to read. Over the ceiling there is too
much movement to fade: **a candle taller than one 9 cell, wick to wick, is
skipped on both tracks** — the cap is the 9 grid even for the 27 track, because
it is a statement about how volatile the market has become rather than about
which grid is being traded.

The arithmetic behind it, for a bearish rejection of the 9 level at 4383 on M5:

| Candle height | Entry | Stop | Risk | Target | Reward | R |
|---|---|---|---|---|---|---|
| $2.10 | 4381.50 | 4384.27 | 2.77 | 4374.00 | 7.50 | **2.70** |
| $4.90 | 4378.90 | 4384.27 | 5.38 | 4374.00 | 4.90 | 0.91 |
| $7.40 | 4376.30 | 4384.27 | 7.97 | 4374.00 | 2.30 | 0.29 |
| $9.30 | 4374.40 | 4384.27 | 9.88 | 4374.00 | 0.40 | 0.04 |

The taller the candle, the more of the $9 cell its wick has already eaten, so
the stop grows and the target shrinks by the same dollar and R collapses toward
zero. *Skip if the target is worth less than this many stops* catches most of
that band on its own — at the default of `1.0` it already blocks everything
from about $3 up — so the height cap is not new protection so much as the same
rule stated plainly, with its own line in the log, and one that keeps holding
if the R floor is ever lowered.

### Structure it reads, and mostly trades on

Powers of three nest, so every third 9 level is also a 27 level, and a 27 range
holds three 9 cells that read as discount, equilibrium and premium. On gold the
27 range `[4374 .. 4401]` has its interior 9 levels at 4383 and 4392 — exactly
the 33.3% and 66.7% thirds — with equilibrium at 4387.50.

A 27 level is the stronger of the two and generally holds its first test,
turning into support only once price has closed decisively above it. So each 27
level has a state, support or resistance, and the EA reads it back from bar
history on every signal — how many times the zone has been tested, how many
decisive closes have crossed it, which side price settled on, and how recently
it flipped. All of it is logged on every signal whether or not it is filtering.

Two of the three filters are **on**:

- *Only trade toward the equilibrium of the 27 range* — discount buys, premium
  sells
- *Skip setups that fight a recently flipped 27 level* — a level price has just
  closed decisively through is expected to hold from its new side now

One is **off**, so its cost can be measured against a run that already has the
other two:

- *Skip levels chopped through more than this many times*

**The premium/discount rule only bites on the 9 track.** A 27 level *is* a
range boundary, so a rejection of one is always read from whichever side suits
it — a short off a 27 level sits at 98% of the range below, a long off it at 2%
of the range above. Checked across gold 4300–4600 it blocks **34% of 9-grid
setups and 0% of 27-grid setups**: on the 9 grid it removes shorts at the 33.3%
level and longs at the 66.7% level, and on the 27 grid it is a no-op by
construction.

The state is read from history rather than kept in memory, so a restart, a
recompile or a timeframe change cannot leave the EA holding a stale view of a
level it never saw trade. The cooldown is the one thing that *is* remembered
across a reload, in terminal global variables keyed by symbol and magic —
otherwise recompiling would let the level just traded be taken again on the
next candle.

### Size, and why there is no partial close

Lots are fixed at `0.1`, the XM micro minimum, and clamped to whatever the
symbol will actually accept. Contract size and tick value are read from the
symbol rather than assumed, so sizing is right whether `#GOLDm` is quoted at 10
or 100 oz per lot.

**A second target needs a second position.** Part-closing 0.1 lots would leave
0.05, which is under the minimum, and the broker rejects it. So the *runner
leg* input opens a second 0.1 position aimed further out, with its stop pulled
to break-even once the first leg closes. That doubles the risk on any setup
stopped before the first target, which is why it is **off** by default.

The runner needs nothing remembered between ticks: the first leg being absent
while the runner is still open *is* the first target having filled, because a
stop would have taken both legs together.

### Inputs

| Group | Input | Default | Notes |
|-------|-------|---------|-------|
| Symbol and size | Trade only if the symbol name contains this | `GOLD` | The EA refuses to load otherwise; the grids are gold figures |
| | Magic base | `903000` | Track A takes base+0 and +1, track B base+10 and +11 |
| | Lots per leg | `0.1` | Raised automatically if the symbol's minimum is higher |
| | Scale divisor | `1.0` | As the indicator |
| Track A — PO3 9 | Trade the 9 grid | `true` | |
| | Candles to read | `M1` | |
| | Zone floor / min candle / stop floor, in points | `20` / `15` / `15` | |
| | Target this many 9 levels away | `1` | |
| | Cooldown bars, setups per day | `5`, `0` | `0` is no daily cap |
| Track B — PO3 27 | Trade the 27 grid | `true` | |
| | Candles to read | `M5` | |
| | Zone floor / min candle / stop floor, in points | `40` / `40` / `30` | |
| | Target this many 27 levels away | `1` | |
| | Cooldown bars, setups per day | `3`, `0` | |
| Rejection shape | Zone around a level, in ATR | `0.25` | Capped at a fraction of the grid, so adjacent zones cannot overlap |
| | Zone ceiling, as a fraction of the grid | `0.25` | |
| | Rejecting wick, as a % of the candle | `50` | The wick is the whole signal |
| | Largest body, as a % of the candle | `45` | Keeps trend bars out |
| | Ignore candles taller than this many 9 grids | `1.0` | $9 wick to wick, on both tracks; `0` is off |
| | Close must clear the level by this much ATR | `0.05` | |
| | Past this much ATR beyond the level it broke | `1.20` | `0` removes the cap |
| Stop and target | Stop past the wick end, in ATR | `0.35` | Whichever is larger, this or the track's point floor |
| | Skip if the target is worth less than this many stops | `1.0` | |
| Runner leg | Open a second leg | `false` | See above — it doubles the risk |
| | Extra levels out, break-even, offset | `1`, `true`, `10` | |
| Protection | Read the stop back off the position | `true` | Repairs it, or closes the position if it cannot be protected |
| | Retries on a requote or a moved price | `2` | |
| | Flatten and stop trading at this hour on Friday | `20` server time | `-1` leaves positions to ride the weekend |
| Filters | Skip if the spread is wider than this | `40` points | |
| | Trading window, server time | `8` to `21` | Skips the daily gold break |
| | Let one track open against the other's trade | `false` | Otherwise the two pay both spreads to cancel out |
| PO3 structure | Bars of history the state is read from | `300` | |
| | A close this far past a level flips it | `0.30` ATR | |
| | A flip this recent makes the next touch a retest | `30` bars | |
| | Skip setups that fight a recently flipped 27 level | `true` | |
| | Only trade toward the equilibrium of the 27 range | `true` | A no-op on the 27 track; blocks 34% on the 9 track |
| | Skip levels chopped through more than this many times | `0` (off) | Left off so its cost can be measured |
| Display | Chart panel, signal marks, verbose log | all on | |

The panel shows both tracks, where price sits in its 27 range, and whether the
window is open. Signal candles are marked with an arrow and left on the chart
on purpose — they are the record of what the EA saw, and a recompile should not
wipe it.

### Two things that can lose more than the stop says

**An accepted order is not an attached stop.** `Buy()` returning true means the
*order* was accepted, not that the SL and TP reached the position. On market
execution — which XM uses on several account types — a broker may strip them
and expect a separate modify. So the EA reads the stop back off the position
after the fill, attaches it if it is missing, and **closes the position** if it
cannot attach one after three tries. Being flat is a known loss; being naked is
not a bounded one. The log says which happened.

**A stop bounds a loss only while the market is trading through it.** Entries
stop at the end of the window, but nothing used to close a position, so a
Friday afternoon trade rode the weekend — and gold's weekend gap runs far past
any stop this EA sets, opening beyond it rather than at it. From
`Flatten and stop trading at this hour on Friday` the EA closes what it holds
and opens nothing further until the new week. Set it to `-1` to switch that off.

Neither is a cap on trading. They bound what a *single open position* can cost
when the mechanism the stop relies on is not there.

### Running it in the Strategy Tester

The EA reads M1 and M5 from the symbol itself, so **the tester's chart period
is irrelevant to the logic** — but the tick model is not:

- Use **Every tick based on real ticks**, or **Every tick**. *Open prices only*
  and *1 minute OHLC* will not fill stops and targets inside a candle, and both
  tracks depend on that.
- Download `#GOLDm` history first, and set the deposit, currency and leverage
  to match the XM micro account you intend to run on. Lot size is fixed at
  `0.1`, so the account size decides what that risk means.
- **Run each track alone before running them together.** Set *Trade the 9 grid*
  and *Trade the 27 grid* one at a time. The two tracks have separate magic
  numbers, but the tester's report aggregates everything, so a combined run
  cannot tell you which track earned or lost what.
- Give it months, not weeks. A high-R, low-hit-rate rule needs a lot of trades
  before its average means anything.
- The Friday flatten shortens Friday to the window's start until `20:00`. If
  your broker's server clock is offset from what you expect, that is the input
  to check first — it is server time, not yours.

The log names every setup it passed on and why, but only for candles that
reached a level and closed back off it — the ones that were nearly trades.
Candles nowhere near a level are not logged, or M1 would bury the Experts tab.

### Before you run it

**The M1 track has a long target against a short stop.** A $9 target on an M1
wick whose stop is a dollar or two away is a 5–8R trade, which is only
profitable at a low hit rate — most of these stop out, and the arithmetic
depends on the few that do not. That is what asking for "the next 9 level" from
an M1 candle produces; it is not a flaw in the code, but it is the number to
check first in the Strategy Tester. Raising *Target this many 9 levels away* is
the wrong lever if the R is already too high; the honest ones are the wick and
body percentages, and the trading window.

Test on a demo account first. Every rejected setup is logged with the reason it
was passed on, so a track that takes no trades can be told apart from one that
is never being offered any.

## PO3 Levels on TradingView

`PO3_Levels.pine` is a Pine v5 port of `PO3_Levels.mq5`. Same grids, same
merge, same counts, same panel — it is the indicator, on the other platform,
not a reduced companion to it. Pine has no `#include`, so `PO3_Kihon.mqh` and
`PO3_Core.mqh` are inlined at the top of the file as their own sections, kept
whole and kept first so the port can be read against the originals function by
function.

The inputs mirror the MT5 ones group for group, so anything in
[Inputs](#inputs) above applies here too, with the exceptions below.

### What the platform changes

Every one of these is a Pine limit rather than a decision, and each is stated
in the file's own header as well:

| | MetaTrader 5 | TradingView |
|---|---|---|
| Drawing budget | No practical ceiling | 500 lines and 500 labels per script |
| *Levels each side of price* | 1–100 | **1–25**, so nine grids fit in 450 lines |
| Lines behind the candles | An input | No z-order in Pine; not offered |
| Panel placement | Corner plus a pixel X and Y | One of nine table positions |
| The two blocks | Two bordered blocks, measured apart | One table, a spacer column between |
| Text size | 5–24 points | tiny / small / normal / large / huge |
| Countdown refresh | Once a second, off `OnTimer` | On a tick — a quiet market freezes it |
| Session timer | Survives a timeframe change | Restarts on one |
| Server time | The broker's clock | The exchange timezone |
| The Experts log | Line counts per grid, resolved sizes | No log; the panel carries what it can |

**The session timer is the one real loss.** MT5 keeps its start time in a
terminal global variable keyed by the chart, which is what lets it survive the
teardown a period change triggers. Pine has nothing equivalent, so switching
timeframe restarts the clock — the exact thing the MT5 version goes out of its
way to prevent.

**The label budget is spent, not silently exceeded.** Level labels get whatever
Pine's 500 leaves after the kihon marks, which is 480 normally and 180 with
*Number every candle* switched on. If a setting asks for more than that, the
panel grows a `labels N over budget` row rather than dropping them quietly.
Raising *Label only levels of PO3 >=* is the way to clear it.

### How the counts are made

MT5 asks the terminal "how many bars of timeframe T lie between the anchor and
now" and gets an answer from its own history. Pine has no such call, so each
count is computed **in the context of the timeframe being counted** — bars
since the anchor condition last fired — and pulled back with
`request.security`. `ta.barssince` returns 0 on the bar the condition fired, so
`+ 1` gives the same inclusive count, and the anchor candle is candle 1 exactly
as it is in the MQL.

That puts nineteen `request.security` calls at the top of the file, all at
global scope and all unconditional, because Pine will not have them inside an
`if` or a loop. A row you have switched off is therefore still counted and
simply not shown.

`KihonSegmentStart()` is the one header function that could not survive as a
function. It works by indexing an arbitrary bar of another timeframe, which
Pine cannot do, so the nested M1 count is instead tracked forward on the M1
series itself — an hour counter that resets on the day open and a minute
counter that resets whenever that hour counter lands on a kihon number. Same
rule, same output, different shape.

### What it adds

One alert condition, **Kihon suchi candle**, fires when the count on the
chart's own timeframe reaches a kihon number. MT5 has no equivalent because the
indicator there raises no alerts at all. It is still only a count: it says a
turn is due, never that one is happening and never which way.

## Notes

- Levels were checked against the source workbook's gold sheet for 14 March
  2025: `2187 x 128..141` reproduces 2799.36–3083.67, `6561 x 42..48`
  reproduces 2755.62–3149.28, and `19683 x 14..16` reproduces the same
  endpoints.
- A coarse grid spends most of its window off-chart. Ticking 2187 at gold 4374
  draws 2187 and 4374, then 6561, 8748 and 10935 far above — five levels, two
  of them near price. That is inherent to giving each grid its own window.
- The monthly countdown is nominal. MT5 treats a month as 30 days when asked
  for a period length, so `MN1` drifts against the real month end. Every other
  timeframe is exact.
- Level prices are not passed through `NormalizeDouble`. The integer multiply
  and single divide already land on the exact figure; rounding to a broker's
  digit count could only move a level off it.
- The source workbook and course PDF are not redistributed here. Every level
  they contain is reproduced by the code.
- The EA takes its levels from `PO3_Core.mqh`, so it cannot end up trading a
  different grid from the one the indicator draws. The MT5 indicator still
  carries its own copy of the maths and is untouched by the EA.
- **Three copies of the level maths now exist**: `PO3_Core.mqh` for the EA,
  `PO3_Levels.mq5`'s own, and the inlined block in `PO3_Levels.pine`. Only the
  first two can share a file — Pine has no `#include` — so the Pine copy is the
  one that can drift. It is a dozen lines and they are checked against the
  header they came from; change one and change the other.

## Disclaimer

For educational and analytical use. `PO3_Levels.mq5` and `PO3_Levels.pine`
draw chart levels, not trade signals, and place no orders.

`PO3_Scalper.mq5` does place orders and manage positions. It is a starting
point, not a tested strategy: no edge is claimed for it, and it has not been
run against a broker's tick history here. Trading carries risk of loss. Run it
on a demo account, read the log, and do your own analysis before risking
capital.

## License

This project is licensed under the [MIT License](LICENSE).

## Author

**Neo Malesa** — [n30dyn4m1c](https://github.com/n30dyn4m1c)
