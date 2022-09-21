#pragma semicolon 1

#include <sourcemod>
#include <updater>
#include <color_literals>

#define REQUIRE_EXTENSIONS
#include <SteamWorks>

#define PLUGIN_NAME                   "RGL.gg Server Resources Updater"
#define PLUGIN_VERSION                "2.0.2"
char UPDATE_URL[128]                = "";
bool:updatePlug;

public Plugin:myinfo =
{
    name                            =  PLUGIN_NAME,
    author                          = "Stephanie, Aad",
    description                     = "Automatically updates RGL.gg plugins and files",
    version                         =  PLUGIN_VERSION,
    url                             = "https://github.com/RGLgg/server-resources-updater"
}

public OnPluginStart()
{
    DisablePlugin("roundtimer_override");
    LogMessage("[RGLUpdater] version %s has been loaded.", PLUGIN_VERSION);
    PrintColoredChatAll("\x07FFA07A[RGLUpdater]\x01 version \x07FFA07A%s\x01 has been \x073EFF3Eloaded\x01.", PLUGIN_VERSION);
    updatePlug = false;
    CreateConVar
        (
            "rgl_beta",
            "0.0",
            "controls if rglupdater uses the beta branch on github",
            // notify clients of cvar change
            FCVAR_NOTIFY,
            true,
            0.0,
            true,
            1.0
        );
    HookConVarChange(FindConVar("rgl_beta"), OnRGLBetaChanged);
    CheckRGLBeta();
    
}

public DisablePlugin(const String:plugin_file[])
{
    // Thanks to DarthNinja's Plugin Enable/Disable
    new String:disabledpath[256], String:enabledpath[256];
    
    BuildPath(Path_SM, disabledpath, sizeof(disabledpath), "plugins/disabled/%s.smx", plugin_file);	
    BuildPath(Path_SM, enabledpath, sizeof(enabledpath), "plugins/%s.smx", plugin_file);	
    new String:PluginWExt[70];
	Format(PluginWExt, sizeof(PluginWExt), "%s.smx", plugin_file);
    
    if (!FileExists(enabledpath))
    {
        LogMessage("[RGLUpdater] The plugin file could not be found.");
        return Plugin_Handled;
    }

    if (FileExists(disabledpath))
    {
        LogMessage("[RGLUpdater] An existing plugin file (%s) has been detected that conflicts with the one being moved. No action has been taken.", disabledpath);
        return Plugin_Handled;
    }
    
    new Handle:Loaded = FindPluginByFile(PluginWExt);
    new String:PluginName[128];
    if (Loaded != INVALID_HANDLE)
        GetPluginInfo(Loaded, PlInfo_Name, PluginName, sizeof(PluginName));
    else
        strcopy(PluginName, sizeof(PluginName), PluginWExt);
    ServerCommand("sm plugins unload %s", plugin_file);
    RenameFile(disabledpath, enabledpath);
    
    LogMessage("[RGLUpdater] The plugin '%s' has been unloaded and moved to the /disabled/ directory.", PluginName);
    return true;
}

public OnLibraryAdded(const String:name[])
{
    if (StrEqual(name, "updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
}

public OnRGLBetaChanged(ConVar convar, char[] oldValue, char[] newValue)
{
    LogMessage("[RGLUpdater] rgl_beta cvar changed!");
    CheckRGLBeta();
    LogMessage("[RGLUpdater] QUEUING UPDATE");
    Updater_AddPlugin(UPDATE_URL);
    Updater_ForceUpdate();
    updatePlug = true;
}

public OnClientPostAdminCheck(client)
{
    char cfgVal[128];
    GetConVarString(FindConVar("servercfgfile"), cfgVal, sizeof(cfgVal));
    if (StrContains(cfgVal, "rgl") != -1)
    {
        CreateTimer(15.0, prWelcomeClient, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
    
}

public Action prWelcomeClient(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (client)
    {
        PrintColoredChat(client, "\x07FFA07A[RGLUpdater]\x01 This server is running RGL Updater version \x07FFA07A%s\x01", PLUGIN_VERSION);
        PrintColoredChat(client, "\x07FFA07A[RGLUpdater]\x01 Remember, per RGL rules, players must record POV demos for every match!");
    }
}

CheckRGLBeta()
{
    if (!GetConVarBool(FindConVar("rgl_beta")))
    {
        UPDATE_URL = "https://raw.githubusercontent.com/RGLgg/server-resources-updater/updater/updatefile.txt";
        LogMessage("[RGLUpdater] rgl_beta = 0");
        LogMessage("[RGLUpdater] Update url is %s.", UPDATE_URL);
    }
    else if (GetConVarBool(FindConVar("rgl_beta")))
    {
        UPDATE_URL = "https://raw.githubusercontent.com/RGLgg/server-resources-updater/updater-beta/updatefile.txt";
        LogMessage("[RGLUpdater] rgl_beta = 1");
        LogMessage("[RGLUpdater] Update url is %s.", UPDATE_URL);
    }
}

public Updater_OnPluginUpdated()
{
    if (updatePlug)
    {
        CreateTimer(5.0, reloadPlug);
    }
}

public Action reloadPlug(Handle timer)
{
    ServerCommand("sm plugins reload disabled/tf2Halftime");
    ServerCommand("sm plugins reload pause");
    ServerCommand("sm plugins reload rglqol");
    ServerCommand("sm plugins reload rglupdater");
}

public void OnPluginEnd()
{
    LogMessage("[RGLUpdater] version %s has been unloaded.", PLUGIN_VERSION);
    PrintColoredChatAll("\x07FFA07A[RGLUpdater]\x01 version \x07FFA07A%s\x01 has been \x07FF4040unloaded\x01.", PLUGIN_VERSION);
}
