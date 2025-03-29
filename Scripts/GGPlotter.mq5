#include <GG.mqh>

// Input parameters
input int      DaysToLookBack = 30;     // Number of days to look back for FVGs
input ENUM_TIMEFRAMES HTF = PERIOD_H1;  // Higher timeframe for FVGs (default 1-hour)
input ENUM_TIMEFRAMES LTF = PERIOD_M5;  // Lower timeframe for FVGs (default 5-min)
input bool     ShowOnlyActive = false;  // Show only active Guru Gaps
input bool     ShowDebugInfo = true;    // Show additional debug information

void OnStart() {
   // Clear any previously drawn GGs
   ClearGGs();
   
   GG ggs[];
   int ggCount;
   
   Print("===== Guru Gap Plotter =====");
   Print("Symbol: ", _Symbol);
   Print("Timeframes: ", EnumToString(HTF), " × ", EnumToString(LTF));
   Print("Looking for Guru's Gaps over the past ", DaysToLookBack, " days...");
   datetime start_time = GetTickCount();
   
   // Detect Guru Gaps with the specified parameters
   DetectGuruGaps(_Symbol, ggs, ggCount, HTF, LTF, DaysToLookBack);
   
   datetime end_time = GetTickCount();
   Print("Analysis completed in ", (end_time - start_time), " ms");
   
   int plotted = 0;
   datetime oldest_gg = TimeCurrent();
   datetime newest_gg = 0;
   
   // Plot all detected Guru Gaps
   for(int i = 0; i < ggCount; i++) {
      // If ShowOnlyActive is true, only plot active GGs
      if(!ShowOnlyActive || ggs[i].active) {
         PlotGG(ggs[i], i);
         plotted++;
         
         // Track date range of detected GGs
         if(ggs[i].start_time < oldest_gg) oldest_gg = ggs[i].start_time;
         if(ggs[i].start_time > newest_gg) newest_gg = ggs[i].start_time;
      }
   }
   
   // Report results
   Print("Found ", ggCount, " Guru Gaps");
   Print("Plotted ", plotted, " Guru Gaps on the chart");
   
   if(ShowDebugInfo && ggCount > 0) {
      Print("Oldest GG detected: ", TimeToString(oldest_gg));
      Print("Newest GG detected: ", TimeToString(newest_gg));
      Print("Date range: ", TimeToString(oldest_gg), " to ", TimeToString(newest_gg));
   }
   
   if(ShowOnlyActive) {
      Print("Note: Only showing active (unclosed) Guru Gaps");
   }
   
   if(ggCount == 0) {
      Print("Warning: No Guru Gaps found in the specified time period. Try increasing DaysToLookBack.");
   }
   
   // Show statistics if we have GGs
   if(ggCount > 0 && ShowDebugInfo) {
      Print("=== Guru Gap Statistics ===");
      int bullish = 0, bearish = 0, active = 0, closed = 0;
      
      for(int i = 0; i < ggCount; i++) {
         if(ggs[i].type == "Bullish") bullish++;
         else bearish++;
         
         if(ggs[i].active) active++;
         else closed++;
      }
      
      Print("Bullish GGs: ", bullish, " (", DoubleToString(100.0 * bullish / ggCount, 1), "%)");
      Print("Bearish GGs: ", bearish, " (", DoubleToString(100.0 * bearish / ggCount, 1), "%)");
      Print("Active GGs: ", active, " (", DoubleToString(100.0 * active / ggCount, 1), "%)");
      Print("Closed GGs: ", closed, " (", DoubleToString(100.0 * closed / ggCount, 1), "%)");
   }
}