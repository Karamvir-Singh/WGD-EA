// WGD-Bot: Trading Expert for Reversal Patterns at Guru Gaps
// Copyright © 2025
//
// This expert advisor detects reversal patterns touching Guru Gaps (GG)
// and places actual trades when these setups are identified

#include <Patterns.mqh>
#include <Trade\Trade.mqh>

// Input parameters for configurability
input string InpSymbol = "";           // Symbol (empty for current chart symbol)
input int InpLookBackDays = 30;        // Number of days to look back
input ENUM_TIMEFRAMES InpHTF = PERIOD_H1; // Higher Timeframe for GGs
input ENUM_TIMEFRAMES InpLTF = PERIOD_M5; // Lower Timeframe for GGs
input double InpRiskRewardRatio = 2.0;    // Risk:Reward ratio
input double InpRiskPercent = 1.0;        // Risk percent per trade (% of balance)
input double InpMaxLotSize = 5.0;         // Maximum lot size (to prevent oversized trades)
input bool InpPlotGGs = true;             // Plot Guru Gaps
input bool InpPlotTrades = true;          // Plot pattern trades
input bool InpEnableRealTrading = true;   // Enable real trading (false = demo mode)
input bool InpReverseSignal = false;      // Reverse the trade direction and levels
input bool InpDebugMode = false;          // Enable debug output in logs

// Global arrays to store GGs
GG g_bullishGGs[];
GG g_bearishGGs[];
int g_bullishCount = 0;
int g_bearishCount = 0;

// Global arrays to store processed trade IDs to avoid duplicates
datetime g_processedBullishTrades[];
datetime g_processedBearishTrades[];
int g_processedBullishCount = 0;
int g_processedBearishCount = 0;

// Global variables
CTrade g_trade;
datetime g_lastUpdateTime = 0;
datetime g_lastDetectionTime = 0;
string g_symbol;
bool g_firstRun = true;

//+------------------------------------------------------------------+
//| Custom debug print function - only outputs when debug is enabled  |
//+------------------------------------------------------------------+
void DebugPrint(string message)
{
   if(InpDebugMode) {
      Print(message);
   }
}

//+------------------------------------------------------------------+
//| Always print function - for critical messages regardless of debug |
//+------------------------------------------------------------------+
void InfoPrint(string message)
{
   Print(message);
}

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set the symbol to use
   g_symbol = (InpSymbol == "") ? Symbol() : InpSymbol;
   
   // Check if the symbol is valid
   if(!SymbolSelect(g_symbol, true)) {
      InfoPrint("Error: Cannot select symbol " + g_symbol);
      return INIT_FAILED;
   }
   
   // Set debug mode for all modules to match our EA debug mode
   GG_SetDebugMode(InpDebugMode);
   Patterns_SetDebugMode(InpDebugMode);
   
   // Initialize trade object
   g_trade.SetExpertMagicNumber(123456); // Set a unique magic number for this EA
   g_trade.SetMarginMode();
   g_trade.SetTypeFillingBySymbol(g_symbol);
   g_trade.LogLevel(InpDebugMode ? LOG_LEVEL_ALL : LOG_LEVEL_ERRORS);  // Only detailed logs in debug mode
   
   // Set the risk:reward ratio
   SetRiskRewardRatio(InpRiskRewardRatio);
   
   // Clear previous objects
   ClearAllObjects();
   
   // Reset processed trades arrays
   ArrayResize(g_processedBullishTrades, 0);
   ArrayResize(g_processedBearishTrades, 0);
   g_processedBullishCount = 0;
   g_processedBearishCount = 0;
   
   // First run flag - to skip trading historical patterns on startup
   g_firstRun = true;
   
   // Initial detection of GGs
   DetectAllGGs();
   
   // Plot GGs if required
   if(InpPlotGGs) {
      PlotAllGGs();
   }
   
   // Set up a timer to update GGs periodically (every 5 minutes)
   EventSetTimer(300);
   
   InfoPrint("WGD-Bot initialized successfully for symbol: " + g_symbol);
   InfoPrint("Trading is " + (InpEnableRealTrading ? "ENABLED" : "DISABLED (Demo Mode)"));
   InfoPrint("Each new pattern will be traded once when detected");
   InfoPrint("Maximum lot size set to " + DoubleToString(InpMaxLotSize, 2));
   InfoPrint("Debug mode is " + (InpDebugMode ? "ENABLED" : "DISABLED"));
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clear all objects on chart
   ClearAllObjects();
   
   // Kill the timer
   EventKillTimer();
   
   InfoPrint("WGD-Bot stopped");
}

