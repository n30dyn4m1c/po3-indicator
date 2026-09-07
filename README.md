# PO3 Levels

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-MetaTrader%205-blue.svg)](https://www.metatrader5.com/)
[![Language](https://img.shields.io/badge/Language-MQL5-orange.svg)](https://www.mql5.com/)
[![Also](https://img.shields.io/badge/Also-Pine%20Script%20v5-green.svg)](https://www.tradingview.com/pine-script-docs/)

**MetaTrader 5 indicator that draws Power of Three (PO3) support and resistance levels on XAUUSD, with a checkbox per PO3 number from 3 to 19683, a TradingView Pine companion, and an Expert Advisor that scalps rejections of the 9 and 27 grids.**

Levels are multiples of powers of three — 3, 9, 27, 81, 243, 729, 2187, 6561,
19683 — drawn around current price. Nothing is fitted, optimised or inferred
from price action: a level either is a multiple of a power of three or it is
not. The MT5 indicator draws lines only. It places no orders and reads no
account state.

`PO3_Scalper.mq5` is the exception to "places no orders": it is an EA, and it
trades. The indicator it ships beside is unchanged and still draws only.

Based on the Power of Three / Goldbach level model taught by **Hopiplaka**.

## Features

- One checkbox per PO3 number from 3 to 19683, each with its own colour
- Levels drawn around current price, a configurable count each side
- Overlapping levels merge and take the highest PO3 number that lands on them
- Width and style follow magnitude, so stronger levels read as stronger lines
- PO3 number written on each line, with a threshold to keep fine grids unlabelled
- Whole-number levels by default on gold; a scale divisor switches to the two-decimal form
- Countdown to the current candle's close beside that candle, in units that follow the chart timeframe
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
so it is drawn and labelled as 2187. With 9 and 27 ticked at that price,
twelve candidate lines merge into ten distinct prices:

| Price | Produced by | Drawn as |
|-------|-------------|----------|
| 4347 | 27 | 27 |
| 4356 | 9 | 9 |
| 4365 | 9 | 9 |
| **4374** | 9 and 27 | **27** |
| 4383 | 9 | 9 |
| 4392 | 9 | 9 |
| 4401 | 9 and 27 | 27 |

Ownership is order-independent — a number gives the same result whichever
checkbox order it is registered in.

## Files

```text
PO3_Core.mqh            Shared PO3 level maths, used by the EA
PO3_Levels.mq5          MetaTrader 5 indicator, whole-number PO3 grids by checkbox
PO3_Scalper.mq5         MetaTrader 5 Expert Advisor, scalps rejections of the 9 and 27 grids
PO3_Gold_Levels.pine    TradingView Pine v5, fixed gold level list from the workbook
```

**The two draw different level sets, by design.** `PO3_Levels.mq5` draws every
multiple of the PO3 numbers you tick, following price. `PO3_Gold_Levels.pine`
draws 34 fixed decimal levels transcribed from the source workbook's gold
sheet, plus that range's equilibrium and premium/discount shading. Both are
faithful to the same model; loading both will not give you the same lines.

## Install

**MetaTrader 5**

1. MetaEditor or MT5 → File → Open Data Folder
2. Copy `PO3_Levels.mq5` into `MQL5/Indicators/`
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

> `file 'Include\PO3_Core.mqh' not found` means `PO3_Core.mqh` is not in the
> same folder as the `.mq5`. That is the only thing it means.

Changing the input list between versions means removing the indicator from the
chart and re-adding it, since MT5 caches inputs per chart.

**TradingView**

Open Pine Editor, paste `PO3_Gold_Levels.pine`, save, then Add to chart.

## Inputs (MetaTrader 5)

| Input | Default | Notes |
|-------|---------|-------|
| Scale divisor | `1.0` | `1` for whole numbers, `100` for the workbook's two-decimal gold form |
| Levels each side of price | `3` | Applies per ticked grid; clamped to 1–100 |
| Draw lines behind the candles | `false` | Fine grids sit where the candles are, so the default draws in front |
| Write the PO3 number on each line | `true` | |
| Label only levels of PO3 >= | `3` | Everything is labelled; every label shares one time anchor, so raise this if the fine grids stack digits |
| Label text size | `7` | |
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
  different grid from the one the indicator draws. The indicator still carries
  its own copy of the maths and is untouched by the EA.

## Disclaimer

For educational and analytical use. `PO3_Levels.mq5` and `PO3_Gold_Levels.pine`
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
