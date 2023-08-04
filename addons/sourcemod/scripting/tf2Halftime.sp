#pragma semicolon 1                 // enables strict semicolon mode
#pragma newdecls required           // force newdecls

#include <sourcemod>
#include <morecolors>

#pragma newdecls required           // force newdecls again because SourceMod(tm)


#define PLUGIN_VERSION  "1.5.1"

public Plugin myinfo = {
    name                            = "basic halftime for 5cp and koth",
    author                          = "stephanie",
    description                     = "emulates esea style halves for 5cp and koth maps",
    version                         =  PLUGIN_VERSION,
    url                             = "https://sappho.io"
};

int bluRnds;                        // blu round int created here
int redRnds;                        // blu round int created here
bool isHalf2;                       // bool value for determining halftime created here
char mapName[128];                  // holds map name value to then later check against for determining map type
int half1Limit;                     // int for determining winlimit for half 1
int totalWinLimit;                  // int for determining total winlimit b4 resetting tourney
bool tourneyRestart;                // bool value for determining if we should restart the tournament on the next round start
char staleReason[32];               // why did a stalemate happen?
int HalfStale;                      // if a stalemate happened, was it due to a natural server timelimit being reached, or the winlimit being reached?
bool gameIsLive;                    // is the game live yet? set on round end events

public void OnPluginStart()
{
    MC_PrintToChatAll("{mediumpurple}[tf2Halftime] {white}has been {green}loaded{default}.");
    HookEvent("teamplay_game_over", EventGameOver);                 // hooks game over events
    HookEvent("teamplay_round_win", EventRoundEnd);                 // hooks round win events
    HookEvent("teamplay_round_start", EventRoundStart);             // hooks round start events
    SetConVarInt(FindConVar("mp_winlimit"), 0, true);               // finds and sets winlimit to 0, as this plugin handles it instead
    //SetConVarInt(FindConVar("mp_tournament_readymode"), 1, true);   // sets readymode to per player
    // ^ OUTSIDE OF SCOPE & VERY BUGGY!
}

public void OnMapStart()
{
    GetCurrentMap(mapName, sizeof(mapName));        // checks for current map name
    if (strncmp(mapName, "cp_", 3) == 0)            // checks if it's cp...
    {
        half1Limit = 3;
        totalWinLimit = 5;
    }
    else if (strncmp(mapName, "koth_", 5) == 0)     // koth...
    {
        half1Limit = 2;
        totalWinLimit = 4;
    }
    else                                            // or something else.
    {
        half1Limit = 0;
        totalWinLimit = 0;
        MC_PrintToChatAll("{mediumpurple}[tf2Halftime] {yellow}Warning!{white} tf2Halftime is somehow running on an unsupported map. Unloading!");
        ServerCommand("sm plugins unload disabled/tf2Halftime");
    }
}

public void OnMapEnd()          // resets score and map specific stored vars on map change, if the plugin somehow doesn't get unloaded and reloaded
{
    bluRnds = 0;                // resets total blu rounds
    redRnds = 0;                // resets total red rounds
    isHalf2 = false;            // unsets halftime, if set
    mapName = "";               // zeros the mapname string
    half1Limit = 0;             // don't set half winlimit until map type is determined above
    totalWinLimit = 0;          // don't set winlimit until map type is determined above
    tourneyRestart = false;     // don't restart the tournament on next round start
    HalfStale = false;          // reset result of timelimit gameover bool, if set
    gameIsLive = false;
}

public void EventGameOver(Event event, const char[] name, bool dontBroadcast)   // game over event
{
    event.GetString("reason", staleReason, sizeof(staleReason));
    if (strncmp(staleReason, "Reached Time Limit", 32) == 0)
    {
        HalfStale = true;                                                       // means we reached the end of the server timelimit, used to differentiate between 5cp round timeouts and map timelimit timeouts
    }
    else HalfStale = false;
//  PrintToChatAll("reason %s", staleReason);
}

