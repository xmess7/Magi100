//+------------------------------------------------------------------+
//|                                             xm7_Magic100__v1.mq4 |
//|                                            Copyright © 2020, xm7 |
//|                                           Created in  2020.06.06 |
//|                                          v2.0 update  2020.06.09 |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2020, xm7 Magic100 version 4.0"
#property strict

//multi pairs version
//Added signal/trading periods 

string DisplayTitle="xm7 Magic100 v4.0";
string tradeComment="xm7_Magic100_";

#include <stderror.mqh>
#include <stdlib.mqh>
#include <xm7/UserAgreement.mqh>
#include <xm7/display.mqh>
#include <xm7/xm7_controls.mqh>
#include <xm7/functions.mqh>
#include <xm7/LotSizeCalculations.mqh>
#include <xm7/profitCalculations.mqh>

enum LotType { Fixed, LotsPerBalance, LotsOnPercentRisk };
enum ttake { useFixedTP,useTPRatio, noTP };
enum tdirection { _longs_, _shorts_, either };
enum tstop { useFixedSL, useBar1_HiLo, noSL };
enum uPipsPercent { pips,percent }; 

extern int MagicNumber=20200606;
extern string PairsToTrade="EURUSD,GBPUSD,AUDUSD,EURAUD,USDJPY";
//"AUDCAD,AUDCHF,AUDJPY,AUDNZD,AUDUSD,CADCHF,CADJPY,CHFJPY,EURAUD,EURCAD,EURCHF,EURGBP,EURJPY,EURNZD,EURUSD,GBPAUD,GBPCAD,GBPCHF,GBPJPY,GBPNZD,GBPUSD,NZDCAD,NZDCHF,NZDJPY,NZDUSD,USDCAD,USDCHF,USDJPY"; //
extern string TradeHours="00:00-23:59";
extern string noTradingDays="";//noTradingDays(Monday,Wednesday,etc..")
extern string empty0="////= = = = = = = = = = = = = = = = = = = = = = = = =///"; //==== ---- ====
extern string MMInputs="==== Money Management Settings ===="; //==== ---- ====
extern LotType LotSizing = LotsOnPercentRisk;
extern double FixedLotSize=0.01;
extern string Lots_Per_Balance="0.01/1000";
extern double percentRisk=0.5;
extern string empty11="////= = = = = = = = = = = = = = = = = = = = = = = = =///"; //==== ---- ====
extern string firstTrigInputs="==== SL/TP Settings ===="; //==== ---- ====
extern tstop stopLossSetting = useBar1_HiLo;
extern double SL=0;//Fixed StopLoss (pips)
extern double slpadding=0; //add xtra pips to SL
extern string empty12="////= = = = = = = = = = = = = = = = = = = = = = = = =///"; //==== ---- ====
extern string tpSettings="==== TakeProfit Settings ===="; //==== ---- ====
extern ttake takeProfitSetting=useTPRatio;
extern double TP=0;//Fixed TakeProfit (pips)
extern string tpRatio="1:2"; //set tpRatio (1:1.5, 1:3, etc)
extern string empty1="////= = = = = = = = = = = = = = = = = = = = = = = = =///"; //==== ---- ====
extern string secndTrigInputs="==== Gain/Limit Settings ===="; //==== ---- ====
extern int maxTradersPerDay=1; //maxTradersPerDay(0=noLimit)
extern double weeklyPercent = 0.0;
extern string empty2="////= = = = = = = = = = = = = = = = = = = = = = = = =///"; //==== ---- ====
extern string Be_Trail_Inputs=" === BE/Trail Settings === "; //==== ---- ====
extern uPipsPercent usePipsOrPercent=pips;
extern double setBE=0; //Set BE (pips or %)
extern double trailingStop=0;//Set TrailStop (pips or %)
extern double stepDelta=0;//Set StepDelta (pips or %)
extern string empty3="////= = = = = = = = = = = = = = = = = = = = = = = = =///"; //==== ---- ====
extern string additionalInputs=" === Additional Inputs == "; //==== ---- ====
extern tdirection setTradeDirection=either;
extern double minBarSize=0;
extern double minStopLossRange=0;
string debugFlag_Inputs="==== Debug Settings ===="; //==== ---- ====
extern bool debug=false;
extern bool showPanelAsComments=false;

bool buyPassThru,sellPassThru,trd;

int _ticket1=-1,_ticket2=-1,trig_signal=-1;

double trig_level=0,trig_stop=0,ratio_value; 
double localGMToffSet,brokerGMToffSet,pivot_levels[];
double sl,tp; //pointz,lotstep
double range=0,buyPassThruFractal,sellPassThruFractal;
double pips,profit,max,min;

datetime timeGMT,timer_exec,startTime,endTime,Time1;

int mainTitlelen,_bars,haTrig_signal=-1,hr,mn,hr_end,mn_end;
int Period_1, Period_2, Period_3, Period_4;

long _xm7_ea_chartid;

string units,ea_profit_str="0",ea_pips_str="0",tradeGain="0",prfx="",sufx="";
string max_str,min_str,maxTime_str,minTime_str,_pairsToTrade;

tOrders tradeOrders[];
tPairs sPairs[];

