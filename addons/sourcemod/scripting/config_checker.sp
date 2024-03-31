#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_NAME                   "Config Checker"
#define PLUGIN_VERSION                "1.0.0"
char cfgVal[128];

public Plugin myinfo =
{
    name                            =  PLUGIN_NAME,
    author                          = "Aad",
    description                     = "Prints executed config file to client and chat",
    version                         =  PLUGIN_VERSION,
    url                             = "https://github.com/RGLgg/server-resources-updater"
}

public void OnPluginStart()
{
    LogMessage("[CC] version %s has been loaded.", PLUGIN_VERSION);
    PrintToChatAll("[CC] version %s has been loaded.", PLUGIN_VERSION);
    RegConsoleCmd("cc", Config_Info, "!cc - Prints Config name to client");
    GetConVarString(FindConVar("servercfgfile"), cfgVal, sizeof(cfgVal));
    HookConVarChange(FindConVar("servercfgfile"), OnServerCfgChanged);
    HookEvent("teamplay_round_start", EventRoundStart);
}

public Action Config_Info(int client, int args)
{
    ReplyToCommand(client, "[CC] This server is running config: %s", cfgVal);
    return Plugin_Handled;
}

public Action EventRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
    PrintToAll();
    return Plugin_Continue;
}

public void OnServerCfgChanged(ConVar convar, char[] oldValue, char[] newValue)
{
    PrintToAll();
}

public void OnClientPostAdminCheck(int client)
{
    GetConVarString(FindConVar("servercfgfile"), cfgVal, sizeof(cfgVal));
    CreateTimer(15.0, prWelcomeClient, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action prWelcomeClient(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (client)
    {
        PrintToChat(client, "[CC] This server is running config: %s", cfgVal);
    }
    
    return Plugin_Continue;
}

public void PrintToAll() {
    GetConVarString(FindConVar("servercfgfile"), cfgVal, sizeof(cfgVal));
    PrintToChatAll("[CC] This server is running config: %s", cfgVal);
}

public void OnPluginEnd()
{
    LogMessage("[CC] version %s has been unloaded.", PLUGIN_VERSION);
    PrintToChatAll("[CC] version %s has been unloaded.", PLUGIN_VERSION);
}