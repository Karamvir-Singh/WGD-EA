#ifndef FVG_MQH
#define FVG_MQH

struct FVG {
   double high;
   double low;
   string type;
   datetime start_time;
   datetime end_time;
   bool active;
};

void DetectFVGs(string symbol, ENUM_TIMEFRAMES timeframe, FVG &fvgs[], int &fvgCount, int days_to_look_back = 30) {
   
   // Initialize array if this is first run
   if(ArraySize(fvgs) == 0) {
      fvgCount = 0;
   }
   
   // Calculate the approximate number of bars for the specified days based on the timeframe
   int minutes_per_bar = PeriodSeconds(timeframe) / 60;
   
   // Calculate how many bars we need based on calendar days
   // For lower timeframes like M5, we need to account for trading hours only
   int trading_minutes_per_day = 24 * 60; // Assume 24-hour trading for forex
   int bars_per_day = trading_minutes_per_day / minutes_per_bar;
   int total_bars_to_check = bars_per_day * days_to_look_back;
   
   // Cap at a reasonable maximum (50,000 bars)
   if(total_bars_to_check > 50000) {
      Print("Warning: Requested ", total_bars_to_check, " bars which is too many. Limiting to 50,000.");
      total_bars_to_check = 50000;
   }
   
   // Ensure we don't try to access more bars than are available
   int available_bars = Bars(symbol, timeframe);
   if(total_bars_to_check > available_bars - 3) {
      Print("Note: Requested ", total_bars_to_check, " bars but only ", available_bars - 3, " are available.");
      total_bars_to_check = available_bars - 3;
   }
   
   // Get rates data - set as NOT series (oldest first, newest last)
   // This way we process bars in chronological order
   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   int copied = CopyRates(symbol, timeframe, 0, total_bars_to_check + 3, rates);
   
   if(copied <= 0) {
      Print("Error copying rates data: ", GetLastError());
      return;
   }
   
   Print("Successfully loaded ", copied, " bars for analysis.");
   Print("Date range: ", TimeToString(rates[0].time), " to ", TimeToString(rates[copied-1].time));
   
   // Process each bar in chronological order (oldest to newest)
   // Starting from bar 2 since we need 2 bars before to check for FVG
   for(int i = 2; i < copied; i++) {
      // Current bar data
      double high0 = rates[i].high;
      double low0 = rates[i].low;
      double close0 = rates[i].close;
      datetime current_time = rates[i].time;
      
      // Bar 2 bars back data
      double high2 = rates[i-2].high;
      double low2 = rates[i-2].low;
      
      // First, check if any existing active FVGs should be closed by this bar
      for(int j = 0; j < fvgCount; j++) {
         if(fvgs[j].active) {
            // For Bullish FVGs, close if a candle's close is below the FVG's low
            if(fvgs[j].type == "Bullish" && close0 < fvgs[j].low) {
               fvgs[j].active = false;
               fvgs[j].end_time = current_time;
            }
            // For Bearish FVGs, close if a candle's close is above the FVG's high
            else if(fvgs[j].type == "Bearish" && close0 > fvgs[j].high) {
               fvgs[j].active = false;
               fvgs[j].end_time = current_time;
            }
         }
      }
      
      // Second, check if this bar forms a new FVG with the bar 2 bars back
      
      // Bullish FVG (Low of current bar > High of the bar 2 bars back)
      if(low0 > high2) {
         ArrayResize(fvgs, fvgCount + 1);
         fvgs[fvgCount].high = low0;
         fvgs[fvgCount].low = high2;
         fvgs[fvgCount].type = "Bullish";
         fvgs[fvgCount].start_time = current_time;
         fvgs[fvgCount].end_time = rates[copied-1].time; // Set end time to newest bar
         fvgs[fvgCount].active = true;
         fvgCount++;
      }
      
      // Bearish FVG (High of current bar < Low of the bar 2 bars back)
      if(high0 < low2) {
         ArrayResize(fvgs, fvgCount + 1);
         fvgs[fvgCount].high = low2;
         fvgs[fvgCount].low = high0;
         fvgs[fvgCount].type = "Bearish";
         fvgs[fvgCount].start_time = current_time;
         fvgs[fvgCount].end_time = rates[copied-1].time; // Set end time to newest bar
         fvgs[fvgCount].active = true;
         fvgCount++;
      }
   }
   
   Print("Detected ", fvgCount, " FVGs in total");
   int active_count = 0;
   for(int i = 0; i < fvgCount; i++) {
      if(fvgs[i].active) active_count++;
   }
   Print("Active FVGs: ", active_count);
}

void PlotFVG(FVG &fvg, int index) {
   string name = "FVG_" + IntegerToString(index);
   color clr = (fvg.type == "Bullish") ? clrLightGreen : clrLightPink;
   
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, 
               fvg.start_time, fvg.high,
               fvg.end_time, fvg.low);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_FILL, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
}

// Clean up all FVG objects
void ClearFVGs() {
   ObjectsDeleteAll(0, "FVG_");
}

#endif