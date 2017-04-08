#pragma semicolon 1

#define PLUGIN_AUTHOR "Fishy"
#define PLUGIN_VERSION "1.0.62"

#include <sourcemod>
#include <steamtools>
#include <EventLogs>

#pragma newdecls required

//<!--- Convars --->
ConVar cvarChatLogEnabled;
ConVar cvarPluginLogEnabled;

bool g_bChatLogEnabled;
bool g_bPluginLogEnabled;

//<!--- Main --->

Database hDB;
char g_IP[64];
bool g_bSteamTools;

public Plugin myinfo = 
{
	name = "EventLogs",
	author = PLUGIN_AUTHOR,
	description = "Logging all sorts of stuff :3",
	version = PLUGIN_VERSION,
	url = "https://keybase.io/rumblefrog"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	hDB = SQL_Connect("eventlogs", true, error, err_max);
	
	if (hDB == INVALID_HANDLE)
		return APLRes_Failure;
		
	char ChatLogSQL[] = "CREATE TABLE IF NOT EXISTS EventLogs_Chat ( `id` INT NOT NULL AUTO_INCREMENT , `host` VARCHAR(64) NOT NULL , `steamid` VARCHAR(32) NOT NULL , `name` VARCHAR(64) NOT NULL , `message` TEXT NOT NULL , `time` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , PRIMARY KEY (`id`))";
	char PluginLogSQL[] = "CREATE TABLE IF NOT EXISTS EventLogs_Plugin ( `id` INT NOT NULL AUTO_INCREMENT , `host` VARCHAR(64) NOT NULL , `name` VARCHAR(255) NOT NULL , `level` ENUM('trace','debug','info','warn','error','fatal') NOT NULL DEFAULT 'info' , `message` LONGTEXT NOT NULL , `time` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , PRIMARY KEY (`id`))";
	
	SQL_SetCharset(hDB, "utf8");
	SQL_TQuery(hDB, OnTableCreate, ChatLogSQL);
	SQL_TQuery(hDB, OnTableCreate, PluginLogSQL);
	
	RegPluginLibrary("EventLogs");
	CreateNative("EL_LogPlugin", NativeLogPlugin);
	return APLRes_Success;
}

public void OnTableCreate(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == INVALID_HANDLE)
	{
		EL_LogPlugin(LOG_FATAL, "Unable to create table: %s", error);
		SetFailState("Unable to create table: %s", error);
	}
}

public void OnPluginStart()
{
	CreateConVar("sm_eventlogs_version", PLUGIN_VERSION, "EventLogs Version", FCVAR_REPLICATED | FCVAR_SPONLY | FCVAR_DONTRECORD | FCVAR_NOTIFY);
	
	cvarChatLogEnabled = CreateConVar("sm_eventlogs_chat", "1", "Enable Chat Logging", 0, true, 0.0, true, 1.0);
	g_bChatLogEnabled = cvarChatLogEnabled.BoolValue;
	
	cvarPluginLogEnabled = CreateConVar("sm_eventlogs_plugin", "1", "Enable Plugin Logging", 0, true, 0.0, true, 1.0);
	g_bPluginLogEnabled = cvarPluginLogEnabled.BoolValue;
		
	HookConVarChange(cvarChatLogEnabled, OnConvarChange);
	HookConVarChange(cvarPluginLogEnabled, OnConvarChange);
	
	AutoExecConfig(true, "eventlogs");
	
	if (!g_bSteamTools || !Steam_IsConnected())
	{
		int ip = GetConVarInt(FindConVar("hostip"));
		Format(g_IP, sizeof(g_IP), "%d.%d.%d.%d:%d", ((ip & 0xFF000000) >> 24) & 0xFF, ((ip & 0x00FF0000) >> 16) & 0xFF, ((ip & 0x0000FF00) >>  8) & 0xFF, ((ip & 0x000000FF) >>  0) & 0xFF, GetConVarInt(FindConVar("hostport")));
	}
	
}

