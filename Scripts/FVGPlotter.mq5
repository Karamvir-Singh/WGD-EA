#include <FVG.mqh>

// Input parameters
input int      DaysToLookBack = 30;     // Number of days to look back for FVGs
input bool     ShowOnlyActive = false;  // Show only active FVGs that haven't been closed
input bool     ShowDebugInfo = true;    // Show additional debug information

void OnStart() {
   // Clear any previously drawn FVGs
   ClearFVGs();
   
   FVG fvgs[];
   int fvgCount;
   
   Print("===== FVG Plotter =====");
   Print("Symbol: ", _Symbol, ", Timeframe: ", EnumToString(PERIOD_CURRENT));
   Print("Looking for FVGs over the past ", DaysToLookBack, " days...");
   datetime start_time = GetTickCount();
   
   // Detect FVGs with the specified number of days to look back
   DetectFVGs(_Symbol, PERIOD_CURRENT, fvgs, fvgCount, DaysToLookBack);
   
   datetime end_time = GetTickCount();
   Print("Analysis completed in ", (end_time - start_time), " ms");
   
   int plotted = 0;
   datetime oldest_fvg = TimeCurrent();
   datetime newest_fvg = 0;
   
   // Plot all detected FVGs
   for(int i = 0; i < fvgCount; i++) {
      // If ShowOnlyActive is true, only plot active FVGs
      if(!ShowOnlyActive || fvgs[i].active) {
         PlotFVG(fvgs[i], i);
         plotted++;
         
         // Track date range of detected FVGs
         if(fvgs[i].start_time < oldest_fvg) oldest_fvg = fvgs[i].start_time;
         if(fvgs[i].start_time > newest_fvg) newest_fvg = fvgs[i].start_time;
      }
   }
   
   // Report results
   Print("Found ", fvgCount, " FVGs on ", EnumToString(PERIOD_CURRENT));
   Print("Plotted ", plotted, " FVGs on the chart");
   
   if(ShowDebugInfo && fvgCount > 0) {
      Print("Oldest FVG detected: ", TimeToString(oldest_fvg));
      Print("Newest FVG detected: ", TimeToString(newest_fvg));
      Print("Date range: ", TimeToString(oldest_fvg), " to ", TimeToString(newest_fvg));
   }
   
   if(ShowOnlyActive) {
      Print("Note: Only showing active (unclosed) FVGs");
   }
   
   if(fvgCount == 0) {
      Print("Warning: No FVGs found in the specified time period. Try increasing DaysToLookBack.");
   }
   
   // Show statistics if we have FVGs
   if(fvgCount > 0 && ShowDebugInfo) {
      Print("=== FVG Statistics ===");
      int bullish = 0, bearish = 0, active = 0, closed = 0;
      
      for(int i = 0; i < fvgCount; i++) {
         if(fvgs[i].type == "Bullish") bullish++;
         else bearish++;
         
         if(fvgs[i].active) active++;
         else closed++;
      }
      
      Print("Bullish FVGs: ", bullish, " (", DoubleToString(100.0 * bullish / fvgCount, 1), "%)");
      Print("Bearish FVGs: ", bearish, " (", DoubleToString(100.0 * bearish / fvgCount, 1), "%)");
      Print("Active FVGs: ", active, " (", DoubleToString(100.0 * active / fvgCount, 1), "%)");
      Print("Closed FVGs: ", closed, " (", DoubleToString(100.0 * closed / fvgCount, 1), "%)");
   }
}