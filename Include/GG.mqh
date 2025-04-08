#ifndef GG_MQH
#define GG_MQH

#include <FVG.mqh>

// Debug mode flag - can be set by the calling code
static bool g_GG_DebugMode = false;

// Use enum instead of strings for better performance
enum FVG_TYPE {
   FVG_BULLISH,
   FVG_BEARISH
};

struct FVG_Optimized {
   double high;
   double low;
   FVG_TYPE type;
   datetime start_time;
   datetime end_time;
   bool active;
};

struct GG {
   double high;
   double low;
   string type;       // Changed back to string to maintain compatibility
   datetime start_time;
   datetime end_time;
   bool active;
   datetime htf_start_time; // Start time of the higher timeframe FVG
   datetime ltf_start_time; // Start time of the lower timeframe FVG
};

//+------------------------------------------------------------------+
//| Set debug mode for GG module                                      |
//+------------------------------------------------------------------+
void GG_SetDebugMode(bool debugMode) {
   g_GG_DebugMode = debugMode;
   // Also set debug mode for the FVG module
   FVG_SetDebugMode(debugMode);
}

//+------------------------------------------------------------------+
//| Get current debug mode state                                      |
//+------------------------------------------------------------------+
bool GG_GetDebugMode() {
   return g_GG_DebugMode;
}

//+------------------------------------------------------------------+
//| Custom debug print function - only outputs when debug is enabled  |
//+------------------------------------------------------------------+
void GG_DebugPrint(string message) {
   if(g_GG_DebugMode) {
      Print(message);
   }
}

//+------------------------------------------------------------------+
//| Always print function - for critical messages regardless of debug |
//+------------------------------------------------------------------+
void GG_InfoPrint(string message) {
   Print(message);
}