//+------------------------------------------------------------------+
//| Calculate mid price and round to symbol precision                 |
//+------------------------------------------------------------------+
double GetMidPrice(string symbol)
{
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double midPrice = (ask + bid) / 2.0;
   
   // Round to the same precision as ask and bid
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   return NormalizeDouble(midPrice, digits);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Skip processing if no price change
   static double lastPrice = 0;
   double currentPrice = GetMidPrice(g_symbol); // Use mid price instead of bid
   if(lastPrice == currentPrice)
      return;
   lastPrice = currentPrice;
   
   // Update GGs and check for new patterns every 5 minutes or on a new bar
   datetime currentTime = TimeCurrent();
   datetime currentBarTime = iTime(g_symbol, PERIOD_CURRENT, 0);
   
   // Check if we have a new bar
   bool newBar = (currentBarTime > g_lastDetectionTime);
   bool timeToUpdate = (currentTime - g_lastUpdateTime > 300); // 5 minutes
   
   // Only update when needed to conserve resources
   if(timeToUpdate || newBar) {
      // Update Guru Gaps
      DetectAllGGs();
      
      // Plot GGs if required
      if(InpPlotGGs) {
         ClearGGs();
         PlotAllGGs();
      }
      
      // Find reversal patterns and execute trades if new ones are found
      g_lastDetectionTime = currentBarTime;
      g_lastUpdateTime = currentTime;
      
      // Find pattern trades
      FindGGReversalPatternTrades(g_symbol, g_bullishGGs, g_bullishCount, 
                              g_bearishGGs, g_bearishCount, InpLookBackDays);
      
      // Check and execute new pattern trades
      ProcessNewTrades();
      
      // Plot all trade setups if required (this plots ALL patterns, historical and current)
      if(InpPlotTrades) {
         ClearTradeSetups();
         PlotTradeSetups();
      }
      
      // After first run, clear the flag
      if(g_firstRun) {
         g_firstRun = false;
         // Store all current patterns as processed to avoid trading historical patterns
         StoreCurrentPatternsAsProcessed();
         DebugPrint("Initial patterns stored as processed - will only trade new patterns from now on");
      }
      
      // Refresh the chart
      ChartRedraw();
   }
}

//+------------------------------------------------------------------+
//| Store all current patterns as already processed                   |
//+------------------------------------------------------------------+
void StoreCurrentPatternsAsProcessed()
{
   // Process all current bullish patterns
   int bullishCount = GetBullishTradeCount();
   ArrayResize(g_processedBullishTrades, bullishCount);
   g_processedBullishCount = 0;
   
   for(int i = 0; i < bullishCount; i++) {
      TradeSetup trade = GetBullishTrade(i);
      g_processedBullishTrades[g_processedBullishCount++] = trade.time;
   }
   
   // Process all current bearish patterns
   int bearishCount = GetBearishTradeCount();
   ArrayResize(g_processedBearishTrades, bearishCount);
   g_processedBearishCount = 0;
   
   for(int i = 0; i < bearishCount; i++) {
      TradeSetup trade = GetBearishTrade(i);
      g_processedBearishTrades[g_processedBearishCount++] = trade.time;
   }
   
   DebugPrint("Stored " + IntegerToString(g_processedBullishCount) + " bullish and " + 
             IntegerToString(g_processedBearishCount) + " bearish patterns as already processed");
}