int OnInit()
  { 
  
    if(!UserAgreement(WindowExpertName()+".ex4")) return(INIT_FAILED); 
   
   if(IsTesting()) {
      Print("Sorry I can't run in strategy tester.. to complicated to explain :).");
      return(INIT_FAILED);
    } 
    
    if(!checkIfWeekend() || !IsTesting()) {
          GetGMTInfo(localGMToffSet,brokerGMToffSet);
          GlobalVariableSet("xm7_LocalGMToffSet",localGMToffSet);
          GlobalVariableSet("xm7_BrokerGMToffSet",brokerGMToffSet);  
       }
       
    if(IsTesting()) brokerGMToffSet=0;
    
    HideTestIndicators(true);
    
    timeGMT=TimeCurrent()-(int)brokerGMToffSet*PERIOD_H1*60;
    
    if((StringFind(TradeHours,",")>-1 && StringFind(TradeHours,":")==2) || (StringFind(TradeHours,"-")==5 && StringFind(TradeHours,":")==2))
    GetDiscreteHourMin(hr,mn,hr_end,mn_end);

    if(hr==0 && mn==0 && hr_end==0 && mn_end==0) {
         MessageBox("Please check the format for the TradeHours input\n"+
                    "Use this form:  'HH:mm-HH2:mm'",DisplayTitle,MB_ICONEXCLAMATION); 
         return(INIT_FAILED);
    }                                      
    
    startTime=(datetime)((datetime)TimeToStr(Time[0],TIME_DATE)+hr*PERIOD_H1*60+mn*PERIOD_M1*60);
    endTime=(datetime)((datetime)TimeToStr(Time[0],TIME_DATE)+hr_end*PERIOD_H1*60+mn_end*PERIOD_M1*60);
    if(startTime>endTime) startTime-=PERIOD_D1*60;
    
    _bars=0;
    
   //Display/control variables
    _xm7_ea_chartid=ChartID();   

    isNewDay();
    newBar();

    _populateOrdersArray(tradeOrders);
    if(ArraySize(tradeOrders)>0) _ticket1=tradeOrders[ArraySize(tradeOrders)-1].ticket;
      
    if(takeProfitSetting==useTPRatio) {
             
           if(tpRatio=="" || StringFind(tpRatio,":")==-1 || StringLen(tpRatio)<3) {
                Alert("Incorrect input entry for tpRatio.., PLease fix and reload EA");
                ratio_value=1;
                return(INIT_FAILED);
           }
           string ratio[];
           StringToArray(tpRatio,":",ratio);
           double rvalue=StringToDouble(ratio[1])/StringToDouble(ratio[0]);
           ratio_value=NormalizeNumber(rvalue,2);                   
    }
       
    _pairsToTrade=StringTrimLeft(StringTrimRight(PairsToTrade));

    string lastChar=StringSubstr(_pairsToTrade,StringLen(_pairsToTrade)-1,1);
    
    if(lastChar!="" && lastChar==",") 
         _pairsToTrade=StringSubstr(_pairsToTrade,0,StringLen(_pairsToTrade)-1);
    
    //if(_pairsToTrade!="") getCoreSymbols(_pairsToTrade); //lets get core symbols, this prevents duplicate prefexes
       
    if(StringFind(_pairsToTrade,",")==-1 || IsTesting() || _pairsToTrade=="") {
       ArrayResize(sPairs,1);
       if(IsTesting()) _pairsToTrade=_Symbol;
       sPairs[0].symbol=_pairsToTrade;
    } else {
       StringToArrayStructure(_pairsToTrade,",",sPairs);
    }
         
    GetPrefixSuffix(Symbol(),prfx,sufx); //Get the current Symbol chart prefix and suffix 
    if(debug) Print(TimeToStr(TimeCurrent()),"  sufix: ",sufx,"  prefix: ",prfx); 
                  
    if(_pairsToTrade!=_Symbol && StringFind(_pairsToTrade,sufx)==-1 && StringFind(_pairsToTrade,sufx)==-1)
       for(int x=0; x<ArraySize(sPairs); x++) sPairs[x].symbol=StringTrimLeft(StringTrimRight(prfx+sPairs[x].symbol+sufx));
               
    if(debug)
       for(int x=0; x<ArraySize(sPairs); x++) Print((string)x,"  ",sPairs[x].symbol);     
      
    if(ArraySize(sPairs)==0) MessageBox("The EA did not recognize any of the pairs you listed\n"+
                                        "Please enter valid symbols\n"+
                                        "The EA will not look for trades until"+
                                        "\nvalid signals are added to the input list",
                                        "xm7 LondonClose",MB_ICONEXCLAMATION); 
  
    minimized_display_panel=false; minimized_virtual_panel=false;
    

    if(showPanelAsComments) {
      showAsComments(profit);
    } else {  
      ShowDisplay(mainTitlelen,profit,"0");
          if(GlobalVariableCheck("xm7_minmizeDisplay")) { 
              GlobalVariableDel("xm7_minmizeDisplay");  minimized_display_panel=true;
              ShowDisplay(mainTitlelen,profit,"0");
          }            
    }    
    
    if(!IsTesting()) SetEventTimer(1);
    
    return(INIT_SUCCEEDED);

  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(minimized_display_panel) GlobalVariableSet("xm7_minmizeDisplay",0);
   Comment("");
   removeObjects(0,"xm7");  //xm7_3Bar
   EventKillTimer();
  }

void OnTimer() {

      if(IsTesting()) {
         if(ObjectGetInteger(0,"xm77_CloseTradesButton_"+(string)_xm7_ea_chartid, OBJPROP_STATE)) closeTradeButton();
         if(ObjectFind(_xm7_ea_chartid,"xm77_CloseTradesButton_"+(string)_xm7_ea_chartid)==0)  TrackButtonPosition(_xm7_ea_chartid,"xm77_CloseTradesButton",x_btn,y_btn,btn_width, btn_heigth); 
      }
      
      if(!checkIfWeekend() || IsTesting())  {
            timeGMT=TimeCurrent()-(int)brokerGMToffSet*PERIOD_H1*60;
            DetermineProfit(MagicNumber,"",0);
      
            runningProfit(pips,profit);
            
             if(showPanelAsComments) {
               showAsComments(profit);
             } else {  
               ShowDisplay(mainTitlelen,profit,"0");
             }       
         }
      
      if(_OrdersTotal()>0){
            if(ObjectGetInteger(0,"xm77_CloseTradesButton_"+(string)ChartID(),OBJPROP_BGCOLOR)==clrGray)
               EnableButton(_xm7_ea_chartid,true,"xm77_CloseTradesButton_");
            
            for(int x=0; x<OrdersTotal(); x++) {
               if(!OrderSelect(x,SELECT_BY_POS)) continue;
               if(OrderMagicNumber()!=MagicNumber || OrderType()>OP_SELL) continue;                
               if(setBE>0) doBE(OrderSymbol(),OrderTicket());  
               if(trailingStop>0) MonitorTrailing(OrderSymbol(),OrderTicket());             
            }
        
      } else {
            if(ObjectGetInteger(0,"xm77_CloseTradesButton_"+(string)ChartID(),OBJPROP_BGCOLOR)!=clrGray)
               EnableButton(_xm7_ea_chartid,false,"xm77_CloseTradesButton_");
               
               if(ArraySize(tradeOrders)>0)
                  if(lastOrderClosed(_ticket1)) {
                     trig_signal=-1;  _ticket1=-1;                  
                     trig_level=0;  trig_stop=0; haTrig_signal=-1;
                     closeOtherPendingOrders();
                  } 

      }

      if(!checkIfWeekend())
            if(isNewDay()) {  
               GetGMTInfo(localGMToffSet,brokerGMToffSet);
               GlobalVariableSet("xm7_LocalGMToffSet",localGMToffSet);
               GlobalVariableSet("xm7_BrokerGMToffSet",brokerGMToffSet);  
               if(IsTesting()) brokerGMToffSet=0; 
               resetGlobals(tradeComment);  
               timeGMT=TimeCurrent()-(int)brokerGMToffSet*PERIOD_H1*60;
               startTime=(datetime)((datetime)TimeToStr(Time[0],TIME_DATE)+hr*PERIOD_H1*60+mn*PERIOD_M1*60);
               endTime=(datetime)((datetime)TimeToStr(Time[0],TIME_DATE)+hr_end*PERIOD_H1*60+mn_end*PERIOD_M1*60);
               if(startTime>endTime) startTime-=PERIOD_D1*60;
               closeOtherPendingOrders();  
               if(_OrdersTotal()==0) { _ticket1=-1; Time1=0; ArrayFree(tradeOrders); }                  
            }
}

