// https://github.com/b4nnyBot/TF2-Improved-Round-Timer-Plugin
// Temporarily included for the 6s season the repo is updated

#include <sdkhooks>
#include <sdktools>

ConVar round_time_override = null;
Handle timer_preventSpam = INVALID_HANDLE;

public void OnPluginStart()
{
	round_time_override = CreateConVar("round_time_override", "-1", "(Seconds) Overrides the round timer on 5cp maps so that instead of 10 minutes, it can be set to any length");
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (round_time_override.IntValue < 0)
		return;
	
	if (StrEqual(classname, "team_round_timer"))
	{
		SDKHook(entity, SDKHook_SpawnPost, timer_spawn_post);
	}
}

public void timer_spawn_post(int timer)
{
	SetVariantInt(round_time_override.IntValue);
	AcceptEntityInput(timer, "SetMaxTime");
	if(timer_preventSpam==INVALID_HANDLE){
        PrintToChatAll("Overrode round timer time to %d seconds", round_time_override.IntValue);
        timer_preventSpam = CreateTimer(1.0, preventSpam, _, TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action preventSpam(Handle timer){
    timer_preventSpam = INVALID_HANDLE;
    return Plugin_Continue;
}