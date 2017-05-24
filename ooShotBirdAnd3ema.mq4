//+------------------------------------------------------------------+
//|                              
//|  1、marti前先对冲，只能对冲一次，对冲的时候原单和对冲单，哪个先达目标点位则平仓，随后需要在字典里做key调换。
//|  2、对冲关闭后，开始看情况marti，marti后不能再对冲。
//|                                                      
//|                                              
//+------------------------------------------------------------------+
#property copyright "xiaoxin003"
#property link      "yangjx009@139.com"
#property version   "1.00"
#property strict

#include <Arrays\ArrayInt.mqh>
#include "dictionary.mqh" //keyvalue数据字典类
#include "trademgr.mqh"   //交易工具类
#include "citems.mqh"     //交易组item
#include "martimgr.mqh"   //马丁管理类
#include "mamgr.mqh"      //均线数值管理类
#include "profitmgr.mqh"      //均线数值管理类

extern int       MagicNumber     = 20170514;
extern double    Lots            = 0.2;
extern double    TPinMoney       = 20;          //Net TP (money)
extern int       MaxGroupNum     = 6;
extern int       MaxMartiNum     = 2;
extern double    Mutilplier      = 1;   //马丁加仓倍数
extern int       GridSize        = 40;
extern int       fastMa          = 50;
extern int       slowMa          = 89;
extern int       slowerMa        = 120;

int       NumberOfTries   = 10,
          Slippage        = 5;
datetime  CheckTime;
double    Pip;
CTradeMgr *objCTradeMgr;  //订单管理类
CMartiMgr *objCMartiMgr;  //马丁管理类
CDictionary *objDict = NULL;     //订单数据字典类
CProfitMgr *objProfitMgr; //利润和仓位管理类
int tmp = 0;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
//---
   Print("begin");
   if(Digits==2 || Digits==4) Pip = Point;
   else if(Digits==3 || Digits==5) Pip = 10*Point;
   else if(Digits==6) Pip = 100*Point;
   if(objDict == NULL){
      objDict = new CDictionary();
      objCTradeMgr = new CTradeMgr(MagicNumber, Pip, NumberOfTries, Slippage);
      objCMartiMgr = new CMartiMgr(objCTradeMgr, objDict);
      objProfitMgr = new CProfitMgr(objCTradeMgr,objDict);
   }
   objCMartiMgr.Init(GridSize, MaxMartiNum, Mutilplier);
   objProfitMgr.Init(TPinMoney);
//---
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   Print("deinit");
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
     subPrintDetails();
     if(CheckTime==iTime(NULL,0,0)){
         return;
     } else {
         CheckTime = iTime(NULL,0,0);
         /*
            每次新柱的开始：
            1、获取计算均线所需数据，计算常用均线位置值。
            2、遍历keyValue数据字典，分析该做何操作。
            3、开单检测buy / sell。
            4、
         */
         Print("#############begin############");
         CMaMgr::Init(fastMa,slowMa,slowerMa);
         //objCMartiMgr.Init(GridSize,MaxMartiNum,Mutilplier);
         objProfitMgr.EachColumnDo();
         objProfitMgr.CheckTakeprofit(checkFastSlowTradeType());
         objProfitMgr.CheckOpenHedg();
         objCMartiMgr.CheckAllMarti(checkFastSlowTradeType());
         dealRSI();
         string tradeType = deal3ema();
         Print("#############end############");
     }
 }

string  tradeType  = "none";      //buy sell none
string deal3ema()
{
   if(objDict.Total()>=MaxGroupNum)return tradeTypeCheck();
   string type = "";
   int t = 0;
   if(tradeType == "none"){
      tradeType = tradeTypeCheck();
   }else if(tradeType == "buy"){
      if(tradeTypeCheck() != "sell"){
          //开始逻辑处理
         if(checkSlowerBuy()){
            type = "slower";
         }else if(checkSlowBuy()){
            type = "slow";
         }else if(checkFastBuy()){
            type = "fast";
         }
         if(objDict.Total() >0){
            CItems* currItem = objDict.GetLastNode();
            if(currItem.Hedg == 0){
               if(currItem.GetType()== type){
                  return tradeTypeCheck();
               }
               currItem = objDict.GetPrevNode();
               if(currItem!=NULL && currItem.Hedg == 0){
                  return tradeTypeCheck();
               }
            }
            currItem = NULL;
            
         }
         if(type != ""){
            t = objCTradeMgr.Buy(Lots, 0, 0, type);
            if(t != 0){
               objDict.AddObject(t, new CItems(t, type, TPinMoney));
            }
         }
      }else if(tradeTypeCheck() == "sell"){
         tradeType = "sell";
      }
   }else if(tradeType == "sell"){
      if(tradeTypeCheck() != "buy"){
         if(checkSlowerSell()){
            type = "slower";
         }else if(checkSlowSell()){
            type = "slow";
         }else if(checkFastSell()){
            type = "fast";
         }
         if(objDict.Total() >0){
            CItems* currItem = objDict.GetLastNode();
            if(currItem.Hedg == 0){
               if(currItem.GetType()== type){
                  return tradeTypeCheck();
               }
               currItem = objDict.GetPrevNode();
               if(currItem!=NULL && currItem.Hedg == 0){
                  return tradeTypeCheck();
               }
            }
            currItem = NULL;
         }
         
         if(type != ""){
            t = objCTradeMgr.Sell(Lots, 0, 0, type);
            if(t != 0){
               objDict.AddObject(t, new CItems(t, type, TPinMoney));
            }
         }
      }else if(tradeTypeCheck() == "buy"){
         tradeType = "buy";
      }
   }
   return tradeType;
}

