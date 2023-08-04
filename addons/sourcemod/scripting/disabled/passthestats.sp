#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>

//adding support for maps other than arena2
#define PLUGIN_VERSION        "1.6.0"
#define NAME_SIZE 25

public Plugin myinfo = {
    name = "[TF2] Pass the Stats",
    author = "easye",
    description = "Stats for Competitve 4v4 Passtime",
    version = "PLUGIN_VERSION",
    url="https://github.com/eaasye/passtime"
}


//playerArray: 0 = scores, saves = 1, 2 = interceptions, 3 = steals
int playerArray[MAXPLAYERS][4];
float bluGoal[3], redGoal[3];
ConVar statsEnable, statsDelay, saveRadius;


public void OnPluginStart() {
    statsEnable = CreateConVar("sm_passtime_stats", "1", "Enables passtime stats")
    statsDelay = CreateConVar("sm_passtime_stats_delay", "7.5", "Delay for passtime stats to be displayed after a game is won")
    saveRadius = CreateConVar("sm_passtime_stats_save_radius", "200", "The Radius in hammer units from the goal that an intercept is considered a save")
    CreateConVar("sm_passthestats_version", PLUGIN_VERSION, "*DONT MANUALLY CHANGE* PassTheStats Plugin Version", FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_SPONLY);
    char mapName[64], prefix[16];
    GetCurrentMap(mapName, sizeof(mapName));
    prefix[0] = mapName[0], prefix[1] = mapName[1];
    if 
        (StrEqual("pa", prefix)) statsEnable.SetInt(1);
    else 
        statsEnable.SetInt(0);
    
    HookEvent("teamplay_round_win", Event_TeamWin, EventHookMode_Post);
    HookEvent("pass_score", Event_PassScore, EventHookMode_Post);
    HookEvent("pass_pass_caught", Event_PassCaught, EventHookMode_Post);
    HookEvent("pass_ball_stolen", Event_PassStolen, EventHookMode_Post);
}

public void OnMapStart() {
    GetGoalLocations();
}

public void OnClientDisconnect(int client) {
    playerArray[client][0] = 0, playerArray[client][1] = 0, playerArray[client][2] = 0, playerArray[client][3] = 0;
}


public Action Event_PassScore(Event event, const char[] name, bool dontbroadcast) {
    if (!statsEnable.BoolValue) return Plugin_Handled;

    int client = event.GetInt("scorer")
    if (!IsValidClient(client)) return Plugin_Handled;
    char playerName[NAME_SIZE];
    GetClientName(client, playerName, sizeof(playerName));
    PrintToChatAll("\x0700ffff[PASS] %s\x073BC43B scored a goal!", playerName);
    playerArray[client][0]++;
    return Plugin_Handled;
}

public Action Event_PassCaught(Event event, const char[] name, bool dontBroadcast) {
    if (!statsEnable.BoolValue) return Plugin_Handled;

    int passer = event.GetInt("passer");
    int catcher = event.GetInt("catcher");
    if (TF2_GetClientTeam(passer) == TF2_GetClientTeam(catcher)) return Plugin_Handled;
    if (TF2_GetClientTeam(passer) == TFTeam_Spectator || TF2_GetClientTeam(catcher) == TFTeam_Spectator) return Plugin_Handled;

    char passerName[NAME_SIZE], catcherName[NAME_SIZE];
    GetClientName(passer, passerName, sizeof(passerName));
    GetClientName(catcher, catcherName, sizeof(catcherName));
    if (InGoalieZone(catcher)) {
        PrintToChatAll("\x0700ffff[PASS] %s \x07ffff00 blocked \x0700ffff%s!", catcherName, passerName);
        playerArray[catcher][1]++;
    }
    else {
        PrintToChatAll("\x0700ffff[PASS] %s \x07ff00ffintercepted \x0700ffff%s!", catcherName, passerName);
        playerArray[catcher][2]++;
    }

    return Plugin_Handled;    
}

public Action Event_PassStolen(Event event, const char[] name, bool dontBroadcast) {
    if (!statsEnable.BoolValue) return Plugin_Handled;

    int thief = event.GetInt("attacker");
    int victim = event.GetInt("victim");
    char thiefName[NAME_SIZE], victimName[NAME_SIZE];
    GetClientName(thief, thiefName, sizeof(thiefName));
    GetClientName(victim, victimName, sizeof(victimName));
    PrintToChatAll("\x0700ffff[PASS] %s\x07ff8000 stole from\x0700ffff %s!", thiefName, victimName);
    playerArray[thief][3]++;

    return Plugin_Handled;
}

public Action Event_TeamWin(Event event, const char[] name, bool dontBroadcast) {
    if (!statsEnable.BoolValue) return Plugin_Handled;    
    CreateTimer(statsDelay.FloatValue, Timer_DisplayStats)
    return Plugin_Handled;
}

