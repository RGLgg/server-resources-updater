#pragma semicolon 1

#include <sourcemod>
#include <color_literals>
#include <regex>

#define PLUGIN_NAME                 "RGL.gg QoL Tweaks"
#define PLUGIN_VERSION              "1.4.2"

bool:CfgExecuted;
bool:alreadyChanging;
bool:IsSafe;
bool:warnedStv;
isStvDone                           = -1;
stvOn;
formatVal;
slotVal;
curplayers;
Handle:g_hForceChange;
Handle:g_hWarnServ;
Handle:g_hcheckStuff;
Handle:g_hSafeToChangeLevel;

public Plugin:myinfo =
{
    name                            =  PLUGIN_NAME,
    author                          = "Stephanie, Aad",
    description                     = "Adds QoL tweaks for easier competitive server management",
    version                         =  PLUGIN_VERSION,
    url                             = "https://github.com/RGLgg/server-resources-updater"
}

public OnPluginStart()
{
    // creates cvar for antitrolling stuff
    CreateConVar
        (
            "rgl_cast",
            "0.0",
            "controls antitroll function for casts",
            // notify clients of cvar change
            FCVAR_NOTIFY,
            true,
            0.0,
            true,
            1.0
        );
    // hooks stuff for auto changelevel
    HookConVarChange(FindConVar("rgl_cast"), OnRGLChanged);
    HookConVarChange(FindConVar("tv_enable"), OnSTVChanged);
    HookConVarChange(FindConVar("servercfgfile"), OnServerCfgChanged);
    AddCommandListener(OnPure, "sv_pure");

    LogMessage("[RGLQoL] Initializing RGLQoL version %s", PLUGIN_VERSION);
    PrintColoredChatAll("\x07FFA07A[RGLQoL]\x01 version \x07FFA07A%s\x01 has been \x073EFF3Eloaded\x01.", PLUGIN_VERSION);
    // hooks round start events
    HookEvent("teamplay_round_start", EventRoundStart);
    
    // Win conditions met (maxrounds, timelimit)
    HookEvent("teamplay_game_over", GameOverEvent);
    // Win conditions met (windifference)
    HookEvent("tf_game_over", GameOverEvent);

    RegServerCmd("changelevel", changeLvl);
}

public OnMapStart()
{
    delete g_hForceChange;
    delete g_hWarnServ;
    delete g_hSafeToChangeLevel;
    alreadyChanging = false;
    // this is to prevent server auto changing level
    ServerCommand("sm plugins unload nextmap");
    ServerCommand("sm plugins unload mapchooser");
    // this is to unload waitforstv which can break 5cp matches
    ServerCommand("sm plugins unload waitforstv");
}


public Action EventRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
    AntiTrollStuff();
    // prevents stv done notif spam if teams play another round before 90 seconds have passed
    delete g_hSafeToChangeLevel;
}

// checks stuff for restarting server
public Action checkStuff(Handle timer)
{
    // using tv_enable value here would be inaccurate if stv hasn't joined yet
    char tvStatusOut[512];
    ServerCommandEx(tvStatusOut, sizeof(tvStatusOut), "tv_status");
    if (StrContains(tvStatusOut, "SourceTV not active") != -1)
    {
        stvOn = 0;
    }
    else
    {
        stvOn = 1;
    }
    curplayers = GetClientCount() - stvOn;
    LogMessage("[RGLQoL] %i players on server.", curplayers);
    char cfgVal[128];
    GetConVarString(FindConVar("servercfgfile"), cfgVal, sizeof(cfgVal));
    if (StrContains(cfgVal, "rgl") != -1)
    {
        CfgExecuted = true;
    }
    else
    {
        CfgExecuted = false;
    }
    // if the server isnt empty, don't restart!
    if (curplayers > 0)
    {
        LogMessage("[RGLQoL] At least 1 player on server. Not restarting.");
        return;
    }
    else if (!CfgExecuted)
    // if the rgl isnt exec'd dont restart.
    {
        LogMessage("[RGLQoL] RGL config not executed. Not restarting.");
        return;
    }
    // if the stv hasnt ended aka if the GAME hasn't ended + 90 seconds, don't restart. If isStvDone is -1 or 1 then it's ok.
    else if (isStvDone == 0)
    {
        LogMessage("[RGLQoL] STV is currently live! Not restarting.");
        return;
    }
}

