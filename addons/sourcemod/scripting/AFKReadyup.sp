#pragma semicolon 1

#include <sourcemod>
#include <l4d2util_constants>
#include <l4d2util_stocks>
#include <sdktools>
#include <colors>

#undef REQUIRE_PLUGIN
#include <readyup>
#define REQUIRE_PLUGIN

/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

ConVar
	g_cvarDebug,
	g_cvarEnable,
	g_cvarPlayerIgnore,
	g_cvarTime,
	g_cvarReadyFooter,
	g_cvarShowTimer;

int
	g_iPlayerAFK[MAXPLAYERS + 1];

float
	g_fPlayerLastPos[MAXPLAYERS + 1][3],
	g_fPlayerLastEyes[MAXPLAYERS + 1][3];

Handle
	 g_hStartTimerAFK;

bool g_bReadyUpAvailable;

/*****************************************************************
			P L U G I N   I N F O
*****************************************************************/
public Plugin myinfo =
{
	name		= "AFK on Readyup",
	author		= "lechuga",
	description = "Manage AFK players in the readyup",
	version		= "1.0",
	url			= ""
};

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/
public void OnAllPluginsLoaded()
{
	g_bReadyUpAvailable = LibraryExists("readyup");
}

public void OnLibraryAdded(const char[] sName)
{
	if (StrEqual(sName, "readyup"))
		g_bReadyUpAvailable = true;
}

public void OnLibraryRemoved(const char[] sName)
{
	if (StrEqual(sName, "readyup"))
		g_bReadyUpAvailable = false;
}

public void OnPluginStart()
{
	LoadTranslations("AFKReadyup.phrases");
	g_cvarDebug		   = CreateConVar("sm_debug", "0", "Debug messages", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarEnable	   = CreateConVar("sm_afk_enable", "1", "Activate the plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarPlayerIgnore = CreateConVar("sm_afk_ignore", "1", "Ignore players ready", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarTime		   = CreateConVar("sm_afk_time", "40", "Time to move players", FCVAR_NOTIFY, true, 0.0);
	g_cvarReadyFooter  = CreateConVar("sm_afk_footer", "1", "Show ready footer", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarShowTimer	   = CreateConVar("sm_afk_show", "10", "Show timer to players, 0 is disable", FCVAR_NOTIFY, true, 0.0);

	AutoExecConfig(false, "AFKReadyup");
	g_cvarEnable.AddChangeHook(Cvars_Enable);

	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say_team", Command_Say);

	HookEvent("entity_shoved", Event_PlayerAction);
	HookEvent("player_shoved", Event_PlayerAction);
	HookEvent("player_hurt", Event_PlayerAction);
	HookEvent("player_hurt_concise", Event_PlayerAction);

	HookEvent("player_jump", Event_PlayerJump);
	HookEvent("player_team", Event_PlayerTeam);
	HookEntityOutput("func_button_timed", "OnPressed", Event_OnPressed);
}

void Cvars_Enable(ConVar hConVar, const char[] sOldValue, const char[] sNewValue)
{
	if (StrEqual(sNewValue, "0"))
	{
		UnhookEvent("entity_shoved", Event_PlayerAction);
		UnhookEvent("player_shoved", Event_PlayerAction);
		UnhookEvent("player_hurt", Event_PlayerAction);
		UnhookEvent("player_hurt_concise", Event_PlayerAction);

		UnhookEvent("player_jump", Event_PlayerJump);
		UnhookEvent("player_team", Event_PlayerTeam);
		UnhookEntityOutput("func_button_timed", "OnPressed", Event_OnPressed);
	}
	else if (StrEqual(sNewValue, "1"))
	{
		HookEvent("entity_shoved", Event_PlayerAction);
		HookEvent("player_shoved", Event_PlayerAction);
		HookEvent("player_hurt", Event_PlayerAction);
		HookEvent("player_hurt_concise", Event_PlayerAction);

		HookEvent("player_jump", Event_PlayerJump);
		HookEvent("player_team", Event_PlayerTeam);
		HookEntityOutput("func_button_timed", "OnPressed", Event_OnPressed);
	}
}

Action Command_Say(int iClient, int iArgs)
{
	if (IsValidClientIndex(iClient) && IsClientInGame(iClient) && !IsFakeClient(iClient))
		ResetTimers(iClient);

	return Plugin_Continue;
}

void Event_PlayerAction(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(hEvent.GetInt("attacker"));

	if (IsValidClientIndex(iClient) || IsClientInGame(iClient) || !IsFakeClient(iClient))
		ResetTimers(iClient);
}

void Event_PlayerJump(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));

	if (IsValidClientIndex(iClient) || IsClientInGame(iClient) || !IsFakeClient(iClient))
		ResetTimers(iClient);
}

void Event_PlayerTeam(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));

	if (IsValidClientIndex(iClient) || IsClientInGame(iClient) || !IsFakeClient(iClient))
		ResetTimers(iClient);
}

