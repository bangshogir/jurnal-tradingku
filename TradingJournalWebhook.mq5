//+------------------------------------------------------------------+
//|                                        TradingJournalWebhook.mq5 |
//|                                      Copyright 2026, [Your Name] |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Trading Journal"
#property link      "https://your-domain.com"
#property version   "1.00"

input string WebhookURL = "http://localhost:8000/api/webhook/trading-log"; // Webhook URL
input string WebhookToken = "";                                            // Webhook API Token

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("Trading Journal Webhook EA Started. URL: ", WebhookURL);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Print("Trading Journal Webhook EA Stopped.");
  }

//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
  {
   // DETECT CLOSED TRADES
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
     {
      ulong ticket = trans.deal;
      if(HistoryDealSelect(ticket))
        {
         long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
         if(entry == DEAL_ENTRY_OUT)
           {
            SendTradeDataToWebhook(ticket, "deal_close");
           }
        }
     }
     
   // DETECT PENDING ORDERS (For Testing)
   // We look for Order Addition (placed pending) or Deletion (cancelled) in history
   if(trans.type == TRADE_TRANSACTION_HISTORY_ADD)
     {
      ulong order_ticket = trans.order;
      if(HistoryOrderSelect(order_ticket))
        {
         long orderType = HistoryOrderGetInteger(order_ticket, ORDER_TYPE);
         
         // If it's a pending order (Buy Limit, Sell Limit, Buy Stop, Sell Stop)
         if(orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT || 
            orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_SELL_STOP)
           {
             // Give a tiny delay so the server records it properly
             Sleep(100);
             SendTradeDataToWebhook(order_ticket, "pending_order");
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Submits trade data to Laravel Webhook                            |
//+------------------------------------------------------------------+
void SendTradeDataToWebhook(ulong ticket, string eventType)
  {
   string symbol = "";
   string typeStr = "";
   double closePrice = 0.0;
   double lotSize = 0.0;
   double profitLoss = 0.0;
   double slPrice = 0.0;
   double tpPrice = 0.0;
   double swap = 0.0;
   double commission = 0.0;
   long magicNumber = 0;
   string comment = "";
   double entryPrice = 0.0;
   datetime openTime = 0;
   datetime closeTime = 0;
   long dealType = -1;

   // 1. If it's a Closed Deal Event
   if(eventType == "deal_close")
     {
      if(!HistoryDealSelect(ticket)) return;
      
      symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
      dealType = HistoryDealGetInteger(ticket, DEAL_TYPE); 
      typeStr = (dealType == DEAL_TYPE_BUY) ? "buy_closed" : ((dealType == DEAL_TYPE_SELL) ? "sell_closed" : "other_closed");
      
      closePrice = HistoryDealGetDouble(ticket, DEAL_PRICE);
      lotSize = HistoryDealGetDouble(ticket, DEAL_VOLUME);
      profitLoss = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
      commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      magicNumber = HistoryDealGetInteger(ticket, DEAL_MAGIC);
      comment = HistoryDealGetString(ticket, DEAL_COMMENT);
      closeTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      
      long posID = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
      
      if(HistorySelectByPosition(posID))
        {
         int dealsTotal = HistoryDealsTotal();
         for(int i=0; i<dealsTotal; i++)
           {
            ulong dticket = HistoryDealGetTicket(i);
            long dentry = HistoryDealGetInteger(dticket, DEAL_ENTRY);
            if(dentry == DEAL_ENTRY_IN)
              {
               entryPrice = HistoryDealGetDouble(dticket, DEAL_PRICE);
               openTime = (datetime)HistoryDealGetInteger(dticket, DEAL_TIME);
               break; 
              }
           }
           
         // Get SL and TP from the position history (the closing deal doesn't always have them)
         // We can find the order that closed it, or the last order modified.
         // Alternatively, we use HistoryOrderSelect for the last order of this position
         int ordersTotal = HistoryOrdersTotal();
         for(int i=ordersTotal-1; i>=0; i--)
           {
            ulong oticket = HistoryOrderGetTicket(i);
            if(HistoryOrderGetInteger(oticket, ORDER_POSITION_ID) == posID)
              {
               slPrice = HistoryOrderGetDouble(oticket, ORDER_SL);
               tpPrice = HistoryOrderGetDouble(oticket, ORDER_TP);
               break;
              }
           }
        }
     }
     
   // 2. If it's a Pending Order Event
   else if(eventType == "pending_order")
     {
      if(!HistoryOrderSelect(ticket)) return;
      
      symbol = HistoryOrderGetString(ticket, ORDER_SYMBOL);
      dealType = HistoryOrderGetInteger(ticket, ORDER_TYPE);
      
      if(dealType == ORDER_TYPE_BUY_LIMIT) typeStr = "buy_limit";
      else if(dealType == ORDER_TYPE_SELL_LIMIT) typeStr = "sell_limit";
      else if(dealType == ORDER_TYPE_BUY_STOP) typeStr = "buy_stop";
      else if(dealType == ORDER_TYPE_SELL_STOP) typeStr = "sell_stop";
      else typeStr = "unknown_pending";
      
      entryPrice = HistoryOrderGetDouble(ticket, ORDER_PRICE_OPEN);
      slPrice = HistoryOrderGetDouble(ticket, ORDER_SL);
      tpPrice = HistoryOrderGetDouble(ticket, ORDER_TP);
      closePrice = 0; // Not closed yet
      lotSize = HistoryOrderGetDouble(ticket, ORDER_VOLUME_INITIAL);
      openTime = (datetime)HistoryOrderGetInteger(ticket, ORDER_TIME_SETUP);
      closeTime = 0; // Not closed
      profitLoss = 0;
      swap = 0;
      commission = 0;
      magicNumber = HistoryOrderGetInteger(ticket, ORDER_MAGIC);
      comment = HistoryOrderGetString(ticket, ORDER_COMMENT);
     }
    
   // Format dates for PHP processing (Y-m-d H:i:s)
   string openTimeStr = (openTime > 0) ? TimeToString(openTime, TIME_DATE|TIME_SECONDS) : "";
   string closeTimeStr = (closeTime > 0) ? TimeToString(closeTime, TIME_DATE|TIME_SECONDS) : "";
   
   // Replace dots with dashes for MySQL date compatibility
   StringReplace(openTimeStr, ".", "-");
   StringReplace(closeTimeStr, ".", "-");

   // Format data as JSON
   string json = "{";
   json += "\"ticket_id\": \"" + IntegerToString(ticket) + "\",";
   json += "\"symbol\": \"" + symbol + "\",";
   json += "\"type\": \"" + typeStr + "\",";
   json += "\"entry_price\": " + DoubleToString(entryPrice, 5) + ",";
   json += "\"close_price\": " + DoubleToString(closePrice, 5) + ",";
   json += "\"sl_price\": " + DoubleToString(slPrice, 5) + ",";
   json += "\"tp_price\": " + DoubleToString(tpPrice, 5) + ",";
   json += "\"lot_size\": " + DoubleToString(lotSize, 2) + ",";
   json += "\"profit_loss\": " + DoubleToString(profitLoss, 2) + ",";
   json += "\"swap\": " + DoubleToString(swap, 2) + ",";
   json += "\"commission\": " + DoubleToString(commission, 2) + ",";
   
   if(openTimeStr != "") json += "\"open_time\": \"" + openTimeStr + "\",";
   if(closeTimeStr != "") json += "\"close_time\": \"" + closeTimeStr + "\",";
   
   json += "\"magic_number\": \"" + IntegerToString(magicNumber) + "\",";
   // Escape quotes in comment
   StringReplace(comment, "\"", "\\\"");
   json += "\"comment\": \"" + comment + "\"";
   json += "}";

   // WebRequest payload
   char post[], result_web[];
   string headers;
   
   // Prepare headers (add custom API key)
   headers = "Content-Type: application/json\r\n";
   headers += "X-Webhook-Token: " + WebhookToken + "\r\n";
   
   StringToCharArray(json, post, 0, WHOLE_ARRAY, CP_UTF8);
   
   // Note: Remove the trailing null terminator added by StringToCharArray for standard POST bodies
   int post_size = ArraySize(post);
   if(post_size > 0)
      ArrayResize(post, post_size - 1);

   Print("Sending JSON: ", json);

   int resCode = WebRequest("POST", WebhookURL, headers, 3000, post, result_web, headers);
   
   if(resCode == 200 || resCode == 201)
     {
      Print("Successfully sent trade ", ticket, " to Webhook.");
     }
   else
     {
      Print("Failed to send trade. HTTP Code: ", resCode, ". Error: ", GetLastError());
      // WebRequest error requires adding the URL to MT5 Options -> Expert Advisors -> Allow WebRequest
     }
  }