public void OnClientSayCommand_Post(int iClient, const char[] sCommand, const char[] sArgs)
{
	if (g_bChatLogEnabled && Client_IsValid(iClient))
	{
		char SteamID64[32], Client_Name[MAX_NAME_LENGTH], ChatSQL[512], Escaped_Name[256], Escaped_MSG[1024];
		
		GetClientAuthId(iClient, AuthId_SteamID64, SteamID64, sizeof SteamID64);
		
		if (StrEqual(SteamID64, "STEAM_ID_STOP_IGNORING_RETVALS"))
			return;
		
		GetClientName(iClient, Client_Name, sizeof Client_Name);
			
		SQL_EscapeString(hDB, Client_Name, Escaped_Name, sizeof Escaped_Name);
		SQL_EscapeString(hDB, sArgs, Escaped_MSG, sizeof Escaped_MSG);
		Format(ChatSQL, sizeof ChatSQL, "INSERT INTO EventLogs_Chat (`host`, `steamid`, `name`, `message`) VALUES ('%s', '%s', '%s', '%s')", g_IP, SteamID64, Escaped_Name, Escaped_MSG);
		
		SQL_TQuery(hDB, OnRowInsert, ChatSQL);
	}
}

public void OnRowInsert(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == INVALID_HANDLE)
		EL_LogPlugin(LOG_ERROR, "Unable to insert row: %s", error);
}

public void OnConvarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == cvarChatLogEnabled)
		g_bChatLogEnabled = cvarChatLogEnabled.BoolValue;
}

public int Steam_SteamServersConnected() {
	int octets[4];
	Steam_GetPublicIP(octets);
	Format(g_IP, sizeof(g_IP), "%d.%d.%d.%d:%d", octets[0], octets[1], octets[2], octets[3], GetConVarInt(FindConVar("hostport")));
}

public int Steam_FullyLoaded()
{
	g_bSteamTools = true;
}

public int Steam_Shutdown()
{
	g_bSteamTools = false;
}

public int NativeLogPlugin(Handle plugin, int numParams)
{
	if (!g_bPluginLogEnabled)
		return false;
	
	int written;
	char sMessage[1024], Plugin_Name[255], PluginSQL[512], Level[16], Escaped_Name[512], Escaped_Message[2049];
	
	SQLGetLogLevel(GetNativeCell(1), Level, sizeof Level);
	FormatNativeString(0, 2, 3, sizeof sMessage, written, sMessage);
	GetPluginInfo(plugin, PlInfo_Name, Plugin_Name, sizeof Plugin_Name);
	
	SQL_EscapeString(hDB, Plugin_Name, Escaped_Name, sizeof Escaped_Name);
	SQL_EscapeString(hDB, sMessage, Escaped_Message, sizeof Escaped_Message);
	
	Format(PluginSQL, sizeof PluginSQL, "INSERT INTO EventLogs_Plugin (`host`, `name`, `level`, `message`) VALUES ('%s', '%s', '%s', '%s')", g_IP, Escaped_Name, Level, Escaped_Message);
	
	SQL_TQuery(hDB, OnRowInsert, PluginSQL);
	
	return true;
}

void SQLGetLogLevel(int Level, char[] buffer, int buffer_size)
{
	switch (Level)
	{
		case LOG_TRACE:
			Format(buffer, buffer_size, "trace");
		case LOG_DEBUG:
			Format(buffer, buffer_size, "debug");
		case LOG_INFO:
			Format(buffer, buffer_size, "info");
		case LOG_WARN:
			Format(buffer, buffer_size, "warn");
		case LOG_ERROR:
			Format(buffer, buffer_size, "error");
		case LOG_FATAL:
			Format(buffer, buffer_size, "fatal");
	}
}

stock bool Client_IsValid(int client, bool checkConnected=true)
{
	if (client > 4096) {
		client = EntRefToEntIndex(client);
	}

	if (client < 1 || client > MaxClients) {
		return false;
	}

	if (checkConnected && !IsClientConnected(client)) {
		return false;
	}

	return true;
}