#include <Patterns.mqh>

// Input parameters for configurability
input string SymbolToUse = "";        // Symbol (empty for current chart symbol)
input int LookBackDays = 30;          // Number of days to look back
input ENUM_TIMEFRAMES HTF = PERIOD_H1; // Higher Timeframe for GGs
input ENUM_TIMEFRAMES LTF = PERIOD_M5; // Lower Timeframe for GGs
input double RiskRewardRatio = 2.0;    // Risk:Reward ratio
input bool PlotGGs = true;             // Plot Golden Gaps
input bool PlotPatterns = true;        // Plot pattern trades

// Global arrays to store GGs
GG bullishGGs[];
GG bearishGGs[];
int bullishCount = 0;
int bearishCount = 0;

//+------------------------------------------------------------------+
//| Script program start function                                     |
//+------------------------------------------------------------------+
void OnStart()
{
   // Get the symbol to use
   string symbol = (SymbolToUse == "") ? Symbol() : SymbolToUse;
   
   // Clear previous objects
   ClearAllObjects();
   
   // Set the risk:reward ratio
   SetRiskRewardRatio(RiskRewardRatio);
   
   // Step 1: Detect all GGs
   DetectAllGGs(symbol);
   
   // Step 2: Plot GGs if required
   if(PlotGGs)
   {
      PlotAllGGs();
   }
   
   // Step 3: Detect reversal patterns if required
   if(PlotPatterns)
   {
      // Find reversal patterns
      FindGGReversalPatternTrades(symbol, bullishGGs, bullishCount, bearishGGs, bearishCount, LookBackDays);
      
      // Plot the detected pattern trades
      PlotTradeSetups();
      
      // Print trade statistics
      int totalBullish = GetBullishTradeCount();
      int totalBearish = GetBearishTradeCount();
      Print("Total pattern trades found: ", totalBullish + totalBearish, 
           " (Bullish: ", totalBullish, ", Bearish: ", totalBearish, ")");
   }
   
   // Refresh the chart
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Detect bullish and bearish GGs                                    |
//+------------------------------------------------------------------+
void DetectAllGGs(string symbol)
{
   // Temporary array to hold all GGs
   GG allGGs[];
   int ggCount = 0;
   
   // Detect GGs (this will fill the allGGs array)
   Print("Detecting GGs for ", symbol, " (", LookBackDays, " days lookback)...");
   DetectGuruGaps(symbol, allGGs, ggCount, HTF, LTF, LookBackDays);
   
   // Resize arrays to hold bullish and bearish GGs
   ArrayResize(bullishGGs, ggCount);
   ArrayResize(bearishGGs, ggCount);
   bullishCount = 0;
   bearishCount = 0;
   
   // Separate bullish and bearish GGs
   for(int i = 0; i < ggCount; i++)
   {
      if(allGGs[i].type == "Bullish")
      {
         bullishGGs[bullishCount] = allGGs[i];
         bullishCount++;
      }
      else if(allGGs[i].type == "Bearish")
      {
         bearishGGs[bearishCount] = allGGs[i];
         bearishCount++;
      }
   }
   
   // Resize arrays to actual count
   ArrayResize(bullishGGs, bullishCount);
   ArrayResize(bearishGGs, bearishCount);
   
   Print("Found ", bullishCount, " bullish and ", bearishCount, " bearish GGs");
}

//+------------------------------------------------------------------+
//| Plot all detected GGs on the chart                               |
//+------------------------------------------------------------------+
void PlotAllGGs()
{
   // Plot bullish GGs
   for(int i = 0; i < bullishCount; i++)
   {
      PlotGG(bullishGGs[i], i);
   }
   
   // Plot bearish GGs
   for(int i = 0; i < bearishCount; i++)
   {
      PlotGG(bearishGGs[i], i + bullishCount); // Use offset to avoid name conflicts
   }
}

//+------------------------------------------------------------------+
//| Clear all chart objects created by this script                    |
//+------------------------------------------------------------------+
void ClearAllObjects()
{
   // Clear GGs
   ClearGGs();
   
   // Clear pattern trades
   ClearTradeSetups();
}