//this is really fucking sloppy but shrug
public Action Timer_DisplayStats(Handle timer) {
    int redTeam[16], bluTeam[16];
    int redCursor, bluCursor = 0;
    for (int x=1; x < MaxClients+1; x++) {
        if (!IsValidClient(x)) continue;

        if (TF2_GetClientTeam(x) == TFTeam_Red) {
            redTeam[redCursor] = x;
            redCursor++;
        }

        else if (TF2_GetClientTeam(x) == TFTeam_Blue) {
            bluTeam[bluCursor] = x;
            bluCursor++;
        }
    }
    for (int x=1; x < MaxClients+1; x++) {
        if (!IsValidClient2(x)) continue;
        
        if (TF2_GetClientTeam(x) == TFTeam_Red) {
            for (int i=0; i < bluCursor; i++) {
                char playerName[NAME_SIZE];
                GetClientName(bluTeam[i], playerName, sizeof(playerName))
                PrintToChat(x, "\x0700ffff[PASS]\x074EA6C1 %s:\x073BC43B goals %d,\x07ffff00 saves %d,\x07ff00ff intercepts %d,\x07ff8000 steals %d", playerName, playerArray[bluTeam[i]][0], playerArray[bluTeam[i]][1], playerArray[bluTeam[i]][2], playerArray[bluTeam[i]][3])
            }

            for (int i=0; i < redCursor; i++) {
                char playerName[NAME_SIZE];
                GetClientName(redTeam[i], playerName, sizeof(playerName))
                PrintToChat(x, "\x0700ffff[PASS]\x07C43F3B %s:\x073BC43B goals %d,\x07ffff00 saves %d,\x07ff00ff intercepts %d,\x07ff8000 steals %d", playerName, playerArray[redTeam[i]][0], playerArray[redTeam[i]][1], playerArray[redTeam[i]][2], playerArray[redTeam[i]][3])
            }
        }

        else if (TF2_GetClientTeam(x) == TFTeam_Blue|| TF2_GetClientTeam(x) == TFTeam_Spectator) {
            for (int i=0; i < redCursor; i++) {
                                 char playerName[NAME_SIZE];
                                 GetClientName(redTeam[i], playerName, sizeof(playerName))
                                 PrintToChat(x, "\x0700ffff[PASS]\x07C43F3B %s:\x073BC43B goals %d,\x07ffff00 saves %d,\x07ff00ff intercepts %d,\x07ff8000 steals %d", playerName, playerArray[redTeam[i]][0], playerArray[redTeam[i]][1], playerArray[redTeam[i]][2], playerArray[redTeam[i]][3])
                         }

            for (int i=0; i < bluCursor; i++) {
                char playerName[NAME_SIZE];
                GetClientName(bluTeam[i], playerName, sizeof(playerName))
                PrintToChat(x, "\x0700ffff[PASS]\x074EA6C1 %s:\x073BC43B goals %d,\x07ffff00 saves %d,\x07ff00ff intercepts %d,\x07ff8000 steals %d", playerName, playerArray[bluTeam[i]][0], playerArray[bluTeam[i]][1], playerArray[bluTeam[i]][2], playerArray[bluTeam[i]][3])
            }

        }
    }

    //clear stats
    for (int i=0; i < MaxClients+1;i++) {
        playerArray[i][0] = 0, playerArray[i][1] = 0, playerArray[i][2] = 0, playerArray[i][3] = 0;
    }
    return Plugin_Continue;
}

public bool InGoalieZone(int client) {
    int team = GetClientTeam(client);
    float position[3];
    GetClientAbsOrigin(client, position);
    
    if (team == view_as<int>(TFTeam_Blue)) {
        float distance = GetVectorDistance(position, bluGoal, false);
        if (distance < saveRadius.FloatValue) return true;
    }

    if (team == view_as<int>(TFTeam_Red)) {
        float distance = GetVectorDistance(position, redGoal, false);
        if (distance < saveRadius.FloatValue) return true;
    }

    return false;
}

public void GetGoalLocations() {
    int goal1 = FindEntityByClassname(-1, "func_passtime_goal");
    int goal2 = FindEntityByClassname(goal1, "func_passtime_goal");
    int team1 = GetEntProp(goal1, Prop_Send, "m_iTeamNum");
    if (team1 == 2) {
        GetEntPropVector(goal1, Prop_Send, "m_vecOrigin", bluGoal);
        GetEntPropVector(goal2, Prop_Send, "m_vecOrigin", redGoal);
    }
    else {
        GetEntPropVector(goal2, Prop_Send, "m_vecOrigin", bluGoal);
        GetEntPropVector(goal1, Prop_Send, "m_vecOrigin", redGoal);
    }
}

//i have two of these because i have no friends so i test with robots
public bool IsValidClient(int client) {
    if (client > 4096) client = EntRefToEntIndex(client);
    if (client < 1 || client > MaxClients) return false;
    if (!IsClientInGame(client)) return false;
    //if (IsFakeClient(client)) return false;
    if (GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
    return true;
}

public bool IsValidClient2(int client) {
    if (client > 4096) client = EntRefToEntIndex(client);
    if (client < 1 || client > MaxClients) return false;
    if (!IsClientInGame(client)) return false;
    if (IsFakeClient(client)) return false;
    if (GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
    return true;
}