public OnRGLChanged(ConVar convar, char[] oldValue, char[] newValue)
{
    if (StringToInt(newValue) == 1)
    {
        AntiTrollStuff();
    }
    else if (StringToInt(newValue) == 0)
    {
        // zeros reserved slots value
        SetConVarInt(FindConVar("sm_reserved_slots"), 0, true);
        // unloads reserved slots
        ServerCommand("sm plugins unload reservedslots");
        // unloads reserved slots in case its in the disabled folder
        ServerCommand("sm plugins unload disabled/reservedslots");
        // resets visible slots
        SetConVarInt(FindConVar("sv_visiblemaxplayers"), -1, true);
        LogMessage("[RGLQoL] Cast AntiTroll has been turned off!");
    }
}

// this section was influenced by f2's broken FixSTV plugin
public OnSTVChanged(ConVar convar, char[] oldValue, char[] newValue)
{
    if (StringToInt(newValue) == 1)
    {
        LogMessage("[RGLQoL] tv_enable changed to 1! Changing level in 30 seconds unless manual map change occurs before then.");
        change15();
    }
    else if (StringToInt(newValue) == 0)
    {
        LogMessage("[RGLQoL] tv_enable changed to 0!");
    }
}

public OnServerCfgChanged(ConVar convar, char[] oldValue, char[] newValue)
{
    // if cfg changes, then update tv_maxclients to 5
    if (GetConVarInt(FindConVar("tv_maxclients")) == 128)
    {
        SetConVarInt(FindConVar("tv_maxclients"), 5);
    }

    SetDefaultWhitelist();
    AntiTrollStuff();
}

public SetDefaultWhitelist() 
{
    // check to see if tftrue exists, and if it fails to load after a tf2 update use default mp_tournament_whitelist
    if(FileExists("addons/TFTrue.vdf")) 
    {
        if (FindConVar("tftrue_version") != INVALID_HANDLE) 
        {
            LogMessage("[RGLQoL] TFTrue exists but is not loaded, may be broken. Using default mp_tournament_whitelist value instead.");

            char cfgVal[128];
            GetConVarString(FindConVar("servercfgfile"), cfgVal, 128);

            if (StrContains(cfgVal, "6s", false) != -1) 
            {
                ServerCommand("exec mp_tournament_whitelist rgl_whitelist_6s.txt");
            }
            else if (StrContains(cfgVal, "mm", false) != -1) 
            {
                ServerCommand("exec mp_tournament_whitelist rgl_whitelist_mm.txt");
            }
            else if (StrContains(cfgVal, "HL", false) != -1) 
            {
                ServerCommand("exec mp_tournament_whitelist rgl_whitelist_HL.txt");
            }
            else if (StrContains(cfgVal, "7s", false) != -1) 
            {
                ServerCommand("exec mp_tournament_whitelist rgl_whitelist_7s.txt");
            }
        } else {
            LogMessage("[RGLQoL] TFTrue exists and is functional");
        }
    }
}

// pure checking code
public Action OnPure(int client, const char[] command, int argc)
{
    if (argc > 0)
    {
        RequestFrame(InvokePureCommandCheck);
    }
    return Plugin_Continue;
}

public void InvokePureCommandCheck(any ignored)
{
    char pureOut[512];
    ServerCommandEx(pureOut, sizeof(pureOut), "sv_pure");
    if (StrContains(pureOut, "changelevel") != -1)
    {
        LogMessage("[RGLQoL] sv_pure cvar changed! Changing level in 30 seconds unless manual map change occurs before then.");
        change15();
    }
}

public change15()
{
    if (!alreadyChanging)
    {
        g_hWarnServ = CreateTimer(5.0, WarnServ, TIMER_FLAG_NO_MAPCHANGE);
        g_hForceChange = CreateTimer(15.0, ForceChange, TIMER_FLAG_NO_MAPCHANGE);
        alreadyChanging = true;
    }
}

public Action GameOverEvent(Handle event, const char[] name, bool dontBroadcast)
{
    isStvDone = 0;
    PrintColoredChatAll("\x07FFA07A[RGLQoL]\x01 Match ended. Wait 90 seconds to changelevel to avoid cutting off actively broadcasting STV. This can be overridden with a second changelevel command.");
    g_hSafeToChangeLevel = CreateTimer(95.0, SafeToChangeLevel, TIMER_FLAG_NO_MAPCHANGE);
    // this is to prevent server auto changing level
    CreateTimer(5.0, unloadMapChooserNextMap);

    // create a repeating timer for auto restart, checks every 10 minutes if players have left server and autorestarts if so
    // we put it on a gameover event because it assures that the server can't get restarted unless a gameover event occurs at least once
    if (g_hcheckStuff == null)
    {
        g_hcheckStuff = CreateTimer(600.0, checkStuff, _, TIMER_REPEAT);
    }
}

