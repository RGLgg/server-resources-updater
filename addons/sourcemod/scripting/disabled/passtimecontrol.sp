#include <sourcemod>
#include <tf2_stocks>


#define PLUGIN_VERSION  "1.4.0"

bool deadPlayers[MAXPLAYERS + 1];
//0 = hud text, 1 = chat, 2 = sound
bool ballHudEnabled[MAXPLAYERS + 1][3];

ConVar stockEnable, respawnEnable, clearHud, collisionDisable;

Menu ballHudMenu;

public Plugin myinfo = {
    name = "[TF2] PasstimeControl",
    author = "EasyE",
    description = "Intended for 4v4 Competitive Passtime use. Can prevent players from using shotgun, stickies, and needles. Can disable the screenoverlay blur effect after intercepting or stealing the jack.",
    version = PLUGIN_VERSION,
    url = "https://github.com/eaasye/passtime"
}

public void OnPluginStart() {
    RegConsoleCmd("sm_ballhud", Command_BallHud);
    
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
    HookEvent("post_inventory_application", Event_PlayerResup, EventHookMode_Post);
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
    HookEvent("pass_get", Event_PassGet, EventHookMode_Post);
    HookEvent("pass_free", Event_PassFree, EventHookMode_Post);
    HookEvent("pass_ball_stolen", Event_PassStolen, EventHookMode_Post);
    HookEntityOutput("info_passtime_ball_spawn", "OnSpawnBall", Hook_OnSpawnBall)
    AddCommandListener(OnChangeClass, "joinclass");

    stockEnable = CreateConVar("sm_passtime_whitelist", "0", "Enables/Disables passtime stock weapon locking");
    respawnEnable = CreateConVar("sm_passtime_respawn", "0", "Enables/disables fixed respawn time");
    clearHud = CreateConVar("sm_passtime_hud", "1", "Enables/Disables blocking the blur effect after intercepting or stealing the ball");
    collisionDisable = CreateConVar("sm_passtime_collision_disable", "0", "Enables/Disables the passtime jack from colliding with ammopacks or weapons");
    CreateConVar("sm_passtimecontrol_version", PLUGIN_VERSION, "*DONT MANUALLY CHANGE* Passtime-Control Plugin Version", FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_SPONLY);
    
    ballHudMenu = new Menu(BallHudMenuHandler);
    ballHudMenu.SetTitle("Jack Notifcations");
    ballHudMenu.AddItem("hudtext", "Toggle hud notifcation");
    ballHudMenu.AddItem("chattext", "Toggle chat notifcation");
    ballHudMenu.AddItem("sound", "Toggle sound notification");
}

public void OnClientDisconnect(int client) {
    deadPlayers[client] = false;
    ballHudEnabled[client][0] = false;
    ballHudEnabled[client][1] = false;
    ballHudEnabled[client][2] = false;
}

public void TF2_OnConditionAdded(int client, TFCond condition) {
    if (condition == TFCond_PasstimeInterception && clearHud.BoolValue) {
        ClientCommand(client, "r_screenoverlay \"\"");
    }
}

public Action Command_BallHud(int client, int args) {
    if (IsValidClient(client)) ballHudMenu.Display(client, MENU_TIME_FOREVER);
    return Plugin_Handled;
}

public int BallHudMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        char info[32];
        char status[64];
        ballHudMenu.GetItem(param2, info, sizeof(info));
        if (StrEqual(info, "hudtext")) {
            ballHudEnabled[param1][0] = !ballHudEnabled[param1][0];
            ballHudMenu.Display(param1, MENU_TIME_FOREVER);
            
            Format(status, sizeof(status), "\x0700ffff[PASS]\x01 Hud text: %s", ballHudEnabled[param1][0] ? "\x0700ff00Enabled" : "\x07ff0000Disabled");
            PrintToChat(param1, status);
        }
        if (StrEqual(info, "chattext")) {
            ballHudEnabled[param1][1] = !ballHudEnabled[param1][1];
            ballHudMenu.Display(param1, MENU_TIME_FOREVER);

            Format(status, sizeof(status), "\x0700ffff[PASS]\x01 Chat text: %s", ballHudEnabled[param1][1] ? "\x0700ff00Enabled" : "\x07ff0000Disabled");
            PrintToChat(param1, status);

        }
        if (StrEqual(info, "sound")) {
            ballHudEnabled[param1][2] = !ballHudEnabled[param1][2];
            ballHudMenu.Display(param1, MENU_TIME_FOREVER);

            Format(status, sizeof(status), "\x0700ffff[PASS]\x01 Sound notification: %s", ballHudEnabled[param1][2] ? "\x0700ff00Enabled" : "\x07ff0000Disabled");
            PrintToChat(param1, status);     
        }
    }
    return 0;
}

