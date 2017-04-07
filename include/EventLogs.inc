#if defined _EventLogs_included
 #endinput
#endif
#define _EventLogs_included


enum LogLevel
{
	LOG_TRACE,
	LOG_DEBUG,
	LOG_INFO,
	LOG_WARN,
	LOG_ERROR,
	LOG_FATAL
}

/**
* Logs plugin message
* 
* @param level			Logging level
* @param message		Message
* @return				True or false, if request is made
*/
native bool EL_LogPlugin(LogLevel Level, const char[] message);


public SharedPlugin __pl_EventLogs =
{
	name = "EventLogs",
	file = "EventLogs.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};


#if !defined REQUIRE_PLUGIN
public __pl_EventLogs_SetNTVOptional()
{
	MarkNativeAsOptional("EL_LogPlugin");
}
#endif