#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#include <callvote_stock>

#undef REQUIRE_PLUGIN
#include <callvotemanager>
#define REQUIRE_PLUGIN

/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

#define PLUGIN_VERSION "1.3.1"

/**
 * Player profile.
 *
 */
enum struct PlayerInfo
{
	char ClientID[MAX_AUTHID_LENGTH];	// Client SteamID
	char TargetID[MAX_AUTHID_LENGTH];	// Target SteamID
	int	 Kick;							// kick voting call amount
	int	 Target;						// Target kicked
}

PlayerInfo g_Players[MAXPLAYERS + 1];

int
	g_iCaller = 0;

ConVar
	g_cvarKickLimit;

/*****************************************************************
			L I B R A R Y   I N C L U D E S
*****************************************************************/

#include "callvote/kicklimit_sql.sp"

/*****************************************************************
			P L U G I N   I N F O
*****************************************************************/

public Plugin myinfo =
{
	name		= "Call Vote Kick Limit",
	author		= "lechuga",
	description = "Limits the amount of callvote kick",
	version		= PLUGIN_VERSION,
	url			= "https://github.com/lechuga16/callvote_manager"
}

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/

public void OnPluginStart()
{
	LoadTranslation("callvote_kicklimit.phrases");
	LoadTranslation("common.phrases");
	CreateConVar("sm_cvkl_version", PLUGIN_VERSION, "Plugin version", FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);

	g_cvarDebug		= CreateConVar("sm_cvkl_debug", "0", "Enable debug", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarEnable	= CreateConVar("sm_cvkl_enable", "1", "Enable plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarLog		= CreateConVar("sm_cvkl_logs", "1", "Enable logging", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarKickLimit = CreateConVar("sm_cvkl_kicklimit", "1", "Kick limit", FCVAR_NOTIFY, true, 0.0);
	
	RegAdminCmd("sm_kickshow", Command_KickShow, ADMFLAG_KICK, "Shows a list of all local kick records");
	RegConsoleCmd("sm_kicklimit", Command_KickCount, "Shows the number of kicks saved locally");

	HookUserMessage(GetUserMessageId("VotePass"), Message_VotePass);
	HookUserMessage(GetUserMessageId("VoteFail"), Message_VoteFail);

	OnPluginStart_SQL();

	AutoExecConfig(false, "callvote_kicklimit");

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i) || IsFakeClient(i))
			continue;

		char sSteamId[MAX_AUTHID_LENGTH];
		GetClientAuthId(i, AuthId_Steam2, sSteamId, MAX_AUTHID_LENGTH);
		OnClientAuthorized(i, sSteamId);
	}
}

