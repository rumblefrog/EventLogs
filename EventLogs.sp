#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Fishy"
#define PLUGIN_VERSION "1.0.0"

#include <sourcemod>
#include <sdktools>

#pragma newdecls required

ConVar cvarChatLogEnabled;
Database hDB;
bool g_bChatLogEnabled;

public Plugin myinfo = 
{
	name = "EventLogs",
	author = PLUGIN_AUTHOR,
	description = "Logging all sorts of stuff :3",
	version = PLUGIN_VERSION,
	url = "https://keybase.io/rumblefrog"
};

public void OnPluginStart()
{
	CreateConVar("sm_eventlogs_version", PLUGIN_VERSION, "EventLogs Version", FCVAR_REPLICATED | FCVAR_SPONLY | FCVAR_DONTRECORD | FCVAR_NOTIFY);
	
	cvarChatLogEnabled = CreateConVar("sm_eventlogs_chat", "1", "Enable Chat Logging", 0, true, 0.0, true, 1.0);
	g_bChatLogEnabled = cvarChatLogEnabled.BoolValue;
	HookConVarChange(cvarChatLogEnabled, OnConvarChange);
	
	AutoExecConfig(true, "eventlogs.cfg");
	
	InitDB(hDB);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
   CreateNative("PluginLog", NativePluginLog);
   return APLRes_Success;
}

void InitDB(Handle &DbHNDL)
{
	char sError[512];
	
	DbHNDL = SQL_Connect("eventlogs", true, sError, sizeof sError);
	
	if (DbHNDL == INVALID_HANDLE)
		SetFailState(sError);
		
	char ChatLogSQL[] = "CREATE TABLE IF NOT EXISTS EventsLog_Chat ( `id` INT NOT NULL AUTO_INCREMENT , `steamid` VARCHAR(32) NOT NULL , `name` VARCHAR(64) NOT NULL , `message` TEXT NOT NULL , `time` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , PRIMARY KEY (`id`))";
	
	SQL_FastQuery(DbHNDL, ChatLogSQL, sizeof ChatLogSQL);
}

public void OnClientSayCommand_Post(int iClient, const char[] sCommand, const char[] sArgs)
{
	if (g_bChatLogEnabled)
	{
		DBStatement ChatSQL;
		char SteamID64[32], Client_Name[MAX_NAME_LENGTH], Error[255];
		
		GetClientAuthId(iClient, AuthId_SteamID64, SteamID64, sizeof SteamID64);
		GetClientName(iClient, Client_Name, sizeof Client_Name);
		
		ChatSQL = SQL_PrepareQuery(hDB, "INSERT INTO EventsLog_Chat (`steamid`, `name`, `message`) VALUES (?, ?, ?)", Error, sizeof Error);
		SQL_BindParamString(ChatSQL, 0, SteamID64, false);
		SQL_BindParamString(ChatSQL, 1, Client_Name, false);
		SQL_BindParamString(ChatSQL, 2, sArgs, false);
		
		if (!SQL_Execute(ChatSQL))
			LogError(Error);
	}
}

public void OnConvarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == cvarChatLogEnabled)
		g_bChatLogEnabled = cvarChatLogEnabled.BoolValue;
}


public int NativePluginLog(Handle plugin, int numParams)
{
	char sMessage[1024], Plugin_Name[128];
	
	GetNativeString(1, sMessage, sizeof sMessage);
	GetPluginInfo(plugin, PlInfo_Name, Plugin_Name, sizeof Plugin_Name);
	
	//Finish Up
}