public Action unloadMapChooserNextMap(Handle timer)
{
    ServerCommand("sm plugins unload nextmap");
    ServerCommand("sm plugins unload mapchooser");
}

public Action WarnServ(Handle timer)
{
    LogMessage("[RGLQoL] An important cvar has changed. Forcing a map change in 25 seconds unless the map is manually changed before then.");
    PrintColoredChatAll("\x07FFA07A[RGLQoL]\x01 An important cvar has changed. Forcing a map change in 25 seconds unless the map is manually changed before then.");
    g_hWarnServ = null;
}

public Action SafeToChangeLevel(Handle timer)
{
    isStvDone = 1;
    if (!IsSafe)
    {
        PrintColoredChatAll("\x07FFA07A[RGLQoL]\x01 STV finished. It is now safe to changelevel.");
        // this is to prevent double printing
        IsSafe = true;
    }
    g_hSafeToChangeLevel = null;
}

public Action changeLvl(int args)
{
    if (warnedStv || isStvDone != 0)
    {
        return Plugin_Continue;
    }
    else
    {
        PrintToServer("*** Refusing to changelevel! STV is still broadcasting. If you don't care about STV, changelevel again to override this message and force a map change. ***");
        warnedStv = true;
        ServerCommand("tv_delaymapchange 0");
        ServerCommand("tv_delaymapchange_protect 0");
        return Plugin_Stop;
    }
}

public Action ForceChange(Handle timer)
{
    LogMessage("[RGLQoL] Forcibly changing level.");
    char mapName[128];
    GetCurrentMap(mapName, sizeof(mapName));
    ForceChangeLevel(mapName, "Important cvar changed! Forcibly changing level to prevent bugs.");
    g_hForceChange = null;
}

public AntiTrollStuff()
{
    if (!GetConVarBool(FindConVar("rgl_cast")))
    {
        LogMessage("[RGLQoL] Cast AntiTroll is OFF!");
        return;
    }
    else
    {
        // ANTI TROLLING STUFF (prevents extra users from joining the server, used for casts and also matches if you want to)
        char cfgVal[128];
        GetConVarString(FindConVar("servercfgfile"), cfgVal, 128);
        if ((StrContains(cfgVal, "6s", false) != -1) ||
            (StrContains(cfgVal, "mm", false) != -1))
        {
            formatVal = 12;
        }
        else if (StrContains(cfgVal, "HL", false) != -1)
        {
            formatVal = 18;
        }
        else if (StrContains(cfgVal, "7s", false) != -1)
        {
            formatVal = 14;
        }
        else
        {
            formatVal = 0;
            LogMessage("[RGLQoL] Config not executed! Cast AntiTroll is OFF!");
        }
        if (formatVal != 0)
        {
            // this calculates reserved slots to leave just enough space for 12/12, 14/14 or 18/18 players on server
            slotVal = ((MaxClients - formatVal) - 1);
            // loads reserved slots because it gets unloaded by soap tournament (thanks lange... -_-)
            ServerCommand("sm plugins load reservedslots");
            // loads it from disabled/ just in case it's disabled by the server owner
            ServerCommand("sm plugins load disabled/reservedslots");
            // set type 0 so as to not kick anyone ever
            SetConVarInt(FindConVar("sm_reserve_type"), 0, true);
            // hide slots is broken with stv so disable it
            SetConVarInt(FindConVar("sm_hide_slots"), 0, true);
            // sets reserved slots with above calculated value
            SetConVarInt(FindConVar("sm_reserved_slots"), slotVal, true);
            // manually override this because hide slots is broken
            SetConVarInt(FindConVar("sv_visiblemaxplayers"), formatVal, true);
            // players can still join if they have password and connect thru console but they will be instantly kicked due to the slot reservation we just made
            // obviously this can go wrong if there's an collaborative effort by a player and a troll where the player leaves, and the troll joins in their place...
            // ...but if that's happening the players involved will almost certainly face severe punishments and a probable league ban.
            LogMessage("[RGLQoL] Cast AntiTroll is ON!");
        }
    }
}

public OnPluginEnd()
{
    PrintColoredChatAll("\x07FFA07A[RGLQoL]\x01 version \x07FFA07A%s\x01 has been \x07FF4040unloaded\x01.", PLUGIN_VERSION);
}