Action Command_KickCount(int iClient, int sArgs)
{
	if (!g_cvarEnable.BoolValue)
	{
		CPrintToChat(iClient, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}

	if (sArgs < 1)
	{
		CPrintToChat(iClient, "%t %t sm_kicklimit <#userid|name>", "Tag", "Usage");
		return Plugin_Handled;
	}

	char sArguments[256];
	GetCmdArgString(sArguments, sizeof(sArguments));

	char sArg[65];
	BreakString(sArguments, sArg, sizeof(sArg));

	char sTargetName[MAX_TARGET_LENGTH];
	int	 sTargetList[MAXPLAYERS], sTargetCount;
	bool bTnIsMl;
	int	 iFlags = COMMAND_FILTER_CONNECTED | COMMAND_FILTER_NO_BOTS | COMMAND_FILTER_NO_MULTI;

	if ((sTargetCount = ProcessTargetString(sArg, iClient, sTargetList, MAXPLAYERS, iFlags, sTargetName, sizeof(sTargetName), bTnIsMl)) > 0)
	{
		for (int i = 0; i < sTargetCount; i++)
		{
			if (sTargetList[i] == iClient)
				CPrintToChat(iClient, "%t %t", "Tag", "KickLimit", g_Players[iClient].Kick, g_cvarKickLimit.IntValue);
			else
				CPrintToChat(iClient, "%t %t", "Tag", "KickLimitTarget", sTargetName, g_Players[sTargetList[i]].Kick, g_cvarKickLimit.IntValue);
		}
	}
	else
		ReplyToTargetError(iClient, sTargetCount);

	return Plugin_Handled;
}

Action Command_KickShow(int iClient, int sArgs)
{
	if (!g_cvarEnable.BoolValue)
	{
		CPrintToChat(iClient, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}

	char sAuth[32];
	GetClientAuthId(iClient, AuthId_Steam2, sAuth, sizeof(sAuth));

	int iFound = 0;
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		if (!g_Players[i].Kick)
			continue;

		if (StrEqual(g_Players[i].ClientID, sAuth))
		{
			iFound++;
			CPrintToChat(iClient, "%t %t", "Tag", "KickShow", i, g_Players[i].ClientID, g_Players[i].Kick);
		}
	}

	if (!iFound)
		CPrintToChat(iClient, "%t %t", "Tag", "NoFound");

	return Plugin_Handled;
}

public void OnClientAuthorized(int iClient, const char[] sAuth)
{
	if (!g_cvarEnable.BoolValue || IsFakeClient(iClient))
		return;

	if (g_cvarSQL.BoolValue)
	{
		if (!GetCountKick(iClient, sAuth))
			IsNewClient(iClient);
	}
	else
	{
		if (!IsClientRegistred(iClient, sAuth))
			IsNewClient(iClient);
	}
}

/*****************************************************************
			F O R W A R D   P L U G I N S
*****************************************************************/

public void CallVote_Start(int iClient, TypeVotes iVotes, int iTarget)
{
	if (!g_cvarEnable.BoolValue)
		return;

	if (iVotes != Kick)
		return;

	if (g_cvarKickLimit.IntValue <= g_Players[iClient].Kick)
	{
		char sBuffer[128];
		Format(sBuffer, sizeof(sBuffer), "%t", "KickReached", g_Players[iClient].Kick, g_cvarKickLimit.IntValue);
		CallVote_Reject(iClient, sBuffer);
		return;
	}

	g_iCaller = iClient;
	g_Players[g_iCaller].Target = iTarget;
	GetClientAuthId(iClient, AuthId_Steam2, g_Players[g_iCaller].ClientID, MAX_AUTHID_LENGTH);
	GetClientAuthId(iTarget, AuthId_Steam2, g_Players[g_iCaller].TargetID, MAX_AUTHID_LENGTH);
	return;
}

/****************************************************************
			C A L L B A C K   F U N C T I O N S
****************************************************************/

/*
 *	VotePass
 *	Note: Sent to all players after a vote passes.
 *
 *	Structure:
 *			byte	team	Team index or 255 for all
 *			string	details	Vote success translation string
 *			string	param1	Vote winner
 */
public Action Message_VotePass(UserMsg hMsg_id, BfRead hBf, const int[] iPlayers, int iPlayersNum, bool bReliable, bool bInit)
{
	if (!g_cvarEnable.BoolValue)
		return Plugin_Continue;

	if (g_iCaller == 0)
		return Plugin_Continue;

	char sIssue[128];
	hBf.ReadString(sIssue, 128);

	if (strcmp(sIssue, "#L4D_vote_kick_player"))
	{
		char sParam1[128];
		hBf.ReadString(sParam1, 128);

		g_Players[g_iCaller].Kick++;

		if (g_cvarSQL.BoolValue)
			sqlinsert(g_Players[g_iCaller].ClientID, g_Players[g_iCaller].TargetID);

		CreateTimer(0.1, Timer_CallVote_Pass, TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Continue;
}

Action Timer_CallVote_Pass(Handle timer)
{
	if (!g_iCaller)
	{
		g_Players[g_iCaller].Target = 0;
		return Plugin_Stop;
	}

	CPrintToChat(g_iCaller, "%t %t", "Tag", "KickLimit", g_Players[g_iCaller].Kick, g_cvarKickLimit.IntValue);
	g_Players[g_iCaller].Target = 0;
	return Plugin_Stop;
}

/*
 *	VoteFail
 *	Note: Sent to all players after a vote fails.
 *
 *	Structure:
 *			byte	team	Team index or 255 for all
 */
public Action Message_VoteFail(UserMsg hMsg_id, BfRead hBf, const int[] iPlayers, int iPlayersNum, bool bReliable, bool bInit)
{
	if (!g_cvarEnable.BoolValue)
		return Plugin_Continue;

	char sIssue[128];
	hBf.ReadString(sIssue, 128);

	if (strcmp(sIssue, "#L4D_vote_kick_player"))
		g_Players[g_iCaller].Target = 0;

	return Plugin_Continue;
}

/*****************************************************************
			P L U G I N   F U N C T I O N S
*****************************************************************/

void IsNewClient(int iClient)
{
	g_Players[iClient].Kick	  = 0;
	g_Players[iClient].Target = 0;
}

bool IsClientRegistred(int iClient, const char[] sAuth)
{
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		if (!g_Players[i].Kick)
			continue;

		if (StrEqual(g_Players[i].ClientID, sAuth, false))
		{
			if (i == iClient)
				return true;
			// Move the customer's saved data to their new ID
			g_Players[iClient].Kick	  = g_Players[i].Kick;
			g_Players[iClient].Target = 0;

			// Clear the old ID
			g_Players[i].Kick	= 0;
			g_Players[i].Target = 0;
			return true;
		}
	}
	return false;
}

// =======================================================================================
// Bibliography
// https://developer.valvesoftware.com/wiki/List_of_L4D2_Cvars
// https://wiki.alliedmods.net/Left_4_Voting_2
// https://forums.alliedmods.net/showthread.php?p=1582772
// https://github.com/SirPlease/L4D2-Competitive-Rework
// =======================================================================================