/**
 * demorecorder_check.sp
 *
 * Plugin to check if a player is recording a demo.
 */

#include <sourcemod>
#include <sdktools>
#include <morecolors>

#define DEMOCHECK_TAG "{lime}[{red}Demo Check{lime}]{white} "

public Plugin:myinfo =
{
    name = "Demo Check (No Discord)",
    author = "Shigbeard, Aad",
    description = "Checks if a player is recording a demo",
    version = "2.0.0",
    url = "https://ozfortress.com/"
};

#define RED                 0
#define BLU                 1
#define TEAM_OFFSET         2

ConVar g_bDemoCheckEnabled;
ConVar g_bDemoCheckOnReadyUp;
ConVar g_bDemoCheckWarn;
ConVar g_bDemoCheckAnnounce;

bool teamReadyState[2];
bool pregame;
Handle redPlayersReady;
Handle bluePlayersReady;
Handle g_readymode_min;

Handle g_hDemoCheckTimer = INVALID_HANDLE;
int g_iRealPlayerCount = 0;
bool g_bWarnedClientDsEnable[MAXPLAYERS + 1]; // Tracks if client has already been warned
bool g_bWarnedClientDsDelete[MAXPLAYERS + 1]; // Tracks if client has already been warned

public void OnPluginStart()
{
    LoadTranslations("demo_check.phrases");

    g_bDemoCheckEnabled = CreateConVar("sm_democheck_enabled", "1", "Enable demo check", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_bDemoCheckOnReadyUp = CreateConVar("sm_democheck_onreadyup", "1", "Check if all players are recording a demo when both teams ready up", FCVAR_NOTIFY, true, 0.0, true, 1.0);

    g_bDemoCheckWarn = CreateConVar("sm_democheck_warn", "1", " Set the plugin into warning only mode.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_bDemoCheckAnnounce = CreateConVar("sm_democheck_announce", "1", "Announce passed demo checks to chat", FCVAR_NOTIFY, true, 0.0, true, 1.0);

    RegServerCmd("sm_democheck", Cmd_DemoCheck_Console, "Check if a player is recording a demo", 0);
    RegServerCmd("sm_democheck_enable", Cmd_DemoCheckEnable_Console, "Enable demo check", 0);
    RegServerCmd("sm_democheck_disable", Cmd_DemoCheckDisable_Console, "Disable demo check", 0);
    RegServerCmd("sm_democheck_all", Cmd_DemoCheckAll_Console, "Check if all players are recording a demo", 0);

    HookConVarChange(g_bDemoCheckEnabled, OnDemoCheckEnabledChange)
    g_readymode_min = FindConVar("mp_tournament_readymode_min");

    HookConVarChange(g_bDemoCheckWarn, OnDemoCheckWarn);

    // Listen for player readying or unreadying.
    AddCommandListener(Listener_TournamentPlayerReadystate, "tournament_player_readystate");
    HookEvent("tournament_stateupdate", Event_TournamentStateUpdate);

    redPlayersReady = CreateArray();
    bluePlayersReady = CreateArray();
    
    // Perform a check on all players when the plugin is loaded
    if (GetConVarBool(g_bDemoCheckEnabled))
    {
        PrintToChatAll("%t", "plugin_start_check_all");
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && !IsFakeClient(i))
            {
                CheckDemoRecording(i);
                g_iRealPlayerCount++;
                g_bWarnedClientDsEnable[i] = false;
                g_bWarnedClientDsDelete[i] = false;
            }
        }
    }

    if (g_iRealPlayerCount > 0)
    {
        StartDemoCheckTimer();
    }
}

public void OnMapStart()
{
    teamReadyState[RED] = false;
    teamReadyState[BLU] = false;

    pregame = false;
    StartPregaming();
}