void OnTick() {
     
     MqlRates Candles[];
     string timecurrnt="",pairtime="";
     double _pointz=0;
     int _digits=0;
     
     if(IsTesting()) OnTimer();
       
     if(weeklyPercent>0)
      if(StringToDouble(weeks_gain)>=weeklyPercent) return;  
     
     int _time=TimeHour(TimeCurrent())*3600 + TimeMinute(TimeCurrent())*60;
     int _startTime = hr*PERIOD_H1*60+mn*60;
     int _endTime = hr_end*PERIOD_H1*60+mn_end*60;
           
     if(_time<_startTime || _time>_endTime) return; //if(timeGMT<startTime || timeGMT>endTime) return;

     if(!newBar()) return;
      
     for(int x=0; x<ArraySize(sPairs); x++){ 
 
         refreshRates();
         
         if(!IsTesting() && !SymbolSelect(sPairs[x].symbol,true)) { Print("Pair: ",sPairs[x].symbol," was not found in broker list, it this is an error have code checked"); continue; }

         if(_openOrdersTotal(sPairs[x].symbol)>0) continue;
                  
         if(debug) { timecurrnt=TimeToStr(Time[0]); pairtime=TimeToStr(iTime(sPairs[x].symbol,PERIOD_CURRENT,0)); }
              
         int cnt=0;
         while(TimeToStr(iTime(sPairs[x].symbol,PERIOD_CURRENT,0),TIME_DATE)!=TimeToStr(Time[0],TIME_DATE) ||
               TimeToStr(iTime(sPairs[x].symbol,PERIOD_CURRENT,0),TIME_MINUTES)!=TimeToStr(Time[0],TIME_MINUTES)) {
                     Sleep(100);
                     RefreshRates();
                     if(cnt>9) break;
                     cnt++;                
         }
        
        
         getSymbolBars(sPairs[x].symbol,Candles);
         getSymbolPointzDigitz(sPairs[x].symbol,Candles[1].open,Candles[1].close,Candles[1].high,Candles[1].low,_pointz,_digits);                
           /*//Use follow to test for correct bar info
          *double o=Candles[0].open;
           double h=Candles[0].high;
           double l=Candles[0].low;
           double c=Candles[0].close;
           double bid=MarketInfo(sPairs[x],MODE_BID);*/
           
           int trade_cnt=0;
           if(maxTradersPerDay>0)
               for(int z=0; z<OrdersHistoryTotal(); z++) {
                     if(!OrderSelect(x,SELECT_BY_POS,MODE_HISTORY)) continue;
                     if(OrderMagicNumber()!=MagicNumber) continue;
                     if(OrderSymbol()==sPairs[x].symbol) trade_cnt++;
                     if(trade_cnt>=maxTradersPerDay) continue;   
               } 
           
           if(minBarSize>0)
               if(MathAbs(Candles[1].close-Candles[1].open)<=minBarSize*_pointz) continue; 
           
           trig_signal=-1;  
           
           if(_openPendingOrdersTotal(sPairs[x].symbol)) _closePendingOrder(sPairs[x].symbol);           
           
           double ema100=iMA(sPairs[x].symbol,PERIOD_CURRENT,100,0,MODE_EMA,PRICE_CLOSE,1); //EMA 100
           
            // Price below ema100, looking for green candle to place sell pending order
           if(Candles[1].close<ema100 && Candles[1].open<ema100) 
               if(Candles[1].close>Candles[1].open) trig_signal=OP_SELL;   // green candle
           
           // Price above ema100, looking for red candle to place buy pending order
           if(Candles[1].close>ema100 && Candles[1].open>ema100) 
               if(Candles[1].close<Candles[1].open) trig_signal=OP_BUY;   // red candle
            
           if(trig_signal==-1) continue;
           
           //if(maxSpreadAllowed>0)
           //    if(!testSpread(maxSpreadAllowed)) continue;   
                        
           if(trig_signal==OP_BUY) { 
                  if(setTradeDirection==_shorts_) continue;
                  setOrder(sPairs[x].symbol,OP_BUYSTOP,Candles);
           }   
                           
           if(trig_signal==OP_SELL) {
               if(setTradeDirection==_longs_) continue;
               setOrder(sPairs[x].symbol,OP_SELLSTOP,Candles);
           }
     }
      
 
}

void getSymbolBars(string _symbol,MqlRates& _candles[]) {

    int cpy_cnt=-1,cnt=0;
    string _minutes="99:99",_date="1970.01.01";
    
    ArraySetAsSeries(_candles,true);
    
    //Use following to test date of returned Bar0
    //string d = TimeToStr(Time[0],TIME_DATE);
    //string m = TimeToStr(Time[0],TIME_MINUTES);
    
    cnt=0;
    while(cpy_cnt<=0 || _date!=TimeToStr(Time[0],TIME_DATE) || _minutes!=TimeToStr(Time[0],TIME_MINUTES))  { 
        
        cpy_cnt=CopyRates(_symbol,PERIOD_CURRENT,Time[0],2,_candles);

        if(cpy_cnt>0)
          { _date=TimeToStr(_candles[0].time,TIME_DATE); _minutes=TimeToStr(_candles[0].time,TIME_MINUTES); }
        
        Sleep(100); RefreshRates(); if(cnt>20) break; cnt++;   
    }   

}


double getSLprice(int _opType_,double _openprice, double _fracStop,double& _stopRange) {
   double _sl_=0;
   _stopRange=100;
   
   return(_sl_);
}

bool newBar() {
   static datetime time;
   if(time!=Time[0]) {
      time=Time[0];
      return (true);
   }
   return(false);
}

bool isNewDay() {
   static int lastday;
   if(lastday!=DayOfWeek()) {
      lastday=DayOfWeek();
      return (true);
   }
   return(false);
}

void GetGMTInfo(double& _LocalGMToffSet, double& _BrokerGMToffSet){

    bool oddnum=false; //This is for this shifts that have 0.5 (like in india somewhere)
    if(MathMod(MathAbs(TimeGMTOffset()),2)==1) oddnum=true; 
    double diff = (double)(TimeCurrent()-TimeGMT()); 
    diff=(int)diff/3600; 
    if(oddnum) diff=diff+0.5;
        
   _BrokerGMToffSet=diff; //(double)(brkHr-gmtHr);
   _LocalGMToffSet= (double)(-TimeGMTOffset()/3600);
}

void GetDiscreteHourMin(int& h,int& m,int& h_end,int& m_end) {
       string hours[],begin,end;
       h=0; m=0;
       StringToArray(TradeHours,"-",hours);
       begin=hours[0]; end=hours[1];
       
       ArrayFree(hours);
       StringToArray(begin,":",hours);     
       h=(int)hours[0]; m=(int)hours[1];
       
       ArrayFree(hours);
       StringToArray(end,":",hours);     
       h_end=(int)hours[0]; m_end=(int)hours[1];

}

int SendTrade(int type,string symbl,double lotz,double price,double stop,double take, string cmment) {

   int slippage=10, ticket=0, tries;
   
   if(MarketInfo(symbl,MODE_DIGITS)==3 || MarketInfo(symbl,MODE_DIGITS)==5) slippage=100;

   color col=clrRed;
   if(type==OP_BUY || type==OP_BUYSTOP || OP_BUYLIMIT) col=clrGreen;

   marginAvailableLots(lotz);
   if(lotz<MarketInfo(_Symbol, MODE_MINLOT)) return(-1);
   lotz=correctLots(_Symbol,lotz);

    ticket=OrderSend(symbl,type,lotz,price,slippage,0,0,cmment,MagicNumber,0,col); 
                   
    if(ticket!=-1){ 
        if(!ModifyOrder(ticket,type,stop,take)) return(-1);
        return(ticket);
     }  

   //Error trapping for both
   if(ticket==-1) {
     int err=GetLastError();
     
     if(err==4106) {  //Unknown Symbol
      //Print(ticket);   return(0);
     }
     
     if(err==132) { //Makert is closed
        MessageBox("No Trades, Market is Closed",DisplayTitle);
        return(err);
     }
 
      if(err==133 || err==2114) { //handle trade disabled error
         Print("Trading is disabled for this pair: ",symbl);
         return(err);
      }
      
      if(err==138) slippage=1000;
      
      //Try 3 times to see if ERROR can be avoided
      if(err==136) { // errr 136 off quotes
            tries=0;
            while (tries < 3) {
                 int cnt=0;
                 while(!RefreshRates()) { Sleep(100); if(cnt>3) break; cnt++; }
                 ticket=OrderSend(symbl,type,lotz,price,slippage,0,0,cmment,MagicNumber,0,col); 
                 if(ticket!=-1) break; 
                 tries++;
                 Sleep(300);
             }
             
             if(ticket!=-1){
                 if(!ModifyOrder(ticket,type,stop,take)) return(-1);
                 return(ticket);
             }
       }  
     
      //This part is reached only if no trade was ever able to be generated 
      string stype;
      if(type == OP_BUY) stype = "OP_BUY";
      if(type == OP_SELL) stype = "OP_SELL";
      if(type == OP_BUYLIMIT) stype = "OP_BUYLIMIT";
      if(type == OP_SELLLIMIT) stype = "OP_SELLLIMIT";
      if(type == OP_BUYSTOP) stype = "OP_BUYSTOP";
      if(type == OP_SELLSTOP) stype = "OP_SELLSTOP";

      string error_str=ErrorDescription(err); StringToUpper(error_str);
      Print(TimeToStr(Time[0])+": "+symbl," Error in SendTrade(): symbol: ",symbl,"  type = ",stype,"  lots = ",lotz,"  price = ",price,"   stoploss=",stop,"  takeprofit=",take);
      Print(TimeToStr(Time[0])+": "+symbl," Error in SendTrade(): OrderSend() error(",err,") - ", error_str);
   }//if (ticket == -1)  

   return(ticket);
}

