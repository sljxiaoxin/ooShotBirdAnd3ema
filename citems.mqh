//+------------------------------------------------------------------+
//|                                                  CTradeMgr.mqh |
//|                                 Copyright 2015, Vasiliy Sokolov. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015."
#property link      "http://www.mql5.com"

class CItems : public CObject
{
   private:
      int m_Ticket;        //当前的订单号
      string m_Type;       //策略类型：first,cross,rsi
      double m_TPMoney;    //止盈，first6倍，cross4倍，rsi1倍
   public:
      int Hedg;          //对冲单
      CArrayInt *Marti;  //马丁单
      CItems(int ticket, string type, double tp){
         m_Ticket = ticket;
         m_Type = type;
         if(m_Type == "first"){
            m_TPMoney = 6*tp;
         }else if(m_Type == "cross"){
            m_TPMoney = 4*tp;
         }else{
            m_TPMoney = 1*tp;
         }
         Hedg = 0;
         Marti = new CArrayInt;
      }
      string GetType(){return m_Type;}
      double GetTP(){return m_TPMoney;}
      int GetTicket(){return m_Ticket;}
};