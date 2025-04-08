#include <GG.mqh>

// Debug mode flag - can be set by the calling code
static bool g_Patterns_DebugMode = false;

//+------------------------------------------------------------------+
//| Set debug mode for Patterns module                                |
//+------------------------------------------------------------------+
void Patterns_SetDebugMode(bool debugMode) {
   g_Patterns_DebugMode = debugMode;
}

//+------------------------------------------------------------------+
//| Get current debug mode state                                      |
//+------------------------------------------------------------------+
bool Patterns_GetDebugMode() {
   return g_Patterns_DebugMode;
}

//+------------------------------------------------------------------+
//| Custom debug print function - only outputs when debug is enabled  |
//+------------------------------------------------------------------+
void Patterns_DebugPrint(string message) {
   if(g_Patterns_DebugMode) {
      Print(message);
   }
}

//+------------------------------------------------------------------+
//| Always print function - for critical messages regardless of debug |
//+------------------------------------------------------------------+
void Patterns_InfoPrint(string message) {
   Print(message);
}

// Structure to hold trade setup information for a reversal pattern
struct TradeSetup {
   datetime time;         // Time of the trade
   double entry;          // Entry price
   double sl;             // Stop loss level
   double tp;             // Take profit level
   double trailing_sl;    // Trailing stop loss (if applicable)
   string type;           // Pattern type: "pattern1", "pattern2", "pattern3"
   GG gg;                 // The Golden Gap that generated this setup
   double risk_pips;      // Risk in pips
   double spread;         // Spread at the time of detection
   string direction;      // "bullish" or "bearish"
};

// Global arrays to store detected trades
TradeSetup g_BearishTrades[];
TradeSetup g_BullishTrades[];
int g_BearishTradeCount = 0;
int g_BullishTradeCount = 0;
double g_RiskRewardRatio = 2.0;

//+------------------------------------------------------------------+
//| Get the number of bearish trades                                  |
//+------------------------------------------------------------------+
int GetBearishTradeCount() {
   return g_BearishTradeCount;
}

//+------------------------------------------------------------------+
//| Get the number of bullish trades                                  |
//+------------------------------------------------------------------+
int GetBullishTradeCount() {
   return g_BullishTradeCount;
}

//+------------------------------------------------------------------+
//| Get a bearish trade by index                                      |
//+------------------------------------------------------------------+
TradeSetup GetBearishTrade(int index) {
   if(index >= 0 && index < g_BearishTradeCount) {
      return g_BearishTrades[index];
   }
   TradeSetup empty;
   ZeroMemory(empty);
   return empty;
}

//+------------------------------------------------------------------+
//| Get a bullish trade by index                                      |
//+------------------------------------------------------------------+
TradeSetup GetBullishTrade(int index) {
   if(index >= 0 && index < g_BullishTradeCount) {
      return g_BullishTrades[index];
   }
   TradeSetup empty;
   ZeroMemory(empty);
   return empty;
}

//+------------------------------------------------------------------+
//| Set the risk-reward ratio                                         |
//+------------------------------------------------------------------+
void SetRiskRewardRatio(double riskReward) {
   g_RiskRewardRatio = riskReward;
}

//+------------------------------------------------------------------+
//| Add a bearish trade to the array                                  |
//+------------------------------------------------------------------+
void AddBearishTrade(datetime time, double entry, double sl, double tp, 
                    string patternType, GG &gg, double risk, double spread) {
   // Resize array if needed
   if(g_BearishTradeCount >= ArraySize(g_BearishTrades)) {
      ArrayResize(g_BearishTrades, ArraySize(g_BearishTrades) + 50);
   }
   
   // Add the trade setup
   g_BearishTrades[g_BearishTradeCount].time = time;
   g_BearishTrades[g_BearishTradeCount].entry = entry;
   g_BearishTrades[g_BearishTradeCount].sl = sl;
   g_BearishTrades[g_BearishTradeCount].tp = tp;
   g_BearishTrades[g_BearishTradeCount].trailing_sl = 0; // Not implemented yet
   g_BearishTrades[g_BearishTradeCount].type = patternType;
   g_BearishTrades[g_BearishTradeCount].gg = gg;
   g_BearishTrades[g_BearishTradeCount].risk_pips = risk;
   g_BearishTrades[g_BearishTradeCount].spread = spread;
   g_BearishTrades[g_BearishTradeCount].direction = "bearish";
   
   g_BearishTradeCount++;
}