bool CloseTrade(int ticket,double lotsze, double close_price) {
   bool result=false;
   int tries;
   
   while(IsTradeContextBusy()) Sleep(100);

   tries=0;
   while (tries < 10) {
        result=OrderClose(ticket,lotsze,close_price,1000,SandyBrown);
        if(result) return(true);
        tries++;
        Sleep(300);
   }

   return(result);
}

bool ModifyOrder(int tickt, int ordtype,double stop_loss,double take_profit) {

   int tries;
 
   if(stop_loss==0 && take_profit==0) return(true);   

   if(!OrderSelect(tickt,SELECT_BY_TICKET)) return(false); //Trade does not exist, so no mod needed
   
    while(IsTradeContextBusy()) Sleep(300);
 
    if(OrderModify(tickt, OrderOpenPrice(), stop_loss, take_profit, OrderExpiration(), Aqua)) return(true);
       
   //Got this far, so the order modify failed
   // try 10 times with delay to modify order   
   tries=0;
   while (tries < 10) {
           trd= OrderModify(tickt, OrderOpenPrice(), stop_loss, take_profit, OrderExpiration(), Aqua);
           if(trd) return(true);  //OrderModiy was successful so return
           tries++;
           Sleep(300);
   }
   
   //Error persisted so we log the variables to EXPERTS Tab and very IMPORTANT CLOSE THE TRADE
   string close_message="";
   if(ordtype==OP_BUY) { 
      if (!CloseTrade(OrderTicket(),OrderLots(),Bid)) { 
            close_message="Error in CloseTrade(): EA tried 10 times on ModifyOrder() and failed.  When EA attempted to close OpenTicket there was a problem closing Buy trade @ "+DoubleToStr(Ask,Digits()); 
      }
   }
      
   if(ordtype==OP_SELL) {
       if (!CloseTrade(OrderTicket(),OrderLots(),Ask))  {  
            close_message="Error in CloseTrade(): EA tried 10 times on ModifyOrder() and failed.  When EA attempted to close OpenTicket there was a problem closing Sell trade @ "+DoubleToStr(Bid,Digits()); 
       }
   }    
  
   int err=GetLastError();
   if(close_message!="") Print(TimeToStr(Time[0])+": "+Symbol()+" "+close_message);   
   if(close_message!="") Print(TimeToStr(Time[0])+": "+Symbol()+" Error in CloseTrade(), EA was not able to close trade due to ModifyOrder() error");   
   Print(TimeToStr(Time[0])+": "+Symbol()," Error in ModifyOrder(): SL = "+DoubleToStr(stop_loss,Digits())+"    TP = "+DoubleToStr(take_profit,Digits()));
   Print(TimeToStr(Time[0])+": "+Symbol()," Error in ModifyOrder(): SL/TP  order modify failed with error(",err,")");
   return(false);
//   Alert(Symbol(), " SL/TP  order modify failed with error(",err,"): ",ErrorDescription(err));               

}//void ModifyOrder(int ticket, double tp, double sl)   

void _populateOrdersArray(tOrders& _tradeOrders[]) {
   for(int x=0; x<OrdersTotal(); x++) {
      if(!OrderSelect(x,SELECT_BY_POS)) continue; 
      if(OrderMagicNumber()!=MagicNumber) continue;
      
      ArrayResize(_tradeOrders,ArraySize(_tradeOrders)+1);
      _tradeOrders[ArraySize(_tradeOrders)-1].ticket=OrderTicket();
      _tradeOrders[ArraySize(_tradeOrders)-1].symbol=OrderSymbol();
      _tradeOrders[ArraySize(_tradeOrders)-1].optype=OrderType();      
      _tradeOrders[ArraySize(_tradeOrders)-1].pendTickt=-1; 
      _tradeOrders[ArraySize(_tradeOrders)-1].time=OrderOpenTime(); 
   }  
   
   for(int x=0; x<OrdersTotal(); x++) {
      if(!OrderSelect(x,SELECT_BY_POS)) continue; 
      if(OrderMagicNumber()!=MagicNumber) continue;
      if(OrderType()>OP_SELL) continue; 
           
      for(x=0; x<ArraySize(_tradeOrders); x++) { 
            if(OrderSymbol()!=_tradeOrders[x].symbol) continue;
            if(_tradeOrders[x].optype<=OP_SELL) continue;
            _tradeOrders[x].pendTickt=OrderTicket();
            break; 
      }          
   }
}

int _OrdersTotal(string _symbol="") {
   int _total=0;
   for(int x=0; x<=OrdersTotal()-1; x++) {
      if(!OrderSelect(x,SELECT_BY_POS)) continue; 
      if(OrderMagicNumber()!=MagicNumber) continue;
      if(_symbol!="") if(_symbol!=OrderSymbol()) continue;        
      _total++;
   }
   return(_total);
}

int _openOrdersTotal(string _symbol="") {
   int _total=0;
   for(int x=0; x<=OrdersTotal()-1; x++) {
      if(!OrderSelect(x,SELECT_BY_POS)) continue; 
      if(OrderMagicNumber()!=MagicNumber) continue;
      if(OrderType()>OP_SELL) continue;
      if(_symbol!="") if(_symbol!=OrderSymbol()) continue;        
      _total++;
   }
   return(_total);
}

void closeOtherPendingOrders() {
   if(ArraySize(tradeOrders)==0) return;
   for (int x=0; x<ArraySize(tradeOrders); x++) {
       for(int z=0; z<OrdersTotal(); z++) {
         if(!OrderSelect(z,SELECT_BY_POS)) continue; 
         if(OrderMagicNumber()!=MagicNumber || OrderSymbol()!=tradeOrders[x].symbol) continue; 
         if(OrderType()<=OP_SELL) continue;        
         if((int)tradeOrders[x].ticket!=OrderTicket()) continue;
         trd=OrderDelete(OrderTicket());
       }     
   }  
}

bool _openPendingOrdersTotal(string _symbol="") {
      int _total=0;
      for(int x=0; x<=OrdersTotal()-1; x++) {
         if(!OrderSelect(x,SELECT_BY_POS)) continue; 
         if(OrderMagicNumber()!=MagicNumber) continue;
         if(OrderType()<=OP_SELL) continue;
         if(_symbol!="") if(_symbol==OrderSymbol()) return(true);        
      }
      return(false);
}