public void OnClientPutInServer(int client)
// Check a player once they've joined the game. We wait until they've fully connected.
{
    if (IsClientInGame(client) && !IsFakeClient(client))
    {
        if (GetConVarBool(g_bDemoCheckEnabled))
        {
            CheckDemoRecording(client);
            g_iRealPlayerCount++;
            g_bWarnedClientDsEnable[client] = false;
            g_bWarnedClientDsDelete[client] = false;
            CheckAndStartTimer();
            CreateTimer(1.0, PluginCvarPrint, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
        }
    }
}

public Action PluginCvarPrint(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (client)
    {
        char demoCheckEnabled[16], demoCheckOnReadyUp[16], demoCheckWarn[16];

        GetDemoCheckStatus(g_bDemoCheckEnabled, demoCheckEnabled, sizeof(demoCheckEnabled));
        GetDemoCheckStatus(g_bDemoCheckOnReadyUp, demoCheckOnReadyUp, sizeof(demoCheckOnReadyUp));
        GetDemoCheckStatus(g_bDemoCheckWarn, demoCheckWarn, sizeof(demoCheckWarn));
        CPrintToChat(client, DEMOCHECK_TAG ... "%t", "join_cvar_check", demoCheckEnabled, demoCheckOnReadyUp, demoCheckWarn);
    }
    
    return Plugin_Continue;
}

void GetDemoCheckStatus(ConVar convar, char[] buffer, int maxlen)
{
    Format(buffer, maxlen, GetConVarBool(convar) ? "Y" : "N");
}

public void OnClientDisconnect(int client)
{
    if (!IsFakeClient(client))
    {
        g_iRealPlayerCount = (g_iRealPlayerCount > 0) ? g_iRealPlayerCount - 1 : 0;
        g_bWarnedClientDsEnable[client] = false;
        g_bWarnedClientDsDelete[client] = false;
        CheckAndStopTimer();
    }
}

public void OnDemoCheckEnabledChange(ConVar convar, const char[] oldValue, const char[] oldFloatValue)
{
    if (GetConVarBool(g_bDemoCheckEnabled))
    {
        if (GetConVarBool(g_bDemoCheckAnnounce))
        {
            CPrintToChatAll(DEMOCHECK_TAG ... "%t", "enabled");
        }
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && !IsFakeClient(i))
            {
                CheckDemoRecording(i);
            }
        }
    }
    else
    {
        if (GetConVarBool(g_bDemoCheckAnnounce))
        {
            CPrintToChatAll(DEMOCHECK_TAG ... "%t", "disabled");
        }
    }
}

public void OnDemoCheckWarn(ConVar convar, const char[] oldValue, const char[] oldFloatValue)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            CheckDemoRecording(i);
        }
    }
}

public Action Cmd_DemoCheck_Console(int args)
{
    if (args < 1)
    {
        PrintToServer("[Demo Check] Usage: sm_democheck <userid>");
        return Plugin_Handled;
    }

    int target = GetCmdArgInt(1);
    if (target == 0)
    {
        PrintToServer("[Demo Check] Invalid target.");
        return Plugin_Handled;
    }

    if (!IsClientInGame(target) && !IsFakeClient(target))
    {
        PrintToServer("[Demo Check] Target is not in game.");
        return Plugin_Handled;
    }

    CheckDemoRecording(target);
    return Plugin_Handled;
}

public Action Cmd_DemoCheckEnable_Console(int args)
{
    SetConVarBool(g_bDemoCheckEnabled, true);
    PrintToServer("[Demo Check] Demo check enabled.");
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            CheckDemoRecording(i);
        }
    }
    return Plugin_Handled;
}

public Action Cmd_DemoCheckDisable_Console(int args)
{
    SetConVarBool(g_bDemoCheckEnabled, false);
    PrintToServer("[Demo Check] Demo check disabled.");
    return Plugin_Handled;
}

public Action Cmd_DemoCheckAll_Console(int args)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            CheckDemoRecording(i);
        }
    }
    return Plugin_Handled;
}

public Action CheckDemoRecording(int client)
{
    if (!IsClientInGame(client) && !IsFakeClient(client))
    {
        return Plugin_Stop;
    }
    if (!GetConVarBool(g_bDemoCheckEnabled))
    {
        return Plugin_Stop;
    }

    QueryClientConVar(client, "ds_enable", OnDSEnableCheck);
    QueryClientConVar(client, "ds_autodelete", OnDSAutoDeleteCheck);
    return Plugin_Continue;
}