/* ---EVENTS--- */

public Action Event_PassFree(Event event, const char[] name, bool dontBroadcast) {
    int owner = event.GetInt("owner")
    if (ballHudEnabled[owner][0]) {
        SetHudTextParams(-1.0, 0.22, 3.0, 240, 0, 240, 255);
        ShowHudText(owner, 1, "");
    }
    return Plugin_Continue;
}

public Action Event_PassGet(Event event, const char[] name, bool dontBroadcast) {
    int owner = event.GetInt("owner");
    if (ballHudEnabled[owner][0]) {
        SetHudTextParams(-1.0, 0.22, 3.0, 240, 0, 240, 255);
        ShowHudText(owner, 1, "YOU HAVE THE JACK");
    }
    
    if (ballHudEnabled[owner][1]) {
        PrintToChat(owner, "\x07ffff00[PASS]\x0700ff00 YOU HAVE THE JACK!!!");
    }
    
    if (ballHudEnabled[owner][2]) {
        ClientCommand(owner, "playgamesound Passtime.BallSmack");
    }
    return Plugin_Continue;
}

public Action Event_PassStolen(Event event, const char[] name, bool dontBroadcast) {
    int owner = event.GetInt("victim");
    if (ballHudEnabled[owner][0]) {
        SetHudTextParams(-1.0, 0.22, 3.0, 240, 0, 240, 255);
        ShowHudText(owner, 1, "");
    }
    return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(GetEventInt(event, "userid"))
    deadPlayers[client] = true;
    return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(GetEventInt(event, "userid"))
    deadPlayers[client] = false;
    RemoveShotty(client);
    return Plugin_Continue;
}

public Action Event_PlayerResup(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(GetEventInt(event, "userid"))
    RemoveShotty(client);
    return Plugin_Continue;
}

public Action OnChangeClass(int client, const char[] strCommand, int args) {
    if(deadPlayers[client] == true && respawnEnable.BoolValue) {
        PrintCenterText(client, "You cant change class yet.");
        return Plugin_Handled;
    }
        
    return Plugin_Continue;
}

public void Hook_OnSpawnBall(const char[] name, int caller, int activator, float delay) {
    int ball = FindEntityByClassname(-1, "passtime_ball");
    if(collisionDisable.BoolValue) SetEntityCollisionGroup(ball, 4);
}

/* ---FUNCTIONS--- */

public void RemoveShotty(int client) {
    if(stockEnable.BoolValue) {
        TFClassType class = TF2_GetPlayerClass(client);
        int iWep;
        if (class == TFClass_DemoMan || class == TFClass_Soldier) iWep = GetPlayerWeaponSlot(client, 1)
        else if (class == TFClass_Medic) iWep = GetPlayerWeaponSlot(client, 0);

        if(iWep >= 0) {
            char classname[64];
            GetEntityClassname(iWep, classname, sizeof(classname));
            
            if (StrEqual(classname, "tf_weapon_shotgun_soldier") || StrEqual(classname, "tf_weapon_pipebomblauncher")) {
                PrintToChat(client, "\x07ff0000 [PASS] Shotgun/Stickies equipped");
                TF2_RemoveWeaponSlot(client, 1);
            }

            if (StrEqual(classname, "tf_weapon_syringegun_medic")) {
                PrintToChat(client, "\x07ff0000 [PASS] Syringe Gun equipped");
                TF2_RemoveWeaponSlot(client, 0);
            }

        }
    }
}

public bool IsValidClient(int client) {
    if (client > 4096) client = EntRefToEntIndex(client);
    if (client < 1 || client > MaxClients) return false;
    if (!IsClientInGame(client)) return false;
    if (IsFakeClient(client)) return false;
    if (GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
    return true;
}