void _closePendingOrder(string _symbol="") {
       //Print("cloe prev pending for: ",_symbol);
       for(int z=0; z<OrdersTotal(); z++) {
         if(!OrderSelect(z,SELECT_BY_POS)) continue; 
         if(OrderMagicNumber()!=MagicNumber || OrderSymbol()!=_symbol) continue; 
         if(OrderType()<=OP_SELL) continue;        
         trd=OrderDelete(OrderTicket()); break;
       }
   
     //Print("tradeOrders size before: ",ArraySize(tradeOrders));    
   //update tradeOrders   
   tOrders temp[];
   for (int x=0; x<ArraySize(tradeOrders); x++) {
      if(_symbol==tradeOrders[x].symbol) continue; 
      ArrayResize(temp,ArraySize(temp)+1);   
      temp[ArraySize(temp)-1].ticket=tradeOrders[x].ticket;
      temp[ArraySize(temp)-1].symbol=tradeOrders[x].symbol;      
      temp[ArraySize(temp)-1].optype=tradeOrders[x].optype;
      temp[ArraySize(temp)-1].pendTickt=tradeOrders[x].pendTickt;
      temp[ArraySize(temp)-1].stop=tradeOrders[x].stop;
      temp[ArraySize(temp)-1].lots=tradeOrders[x].lots;
      temp[ArraySize(temp)-1].time=tradeOrders[x].time;
      temp[ArraySize(temp)-1].stopRange=tradeOrders[x].stopRange;  
    }
    ArrayFree(tradeOrders);
    ArrayResize(tradeOrders,ArraySize(temp));

    //Copy temp[] to tradeOrders
for (int x=0; x<ArraySize(tradeOrders); x++) {
      tradeOrders[x].ticket=temp[x].ticket;
      tradeOrders[x].symbol=temp[x].symbol;      
      tradeOrders[x].optype=temp[x].optype;
      tradeOrders[x].pendTickt=temp[x].pendTickt;
      tradeOrders[x].stop=temp[x].stop;
      tradeOrders[x].lots=temp[x].lots;
      tradeOrders[x].time=temp[x].time;
      tradeOrders[x].stopRange=temp[x].stopRange; 
    }
    
    // Print("tradeOrders size after: ",ArraySize(tradeOrders));
           
}
 
 void OnChartEvent(const int id, const long &lparam,const double &dparam, const string &sparam){
      
   if(showPanelAsComments) return;

   if(id==CHARTEVENT_CHART_CHANGE) {                                                
        TrackButtonPosition(_xm7_ea_chartid,"xm77_CloseTradesButton",x_btn,y_btn,btn_width, btn_heigth);
        TrackButtonPosition(_xm7_ea_chartid,btn_objName,x_btns,y_btns,btns_width,btn_heigth);
   }     
                        
   if(id==CHARTEVENT_OBJECT_CLICK) {
   
         if(StringFind(sparam,btn_objName,0)==0) { 
               ChartSetSymbolPeriod(0,ObjectGetString(0,sparam,OBJPROP_TEXT),_Period);
               setSymbolButtonColor();
               //if(StringFind(sparam,"changer:time:"  ,0)==0) ChartSetSymbolPeriod(0,_Symbol,stringToTimeFrame(ObjectGetString(0,sparam,OBJPROP_TEXT)));
               //if(StringFind(sparam,"changer:back:"  ,0)==0) ObjectSet(sparam,OBJPROP_STATE,false);
         }    
         
        if(StringFind(sparam,"xm7_Display")>-1 || StringFind(sparam,"xm7_minimizeDisplay")>-1) 
            if(!minimized_display_panel) { minimized_display_panel=true; } else if(minimized_display_panel) minimized_display_panel=false;
                
        if(StringFind(sparam,"xm7_virtual")>-1 || StringFind(sparam,"xm7_minimizeVirtualDisplay")>-1) 
            if(!minimized_virtual_panel){ minimized_virtual_panel=true; } else if(minimized_virtual_panel) minimized_virtual_panel=false;
                                            
        if(sparam=="xm77_CloseTradesButton_"+(string)_xm7_ea_chartid)  { 
            if(sparam=="xm77_CloseTradesButton_"+(string)_xm7_ea_chartid ) {
                   ClickBtn(_xm7_ea_chartid,true,"xm77_CloseTradesButton_"); Sleep(100); ClickBtn(_xm7_ea_chartid,false,"xm77_CloseTradesButton_"); Sleep(50); EnableButton(_xm7_ea_chartid,true,"xm77_CloseTradesButton_"); }
                        
                   if(_OrdersTotal()>0) {
                         ClickBtn(_xm7_ea_chartid,true,"xm77_CloseTradesButton_"); Sleep(100); ClickBtn(_xm7_ea_chartid,false,"xm77_CloseTradesButton_"); Sleep(50);
                         CloseAllTrades();
                         EnableButton(_xm7_ea_chartid,true,"xm77_CloseTradesButton_");
                   }                                                                                            
        }
    }                                   
}       

void closeTradeButton() {
      
     ClickBtn(_xm7_ea_chartid,true,"xm77_CloseTradesButton_"); Sleep(100); ClickBtn(_xm7_ea_chartid,false,"xm77_CloseTradesButton_"); Sleep(50); EnableButton(_xm7_ea_chartid,true,"xm77_CloseTradesButton_"); 
                     
     if(_OrdersTotal()>0) {
            ClickBtn(_xm7_ea_chartid,true,"xm77_CloseTradesButton_"); Sleep(100); ClickBtn(_xm7_ea_chartid,false,"xm77_CloseTradesButton_"); Sleep(50);
            CloseAllTrades();
            EnableButton(_xm7_ea_chartid,true,"xm77_CloseTradesButton_");
     }                                                                                            
     
     ObjectSetInteger(0, "xm77_CloseTradesButton_"+(string)_xm7_ea_chartid, OBJPROP_STATE, false);  

}

void minmaxDisplay() {
   if(!minimized_display_panel) { minimized_display_panel=true; } else if(minimized_display_panel) minimized_display_panel=false;
   ObjectSetInteger(0,Symbol()+"_xm7_minimizeDisplay", OBJPROP_STATE,false);
}
 
void	CloseAllTrades() {
 
  bool allclosed = False;
  int Tickets[]; //Fifo   
      
// Close orders, includes logic to close fifo
  while (_OrdersTotal()>0) { 
  
         int totalOrders=OrdersTotal();
         
         if(AccountLeverage()<=50) { //For now usually brokers with 50 or less use FIFO rules
            PopulateTicketArray(Tickets,MagicNumber); //Fifo
            SortTickets(Tickets); //Fifo
            totalOrders=ArraySize(Tickets);
         }   
  
         for(int t=0;t<totalOrders; t++) {
              
              if(AccountLeverage()>50) {
                  if(!OrderSelect(t,SELECT_BY_POS)) continue;
              } else {
                  if(!OrderSelect(Tickets[t], SELECT_BY_TICKET)) continue;
              }
              
              if(OrderMagicNumber()!=MagicNumber) continue;
              if(OrderCloseTime()!=0) continue;

              if(OrderType() == OP_BUY) trd=OrderClose(OrderTicket(),OrderLots(),MarketInfo(OrderSymbol(),MODE_BID),0,MediumSeaGreen);
              if(OrderType() == OP_SELL) trd=OrderClose(OrderTicket(),OrderLots(),MarketInfo(OrderSymbol(),MODE_ASK),0,DarkOrange);
              if(OrderType()>OP_SELL) trd=OrderDelete(OrderTicket()); //close pending orders
         }

         Sleep(5);
  }
   
  return;
}


void PopulateTicketArray(int& x[],int magic) {
   int size=0;
   ArrayFree(x);
   for (int s=0; s<OrdersTotal(); s++) { 
      if (OrderSelect(s,SELECT_BY_POS)) { 
         if (OrderMagicNumber()==magic) {  
               ArrayResize(x,size+1);
               x[size]=OrderTicket();
               size++;
         }    
      }
   } 
  return; 
}