bool checkFastBuy(){
   int indexHighest = iHighest(NULL,0,MODE_CLOSE,20,1);
   double high = Close[indexHighest];
   if(high-Ask > 20*Pip || high-Ask<10*Pip){
      return false;
   }
   if(Low[1] - CMaMgr::s_ArrFastMa[0] <=2*Pip && Close[1] > CMaMgr::s_ArrFastMa[0] && Close[1] - CMaMgr::s_ArrFastMa[0] < 3*Pip)
   {
      return true;
   }
   return false;
}
bool checkFastSell(){
   int indexLowest = iLowest(NULL,0,MODE_CLOSE,20,1);
   double low = Close[indexLowest];
   if(Bid-low > 20*Pip || Bid-low<10*Pip){
      return false;
   }
   if(CMaMgr::s_ArrFastMa[0] - High[1] <= 2*Pip && Close[1] < CMaMgr::s_ArrFastMa[0] &&  CMaMgr::s_ArrFastMa[0] -Close[1] < 3*Pip)
   {
      return true;
   }
   return false;
}
bool checkSlowBuy(){
   if(Close[1] > Open[1] && Low[1] - CMaMgr::s_ArrSlowMa[0] <=2*Pip && Close[1]<CMaMgr::s_ArrFastMa[0]){
      return true;
   }
   return false;
}
bool checkSlowSell(){
   if(Close[1] < Open[1] && CMaMgr::s_ArrSlowMa[0] -High[1] <=2*Pip && Close[1]>CMaMgr::s_ArrFastMa[0]){
      return true;
   }
   return false;
}

bool checkSlowerBuy(){
   if(Close[1] > Open[1] && Low[1] - CMaMgr::s_ArrSlowerMa[0] <=2*Pip && Close[1]<CMaMgr::s_ArrFastMa[0]){
      return true;
   }
   return false;
}
bool checkSlowerSell(){
   if(Close[1] < Open[1] &&  CMaMgr::s_ArrSlowerMa[0]-High[1] <=2*Pip && Close[1]>CMaMgr::s_ArrFastMa[0]){
      return true;
   }
   return false;
}

string tradeTypeCheck(){
   if(CMaMgr::s_ArrFastMa[0] > CMaMgr::s_ArrSlowMa[0] && 
                CMaMgr::s_ArrFastMa[0] > CMaMgr::s_ArrSlowerMa[0] && 
                CMaMgr::s_ArrSlowMa[0] > CMaMgr::s_ArrSlowerMa[0]){
       return "buy";         
   }
   if(CMaMgr::s_ArrFastMa[0] < CMaMgr::s_ArrSlowMa[0] && 
                CMaMgr::s_ArrFastMa[0] < CMaMgr::s_ArrSlowerMa[0] && 
                CMaMgr::s_ArrSlowMa[0] < CMaMgr::s_ArrSlowerMa[0]){
       return "sell";         
   }
   return "none";
}

string checkFastSlowTradeType(){
   if(CMaMgr::s_ArrFastMa[0] > CMaMgr::s_ArrSlowMa[0]){
       return "buy";         
   }
   if(CMaMgr::s_ArrFastMa[0] < CMaMgr::s_ArrSlowMa[0] ){
       return "sell";         
   }
   return "none";
}


//---------------------------------------------------------------------------------------------
//根据rsi和均线开单处理
string RSIPosition = "";
datetime CrossTime;
void dealRSI(){
   int candleCrossNums;
   double Rsi3_one = iRSI(NULL,0,3,PRICE_CLOSE,1);
   double Rsi3_two = iRSI(NULL,0,3,PRICE_CLOSE,2);
   if(RSIPosition ==""){
      if(Rsi3_one >50){
         RSIPosition = "above";
      }else{
         RSIPosition = "below";
      }
      
      CrossTime = iTime(NULL,0,0);
   }else if(RSIPosition == "above"){
      if(Rsi3_two>50 && Rsi3_one<=50){
         //Print("DOWN!");
         RSIPosition = "below";
         candleCrossNums = (CheckTime-CrossTime)/60/Period();
        // if((TimeCurrent()-prev_order_time_buy)/60<intZhuziNums*Period()){
         //Print("RSIPosition:",RSIPosition,"| candleCrossNums:",candleCrossNums);
         CrossTime = iTime(NULL,0,0);
         RSICrossSell(candleCrossNums);
      }
   }else if(RSIPosition == "below"){
      if(Rsi3_two<=50 && Rsi3_one>50){
        // Print("UP!");
         RSIPosition = "above";
         candleCrossNums = (CheckTime-CrossTime)/60/Period();
         //Print("RSIPosition:",RSIPosition,"| candleCrossNums:",candleCrossNums);
         CrossTime = iTime(NULL,0,0);
         RSICrossBuy(candleCrossNums);
      }
   }
}