public void OnDSEnableCheck(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] value)
{
    if (StrEqual(value, "3") || StrEqual(value, "2"))
    {
        // Expected, show nothing
    }
    else if(StrEqual(value, "1"))
    {
        PrintToConsole(client, "[Demo Check] %t", "ds_enabled 1");
        PrintToConsole(client, "[Demo Check] %t", "docs");
        char sName[64];
        GetClientName(client, sName, sizeof(sName));
        Log_Incident(client, GetConVarBool(g_bDemoCheckWarn), "ds_enable");
        if (GetConVarBool(g_bDemoCheckWarn))
        {
            if (GetConVarBool(g_bDemoCheckAnnounce))
            {
                CPrintToChatAll(DEMOCHECK_TAG ... "%t", "kicked_announce_disabled", sName);
                CPrintToChat(client, DEMOCHECK_TAG ... "%t", "ds_enabled 1");
            }
        } else {
            CreateTimer(2.0, Timer_KickClient, client);
            CPrintToChatAll(DEMOCHECK_TAG ... "%t", "kicked_announce", sName);
        }
    }
    else
    {
        PrintToConsole(client, "[Demo Check] %t", "ds_enabled 0");
        PrintToConsole(client, "[Demo Check] %t", "docs");
        char sName[64];
        GetClientName(client, sName, sizeof(sName));
        Log_Incident(client, GetConVarBool(g_bDemoCheckWarn), "ds_enable");
        if (GetConVarBool(g_bDemoCheckWarn))
        {
            if (GetConVarBool(g_bDemoCheckAnnounce))
            {
                CPrintToChatAll(DEMOCHECK_TAG ... "%t", "kicked_announce_disabled", sName);
                CPrintToChat(client, DEMOCHECK_TAG ... "%t", "ds_enabled 0");
            }
        } else {
            CreateTimer(2.0, Timer_KickClient, client);
            CPrintToChatAll(DEMOCHECK_TAG ... "%t", "kicked_announce", sName);
        }
    }
}

public void OnDSAutoDeleteCheck(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] value)
{
    if (StrEqual(value, "1"))
    {
        PrintToConsole(client, "[Demo Check] %t", "ds_autodelete 1");
        PrintToConsole(client, "[Demo Check] %t", "docs");
        char sName[64];
        GetClientName(client, sName, sizeof(sName));
        Log_Incident(client, GetConVarBool(g_bDemoCheckWarn), "ds_autodelete");
        if (GetConVarBool(g_bDemoCheckWarn))
        {
            if (GetConVarBool(g_bDemoCheckAnnounce))
            {
                CPrintToChatAll(DEMOCHECK_TAG ... "%t", "kicked_announce_disabled", sName);
                CPrintToChat(client, DEMOCHECK_TAG ... "%t", "ds_autodelete 1");
            }
        } else {
            CreateTimer(2.0, Timer_KickClient, client);
            CPrintToChatAll(DEMOCHECK_TAG ... "%t", "kicked_announce", sName);
        }
    }
    else
    {
        // Expected, show nothing
    }
}

public void Log_Incident(int client, bool warn, char[] failType)
{  
    char sName[64];
    char sSteamID[64];
    char sProfileURL[64];
    GetClientName(client, sName, sizeof(sName));
    bool success = GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
    bool success2 = GetClientAuthId(client, AuthId_SteamID64, sProfileURL, sizeof(sProfileURL));
    if (success == false || success2 == false)
    {
        // log to error console that we couldn't get the client's auth id.
        if (strcmp(sSteamID, "STEAM_ID_STOP_IGNORING_RETVALS") == 0) // they are the same string
        {
            PrintToServer("[Demo Check] Hey Sourcemod, do you mind not being a dick?");
        }
        ThrowError("[Demo Check] %t", "plugin_authid_failed", sName, sSteamID);
        // Execution stops here, but we return anyway just to be sure
        return;
    }
    Format(sProfileURL, sizeof(sProfileURL), "https://steamcommunity.com/profiles/%s", sProfileURL);
    GetClientName(client, sName, sizeof(sName));
    char sMsg[512];
    if (warn)
    {
        Format(sMsg, sizeof(sMsg), "[Demo Check] %t", "logs_democheck", sName, sSteamID, sProfileURL, failType);
    }
    else
    {
        Format(sMsg, sizeof(sMsg), "[Demo Check] (Warn) %t", "logs_democheck_warn",sName, sSteamID, sProfileURL, failType);
    }
    LogToGame(sMsg)
}