void SortTickets(int& tickets[]) {
  int res, _ticket;
  int size = ArraySize(tickets);
  for (int i=0; i < size; i++) {
    for (int j=i+1; j < size; j++) {
      res = Compare(tickets[i], tickets[j]);
      if (res == -1) {
        _ticket = tickets[i];
        tickets[i] = tickets[j];
        tickets[j] = _ticket;        
      }
    }
  } 
}
 
 int Compare(int ticket1, int ticket2) {
      trd=OrderSelect(ticket1, SELECT_BY_TICKET);
      string time1 = TimeToStr(OrderOpenTime());
      trd=OrderSelect(ticket2, SELECT_BY_TICKET);
      string time2 = TimeToStr(OrderOpenTime());
      if (time1 < time2) return(1);
      if (time1 > time2) return(-1);
      return(0);
}


void runningProfit(double& totalpips_, double& totalprofit_) {     
      int p=1;
      
      totalpips_=0; totalprofit_=0; 
      
      RefreshRates();
      
      for(int i=0; i<=OrdersTotal(); i++){
         if(!OrderSelect(i,SELECT_BY_POS)) continue;
         if(OrderMagicNumber()!=MagicNumber) continue;
         if(OrderType()>OP_SELL ||  OrderCloseTime()!=0) continue;    
         p=1;
         if(MarketInfo(OrderSymbol(),MODE_DIGITS)==3 || MarketInfo(OrderSymbol(),MODE_DIGITS)==5) p=p*10;   
         totalpips_ += (((OrderProfit())/OrderLots()/MarketInfo(OrderSymbol(), MODE_TICKVALUE))/p);
         totalprofit_ += OrderProfit() + OrderCommission() + OrderSwap(); 
     }
     totalpips_=NormalizeNumber(totalpips_,1);
     totalprofit_=NormalizeNumber(totalprofit_,2); 
}
             

void marginAvailableLots(double& _lots) {
      int digitz=1;
      int cnt=0;
      while(!RefreshRates()) { Sleep(100); if(cnt>3) break; cnt++; }
      if (MarketInfo(Symbol(),MODE_LOTSTEP)==0.1) digitz=1;
      if (MarketInfo(Symbol(),MODE_LOTSTEP)==0.01) digitz=2;
      double Margin=MarketInfo(Symbol(),MODE_MARGINREQUIRED);
      double FreeMargin=AccountFreeMargin();
      double availablelots=NormalizeNumber(FreeMargin/Margin,digitz);
      if(_lots>availablelots) _lots=availablelots;   
}

void SetEventTimer(int time) {
   int error = - 1 ; 
   int counter = 1 ; 
   do
   { 
      ResetLastError (); 
      EventSetTimer (time); 
      error = GetLastError (); 
      //Print (" EventSetMillisecondTimer . Attempt =", counter, "Error =", error); 
      if (error!=0) Sleep  (1000); 
      counter ++; 
   } 
   while (error!=0 && !IsStopped ());
}

bool checkIfWeekend(){
    if(TimeDayOfWeek(TimeGMT())==6 || (TimeDayOfWeek(TimeGMT())==5 && TimeHour(TimeGMT())>=21 && TimeMinute(TimeGMT())>=58) ||
       (TimeDayOfWeek(TimeCurrent())==0 && TimeHour(TimeGMT())<=21 && TimeMinute(TimeGMT())<=59 && TimeSeconds(TimeGMT())<=59)) return(true);
    
    return(false);      
}     

string getStringOf(int dayofweek_) {

   switch(dayofweek_) {
      case(0): return("sunday"); break;
      case(1): return("monday"); break;
      case(2): return("tuesday"); break;
      case(3): return("wednesday"); break;
      case(4): return("thursday"); break;
      case(5): return("friday"); break;
      case(6): return("saturday"); break;
      default: return("noday");
   }

}

string StringToLowerCase(string sText) {
     // Example: StringChangeToLowerCase("oNe mAn"); // one man
     int iLen=StringLen(sText), i, iChar;
     for(i=0; i < iLen; i++) {
       iChar=(int)StringGetChar(sText, i);  
       if(iChar >= 65 && iChar <= 90) sText=StringSetChar(sText, i, (ushort)(iChar+32));
     }
     return(sText);  
}

void ShowDisplay(int& mainTitle_len,double currentProfit, string maxmin) {
   
    string ea_notice,divider = "=========================,";    
    tradeGain=(AccountBalance()==0?"0.0":DoubleToStr(((currentProfit/(AccountBalance()+AccountCredit()))*100),1));             

    if(StringFind(StringToLowerCase(noTradingDays),getStringOf(DayOfWeek()))>0)
          ea_notice="No trade today. It's a noTradingDay,";     
                       
    DisplayStatus2(_xm7_ea_chartid,10,20,"xm7_Display",DisplayTitle,
                   " ,"+
                   "=========================,"+
                   "Broker Time: "+TimeToStr(TimeCurrent(),TIME_MINUTES)+","+
                   "GMT Time: "+TimeToStr(timeGMT,TIME_MINUTES)+","+
                   "Tradehours: "+TimeToStr(startTime,TIME_MINUTES)+"-"+TimeToStr(endTime,TIME_MINUTES)+","+
                   ea_notice+
                   "=========================,"+
                   "Gain: "+tradeGain+"%,"+                       
                   "Day%: "+days_gain+"%   Week%: "+weeks_gain+"%,"+
                   "Month%: "+months_gain+"%   Year%: "+years_gain+"%,"+  
                    "=========================,"+                                                    
                   "Account Margin in use: $" +DoubleToStr(AccountMargin(),2)+","+            
                   "Account Balance:  $" +DoubleToStr(AccountBalance(),2)+","+
                   "Account Equity:  $"+DoubleToStr(AccountEquity(),2)+",",
                   13,mainTitle_len,-1
                   ); 
                   
                   // Comment("after Show: ",x_btn+"  "+y_btn,"  ",btn_width,"  ", btn_heigth);

}

void showAsComments(double currentProfit) {
     
    string ea_notice,divider = "=========================,";    
    tradeGain=(AccountBalance()==0?"0.0":DoubleToStr(((currentProfit/(AccountBalance()+AccountCredit()))*100),1));           

    if(StringFind(StringToLowerCase(noTradingDays),getStringOf(DayOfWeek()))>0)
          ea_notice="No trade today. It's a noTradingDay,";     
    
    
    Comment(DisplayTitle,"\n",
                   "=========================\n"+
                   "Broker Time: "+TimeToStr(TimeCurrent(),TIME_MINUTES)+"\n"+
                   "GMT Time: "+TimeToStr(timeGMT,TIME_MINUTES)+"\n"+
                   "Tradehours: "+TimeToStr(startTime,TIME_MINUTES)+"-"+TimeToStr(endTime,TIME_MINUTES)+"\n"+
                   "=========================\n"+
                   "Gain: "+tradeGain+"%\n"+                       
                   "Day%: "+days_gain+"%   Week%: "+weeks_gain+"%\n"+
                   "Month%: "+months_gain+"%   Year%: "+years_gain+"%\n"+  
                    "=========================\n"+                                                    
                   "Account Margin in use: $" +DoubleToStr(AccountMargin(),2)+"\n"+            
                   "Account Balance:  $" +DoubleToStr(AccountBalance(),2)+"\n"+
                   "Account Equity:  $"+DoubleToStr(AccountEquity(),2)+"\n"+
                   "=========================\n"+ 
                   ea_notice+"\n");
                   
}
  