void RSICrossBuy(int candleNum){
   //Print("RSICrossBuy objDict.total is :",objDict.Total());
   if(candleNum>6 || objDict.Total()>=MaxGroupNum){
      return ;
   }
   if(objDict.Total() >0){
      CItems* currItem = objDict.GetLastNode();
      if(currItem.Hedg == 0){
         if(currItem.GetType()== "rsi"){
            return;
         }
         currItem = objDict.GetPrevNode();
         if(currItem!=NULL && currItem.Hedg == 0){
            return;
         }
      }
      currItem = NULL;
   }
   //Print("RSICrossBuy s_ma10----",CMaMgr::s_ma10);
   //Print("RSICrossBuy s_ma10Overlying----",CMaMgr::s_ma10Overlying);
   //Print("RSICrossBuy s_ma120----",CMaMgr::s_ma120);
   //Print("RSICrossBuy s_ma120Overlying----",CMaMgr::s_ma120Overlying);
   if(CMaMgr::s_ma10 > CMaMgr::s_ma10Overlying && CMaMgr::s_ma10Overlying > CMaMgr::s_ma120 && CMaMgr::s_ma120>CMaMgr::s_ma120Overlying){
      //Print("MA BUY!!!");
      int t = 0;
      t = objCTradeMgr.Buy(Lots, 0, 0, "rsi");
      if(t != 0){
         objDict.AddObject(t, new CItems(t, "rsi", TPinMoney));
      }
   }
   
}
void RSICrossSell(int candleNum){
   //Print("RSICrossSell objDict.total is :",objDict.Total());
   if(candleNum>6 || objDict.Total()>=MaxGroupNum){
      return ;
   }
   if(objDict.Total() >0){
      CItems* currItem = objDict.GetLastNode();
      if(currItem.Hedg == 0){
         if(currItem.GetType()== "rsi"){
            return;
         }
         currItem = objDict.GetPrevNode();
         if(currItem!=NULL && currItem.Hedg == 0){
            return;
         }
      }
      currItem = NULL;
   }
   //Print("RSICrossSell s_ma10----",CMaMgr::s_ma10);
  // Print("RSICrossSell s_ma10Overlying----",CMaMgr::s_ma10Overlying);
   //Print("RSICrossSell s_ma120----",CMaMgr::s_ma120);
   //Print("RSICrossSell s_ma120Overlying----",CMaMgr::s_ma120Overlying);
   if(CMaMgr::s_ma10 < CMaMgr::s_ma10Overlying && CMaMgr::s_ma10Overlying < CMaMgr::s_ma120 && CMaMgr::s_ma120<CMaMgr::s_ma120Overlying){
      int t = 0;
      t = objCTradeMgr.Sell(Lots, 0, 0, "rsi");
      if(t != 0){
         objDict.AddObject(t, new CItems(t, "rsi", TPinMoney));
      }
   }
}


void subPrintDetails()
{
   string sComment   = "";
   string sp         = "----------------------------------------\n";
   string NL         = "\n";

   sComment = sp;
   sComment = sComment + "Net = " + TotalNetProfit() + NL; 
   sComment = sComment + "GroupNum = " + objDict.Total() + NL; 
   sComment = sComment + sp;
   sComment = sComment + "Lots=" + DoubleToStr(Lots,2) + NL;
   CItems* currItem = objDict.GetFirstNode();
   for(int i = 1; (currItem != NULL && CheckPointer(currItem)!=POINTER_INVALID); i++)
   {
      sComment = sComment + sp;
      sComment = sComment + currItem.GetTicket()+ ":" + currItem.Hedg + " | ";
      for(int i=0;i<currItem.Marti.Total();i++){
         sComment = sComment + currItem.Marti.At(i) + ",";
      }
      //double itemNet = objProfitMgr.GetNetProfit(currItem);
      //sComment = sComment + " ==> "+itemNet;
      sComment = sComment + NL;
      if(objDict.Total() >0){
         currItem = objDict.GetNextNode();
      }else{
         currItem = NULL;
      }
   }
   
  
   Comment(sComment);
}

double TotalNetProfit()
{
     double op = 0;
     for(int cnt=0;cnt<OrdersTotal();cnt++)
      {
         OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES);
         if(OrderType()<=OP_SELL &&
            OrderSymbol()==Symbol() &&
            OrderMagicNumber()==MagicNumber)
         {
            op = op + OrderProfit();
         }         
      }
      return op;
}


