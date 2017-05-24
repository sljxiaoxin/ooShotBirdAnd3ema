//+------------------------------------------------------------------+
//|                                                  CTradeMgr.mqh |
//|                                 Copyright 2015, Vasiliy Sokolov. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015."
#property link      "http://www.mql5.com"

//利润保护类
//功能：对冲单开单，对冲单或原单止盈互换，item整体止盈
 class CProfitMgr
 {
      private:
         CDictionary *m_dict;
         CTradeMgr *m_TradeMgr;
         double m_TpInMoney;
         int m_releaseHedgStep;
         int m_releaseHedgAdd;
      public:
         
         CProfitMgr(CTradeMgr *TradeMgr, CDictionary *_dict){
            m_dict = _dict;
            m_TradeMgr = TradeMgr;
            m_releaseHedgStep = 400;
            m_releaseHedgAdd = 0;
         };
         void Init(double tpmoney);
         void EachColumnDo(void);    //每根柱子需要执行的动作
         void CheckOpenHedg(void);   //检测是否需要开启对冲单，最好每颗柱子开盘执行一次
         void CheckTakeprofit(string tradeType); //检测是否该止盈，应该每次tick执行
         double GetNetProfit(CItems* item);  //获取item当前净利润
         double GetNetPips(int ticket);      //获取盈利点数
         bool isOrderClosed(int ticket);     //订单是否已关闭
         bool CloseItem(CItems* item);   //关闭item内所有订单
 };
 void CProfitMgr::Init(double tpmoney)
 {
      m_TpInMoney = tpmoney;
 }
 void CProfitMgr::EachColumnDo(void)
 {
      if(m_releaseHedgAdd >0)
      {
         m_releaseHedgAdd -= 1;
      }
 }
 void CProfitMgr::CheckOpenHedg(void)
 {
      //Print("begin hedg");
      if(m_dict.Total()<=0)return;
     // Print("hedg come in0 total is : ", m_dict.Total());
      CItems* currItem = m_dict.GetFirstNode();
     // Print("hedg come in1");
      for(int i = 1; currItem != NULL; i++)
      {
         //Print("open hedg 02 i is:",i);
         if(currItem.Hedg == 0){
            //Print("pre ticket is:",currItem.Hedg);
            if(OrderSelect(currItem.GetTicket(), SELECT_BY_TICKET)==true){
               double _net = OrderProfit();
               int TradeType = OrderType();
               double _lot = OrderLots();
               //Print("log ticket is:",currItem.GetTicket(),"; profit:",_net);
               if(_net < (-1*3*m_TpInMoney)){
                  if(TradeType == OP_BUY){
                     int sTicket = m_TradeMgr.Sell(_lot,0,0,"Hedg "+currItem.GetTicket());
                     if(sTicket >0){
                        currItem.Hedg = sTicket;
                     }
                  }
                  if(TradeType == OP_SELL){
                     int bTicket = m_TradeMgr.Buy(_lot,0,0,"Hedg "+currItem.GetTicket());
                     if(bTicket >0){
                        currItem.Hedg = bTicket;
                     }
                    // Print("open hedg 03 i is:",i);
                  }
               }
            }
         }
         if(m_dict.Total() >0){
            currItem = m_dict.GetNextNode();
         }else{
            currItem = NULL;
         }
         
      }
      //Print("hedg come in3");
 }
 
 void  CProfitMgr::CheckTakeprofit(string tradeType)
 {
      //Print("begin profit");
      int ord_arr[20];
      int k = 0;
      for(int j=0;j<20;j++){
         ord_arr[j]=0;
      }
      //Print("m_dict total:",m_dict.Total());
      if(m_dict.Total()<=0)return;
     //Print("m_dict total before:",m_dict.Total());
     CItems* currItem = m_dict.GetFirstNode();
     //Print("currItem first is:",currItem);
     for(int i = 1; (currItem != NULL && CheckPointer(currItem)!=POINTER_INVALID); i++)
     {
         //Print("come into for");
         double _net = GetNetProfit(currItem);
         if(_net >= currItem.GetTP()){
            CloseItem(currItem);
            //m_dict.DeleteCurrentNode();  //删除当前节点
            ord_arr[k] = currItem.GetTicket();
            //Print("====TP OK==================>",currItem.GetTicket());
            k += 1;
         }else{
            //检测是否有对冲单，如果有对冲单，check原单或对冲单是否已有达到100点利润者，哪个先到平仓哪个
            //TODO
            if(currItem.Hedg != 0){
               if(isOrderClosed(currItem.Hedg) || isOrderClosed(currItem.GetTicket())){
                   //如果对冲单和原单其中有一个已经关闭了就不能再关了    
               }else{
                  //哪个先到x点利润就先平仓
                  double hedgPips = GetNetPips(currItem.Hedg);        //对冲单净盈利点数
                  double tickPips = GetNetPips(currItem.GetTicket()); //原始单净盈利点数 
                  double closePips = 50 + MathCeil(m_releaseHedgAdd/10);
                  bool isCanClose = true;
                  if(hedgPips > closePips){
                     int hedgOrderType;
                     if(OrderSelect(currItem.Hedg, SELECT_BY_TICKET)==true){
                        hedgOrderType = OrderType();
                     }
                     /*
                     if(tradeType == "buy" && hedgOrderType == OP_BUY){
                        isCanClose = false;
                     }
                     if(tradeType == "sell" && hedgOrderType == OP_SELL){
                        isCanClose = false;
                     }
                     */
                     if(isCanClose){
                        m_TradeMgr.Close(currItem.Hedg);
                        m_releaseHedgAdd += m_releaseHedgStep;
                     }
                  }
                  if(tickPips > closePips){
                     int tickOrderType;
                     if(OrderSelect(currItem.GetTicket(), SELECT_BY_TICKET)==true){
                        tickOrderType = OrderType();
                     }
                     /*
                     if(tradeType == "buy" && tickOrderType == OP_BUY){
                        isCanClose = false;
                     }
                     if(tradeType == "sell" && tickOrderType == OP_SELL){
                        isCanClose = false;
                     }
                     */
                     if(isCanClose){
                        m_TradeMgr.Close(currItem.GetTicket());
                        m_releaseHedgAdd += m_releaseHedgStep;
                     }
                  }
               }
            }
         }
         //Print("m_dict total after:",m_dict.Total());
         if(m_dict.Total() >0){
            currItem = m_dict.GetNextNode();
         }else{
            currItem = NULL;
         }
     }
     for(int m=0;m<20;m++){
         if(ord_arr[m] > 0){
            m_dict.DeleteObjectByKey(ord_arr[m]);  //删除止盈的item
            Print("DeleteObjectByKey:",ord_arr[m]);
         }
     }
     
 }
 //获取单个item总利润
 double CProfitMgr::GetNetProfit(CItems* item)
 {
      double _net = 0;
      if(OrderSelect(item.GetTicket(), SELECT_BY_TICKET)==true){
         //原单利润
         _net += OrderProfit();
      }
      if(item.Hedg != 0){
         if(OrderSelect(item.Hedg, SELECT_BY_TICKET)==true){
            //原单利润
            _net += OrderProfit();
         }
      }
      for(int i=0;i<item.Marti.Total();i++){
         if(OrderSelect(item.Marti.At(i), SELECT_BY_TICKET)==true){
            //原单利润
            _net += OrderProfit();
         }
      }
      return _net;
 }
 
 bool CProfitMgr::CloseItem(CItems* item)
 {
      if(item.GetTicket() != 0){
         m_TradeMgr.Close(item.GetTicket());
      }
      if(item.Hedg != 0){
         m_TradeMgr.Close(item.Hedg);
      }
      for(int i=0;i<item.Marti.Total();i++){
         m_TradeMgr.Close(item.Marti.At(i));
      }
      return true;
 }
 
 double CProfitMgr::GetNetPips(int ticket)
 {
    double pips = 0;
    if(OrderSelect(ticket, SELECT_BY_TICKET)==true){
        datetime dtc = OrderCloseTime();
        if(dtc >0){
            //订单已平仓，则返回0
            return pips;
        }
        int TradeType = OrderType();
        double openPrice = OrderOpenPrice();
        if(TradeType == OP_BUY){
            pips = (Ask - openPrice)/m_TradeMgr.GetPip();
        }
        if(TradeType == OP_SELL){
            pips = (openPrice - Bid)/m_TradeMgr.GetPip();
        }
    }
    return pips;
 }
 
 bool CProfitMgr::isOrderClosed(int ticket)
 {
    if(OrderSelect(ticket, SELECT_BY_TICKET)==true){
         datetime dtc = OrderCloseTime();
         if(dtc >0){
            return true;
         }else{
            return false;
         }
    }
    return false;
 }
 
 