//+------------------------------------------------------------------+
//| Check if a trade has already been processed                       |
//+------------------------------------------------------------------+
bool IsTradeProcessed(datetime tradeTime, bool isBullish)
{
   // Check the appropriate array based on trade direction
   if(isBullish) {
      // Check bullish trades
      for(int i = 0; i < g_processedBullishCount; i++) {
         if(g_processedBullishTrades[i] == tradeTime) {
            return true;
         }
      }
   } else {
      // Check bearish trades
      for(int i = 0; i < g_processedBearishCount; i++) {
         if(g_processedBearishTrades[i] == tradeTime) {
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Add a trade to the processed list                                 |
//+------------------------------------------------------------------+
void AddProcessedTrade(datetime tradeTime, bool isBullish)
{
   if(isBullish) {
      int newSize = g_processedBullishCount + 1;
      ArrayResize(g_processedBullishTrades, newSize);
      g_processedBullishTrades[g_processedBullishCount] = tradeTime;
      g_processedBullishCount++;
   } else {
      int newSize = g_processedBearishCount + 1;
      ArrayResize(g_processedBearishTrades, newSize);
      g_processedBearishTrades[g_processedBearishCount] = tradeTime;
      g_processedBearishCount++;
   }
}

//+------------------------------------------------------------------+
//| Timer event function                                              |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Force an update of GGs and patterns
   g_lastUpdateTime = 0;
}

//+------------------------------------------------------------------+
//| Clear all chart objects created by this EA                        |
//+------------------------------------------------------------------+
void ClearAllObjects()
{
   // Clear GGs
   ClearGGs();
   
   // Clear pattern trades
   ClearTradeSetups();
}

//+------------------------------------------------------------------+
//| Detect bullish and bearish GGs                                    |
//+------------------------------------------------------------------+
void DetectAllGGs()
{
   // Temporary array to hold all GGs
   GG allGGs[];
   int ggCount = 0;
   
   // Detect Guru Gaps (this will fill the allGGs array)
   DetectGuruGaps(g_symbol, allGGs, ggCount, InpHTF, InpLTF, InpLookBackDays);
   
   // Resize arrays to hold bullish and bearish GGs
   ArrayResize(g_bullishGGs, ggCount);
   ArrayResize(g_bearishGGs, ggCount);
   g_bullishCount = 0;
   g_bearishCount = 0;
   
   // Separate bullish and bearish GGs
   for(int i = 0; i < ggCount; i++)
   {
      if(allGGs[i].type == "Bullish")
      {
         g_bullishGGs[g_bullishCount] = allGGs[i];
         g_bullishCount++;
      }
      else if(allGGs[i].type == "Bearish")
      {
         g_bearishGGs[g_bearishCount] = allGGs[i];
         g_bearishCount++;
      }
   }
   
   // Resize arrays to actual count
   ArrayResize(g_bullishGGs, g_bullishCount);
   ArrayResize(g_bearishGGs, g_bearishCount);
}

//+------------------------------------------------------------------+
//| Plot all detected GGs on the chart                               |
//+------------------------------------------------------------------+
void PlotAllGGs()
{
   // Plot bullish GGs
   for(int i = 0; i < g_bullishCount; i++)
   {
      PlotGG(g_bullishGGs[i], i);
   }
   
   // Plot bearish GGs
   for(int i = 0; i < g_bearishCount; i++)
   {
      PlotGG(g_bearishGGs[i], i + g_bullishCount); // Use offset to avoid name conflicts
   }
}

//+------------------------------------------------------------------+
//| Process and execute trades for newly found patterns               |
//+------------------------------------------------------------------+
void ProcessNewTrades()
{
   // Check for bullish trades
   int bullishCount = GetBullishTradeCount();
   for(int i = 0; i < bullishCount; i++) {
      TradeSetup trade = GetBullishTrade(i);
      
      // Skip if this trade has already been processed
      if(IsTradeProcessed(trade.time, true)) {
         continue;
      }
      
      // Skip historical patterns on first run
      if(g_firstRun) {
         DebugPrint("Skipping bullish pattern on startup: " + TimeToString(trade.time));
         continue;
      }
      
      // This is a new pattern, execute it
      InfoPrint("Trading NEW bullish pattern: " + TimeToString(trade.time));
      ExecuteTrade(trade, true);
      
      // Add to processed list to avoid duplicate trading
      AddProcessedTrade(trade.time, true);
   }
   
   // Check for bearish trades
   int bearishCount = GetBearishTradeCount();
   for(int i = 0; i < bearishCount; i++) {
      TradeSetup trade = GetBearishTrade(i);
      
      // Skip if this trade has already been processed
      if(IsTradeProcessed(trade.time, false)) {
         continue;
      }
      
      // Skip historical patterns on first run
      if(g_firstRun) {
         DebugPrint("Skipping bearish pattern on startup: " + TimeToString(trade.time));
         continue;
      }
      
      // This is a new pattern, execute it
      InfoPrint("Trading NEW bearish pattern: " + TimeToString(trade.time));
      ExecuteTrade(trade, false);
      
      // Add to processed list to avoid duplicate trading
      AddProcessedTrade(trade.time, false);
   }
}

//+------------------------------------------------------------------+
//| Calculate appropriate lot size based on risk                      |
//+------------------------------------------------------------------+
double CalculateLotSize(double entryPrice, double stopLoss, double riskPercentage)
{
   // Get account balance
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // Calculate the amount to risk based on the risk percentage
   double riskAmount = balance * riskPercentage / 100.0;
   
   // Calculate the risk in price points
   double riskPips = MathAbs(entryPrice - stopLoss);
   
   // Get symbol specifications
   double tickSize = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_VALUE);
   double pointSize = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   
   // Debug info
   DebugPrint("Risk calculation parameters: Balance=" + DoubleToString(balance, 2) + 
         ", Risk Pips=" + DoubleToString(riskPips, 5) +
         ", Point=" + DoubleToString(pointSize, 5) +
         ", Tick Size=" + DoubleToString(tickSize, 5) +
         ", Tick Value=" + DoubleToString(tickValue, 5));
   
   // Avoid division by zero
   if(riskPips <= 0 || tickValue <= 0 || tickSize <= 0) {
      InfoPrint("Warning: Invalid risk calculation parameters");
      return 0.1; // Return minimum default lot size
   }
   
   // Calculate how many ticks in our risk
   double ticks = riskPips / tickSize;
   
   // Calculate the cost per lot for our risk
   double costPerLot = ticks * tickValue;
   
   // Avoid division by zero
   if(costPerLot <= 0) {
      InfoPrint("Warning: Cost per lot calculation resulted in zero or negative value");
      return 0.1; // Return minimum default lot size
   }
   
   // Calculate lot size based on risk amount
   double lotSize = riskAmount / costPerLot;
   
   // Make sure lot size is within allowed limits
   double minLot = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_STEP);
   
   // Apply our custom max lot size restriction
   maxLot = MathMin(maxLot, InpMaxLotSize);
   
   // Normalize lot size to broker's requirements
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   DebugPrint("Calculated lot size: " + DoubleToString(lotSize, 2) + 
         " (Min: " + DoubleToString(minLot, 2) +
         ", Max: " + DoubleToString(maxLot, 2) +
         ", Step: " + DoubleToString(lotStep, 2) + ")");
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Execute a single trade based on pattern                           |
//+------------------------------------------------------------------+
void ExecuteTrade(TradeSetup &trade, bool isBullish)
{
   // Reverse the trade direction and levels if reverseSignal is true
   if(InpReverseSignal) {
      isBullish = !isBullish; // Flip the direction
      double tempSL = trade.sl;
      trade.sl = trade.tp; // Swap SL and TP
      trade.tp = tempSL;
   }

   // Skip trades if no risk-reward (likely a data or calculation error)
   if(MathAbs(trade.entry - trade.sl) < 0.0000001 || 
      MathAbs(trade.tp - trade.entry) < 0.0000001) {
      InfoPrint("Skipping invalid trade setup - zero risk or reward");
      return;
   }
   
   // Get current market price
   double currentPrice = isBullish ? SymbolInfoDouble(g_symbol, SYMBOL_ASK) : SymbolInfoDouble(g_symbol, SYMBOL_BID);
   
   // Calculate the lot size using our improved position sizing function
   double lotSize = CalculateLotSize(currentPrice, trade.sl, InpRiskPercent);
   
   // If lot size calculation failed or returned zero
   if(lotSize <= 0) {
      InfoPrint("Error calculating lot size. Trade aborted.");
      return;
   }
   
   // Determine trade type
   ENUM_ORDER_TYPE orderType = isBullish ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   
   // Print trade info
   string tradeInfo = StringFormat(
      "Executing %s trade: Pattern %s, Entry: %g, SL: %g, TP: %g, Lot Size: %g%s",
      isBullish ? "BULLISH" : "BEARISH",
      trade.type,
      currentPrice,  // Using current market price for display
      trade.sl,
      trade.tp,
      lotSize,
      InpReverseSignal ? " (Reversed Signal)" : ""
   );
   
   InfoPrint("⚡ NEW TRADE ⚡ - " + tradeInfo);
   
   // Execute the trade if real trading is enabled
   if(InpEnableRealTrading) {
      // Execute market order
      bool result = g_trade.PositionOpen(
         g_symbol,
         orderType,
         lotSize,
         currentPrice,  // Use current market price for entry
         trade.sl,      // Stop Loss
         trade.tp       // Take Profit
      );
      
      if(result) {
         InfoPrint("✅ Trade executed successfully: Deal #" + IntegerToString(g_trade.ResultDeal()) + 
               ", Order #" + IntegerToString(g_trade.ResultOrder()));
      } else {
         string errorMessage = "❌ Failed to execute trade: Error #" + IntegerToString(g_trade.ResultRetcode()) + 
               " - " + g_trade.ResultRetcodeDescription();
         InfoPrint(errorMessage);
         
         // More detailed error information
         string details = "Additional error details:" + 
               " Symbol:" + g_symbol +
               " Type:" + EnumToString(orderType) +
               " Volume:" + DoubleToString(lotSize, 2) +
               " Price:" + DoubleToString(currentPrice, (int)SymbolInfoInteger(g_symbol, SYMBOL_DIGITS)) +
               " SL:" + DoubleToString(trade.sl, (int)SymbolInfoInteger(g_symbol, SYMBOL_DIGITS)) +
               " TP:" + DoubleToString(trade.tp, (int)SymbolInfoInteger(g_symbol, SYMBOL_DIGITS));
         InfoPrint(details);
      }
   } else {
      InfoPrint("🔄 Trade SIMULATED (Demo Mode): " + tradeInfo);
   }
}