public void EventRoundEnd(Event event, const char[] name, bool dontBroadcast)   // Round End Event
{
    int team = event.GetInt("team");                                            // gets int value of the team who won the round. 2 = red, 3 = blu, anything else is a stalemate
    int winreason = event.GetInt("winreason");                                  // gets winreason to prevent incrementing when a stalemate occurs
    gameIsLive = true;                                                          // sets gamelive bool to true because there's no way for a round to end unless the game is live
    if (team == 2 && winreason == 1)                                            // RED TEAM NON-STALEMATE WIN EVENT
    {
        redRnds++;                                                              // increments red round counter by +1
        MC_PrintToChatAll("{mediumpurple}[tf2Halftime] {red}Red{white} wins! The score is {red}Red{white}: {red}%i{white}, {blue}Blu{white}: {blue}%i{white}.", redRnds, bluRnds);
        if (redRnds >= half1Limit && !isHalf2)                                  // red reaches (half1Limit) rounds before timelimit
        {
            isHalf2 = true;
            MC_PrintToChatAll("{mediumpurple}[tf2Halftime] {white}Halftime reached! The score is {red}Red{white}: {red}%i{white}, {blue}Blu{white}: {blue}%i{white}.", redRnds, bluRnds);
            tourneyRestart = true;
        }
        else if (redRnds >= totalWinLimit && isHalf2)                           // red reaches (totalWinLimit) rounds
        {
            MC_PrintToChatAll("{mediumpurple}[tf2Halftime] {white}The game is over, and {red}Red{white} wins! The score is {red}Red{white}: {red}%i{white}, {blue}Blu{white}: {blue}%i{white}.", redRnds, bluRnds);
            tourneyRestart = true;
        }
    }
    else if (team == 3 && winreason == 1)                                       // BLU TEAM NON-STALEMATE WIN EVENT
    {
        bluRnds++;                                                              // increments blu round counter by +1
        MC_PrintToChatAll("{mediumpurple}[tf2Halftime] {blue}Blu{white} wins! The score is {red}Red{white}: {red}%i{white}, {blue}Blu{white}: {blue}%i{white}.", redRnds, bluRnds);
        if (bluRnds >= half1Limit && !isHalf2)                                  // blu reaches (half1Limit) rounds before timelimit
        {
            isHalf2 = true;
            MC_PrintToChatAll("{mediumpurple}[tf2Halftime] {white}Halftime reached! The score is {red}Red{white}: {red}%i{white}, {blue}Blu{white}: {blue}%i{white}.", redRnds, bluRnds);
            tourneyRestart = true;
        }
        else if (bluRnds >= totalWinLimit && isHalf2)                           // blu reaches (totalWinLimit) rounds
        {
            MC_PrintToChatAll("{mediumpurple}[tf2Halftime] {white}The game is over, and {blue}Blu{white} wins! The score is {red}Red{white}: {red}%i{white}, {blue}Blu{white}: {blue}%i{white}.", redRnds, bluRnds);
            tourneyRestart = true;
        }
    }
    else if (winreason == 5 || 6)                                               // TIMELIMIT HIT
    {
        if (winreason == 5 && !HalfStale)                                       // this covers 5cp round timer stalemates
        {
            MC_PrintToChatAll("{mediumpurple}[tf2Halftime] {white}Round stalemate! The score is {red}Red{white}: {red}%i{white}, {blue}Blu{white}: {blue}%i{white}.", redRnds, bluRnds);
        }
        else if (redRnds > bluRnds)                                             // does red have more points?
        {
            if (isHalf2)
            {
                MC_PrintToChatAll("{mediumpurple}[tf2Halftime] {white}Timelimit reached! The game is over, and {red}Red{white} wins! The score is {red}Red{white}: {red}%i{white}, {blue}Blu{white}: {blue}%i{white}.", redRnds, bluRnds);                           // red win @ timelimit in half 2
            }
            else if (!isHalf2)
            {
                MC_PrintToChatAll("{mediumpurple}[tf2Halftime] {white}Timelimit reached! {red}Red{white} is in the lead! The score is {red}Red{white}: {red}%i{white}, {blue}Blu{white}: {blue}%i{white}.", redRnds, bluRnds); // red winning @ halftime
                isHalf2 = true;
            }
        }
        else if (redRnds < bluRnds)                                             // ok, does blu have more points?
        {
            if (isHalf2)
            {
            MC_PrintToChatAll("{mediumpurple}[tf2Halftime] {white}Timelimit reached! The game is over, and {blue}Blu{white} wins! The score is {red}Red{white}: {red}%i{white}, {blue}Blu{white}: {blue}%i{white}.", redRnds, bluRnds); // blu win @ timelimit in half 2
            }
            else if (!isHalf2)
            {
                MC_PrintToChatAll("{mediumpurple}[tf2Halftime] {white}Timelimit reached! {blue}Blu{white} is in the lead! The score is {red}Red{white}: {red}%i{white}, {blue}Blu{white}: {blue}%i{white}.", redRnds, bluRnds); // blu winning @ halftime
                isHalf2 = true;
            }
        }
        else if (redRnds == bluRnds)                                            // no? ok. spit out tie msg and/or exec for gc
        {
            if (isHalf2)
            {
                MC_PrintToChatAll("{mediumpurple}[tf2Halftime] {white}Timelimit reached! Neither team has won! Setting up golden cap. The score is {red}Red{white}: {red}%i{white}, {blue}Blu{white}: {blue}%i{white}.", redRnds, bluRnds);                           // tie @ end of game, do GC stuff
                ServerCommand("exec rgl_6s_5cp_gc");                            // rgl_6s_5cp_gc unloads tf2Halftime FYI!
            }
            else if (!isHalf2)
            {
                MC_PrintToChatAll("{mediumpurple}[tf2Halftime] {white}Timelimit reached! The score is {red}Red{white}: {red}%i{white}, {blue}Blu{white}: {blue}%i{white}.", redRnds, bluRnds); // tie @ halftime
                isHalf2 = true;
            }
        }
        tourneyRestart = false;
    }
    else // catch all for nonsensical scenarios
    {
        MC_PrintToChatAll("{mediumpurple}[tf2Halftime] {white}Something broke!. The score is {red}Red{white}:{red}%i{white}, {blue}Blu{white}: {blue}%i{white}.", redRnds, bluRnds);
        MC_PrintToChatAll("{mediumpurple}[tf2Halftime] {white}Spitting out debug info: winreason %i, team %i. Score is {red}Red{white}:{red}%i{white}, {blue}Blu{white}: {blue}%i{white}.", winreason, team, redRnds, bluRnds);
        MC_PrintToChatAll("{mediumpurple}[tf2Halftime] {white}More debug info: half1Limit %i, totalWinLimit %i.", half1Limit, totalWinLimit);
        MC_PrintToChatAll("{mediumpurple}[tf2Halftime] {white}PLEASE REPORT THIS TO AN RGL ADMIN!");
        if (isHalf2)
        {
            MC_PrintToChatAll("{mediumpurple}[tf2Halftime] {white}isHalf2 = true");
        }
        else
        {
            MC_PrintToChatAll("{mediumpurple}[tf2Halftime] {white}isHalf2 = false");
        }
    }
}