//+------------------------------------------------------------------+
//| Add a bullish trade to the array                                  |
//+------------------------------------------------------------------+
void AddBullishTrade(datetime time, double entry, double sl, double tp, 
                    string patternType, GG &gg, double risk, double spread) {
   // Resize array if needed
   if(g_BullishTradeCount >= ArraySize(g_BullishTrades)) {
      ArrayResize(g_BullishTrades, ArraySize(g_BullishTrades) + 50);
   }
   
   // Add the trade setup
   g_BullishTrades[g_BullishTradeCount].time = time;
   g_BullishTrades[g_BullishTradeCount].entry = entry;
   g_BullishTrades[g_BullishTradeCount].sl = sl;
   g_BullishTrades[g_BullishTradeCount].tp = tp;
   g_BullishTrades[g_BullishTradeCount].trailing_sl = 0; // Not implemented yet
   g_BullishTrades[g_BullishTradeCount].type = patternType;
   g_BullishTrades[g_BullishTradeCount].gg = gg;
   g_BullishTrades[g_BullishTradeCount].risk_pips = risk;
   g_BullishTrades[g_BullishTradeCount].spread = spread;
   g_BullishTrades[g_BullishTradeCount].direction = "bullish";
   
   g_BullishTradeCount++;
}

//+------------------------------------------------------------------+
//| Find GG reversal pattern trades                                   |
//+------------------------------------------------------------------+
void FindGGReversalPatternTrades(string symbol, GG &bullish_GGs[], int bullish_count, 
                               GG &bearish_GGs[], int bearish_count, 
                               int lookBackDays) {
   // Clear existing trade arrays
   ArrayResize(g_BearishTrades, 0);
   ArrayResize(g_BullishTrades, 0);
   g_BearishTradeCount = 0;
   g_BullishTradeCount = 0;
   
   // Get price data
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   // Calculate the number of bars to look back
   datetime startTime = TimeCurrent() - PeriodSeconds(PERIOD_D1) * lookBackDays;
   
   // Load price data
   int bars_needed = CopyRates(symbol, PERIOD_CURRENT, 0, lookBackDays * 24 * 60, rates);
   if(bars_needed <= 0) {
      Patterns_InfoPrint("Error copying rates data: " + IntegerToString(GetLastError()));
      return;
   }
   
   // Get bid/ask prices for more accurate entry
   double askPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bidPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   double currentSpread = askPrice - bidPrice;
   
   // Iterate through price data starting from second candle
   for(int i = 1; i < 10; i++) {
      // Current and previous candle data
      MqlRates current = rates[i];
      MqlRates previous = rates[i+1]; // Note: rates are in reverse chronological order
      
      datetime tradeTime = rates[i-1].time; // Next bar time for trade execution
      
      // Calculate candle-based highs and lows
      double candleBasedHigh = MathMax(current.high, previous.high);
      double candleBasedLow = MathMin(current.low, previous.low);
      
      // Simulate bid/ask prices (MQL5 doesn't store historical bid/ask)
      double closeBid = current.close;
      double closeAsk = current.close + currentSpread;
      
      // Check bearish patterns against bearish GGs
      for(int g = 0; g < bearish_count; g++) {
         // Skip inactive GGs or GGs not within the current timeframe
         if(!bearish_GGs[g].active || 
            current.time < bearish_GGs[g].start_time || 
            current.time > bearish_GGs[g].end_time) {
            continue;
         }
         
         // Pattern 1: Green candle touch reversal
         if(current.high >= bearish_GGs[g].low && 
            current.close < bearish_GGs[g].low && 
            previous.high < bearish_GGs[g].low) {
            
            // Use bid price for selling
            double entry = closeBid;
            double sl = MathMin(candleBasedHigh, bearish_GGs[g].high);
            
            // Check if SL is too close to entry
            if(sl - entry <= currentSpread) {
               sl += currentSpread;
            }
            
            double risk = sl - entry;
            double tp = entry - (risk * g_RiskRewardRatio);
            
            // Add bearish trade setup to the array
            AddBearishTrade(tradeTime, entry, sl, tp, "pattern1", bearish_GGs[g], risk, currentSpread);
         }
         
         // Pattern 2: Inverted Gap kill reversal
         else if(current.close < current.open && // Red candle
                current.open > bearish_GGs[g].high &&
                current.close < bearish_GGs[g].low &&
                previous.open < bearish_GGs[g].low &&
                previous.close > bearish_GGs[g].high &&
                previous.close > previous.open) { // Previous green
            
            // Use bid price for selling
            double entry = closeBid;
            double sl = MathMin(candleBasedHigh, bearish_GGs[g].high);
            
            // Check if SL is too close to entry
            if(sl - entry <= currentSpread) {
               sl += currentSpread;
            }
            
            double risk = sl - entry;
            double tp = entry - (risk * g_RiskRewardRatio);
            
            // Add bearish trade setup to the array
            AddBearishTrade(tradeTime, entry, sl, tp, "pattern2", bearish_GGs[g], risk, currentSpread);
         }
         
         // Pattern 3: Previous green candle closing inside GG and current red candle reversing
         else if(current.close < current.open && // Red candle
                current.close < bearish_GGs[g].low &&
                bearish_GGs[g].low < current.open && current.open < bearish_GGs[g].high &&
                previous.open < bearish_GGs[g].low &&
                bearish_GGs[g].low < previous.close && previous.close < bearish_GGs[g].high &&
                previous.close > previous.open) { // Previous green
                
            // Use bid price for selling
            double entry = closeBid;
            double sl = MathMin(candleBasedHigh, bearish_GGs[g].high);
            
            // Check if SL is too close to entry
            if(sl - entry <= currentSpread) {
               sl += currentSpread;
            }
            
            double risk = sl - entry;
            double tp = entry - (risk * g_RiskRewardRatio);
            
            // Add bearish trade setup to the array
            AddBearishTrade(tradeTime, entry, sl, tp, "pattern3", bearish_GGs[g], risk, currentSpread);
         }
      }
      
      // Check bullish patterns against bullish GGs
      for(int g = 0; g < bullish_count; g++) {
         // Skip inactive GGs or GGs not within the current timeframe
         if(!bullish_GGs[g].active || 
            current.time < bullish_GGs[g].start_time || 
            current.time > bullish_GGs[g].end_time) {
            continue;
         }
         
         // Pattern 1: Red candle touch reversal
         if(current.low <= bullish_GGs[g].high && 
            current.close > bullish_GGs[g].high && 
            previous.low > bullish_GGs[g].high) {
            
            // Use ask price for buying
            double entry = closeAsk;
            double sl = MathMax(candleBasedLow, bullish_GGs[g].low);
            
            // Check if SL is too close to entry
            if(entry - sl <= currentSpread) {
               sl -= currentSpread;
            }
            
            double risk = entry - sl;
            double tp = entry + (risk * g_RiskRewardRatio);
            
            // Add bullish trade setup to the array
            AddBullishTrade(tradeTime, entry, sl, tp, "pattern1", bullish_GGs[g], risk, currentSpread);
         }
         
         // Pattern 2: Inverted Gap kill reversal
         else if(current.close > current.open && // Green candle
                current.open < bullish_GGs[g].low &&
                current.close > bullish_GGs[g].high &&
                previous.open > bullish_GGs[g].high &&
                previous.close < bullish_GGs[g].low &&
                previous.close < previous.open) { // Previous red
            
            // Use ask price for buying
            double entry = closeAsk;
            double sl = MathMax(candleBasedLow, bullish_GGs[g].low);
            
            // Check if SL is too close to entry
            if(entry - sl <= currentSpread) {
               sl -= currentSpread;
            }
            
            double risk = entry - sl;
            double tp = entry + (risk * g_RiskRewardRatio);
            
            // Add bullish trade setup to the array
            AddBullishTrade(tradeTime, entry, sl, tp, "pattern2", bullish_GGs[g], risk, currentSpread);
         }
         
         // Pattern 3: Previous red candle closing inside GG and current green candle reversing
         else if(current.close > current.open && // Green candle
                current.close > bullish_GGs[g].high &&
                bullish_GGs[g].low < current.open && current.open < bullish_GGs[g].high &&
                previous.open > bullish_GGs[g].high &&
                bullish_GGs[g].low < previous.close && previous.close < bullish_GGs[g].high &&
                previous.close < previous.open) { // Previous red
            
            // Use ask price for buying
            double entry = closeAsk;
            double sl = MathMax(candleBasedLow, bullish_GGs[g].low);
            
            // Check if SL is too close to entry
            if(entry - sl <= currentSpread) {
               sl -= currentSpread;
            }
            
            double risk = entry - sl;
            double tp = entry + (risk * g_RiskRewardRatio);
            
            // Add bullish trade setup to the array
            AddBullishTrade(tradeTime, entry, sl, tp, "pattern3", bullish_GGs[g], risk, currentSpread);
         }
      }
   }
   
   Patterns_DebugPrint("Found " + IntegerToString(g_BearishTradeCount) + " bearish and " + 
                     IntegerToString(g_BullishTradeCount) + " bullish pattern trades");
}

