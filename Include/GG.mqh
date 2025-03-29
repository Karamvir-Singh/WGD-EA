#ifndef GG_MQH
#define GG_MQH

#include <FVG.mqh>

struct GG {
   double high;
   double low;
   string type;
   datetime start_time;
   datetime end_time;
   bool active;
   datetime htf_start_time; // Start time of the higher timeframe FVG
   datetime ltf_start_time; // Start time of the lower timeframe FVG
};

// Detect Guru's Gaps (GG) - Intersections between HTF and LTF FVGs of the same type
void DetectGuruGaps(string symbol, GG &ggs[], int &ggCount, 
                      ENUM_TIMEFRAMES htf = PERIOD_H1, 
                      ENUM_TIMEFRAMES ltf = PERIOD_M5,
                      int days_to_look_back = 30) {
   
   // Initialize array if this is first run
   if(ArraySize(ggs) == 0) {
      ggCount = 0;
   }
   
   // Calculate the approximate number of bars for the specified days based on the timeframe
   int minutes_per_bar_ltf = PeriodSeconds(ltf) / 60;
   int trading_minutes_per_day = 24 * 60; // Assume 24-hour trading for forex
   int bars_per_day_ltf = trading_minutes_per_day / minutes_per_bar_ltf;
   int total_bars_to_check_ltf = bars_per_day_ltf * days_to_look_back;
   
   // Cap at a reasonable maximum (50,000 bars)
   if(total_bars_to_check_ltf > 50000) {
      Print("Warning: Requested ", total_bars_to_check_ltf, " LTF bars which is too many. Limiting to 50,000.");
      total_bars_to_check_ltf = 50000;
   }
   
   // Ensure we don't try to access more bars than are available
   int available_bars_ltf = Bars(symbol, ltf);
   if(total_bars_to_check_ltf > available_bars_ltf - 3) {
      Print("Note: Requested ", total_bars_to_check_ltf, " LTF bars but only ", available_bars_ltf - 3, " are available.");
      total_bars_to_check_ltf = available_bars_ltf - 3;
   }
   
   Print("Processing ", total_bars_to_check_ltf, " LTF bars for analysis");
   
   // Arrays to store our FVGs
   FVG htf_fvgs[];
   int htf_fvgCount = 0;
   
   FVG ltf_fvgs[];
   int ltf_fvgCount = 0;
   
   // Variables to track HTF bar changes
   datetime current_htf_time = 0;
   
   // Process all LTF bars in chronological order
   for(int i = total_bars_to_check_ltf + 2; i >= 0; i--) {
      // Get current LTF bar data
      datetime ltf_time = iTime(symbol, ltf, i);
      double ltf_high = iHigh(symbol, ltf, i);
      double ltf_low = iLow(symbol, ltf, i);
      double ltf_close = iClose(symbol, ltf, i);
      
      // Determine current HTF bar
      int htf_shift = iBarShift(symbol, htf, ltf_time);
      datetime htf_time = iTime(symbol, htf, htf_shift);
      
      // Check if this is a new HTF bar
      bool new_htf_bar = (htf_time != current_htf_time);
      
      // If we have a new HTF bar and had a previous one, check for HTF FVG
      if(new_htf_bar && current_htf_time != 0) {
         // We need at least 3 HTF bars to detect an FVG (current + 2 previous)
         // Since htf_shift is now the index of the current HTF bar, we check if htf_shift+2 is valid
         if(htf_shift + 2 < Bars(symbol, htf)) {
            double htf_high0 = iHigh(symbol, htf, htf_shift);
            double htf_low0 = iLow(symbol, htf, htf_shift);
            double htf_high2 = iHigh(symbol, htf, htf_shift + 2);
            double htf_low2 = iLow(symbol, htf, htf_shift + 2);
            
            // Check for bullish HTF FVG
            if(htf_low0 > htf_high2) {
               ArrayResize(htf_fvgs, htf_fvgCount + 1);
               htf_fvgs[htf_fvgCount].high = htf_low0;
               htf_fvgs[htf_fvgCount].low = htf_high2;
               htf_fvgs[htf_fvgCount].type = "Bullish";
               htf_fvgs[htf_fvgCount].start_time = htf_time;
               htf_fvgs[htf_fvgCount].end_time = ltf_time; // temp end time
               htf_fvgs[htf_fvgCount].active = true;
               htf_fvgCount++;
            }
            
            // Check for bearish HTF FVG
            if(htf_high0 < htf_low2) {
               ArrayResize(htf_fvgs, htf_fvgCount + 1);
               htf_fvgs[htf_fvgCount].high = htf_low2;
               htf_fvgs[htf_fvgCount].low = htf_high0;
               htf_fvgs[htf_fvgCount].type = "Bearish";
               htf_fvgs[htf_fvgCount].start_time = htf_time;
               htf_fvgs[htf_fvgCount].end_time = ltf_time; // temp end time
               htf_fvgs[htf_fvgCount].active = true;
               htf_fvgCount++;
            }
         }
      }
      
      // Update current HTF time
      current_htf_time = htf_time;
      
      // Check for LTF FVG if we have at least 3 LTF bars
      if(i <= total_bars_to_check_ltf - 2) {
         double ltf_high2 = iHigh(symbol, ltf, i+2);
         double ltf_low2 = iLow(symbol, ltf, i+2);
         
         // Check for bullish LTF FVG
         if(ltf_low > ltf_high2) {
            ArrayResize(ltf_fvgs, ltf_fvgCount + 1);
            ltf_fvgs[ltf_fvgCount].high = ltf_low;
            ltf_fvgs[ltf_fvgCount].low = ltf_high2;
            ltf_fvgs[ltf_fvgCount].type = "Bullish";
            ltf_fvgs[ltf_fvgCount].start_time = ltf_time;
            ltf_fvgs[ltf_fvgCount].end_time = ltf_time; // temp end time
            ltf_fvgs[ltf_fvgCount].active = true;
            ltf_fvgCount++;
         }
         
         // Check for bearish LTF FVG
         if(ltf_high < ltf_low2) {
            ArrayResize(ltf_fvgs, ltf_fvgCount + 1);
            ltf_fvgs[ltf_fvgCount].high = ltf_low2;
            ltf_fvgs[ltf_fvgCount].low = ltf_high;
            ltf_fvgs[ltf_fvgCount].type = "Bearish";
            ltf_fvgs[ltf_fvgCount].start_time = ltf_time;
            ltf_fvgs[ltf_fvgCount].end_time = ltf_time; // temp end time
            ltf_fvgs[ltf_fvgCount].active = true;
            ltf_fvgCount++;
         }
      }
      
      // Update active/inactive status of existing FVGs based on price action
      // First, check LTF FVGs
      for(int j = 0; j < ltf_fvgCount; j++) {
         if(ltf_fvgs[j].active && ltf_fvgs[j].start_time < ltf_time) {
            // For Bullish FVGs, close if a candle's close is below the FVG's low
            if(ltf_fvgs[j].type == "Bullish" && ltf_close < ltf_fvgs[j].low) {
               ltf_fvgs[j].active = false;
               ltf_fvgs[j].end_time = ltf_time;
            }
            // For Bearish FVGs, close if a candle's close is above the FVG's high
            else if(ltf_fvgs[j].type == "Bearish" && ltf_close > ltf_fvgs[j].high) {
               ltf_fvgs[j].active = false;
               ltf_fvgs[j].end_time = ltf_time;
            }
         }
      }
      
      // Then, check HTF FVGs
      for(int j = 0; j < htf_fvgCount; j++) {
         if(htf_fvgs[j].active && htf_fvgs[j].start_time < ltf_time) {
            // For Bullish FVGs, close if a candle's close is below the FVG's low
            if(htf_fvgs[j].type == "Bullish" && ltf_close < htf_fvgs[j].low) {
               htf_fvgs[j].active = false;
               htf_fvgs[j].end_time = ltf_time;
            }
            // For Bearish FVGs, close if a candle's close is above the FVG's high
            else if(htf_fvgs[j].type == "Bearish" && ltf_close > htf_fvgs[j].high) {
               htf_fvgs[j].active = false;
               htf_fvgs[j].end_time = ltf_time;
            }
         }
      }
      
      // Check for GG formations - intersections between LTF and HTF FVGs
      // We use farthest start_time between LTF and HTF for GG start_time
      for(int l = 0; l < ltf_fvgCount; l++) {
         for(int h = 0; h < htf_fvgCount; h++) {
            // Check if both FVGs exist at this point in time and are the same type
            if(ltf_fvgs[l].start_time <= ltf_time && 
               htf_fvgs[h].start_time <= ltf_time && 
               ltf_fvgs[l].type == htf_fvgs[h].type) {
               
               // Check if a GG with these FVGs already exists
               bool gg_exists = false;
               for(int g = 0; g < ggCount; g++) {
                  if(ggs[g].htf_start_time == htf_fvgs[h].start_time && 
                     ggs[g].ltf_start_time == ltf_fvgs[l].start_time) {
                     gg_exists = true;
                     break;
                  }
               }
               
               // If no GG exists with these FVGs, check for price overlap
               if(!gg_exists) {
                  double intersection_high = MathMin(htf_fvgs[h].high, ltf_fvgs[l].high);
                  double intersection_low = MathMax(htf_fvgs[h].low, ltf_fvgs[l].low);
                  
                  // If intersection_high > intersection_low, we have an overlap
                  if(intersection_high > intersection_low) {
                     // Determine active status - GG is active if both FVGs are active
                     bool is_active = htf_fvgs[h].active && ltf_fvgs[l].active;
                     
                     // Create new GG
                     ArrayResize(ggs, ggCount + 1);
                     ggs[ggCount].high = intersection_high;
                     ggs[ggCount].low = intersection_low;
                     ggs[ggCount].type = htf_fvgs[h].type; // Same as LTF FVG type
                     // Start time is the later of the two FVG start times
                     ggs[ggCount].start_time = MathMax(htf_fvgs[h].start_time, ltf_fvgs[l].start_time);
                     ggs[ggCount].end_time = ltf_time; // Set end time to current bar initially
                     ggs[ggCount].active = is_active;
                     ggs[ggCount].htf_start_time = htf_fvgs[h].start_time;
                     ggs[ggCount].ltf_start_time = ltf_fvgs[l].start_time;
                     ggCount++;
                  }
               }
            }
         }
      }
      
      // Update GG closures
      for(int g = 0; g < ggCount; g++) {
         // Only check active GGs that started before this bar
         if(ggs[g].active && ggs[g].start_time < ltf_time) {
            // Update end time for active GGs
            ggs[g].end_time = ltf_time;
            
            // For Bullish GGs, close if a candle's close is below the GG's low
            if(ggs[g].type == "Bullish" && ltf_close < ggs[g].low) {
               ggs[g].active = false;
            }
            // For Bearish GGs, close if a candle's close is above the GG's high
            else if(ggs[g].type == "Bearish" && ltf_close > ggs[g].high) {
               ggs[g].active = false;
            }
         }
      }
   }
   
   Print("Detected ", ltf_fvgCount, " LTF FVGs, ", htf_fvgCount, " HTF FVGs, and ", ggCount, " Guru Gaps");
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
