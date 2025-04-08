//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   
   Comment("Waheguru Ji Da Bot\nAsk price: ", SymbolInfoDouble(_Symbol, SYMBOL_ASK), "\nBid price: ", SymbolInfoDouble(_Symbol, SYMBOL_BID));
   //Comment("Spread: ", SymbolInfoDouble(_Symbol, SYMBOL_SPREAD));
  }
//+------------------------------------------------------------------+