public Action Timer_KickClient(Handle timer, int client)
{
    if (!IsClientInGame(client) && !IsFakeClient(client))
    {
        return Plugin_Stop;
    }

    KickClient(client, "[Demo Check] %t", "kicked");
    return Plugin_Stop;
}

public void Event_TournamentStateUpdate(Handle event, const char[] name, bool dontBroadcast)
{
    // significantly more robust way of getting team ready status
    // the != 0 converts the result to a bool
    teamReadyState[RED] = GameRules_GetProp("m_bTeamReady", 1, 2) != 0;
    teamReadyState[BLU] = GameRules_GetProp("m_bTeamReady", 1, 3) != 0;

    // If both teams are ready, StopPregaming.
    if (teamReadyState[RED] && teamReadyState[BLU])
    {
        StopPregaming();
    }
    // don't start deathmatching again if we're already pregame!
    else if (!pregame)
    {
        // One or more of the teams isn't ready, StartPregaming.
        StartPregaming();
    }
    else
    {
        if (GetConVarBool(g_bDemoCheckOnReadyUp))
        {
            for (int i = 1; i <= MaxClients; i++)
            {
                if (IsClientInGame(i) && !IsFakeClient(i))
                {
                    CheckDemoRecording(i);
                }
            }
        }
    }
}

void StopPregaming()
{
    ClearArray(redPlayersReady);
    ClearArray(bluePlayersReady);
    pregame = false;

    if (GetConVarBool(g_bDemoCheckOnReadyUp))
    {
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && !IsFakeClient(i))
            {
                CheckDemoRecording(i);
            }
        }
    }
}

void StartPregaming()
{
    ClearArray(redPlayersReady);
    ClearArray(bluePlayersReady);
    pregame = true;
}

public Action Listener_TournamentPlayerReadystate(int client, const char[] command, int args)
{
    char arg[4];
    int min = GetConVarInt(g_readymode_min);
    int clientid = GetClientUserId(client);
    int clientTeam = GetClientTeam(client);

    GetCmdArg(1, arg, sizeof(arg));
    if (StrEqual(arg, "1"))
    {
        if (clientTeam - TEAM_OFFSET == 0)
        {
            PushArrayCell(redPlayersReady, clientid);
        }
        else if (clientTeam - TEAM_OFFSET == 1)
        {
            PushArrayCell(bluePlayersReady, clientid);
        }
    }
    else if (StrEqual(arg, "0"))
    {
        if (clientTeam - TEAM_OFFSET == 0)
        {
            RemoveFromArray(redPlayersReady, FindValueInArray(redPlayersReady, clientid));
        }
        else if (clientTeam - TEAM_OFFSET == 1)
        {
            RemoveFromArray(bluePlayersReady, FindValueInArray(bluePlayersReady, clientid));
        }
    }
    if (GetArraySize(redPlayersReady) == min && GetArraySize(bluePlayersReady) == min)
    {
        StopPregaming();
    }

    return Plugin_Continue;
}

public void CheckAndStartTimer()
{
    if (g_iRealPlayerCount > 0 && g_hDemoCheckTimer == INVALID_HANDLE)
    {
        StartDemoCheckTimer();
    }
}

public void CheckAndStopTimer()
{
    if (g_iRealPlayerCount == 0 && g_hDemoCheckTimer != INVALID_HANDLE)
    {
        CloseHandle(g_hDemoCheckTimer);
        g_hDemoCheckTimer = INVALID_HANDLE;
    }
}

public void StartDemoCheckTimer()
{
    g_hDemoCheckTimer = CreateTimer(float_rand(15.0, 30.0), Timer_DemoCheckAll, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_DemoCheckAll(Handle timer)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            CheckDemoRecordingTimer(i);
        }
    }
    return Plugin_Continue;
}

