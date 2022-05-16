// https://github.com/b4nnyBot/TF2-Improved-Round-Timer-Plugin
// Temporarily included for the 6s season the repo is updated

#include <sdkhooks>
#include <sdktools>

ConVar round_time_override = null;

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
	PrintToChatAll("Overrode round timer time to %d seconds", round_time_override.IntValue);
}