bool lastOrderClosedBE(int tickt) {
    if(tickt==-1) return false;
    if(!OrderSelect(tickt,SELECT_BY_TICKET,MODE_HISTORY)) return(false);     
    refreshRates();
    double digits=MarketInfo(OrderSymbol(),MODE_DIGITS);
    double pointz=MarketInfo(OrderSymbol(),MODE_POINT);
    if(digits==3 || digits==5) pointz*=10;
    if((MathAbs(OrderClosePrice()-OrderOpenPrice())/pointz)<(TP-5)*pointz) return(true); //did trade close BE? yes, return true
    return(false);
}

bool lastOrderClosed(int tickt) {
    if(tickt==-1) return false; 
    if(!OrderSelect(tickt,SELECT_BY_TICKET,MODE_HISTORY)) return(false);
    return(true);
}
 
bool lastOrderClosedProfit(int tickt) {
    if(tickt==-1) return false; 
    if(!OrderSelect(tickt,SELECT_BY_TICKET,MODE_HISTORY)) return(false);    
    if(StringFind(OrderComment(),"tp")>-1) return(true); //if tp hit return false
    return(false);
}

void setOrder(string _symbol,int _optype,MqlRates& _candles[]) { //double _switchUp,double _switchDn
   sl=0; tp=0;
   string commnt;
   int cnt=0,_digitz,_dgtz;
   double price=0,stopRange=100,_ask,_bid,_pointz,_spread; //don't spread, only reason there cause was going to use it to get ask price using candle[].close..
   double _stoplevel=0;
     
   getSymbolData(_symbol,_ask,_bid,_pointz,_digitz,_dgtz,_spread,_stoplevel); 
   
   //if(_optype==OP_BUY) price=_ask;
   //if(_optype==OP_SELL) price=_bid; 

   //we check that pendung price is not beyond current price
   if(_optype==OP_BUYSTOP) {  
         price=_candles[1].high+_spread*_pointz;
         if(MathAbs(_ask-price)<_stoplevel*_pointz) return;
   }      
   
   if(_optype==OP_SELLSTOP) {
         price=_candles[1].low-_spread*_pointz;
         if(MathAbs(_bid-price)<_stoplevel*_pointz) return; 
   } 
               
   //simpleBox types of SLs
   switch(stopLossSetting) {
      case(noSL):
          sl=0;
          stopRange=100;
      break;
         
      case(useFixedSL): 
         if(SL==0) SL=100;
         if(SL>0) {
            if(_optype==OP_BUYSTOP) sl=price-SL*_pointz-_spread*_pointz-(slpadding>0?slpadding*_pointz:0); 
            if(_optype==OP_SELLSTOP) sl=price+SL*_pointz+_spread*_pointz+(slpadding>0?slpadding*_pointz:0);
            stopRange=SL;
         }                       
      break;
      
      case(useBar1_HiLo):
         if(_optype==OP_BUYSTOP) sl=_candles[1].low-_spread*_pointz-(slpadding>0?slpadding*_pointz:0); 
         if(_optype==OP_SELLSTOP) sl=_candles[1].high+_spread*_pointz+(slpadding>0?slpadding*_pointz:0);
         stopRange=MathAbs(price-sl)/_pointz;
      break;      
            
   }
   
   //test for user stopLossRange Minimum
   if(minStopLossRange>0) 
      if(stopRange<=minStopLossRange*_pointz) return;
 
  //simpleBox TP Setup 
   switch(takeProfitSetting) {
      case(noTP):
          tp=0;
      break;

      case(useFixedTP):
         if(TP>0) {
            if(_optype==OP_BUYSTOP) sl=price+TP*_pointz; 
            if(_optype==OP_SELLSTOP) sl=price-TP*_pointz;
         }      
      break;
      
      case(useTPRatio):
         if(_optype==OP_BUYSTOP) tp = price + ratio_value*stopRange*_pointz;
         if(_optype==OP_SELLSTOP) tp = price - ratio_value*stopRange*_pointz; 
      break;              
   }   
   
   sl=NormalizeNumber(sl,_digitz);
   tp=NormalizeNumber(tp,_digitz);
   stopRange=NormalizeNumber(stopRange,1);  
   price=NormalizeNumber(price,_digitz);
   
   if(debug)
      Print(TimeToStr(_candles[1].time)," symbol: ",_symbol," entry price(pending): ",DoubleToStr(price,_digitz),"  sl: ",(string)sl," tp: ",(string)tp,
            "  spread: ",DoubleToStr(_spread,1),(ratio_value>0?"  TpRatio is "+tpRatio:""),"  symbol digits: ",(string)_digitz,
            " stopRange: ",DoubleToStr(stopRange,1),"  _candles[1].close: ",_candles[1].close);
   
   commnt=tradeComment+((_optype==OP_BUY||_optype==OP_BUYSTOP)?"Buy":"Sell");
   
   double lotz=CalcLot(_symbol,stopRange,_pointz,Lots_Per_Balance);
   
   _ticket1=SendTrade(_optype,_symbol,lotz,price,sl,tp,commnt);
   
   if(_ticket1>-1) {
      ArrayResize(tradeOrders,ArraySize(tradeOrders)+1);
      tradeOrders[ArraySize(tradeOrders)-1].ticket=_ticket1;
      tradeOrders[ArraySize(tradeOrders)-1].symbol=_symbol;      
      tradeOrders[ArraySize(tradeOrders)-1].optype=_optype;
      tradeOrders[ArraySize(tradeOrders)-1].pendTickt=(_ticket2>-1?_ticket2:-1);
      tradeOrders[ArraySize(tradeOrders)-1].stop=sl;
      tradeOrders[ArraySize(tradeOrders)-1].lots=lotz;
      tradeOrders[ArraySize(tradeOrders)-1].time=Time[0];
      tradeOrders[ArraySize(tradeOrders)-1].stopRange=stopRange;     
   }     
    if(debug) 
          Print(TimeToStr(TimeCurrent()),"  EA trade opened with ticket: ", _ticket1," _optype: ",(_optype==OP_BUY||_optype==OP_BUYSTOP?"OP_BUY":"OP_SELL"));

}

bool Winners(int mxwins) {
  int count=0;
  for (int x=0; x<OrdersHistoryTotal(); x++) {
   if(!OrderSelect(x,SELECT_BY_POS,MODE_HISTORY)) continue;     
      for(int y=0; y<ArraySize(tradeOrders); y++) {
         if(OrderTicket()!=tradeOrders[y].ticket) continue;
         if(OrderProfit()<0) continue;
         /*if(StringFind(OrderComment(),"tp")==-1) continue; 
            if((MathAbs(OrderClosePrice()-OrderOpenPrice())/pointz)<(TP-5)*pointz) return(false); //did trade close BE? yes, return false not full winner  
            */       
         if(OrderProfit()>0) { count++; break; }
      }
  }
  if(count>=mxwins) return(true);
  return(false);
}

bool Losses(int mxloss) {
  int count=0;
  for (int x=0; x<OrdersHistoryTotal(); x++) {
   if(!OrderSelect(x,SELECT_BY_POS,MODE_HISTORY)) continue;     
      for(int y=0; y<ArraySize(tradeOrders); y++) {
         if(OrderTicket()!=tradeOrders[y].ticket) continue;
         if(OrderProfit()<0) { count++; break; }
      }
  }
  if(count>=mxloss) return(true);
  return(false);
}