public Action CheckDemoRecordingTimer(int client)
{
    if (!IsClientInGame(client) && !IsFakeClient(client))
    {
        return Plugin_Stop;
    }
    if (!GetConVarBool(g_bDemoCheckEnabled))
    {
        return Plugin_Stop;
    }

    QueryClientConVar(client, "ds_enable", OnDSEnableCheckTimer);
    QueryClientConVar(client, "ds_autodelete", OnDSAutoDeleteCheckTimer);
    return Plugin_Continue;
}

public void OnDSEnableCheckTimer(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] value)
{
    if (StrEqual(value, "3") || StrEqual(value, "2"))
    {
        //Do nothing, this is expected
    }
    else if(StrEqual(value, "1"))
    {
        char sName[64];
        GetClientName(client, sName, sizeof(sName));
        if (!g_bWarnedClientDsEnable[client])
        {
            if (GetConVarBool(g_bDemoCheckAnnounce))
            {
                CPrintToChatAll(DEMOCHECK_TAG ... "%t", "kicked_announce_disabled", sName);
                CPrintToChat(client, DEMOCHECK_TAG ... "%t", "ds_enabled 1");
            }
            Log_Incident(client, GetConVarBool(g_bDemoCheckWarn), "ds_enable");
            PrintToConsole(client, "[Demo Check] %t", "ds_enabled 1");
            PrintToConsole(client, "[Demo Check] %t", "docs");
            g_bWarnedClientDsEnable[client] = true;
        }
        
        if (!GetConVarBool(g_bDemoCheckWarn))
        {
            CreateTimer(2.0, Timer_KickClient, client);
            CPrintToChatAll(DEMOCHECK_TAG ... "%t", "kicked_announce", sName);
        }
    }
    else
    {
        char sName[64];
        GetClientName(client, sName, sizeof(sName));

        if (!g_bWarnedClientDsEnable[client])
        {
            if (GetConVarBool(g_bDemoCheckAnnounce))
            {
                CPrintToChatAll(DEMOCHECK_TAG ... "%t", "kicked_announce_disabled", sName);
                CPrintToChat(client, DEMOCHECK_TAG ... "%t", "ds_enabled 0");
            }
            Log_Incident(client, GetConVarBool(g_bDemoCheckWarn), "ds_enable");
            PrintToConsole(client, "[Demo Check] %t", "ds_enabled 0");
            PrintToConsole(client, "[Demo Check] %t", "docs");
            g_bWarnedClientDsEnable[client] = true;
        }
        
        if (!GetConVarBool(g_bDemoCheckWarn))
        {
            CreateTimer(2.0, Timer_KickClient, client);
            CPrintToChatAll(DEMOCHECK_TAG ... "%t", "kicked_announce", sName);
        }
    }
}

public void OnDSAutoDeleteCheckTimer(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] value)
{
    if (StrEqual(value, "1"))
    {
        char sName[64];
        GetClientName(client, sName, sizeof(sName));

        if (!g_bWarnedClientDsDelete[client])
        {
            if (GetConVarBool(g_bDemoCheckAnnounce))
            {
                CPrintToChatAll(DEMOCHECK_TAG ... "%t", "kicked_announce_disabled", sName);
                CPrintToChat(client, DEMOCHECK_TAG ... "%t", "ds_autodelete 1");
            }
            Log_Incident(client, GetConVarBool(g_bDemoCheckWarn), "ds_autodelete");
            PrintToConsole(client, "[Demo Check] %t", "ds_autodelete 1");
            PrintToConsole(client, "[Demo Check] %t", "docs");
            g_bWarnedClientDsDelete[client] = true;
        }
        
        if (!GetConVarBool(g_bDemoCheckWarn))
        {
            CreateTimer(2.0, Timer_KickClient, client);
            CPrintToChatAll(DEMOCHECK_TAG ... "%t", "kicked_announce", sName);
        }
    }
}

float float_rand(float min, float max)
{
    float scale = GetURandomFloat();    /* [0, 1.0] */
    return min + scale * ( max - min ); /* [min, max] */
}