// Detect Guru's Gaps (GG) - Intersections between HTF and LTF FVGs of the same type
void DetectGuruGaps(string symbol, GG &ggs[], int &ggCount, 
                      ENUM_TIMEFRAMES htf = PERIOD_H1, 
                      ENUM_TIMEFRAMES ltf = PERIOD_M5,
                      int days_to_look_back = 30) {
   
   // Initialize array
   if(ArraySize(ggs) == 0) {
      ggCount = 0;
   }
   
   // Step 1: Detect all HTF FVGs
   FVG htf_fvgs[];
   int htf_fvgCount = 0;
   GG_DebugPrint("Detecting HTF FVGs...");
   DetectFVGs(symbol, htf, htf_fvgs, htf_fvgCount, days_to_look_back);
   GG_DebugPrint("Detected " + IntegerToString(htf_fvgCount) + " HTF FVGs");
   
   // Step 2: Detect all LTF FVGs
   FVG ltf_fvgs[];
   int ltf_fvgCount = 0;
   GG_DebugPrint("Detecting LTF FVGs...");
   DetectFVGs(symbol, ltf, ltf_fvgs, ltf_fvgCount, days_to_look_back);
   GG_DebugPrint("Detected " + IntegerToString(ltf_fvgCount) + " LTF FVGs");
   
   // Pre-allocate array for GGs (estimated size)
   int estimated_ggs = MathMin(htf_fvgCount, ltf_fvgCount);
   ArrayResize(ggs, estimated_ggs);
   ggCount = 0;
   
   // Step 3: Find intersections between HTF and LTF FVGs (Guru Gaps)
   GG_DebugPrint("Finding Guru Gaps (intersections)...");
   for(int h = 0; h < htf_fvgCount; h++) {
      for(int l = 0; l < ltf_fvgCount; l++) {
         // Only process FVGs of the same type
         if(htf_fvgs[h].type == ltf_fvgs[l].type) {
            
            // Calculate the potential intersection
            double intersection_high = MathMin(htf_fvgs[h].high, ltf_fvgs[l].high);
            double intersection_low = MathMax(htf_fvgs[h].low, ltf_fvgs[l].low);
            
            // Check if there's an actual price overlap
            if(intersection_high > intersection_low) {
               // Determine when this GG starts - latest of the two FVG start times
               datetime gg_start = MathMax(htf_fvgs[h].start_time, ltf_fvgs[l].start_time);
               
               // For a GG to exist, both FVGs must exist at the same time
               // If one FVG ends before the other starts, there's no GG
               if(htf_fvgs[h].end_time >= ltf_fvgs[l].start_time && 
                  ltf_fvgs[l].end_time >= htf_fvgs[h].start_time) {
                  
                  // Resize GG array if needed
                  if(ggCount >= ArraySize(ggs)) {
                     ArrayResize(ggs, ArraySize(ggs) + 50);
                  }
                  
                  // Determine if GG is active - it's active if both FVGs are active
                  bool is_active = htf_fvgs[h].active && ltf_fvgs[l].active;
                  
                  // Set end time to the earliest end time of either component FVG
                  datetime gg_end = MathMin(htf_fvgs[h].end_time, ltf_fvgs[l].end_time);
                  
                  // Create new GG
                  ggs[ggCount].high = intersection_high;
                  ggs[ggCount].low = intersection_low;
                  ggs[ggCount].type = htf_fvgs[h].type; // Same as component FVGs
                  ggs[ggCount].start_time = gg_start;
                  ggs[ggCount].end_time = gg_end;
                  ggs[ggCount].active = is_active;
                  ggs[ggCount].htf_start_time = htf_fvgs[h].start_time;
                  ggs[ggCount].ltf_start_time = ltf_fvgs[l].start_time;
                  ggCount++;
               }
            }
         }
      }
   }
   
   // Step 4: Load price data for checking GG closures
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   // Get the earliest GG start time and latest end time
   datetime earliest_time = TimeCurrent();
   datetime latest_time = 0;
   
   for(int g = 0; g < ggCount; g++) {
      if(ggs[g].start_time < earliest_time) earliest_time = ggs[g].start_time;
      if(ggs[g].end_time > latest_time) latest_time = ggs[g].end_time;
   }
   
   // Load all necessary price bars (from earliest GG to now)
   int bars_to_load = iBarShift(symbol, ltf, earliest_time) + 10; // Add buffer
   int copied = CopyRates(symbol, ltf, 0, bars_to_load, rates);
   
   if(copied <= 0) {
      GG_InfoPrint("Error copying rates data for GG closure checking: " + IntegerToString(GetLastError()));
   } else {
      GG_DebugPrint("Checking closures for " + IntegerToString(ggCount) + " Guru Gaps...");
      
      // Process GG closures
      for(int g = 0; g < ggCount; g++) {
         // Only need to check active GGs
         if(ggs[g].active) {
            // Find the first bar that matches or is after the GG start time
            int start_bar = iBarShift(symbol, ltf, ggs[g].start_time, false);
            
            // Process each bar from GG start to current time
            for(int i = start_bar; i >= 0; i--) {
               double close = rates[i].close;
               double previous_close = rates[i+1].close;
               datetime time = rates[i].time;
               
               // Update end time for active GGs
               if(time > ggs[g].end_time) {
                  ggs[g].end_time = time;
               }
               
               // Check if this candle closes the GG
               if(ggs[g].type == "Bullish" && previous_close < ggs[g].low) {
                  ggs[g].active = false;
                  ggs[g].end_time = time;
                  break; // No need to check further bars
               }
               else if(ggs[g].type == "Bearish" && previous_close > ggs[g].high) {
                  ggs[g].active = false;
                  ggs[g].end_time = time;
                  break; // No need to check further bars
               }
            }
         }
      }
   }
   
   GG_DebugPrint("Detected " + IntegerToString(ggCount) + " Guru Gaps in total");
}

void PlotGG(GG &gg, int index) {
   string name = "GG_" + IntegerToString(index);
   // Green color for bullish, red for bearish
   color clr = (gg.type == "Bullish") ? clrLightGreen : clrLightPink;
   
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, 
               gg.start_time, gg.high,
               gg.end_time, gg.low);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_FILL, false);       // Fill the GG to make it stand out
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   
   // Add a tooltip with information about the GG
   string tooltip = StringFormat(
      "Guru Gap (%s)\nHTF Start: %s\nLTF Start: %s\nActive: %s",
      gg.type,
      TimeToString(gg.htf_start_time),
      TimeToString(gg.ltf_start_time),
      gg.active ? "Yes" : "No"
   );
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
}

// Clean up all GG objects
void ClearGGs() {
   ObjectsDeleteAll(0, "GG_");
}

#endif
