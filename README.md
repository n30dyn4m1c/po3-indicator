# PO3 Levels

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-MetaTrader%205-blue.svg)](https://www.metatrader5.com/)
[![Language](https://img.shields.io/badge/Language-MQL5-orange.svg)](https://www.mql5.com/)
[![Also](https://img.shields.io/badge/Also-Pine%20Script%20v5-green.svg)](https://www.tradingview.com/pine-script-docs/)

**MetaTrader 5 indicator that draws Power of Three (PO3) support and resistance levels on XAUUSD, with a checkbox per PO3 number from 3 to 19683 and a TradingView Pine companion.**

Levels are multiples of powers of three — 3, 9, 27, 81, 243, 729, 2187, 6561,
19683 — drawn around current price. Nothing is fitted, optimised or inferred
from price action: a level either is a multiple of a power of three or it is
not. The MT5 indicator draws lines only. It places no orders and reads no
account state.

Based on the Power of Three / Goldbach level model taught by **Hopiplaka**.

## Features

- One checkbox per PO3 number from 3 to 19683, each with its own colour
- Levels drawn around current price, a configurable count each side
- Overlapping levels merge and take the highest PO3 number that lands on them
- Width and style follow magnitude, so stronger levels read as stronger lines
- PO3 number written on each line, with a threshold to keep fine grids unlabelled
- Whole-number levels by default on gold; a scale divisor switches to the two-decimal form
- Countdown to the current candle's close, in units that follow the chart timeframe
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
PO3_Levels.mq5          MetaTrader 5 indicator, whole-number PO3 grids by checkbox
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
| Label only levels of PO3 >= | `243` | Every label shares one time anchor; labelling `3` would stack digits |
| Label text size | `7` | |
| Label shift right, in bars | `0` | `0` anchors at the last bar, always on screen |
| Show 3 … Show 19683 | `243`, `729`, `2187` on | One checkbox and one colour per PO3 number |
| Show time left on the current candle | `true` | |
| Corner | `CORNER_RIGHT_UPPER` | X and Y measure inward from the corner you pick |
| Distance from corner, X / Y | `12` / `18` | |
| Text size | `10` | |
| Text colour | `clrSilver` | |
| Show time spent on this chart | `true` | The session timer, second line below the countdown by default |
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

## Disclaimer

For educational and analytical use. These are chart levels, not trade signals,
and neither file places orders or manages positions. Trading carries risk of
loss. Test on a demo account and do your own analysis before risking capital.

## License

This project is licensed under the [MIT License](LICENSE).

## Author

**Neo Malesa** — [n30dyn4m1c](https://github.com/n30dyn4m1c)
