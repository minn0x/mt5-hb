//+------------------------------------------------------------------+
//|  Sends a periodic heartbeat ping to healthchecks.io               |
//|  Attach to any SEPARATE chart — runs independently of trading EAs.|
//+------------------------------------------------------------------+
#property copyright   "minnox"
#property link        "https://github.com/minn0x/"
#property version     "1.0"

//--- Inputs
input string PingURL         = "https://hc-ping.com/YOUR-UUID-HERE"; // Healthchecks.io Ping URL
input int    IntervalMinutes = 5;    // Ping interval in minutes (min: 1)
input bool   PingOnStart     = true; // Send ping immediately on attach

//--- Globals
datetime g_lastPing      = 0;
long     g_intervalSec   = 0;
bool     g_firstTick     = true;
bool     g_pinging       = false;
int      g_failCount     = 0;
int      g_totalPings    = 0; // counts successful pings only

//+------------------------------------------------------------------+
int OnInit() {
   if(StringLen(PingURL) < 20 || StringFind(PingURL, "hc-ping.com") < 0) {
      Print("Heartbeat ERROR: PingURL looks invalid — set a valid healthchecks.io URL in inputs.");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(IntervalMinutes < 1) {
      Print("Heartbeat ERROR: IntervalMinutes must be >= 1.");
      return INIT_PARAMETERS_INCORRECT;
   }

   g_intervalSec = (long)IntervalMinutes * 60;

   if(!EventSetTimer(1)) {
      Print("Heartbeat ERROR: EventSetTimer(1) failed — EA will not send pings. Reload it.");
      return INIT_FAILED;
   }

   Print("Heartbeat started | Interval: ", IntervalMinutes, " min | URL: ", PingURL);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   EventKillTimer();

   string reasonStr;
   switch(reason) {
   case REASON_REMOVE:
      reasonStr = "EA removed";
      break;
   case REASON_CHARTCLOSE:
      reasonStr = "chart closed";
      break;
   case REASON_RECOMPILE:
      reasonStr = "recompiled";
      break;
   case REASON_PARAMETERS:
      reasonStr = "parameters changed";
      break;
   case REASON_ACCOUNT:
      reasonStr = "account changed";
      break;
   case REASON_TEMPLATE:
      reasonStr = "template applied";
      break;
   case REASON_INITFAILED:
      reasonStr = "init failed";
      break;
   case REASON_CLOSE:
      reasonStr = "terminal closing";
      break;
   default:
      reasonStr = "unknown (" + IntegerToString(reason) + ")";
      break;
   }

   Print("Heartbeat stopped | Reason: ", reasonStr,
         " | Total pings sent: ", g_totalPings,
         " | Last fail streak: ", g_failCount);
}

//+------------------------------------------------------------------+
void OnTimer() {
   if(g_pinging) return;

   datetime now = TimeCurrent();

   if(g_firstTick) {
      g_firstTick = false;
      g_lastPing  = now;
      if(PingOnStart) SendPing();
      return;
   }

   if((now - g_lastPing) >= g_intervalSec)
      SendPing();
}

//+------------------------------------------------------------------+
void OnTick() {}

//+------------------------------------------------------------------+
void SendFailPing() {
   // Best-effort /fail ping — ignore return value, network may already be down
   char postData[], result[];
   string responseHdrs = "";
   ArrayResize(postData, 0);
   string headers = "User-Agent: Mozilla/5.0\r\n";
   WebRequest("GET", PingURL + "/fail", headers, 5000, postData, result, responseHdrs);
}

//+------------------------------------------------------------------+
void SendPing() {
   g_pinging = true;

   char   postData[];
   char   result[];
   string responseHdrs = "";
   ArrayResize(postData, 0);
   string headers = "User-Agent: Mozilla/5.0\r\n";

   // /start ping — lets healthchecks.io measure duration and detect slow executions
   WebRequest("GET", PingURL + "/start", headers, 5000, postData, result, responseHdrs);

   int res = WebRequest("GET", PingURL, headers, 5000, postData, result, responseHdrs);

   if(res == 200) {
      g_lastPing = TimeCurrent(); // only reset interval timer on success
      g_failCount = 0;
      g_totalPings++; // counts successful pings only
      if(g_totalPings == 1 || g_totalPings % 100 == 0)
         Print("Heartbeat OK | ", TimeToString(g_lastPing, TIME_DATE | TIME_MINUTES),
               " | Total: ", g_totalPings);
   } else if(res == -1) {
      g_failCount++;
      int err = GetLastError();
      Print("Heartbeat FAILED | err: ", err,
            " | streak: ", g_failCount,
            " | ", TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES));
      if(g_failCount == 1)
         Print("  >> Ensure '", PingURL, "' is whitelisted: Tools > Options > Expert Advisors");
      SendFailPing();
   } else {
      g_failCount++;
      Print("Heartbeat WARNING | HTTP ", res,
            " | streak: ", g_failCount,
            " | ", TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES));
      SendFailPing();
   }

   g_pinging = false;
}
//+------------------------------------------------------------------+