//+------------------------------------------------------------------+
//| Plot a single trade setup on the chart                            |
//+------------------------------------------------------------------+
void PlotTradeSetup(TradeSetup &trade, int index, bool isBullish) {
   string direction = isBullish ? "Bull" : "Bear";
   color entryColor = isBullish ? clrGreen : clrRed;
   color slColor = clrLightGray;
   color tpColor = clrLightBlue;
   
   // Variables to define box boundaries
   datetime timeRight = trade.time + PeriodSeconds(PERIOD_CURRENT) * 2; // Extend box to the right
   
   // 1. Entry line/point
   string entryName = "TradeEntry" + direction + "_" + IntegerToString(index);
   ObjectCreate(0, entryName, OBJ_TREND, 0, 
               trade.time, trade.entry, 
               timeRight, trade.entry);
   ObjectSetInteger(0, entryName, OBJPROP_COLOR, entryColor);
   ObjectSetInteger(0, entryName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, entryName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, entryName, OBJPROP_BACK, false);
   ObjectSetInteger(0, entryName, OBJPROP_SELECTABLE, false);
   
   // 2. Stop Loss box
   string slName = "TradeSL" + direction + "_" + IntegerToString(index);
   ObjectCreate(0, slName, OBJ_RECTANGLE, 0, 
               trade.time, isBullish ? trade.sl : trade.entry,
               timeRight, isBullish ? trade.entry : trade.sl);
   ObjectSetInteger(0, slName, OBJPROP_COLOR, slColor);
   ObjectSetInteger(0, slName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, slName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, slName, OBJPROP_FILL, true);
   ObjectSetInteger(0, slName, OBJPROP_BACK, true);
   ObjectSetInteger(0, slName, OBJPROP_SELECTABLE, false);
   
   // 3. Take Profit box
   string tpName = "TradeTP" + direction + "_" + IntegerToString(index);
   ObjectCreate(0, tpName, OBJ_RECTANGLE, 0, 
               trade.time, isBullish ? trade.entry : trade.tp,
               timeRight, isBullish ? trade.tp : trade.entry);
   ObjectSetInteger(0, tpName, OBJPROP_COLOR, tpColor);
   ObjectSetInteger(0, tpName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, tpName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, tpName, OBJPROP_FILL, true);
   ObjectSetInteger(0, tpName, OBJPROP_BACK, true);
   ObjectSetInteger(0, tpName, OBJPROP_SELECTABLE, false);
   
   // Add tooltip with information about the trade
   string tooltip = StringFormat(
      "%s Pattern %s\nEntry: %g\nSL: %g\nTP: %g\nRisk: %g\nR:R: %g:1\nTime: %s\nGG Type: %s",
      trade.direction,
      trade.type,
      trade.entry,
      trade.sl,
      trade.tp,
      trade.risk_pips,
      g_RiskRewardRatio,
      TimeToString(trade.time),
      trade.gg.type
   );
   
   ObjectSetString(0, entryName, OBJPROP_TOOLTIP, tooltip);
   ObjectSetString(0, slName, OBJPROP_TOOLTIP, tooltip);
   ObjectSetString(0, tpName, OBJPROP_TOOLTIP, tooltip);
}

//+------------------------------------------------------------------+
//| Plot all detected trade setups                                    |
//+------------------------------------------------------------------+
void PlotTradeSetups() {
   // Plot bearish trades
   for(int i = 0; i < g_BearishTradeCount; i++) {
      PlotTradeSetup(g_BearishTrades[i], i, false);
   }
   
   // Plot bullish trades
   for(int i = 0; i < g_BullishTradeCount; i++) {
      PlotTradeSetup(g_BullishTrades[i], i, true);
   }
}

//+------------------------------------------------------------------+
//| Clear all plotted trade setups                                    |
//+------------------------------------------------------------------+
void ClearTradeSetups() {
   ObjectsDeleteAll(0, "TradeEntryBear_");
   ObjectsDeleteAll(0, "TradeSLBear_");
   ObjectsDeleteAll(0, "TradeTPBear_");
   ObjectsDeleteAll(0, "TradeEntryBull_");
   ObjectsDeleteAll(0, "TradeSLBull_");
   ObjectsDeleteAll(0, "TradeTPBull_");
}