void Event_OnPressed(const char[] sName, int iCaller, int iActivator, float fDelay)
{
	if (IsValidClientIndex(iActivator) || IsClientInGame(iActivator))
		ResetTimers(iActivator);
}

public void OnClientPutInServer(int iClient)
{
	if (IsFakeClient(iClient) || !g_bReadyUpAvailable || !IsInReady())
		return;

	g_iPlayerAFK[iClient] = g_cvarTime.IntValue;
}

public OnReadyUpInitiate()
{
	if (!g_cvarEnable.BoolValue)
		return;

	if (g_cvarReadyFooter.BoolValue)
	{
		char sBuffer[64];
		Format(sBuffer, sizeof(sBuffer), "%T", "Footer", LANG_SERVER, g_cvarTime.IntValue);
		AddStringToReadyFooter("");
		AddStringToReadyFooter(sBuffer);
	}

	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient) && !IsFakeClient(iClient))
		{
			int iTeam = GetClientTeam(iClient);
			if (iTeam == L4D2Team_Survivor || iTeam == L4D2Team_Infected)
			{
				if (g_cvarDebug.BoolValue)
					CPrintToChatAll("%t Set timer to: {blue}%N{default} | {green}%d{default}", "Tag", iClient, g_cvarTime.IntValue);
				g_iPlayerAFK[iClient] = g_cvarTime.IntValue;
			}

			GetClientAbsOrigin(iClient, g_fPlayerLastPos[iClient]);
			GetClientEyeAngles(iClient, g_fPlayerLastEyes[iClient]);
		}
	}

	delete g_hStartTimerAFK;
	g_hStartTimerAFK = CreateTimer(1.0, Timer_CheckAFK, _, TIMER_REPEAT);
}

public OnRoundIsLive()
{
	if (g_cvarEnable.BoolValue)
		delete g_hStartTimerAFK;
}

/*****************************************************************
			P L U G I N   F U N C T I O N S
*****************************************************************/

Action Timer_CheckAFK(Handle timer)
{
	float fPos[3];
	float fEyes[3];
	bool  bIsAFK;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			int iTeam = GetClientTeam(i);
			if (iTeam == L4D2Team_Survivor || iTeam == L4D2Team_Infected)
			{
				if (g_cvarPlayerIgnore.BoolValue && IsReady(i))
					continue;

				if (g_cvarShowTimer.BoolValue && g_iPlayerAFK[i] <= g_cvarShowTimer.IntValue)
					CPrintToChat(i, "%t %t", "Tag", "ShowTimer", g_iPlayerAFK[i]);

				GetClientAbsOrigin(i, fPos);
				GetClientEyeAngles(i, fEyes);

				bIsAFK = true;

				if (GetVectorDistance(fPos, g_fPlayerLastPos[i]) > 80.0)
					bIsAFK = false;

				if (bIsAFK)
				{
					if (fEyes[0] != g_fPlayerLastEyes[i][0] && fEyes[1] != g_fPlayerLastEyes[i][1])
						bIsAFK = false;
				}

				if (bIsAFK)
				{
					if (g_iPlayerAFK[i] > 0)
					{
						g_iPlayerAFK[i] = g_iPlayerAFK[i] - 1;

						if (g_iPlayerAFK[i] <= 0)
						{
							ChangeClientTeam(i, L4D2Team_Spectator);
							CPrintToChatAll("%t %t", "Tag", "MoveToSpec", i, g_iPlayerAFK[i]);
						}
					}
				}
				else
				{
					ResetTimers(i);
				}
			}
		}
	}

	return Plugin_Continue;
}

void ResetTimers(int iClient)
{
	int iTeam = GetClientTeam(iClient);
	if (iTeam == L4D2Team_Survivor || iTeam == L4D2Team_Infected)
		g_iPlayerAFK[iClient] = g_cvarTime.IntValue;

	GetClientAbsOrigin(iClient, g_fPlayerLastPos[iClient]);
	GetClientEyeAngles(iClient, g_fPlayerLastEyes[iClient]);
}

/**
 * Check if the translation file exists
 *
 * @param translation	Translation name.
 * @noreturn
 */
stock void LoadTranslation(const char[] translation)
{
	char
		sPath[PLATFORM_MAX_PATH],
		sName[64];

	Format(sName, sizeof(sName), "translations/%s.txt", translation);
	BuildPath(Path_SM, sPath, sizeof(sPath), sName);
	if (!FileExists(sPath))
		SetFailState("Missing translation file %s.txt", translation);

	LoadTranslations(translation);
}