void printScore(int client)
{
    if (IsClientInGame(client) && !IsFakeClient(client))
    {
        SetHudTextParams(-1.0, 0.25, 6.0, 255, 255, 255, 255, 1, 2.0, 0.5, 1.0);  // white color
        ShowHudText(client, -1, "The score is:");
        SetHudTextParams(-1.0, 0.25, 6.0, 255, 20, 20, 255, 1, 2.0, 0.5, 1.0);    // red color
        ShowHudText(client, -1, "\nRed: %i", redRnds);
        SetHudTextParams(-1.0, 0.25, 6.0, 0, 235, 255, 255, 1, 2.0, 0.5, 1.0);    // blu color
        ShowHudText(client, -1, "\n\nBlu: %i", bluRnds);
    }
}

public void EventRoundStart(Event event, const char[] name, bool dontBroadcast)  // Round Start Event
{
    MC_PrintToChatAll("{mediumpurple}[tf2Halftime] {white}This server is running tf2Halftime version {mediumpurple}%s", PLUGIN_VERSION);
    if (gameIsLive)                     // if the game is live, display the score on round start
    {
        // for loop for getting client ids
        for (int client = 1; client <= MaxClients; client++)
        {
            printScore(client);         // print the score if the game is live no matter what
            if (tourneyRestart)         // but only do halftime things if it's halftime
            {
                MC_PrintToChatAll("{mediumpurple}[tf2Halftime] {white}Issuing mp_tournament_restart...");
                ServerCommand("mp_tournament_restart");
                tourneyRestart = false;
                HalfStale = false;
            }
        }
    }
    else if (!gameIsLive)
    {
        MC_PrintToChatAll("{mediumpurple}[tf2Halftime] {white}To see the score at any time during the game, type {mediumpurple}!score");
    }
}

public Action OnClientSayCommand(int client, const char[] command, const char[] clTxt)
{
    // 3 is the igm regex flag for pcre, which sourcemod uses (well i mean technically there's no g flag but who cares)
    if (SimpleRegexMatch(clTxt, "^(\\!|\\.|\\+|\\/|\\?|sm_|)score(|s)$", 3) >= 1)
    {
        printScore(client);
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

public void OnPluginEnd()
{
    MC_PrintToChatAll("{mediumpurple}[tf2Halftime] {white}has been {red}unloaded{default}.");
}
