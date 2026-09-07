//+------------------------------------------------------------------+
//|                                                     PO3_Core.mqh |
//|                                                                  |
//|  Shared PO3 (power of three) level maths.                        |
//|                                                                  |
//|  A level is  multiplier x 3^n / scale.  At scale 1 every level   |
//|  is a whole number, so the gold grid lands on 4374, 4383, 4392   |
//|  and so on. Powers of three nest, so every 27 level is also a 9  |
//|  level: the 27 grid is the every-third member of the 9 grid.     |
//|  That nesting is what gives a 27 range its three 9 cells, and    |
//|  the equilibrium of that range is its midpoint.                  |
//|                                                                  |
//|  Kept apart from any one program so PO3_Levels.mq5 (the          |
//|  indicator) and PO3_Scalper.mq5 (the EA) cannot drift onto       |
//|  different level sets.                                           |
//+------------------------------------------------------------------+
#ifndef __PO3_CORE_MQH__
#define __PO3_CORE_MQH__

//--- The epsilon is not cosmetic. A price sitting exactly on a level,
//--- 2952.45 against PO3 2187, divides to 134.99999999999997 rather than
//--- 135, so a bare floor() would anchor one level too low and shift the
//--- whole window down. Same guard PO3_Levels.mq5 uses in Rebuild().
#define PO3_EPS      1e-9
//--- absolute price tolerance for "is this price exactly on a level".
//--- Levels at scale 1 are integers, so anything this close is on it.
#define PO3_ON_TOL   1e-8

//+------------------------------------------------------------------+
//| Multiplier index of the level at or below price.                 |
//+------------------------------------------------------------------+
long PO3Index(const double price, const long po3, const double scale = 1.0)
  {
   return((long)MathFloor(price * scale / (double)po3 + PO3_EPS));
  }

//+------------------------------------------------------------------+
//| Price of the level with this multiplier.                         |
//|                                                                  |
//| The multiply is done in integers and divided once, so the result |
//| is the nearest double to the exact figure. m * (po3/scale) in    |
//| doubles would accumulate drift across the grid.                  |
//+------------------------------------------------------------------+
double PO3Level(const long m, const long po3, const double scale = 1.0)
  {
   return((double)(m * po3) / scale);
  }

//--- spacing between adjacent levels of this grid
double PO3Step(const long po3, const double scale = 1.0)
  {
   return((double)po3 / scale);
  }

//--- the level at or below price
double PO3Floor(const double price, const long po3, const double scale = 1.0)
  {
   return(PO3Level(PO3Index(price, po3, scale), po3, scale));
  }

//--- the level at or above price
double PO3Ceil(const double price, const long po3, const double scale = 1.0)
  {
   long   m  = PO3Index(price, po3, scale);
   double lo = PO3Level(m, po3, scale);
   if(MathAbs(price - lo) <= PO3_ON_TOL)
      return(lo);
   return(PO3Level(m + 1, po3, scale));
  }

//--- the closer of the two levels bracketing price
double PO3Nearest(const double price, const long po3, const double scale = 1.0)
  {
   double lo = PO3Floor(price, po3, scale);
   double hi = PO3Ceil (price, po3, scale);
   return((price - lo) <= (hi - price) ? lo : hi);
  }

//--- is price sitting on a level of this grid
bool PO3IsOn(const double price, const long po3, const double scale = 1.0)
  {
   return(MathAbs(price - PO3Floor(price, po3, scale)) <= PO3_ON_TOL);
  }

//+------------------------------------------------------------------+
//| The n-th level of this grid strictly beyond `from`, in the       |
//| direction dir (+1 up, -1 down).                                  |
//|                                                                  |
//| "Strictly" matters: stepping down from a price that is already   |
//| on a level must give the level below it, not the same one, or a  |
//| take profit computed from the entry level would sit on the entry |
//| level itself.                                                    |
//+------------------------------------------------------------------+
double PO3StepFrom(const double from, const long po3, const int dir,
                   const int n = 1, const double scale = 1.0)
  {
   long   m    = PO3Index(from, po3, scale);
   bool   onIt = (MathAbs(from - PO3Level(m, po3, scale)) <= PO3_ON_TOL);
   int    k    = (n < 1) ? 1 : n;

   if(dir > 0)
      return(PO3Level(m + k, po3, scale));

   //--- floor already sits below an off-level price, so that price has
   //--- consumed one of the steps down
   return(PO3Level(onIt ? m - k : m - (k - 1), po3, scale));
  }

//+------------------------------------------------------------------+
//| Equilibrium of the po3 range that contains price: the midpoint   |
//| between the level below it and the level above it.               |
//|                                                                  |
//| For the 27 grid on gold this is the level, plus 13.5. The two    |
//| interior 9 levels sit at +9 and +18, straddling it, which is     |
//| what makes the three 9 cells read as discount, equilibrium and   |
//| premium of the 27 range.                                         |
//+------------------------------------------------------------------+
double PO3RangeEQ(const double price, const long po3, const double scale = 1.0)
  {
   return(PO3Floor(price, po3, scale) + PO3Step(po3, scale) * 0.5);
  }

//+------------------------------------------------------------------+
//| Where price sits inside its po3 range: 0.0 at the low, 1.0 at    |
//| the high, 0.5 at equilibrium. Above 0.5 is premium, below is     |
//| discount.                                                        |
//+------------------------------------------------------------------+
double PO3RangePos(const double price, const long po3, const double scale = 1.0)
  {
   double step = PO3Step(po3, scale);
   if(step <= 0.0)
      return(0.5);
   return((price - PO3Floor(price, po3, scale)) / step);
  }

//+------------------------------------------------------------------+
//| The strongest of the given grids that lands on this price, or 0. |
//|                                                                  |
//| Same ownership rule the indicator draws by: 27 nests on 9, so a  |
//| price that is a multiple of both belongs to 27.                  |
//+------------------------------------------------------------------+
long PO3TierOf(const double price, const long &grids[], const double scale = 1.0)
  {
   long best = 0;
   for(int i = 0; i < ArraySize(grids); i++)
      if(grids[i] > best && PO3IsOn(price, grids[i], scale))
         best = grids[i];
   return(best);
  }

#endif // __PO3_CORE_MQH__