void doBE(string _symbol,int _ticket) {
  double newbe=0,_level=0,_setBElevel=0,_spread;
  double _ask=0,_bid=0,_pointz=0,_range_=0,_stoplevel=0;
  int _dgtz,_digitz=0;

  refreshRates();

  getSymbolData(_symbol,_ask,_bid,_pointz,_digitz,_dgtz,_spread,_stoplevel);
  
  _setBElevel=setBE; //need to set this variable like this for when dealing % vs pip gain
       
  if(OrderType()==OP_BUY && OrderStopLoss()>=OrderOpenPrice()+_pointz) return; 
  if(OrderType()==OP_SELL && OrderStopLoss()<=OrderOpenPrice()-_pointz) return; 

  if(usePipsOrPercent==percent) {
     _range_=MathAbs(OrderOpenPrice()-OrderStopLoss());
     if(OrderStopLoss()==0)  _range_=MathAbs(OrderTakeProfit()-OrderOpenPrice()); 
     _setBElevel=NormalizeNumber(((setBE/100)*_range_)/_pointz,1);
  } 
    
  if(OrderType()==OP_BUY) _level=(_bid-OrderOpenPrice())/_pointz; 
  if(OrderType()==OP_SELL) _level=(OrderOpenPrice()-_ask)/_pointz;
 
  if(_level>=_setBElevel) { 
      if (OrderType()==OP_BUY) newbe=OrderOpenPrice()+_pointz;
      if (OrderType()==OP_SELL) newbe=OrderOpenPrice()-_pointz;
      trd=OrderModify(OrderTicket(), OrderOpenPrice(), newbe, OrderTakeProfit(), 0);
   }  
}

void MonitorTrailing(string _symbol,int _ticket) {

    double new_stop=0,percentMove=0,_range_=0;
    double _lastOpenPrice=0,_ask=0,_bid=0,_pointz=0,_spread=0;
    int _dgtz=0,_digitz=0;
    double _trailingStop=0,_stepDelta=0,_stoplevel=0;
    
     refreshRates();
     
     getSymbolData(_symbol,_ask,_bid,_pointz,_digitz,_dgtz,_spread,_stoplevel);
          
     if(_digitz==3||_digitz==5) _pointz*=10;

     _trailingStop=trailingStop;
     _stepDelta=stepDelta;     
     
     if(usePipsOrPercent==percent) { //get the original stoploss pip range.. need it for % usage
        for(int x=0; x<ArraySize(tradeOrders); x++) {
            if(OrderTicket()!=tradeOrders[x].ticket) continue;
            _range_=tradeOrders[x].stopRange;
            break;
        }
        _trailingStop=NormalizeNumber(((trailingStop/100)*_range_)/_pointz,1);
        _stepDelta=NormalizeNumber(((stepDelta/100)*_range_)/_pointz,1);
     } 
   
     if(OrderType()==OP_BUY && (OrderStopLoss()<OrderOpenPrice() ||  OrderStopLoss()==0))
         { _lastOpenPrice=OrderOpenPrice(); } else { _lastOpenPrice=OrderStopLoss()+_trailingStop*_pointz; }        

     if(OrderType()==OP_SELL && (OrderStopLoss()>OrderOpenPrice() ||  OrderStopLoss()==0)) 
         { _lastOpenPrice=OrderOpenPrice(); } else { _lastOpenPrice=OrderStopLoss()-_trailingStop*_pointz; }         

     if(OrderType()==OP_BUY)    
        if(NormalizeNumber((_bid-_lastOpenPrice)/_pointz,1)>=_stepDelta) { 
             new_stop=_bid-_trailingStop*_pointz; 
             trd=OrderModify(OrderTicket(),OrderOpenPrice(),new_stop,OrderTakeProfit(),0,clrGray);
        }    
 
     if(OrderType()==OP_SELL)
        if(NormalizeNumber((_lastOpenPrice-_ask)/_pointz,1)>=_stepDelta) {  
             new_stop=_ask+_trailingStop*_pointz;  
             trd=OrderModify(OrderTicket(),OrderOpenPrice(),new_stop,OrderTakeProfit(),0,clrGray);
        }      
}

void getGlobals(string gname) {
   if(GlobalVariableCheck(gname)) 
      _ticket1=(int)GlobalVariableGet(gname);
}

void resetGlobals(string text){
   for(int x=0; x<GlobalVariablesTotal(); x++)
      if(StringFind(GlobalVariableName(x),text)>-1)
         GlobalVariableDel(GlobalVariableName(x));
}

int generateRandomOpType() {
      //get random number of symbols to trade
      int result=OP_BUY;
      int number=MathAbs(randomInteger(7,20))+7;
      if(number<7) result=OP_BUY;
      if(number>13) result=OP_SELL;
      return(result);
}
           
int randomInteger(int begin, int end) {
  double randvalue,RAND_MAX=32767.0;
  begin = MathAbs(begin);
  end = MathAbs(end);
  
  randvalue=MathRand()/((RAND_MAX)+1);//generates a psuedo-random double between 0.0 and 0.999..
  
  if(begin>end) return((int)(0+begin*randvalue));
  return((int)(begin + (begin-end)*randvalue)); 
}

void GetPrefixSuffix(string symbol, string& prefx, string& suffx) {
   int t1,t2,t3,t4;
   uchar Char[];
   t2=StringToCharArray(symbol,Char,0,-1,CP_UTF8)-2;
   t3=-1; t4=-1; t1=0; 
   while(t1<=t2) {
      if(t3==-1 && Char[t1]>=65 && Char[t1]<=90) t3=t1; 
      if(t3!=-1 && t4==-1 && (Char[t1]<65 || Char[t1]>90)) t4=t1;
      t1++;
   }
   
   prefx=""; suffx="";
   if(t3>0) prefx=StringSubstr(symbol,0,t3);   
   if(t4>0) suffx=StringSubstr(symbol,t4,0);
}

void reloadEA(long chrtID,string fname){
	  string Folder=TerminalInfoString(TERMINAL_DATA_PATH) + "\\templates\\";
	  ChartSaveTemplate(chrtID,fname); // save templage in /templates
     ChartApplyTemplate(chrtID,fname);
}

//======================================================================
string sTfTable[] = {"M1","M5","M15","M30","H1","H4","D1","W1","MN"};
int    iTfTable[] = {1,5,15,30,60,240,1440,10080,43200}; 

int stringToTimeFrame(string tf)
  {
   for(int i=ArraySize(sTfTable)-1; i>=0; i--)
      if(tf==sTfTable[i]) return(iTfTable[i]);
   return(0);
  }
/*
bool reloadScript(long chrtID,string fname){
	   string Folder=TerminalInfoString(TERMINAL_DATA_PATH) + "\\templates\\";
	   if(!_FileExist(Folder+"\\"+fname+".tpl"))  ChartSaveTemplate(chrtID,fname); // save templage in /templates
     return(ChartApplyTemplate(chrtID,fname));
}

#import "kernel32.dll"
   int GetFileAttributesW(string path);
#import

bool _FileExist(string target_path) {
   if (GetFileAttributesW(target_path) == -1) return(false);
   return(true);
}*/
 


//========================================================= Disclaimer Clause =======================================================
//#property description "************** Disclaimer ************"
#property description "The end user/trader of this Expert Advisor (EA) agrees and fully understands that there absolutely"
#property description "no guarantees or representations of any kind written, verbal, or implied that this EA will result"
#property description "in profitable or no-profitable results. The end user/trader agrees to hold no other involved party"
#property description "liable for any incurred damages or losses due to use of this EA. The end user/trader will have no"
#property description "claims direct or indirect against losses/damages that may be incurred."
//#property description "************** Disclaimer ************"

    