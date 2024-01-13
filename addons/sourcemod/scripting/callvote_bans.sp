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

#define PLUGIN_VERSION "1.0"

/**
 * Player profile.
 *
 */
enum struct PlayerBans
{
	char steamid2[MAX_AUTHID_LENGTH];	 // Player SteamID 64
	int	 created;						 // Ban creation date
	int	 type;							 // Ban type
}

PlayerBans
	g_PlayersBans[MAXPLAYERS + 1];

DBStatement
	g_hGetBans;

bool
	g_bshowCooldown;

/*****************************************************************
			P L U G I N   I N F O
*****************************************************************/
public Plugin myinfo =
{
	name		= "Call Vote Bans",
	author		= "lechuga",
	description = "Sanctions with the blocking of calls to votes",
	version		= PLUGIN_VERSION,
	url			= "https://github.com/lechuga16/callvote_manager"


}

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/

public void OnPluginStart()
{
	LoadTranslation("callvote_bans.phrases");
	LoadTranslation("common.phrases");
	g_cvarDebug	 = CreateConVar("sm_cvb_debug", "0", "Debug sMessagess", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarEnable = CreateConVar("sm_cvb_enable", "1", "Enable plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarLog	 = CreateConVar("sm_cvb_log", "1", "Log sMessages", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	RegAdminCmd("sm_cvkl_sql_install", Command_CreateSQL, ADMFLAG_ROOT, "Install SQL tables");
	RegAdminCmd("sm_cvb_show", Command_ShowBans, ADMFLAG_GENERIC, "Show bans");
	RegConsoleCmd("sm_cvb_status", Command_Status, "Shows if I'm banned");
	RegAdminCmd("sm_cvb_ban", Command_Ban, ADMFLAG_BAN, "Show bans");
	RegAdminCmd("sm_cvb_unban", Command_UnBan, ADMFLAG_BAN, "Show bans");

	AutoExecConfig(false, "callvote_bans");
	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), DIR_CALLVOTE);
	g_hDatabase = Connect("callvote");

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i) || IsFakeClient(i))
			continue;

		OnClientPostAdminCheck(i);
	}
}

Action Command_CreateSQL(int iClient, int iArgs)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}

	char sQuery[500];
	g_hDatabase.Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `callvote_bans` ( \
        `id` int(6) NOT NULL auto_increment, \
        `authid` varchar(64) character set utf8 NOT NULL default '' COMMENT 'SteamID2 Banned', \
        `type` int(6) NOT NULL default '0' COMMENT 'Ban type', \
        `admin` varchar(64) character set utf8 NOT NULL default '' COMMENT 'SteamID2 Admin', \
        PRIMARY KEY(`id`)) \
		ENGINE = InnoDB DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci");

	if (!SQL_FastQuery(g_hDatabase, sQuery))
	{
		char sSQLError[255];
		SQL_GetError(g_hDatabase, sSQLError, sizeof(sSQLError));
		log(false, "SQL failed: %s", sSQLError);
		log(false, "Query: %s", sQuery);
		CReplyToCommand(iClient, "%t %t", "Tag", "DBQueryError");
		return Plugin_Handled;
	}

	CReplyToCommand(iClient, "%t %t", "Tag", "DBTableCreated");
	log(true, "%t Tables have been created.", "Tag");
	return Plugin_Handled;
}

Action Command_Status(int iClient, int iArgs)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}

	if (iArgs != 0)
	{
		CReplyToCommand(iClient, "%t %t: sm_cvb_status", "Tag", "Usage");
		return Plugin_Handled;
	}

	if (g_PlayersBans[iClient].type == 0)
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "ShowNoBan");
		return Plugin_Handled;
	}

	char sName[32];
	GetClientName(iClient, sName, sizeof(sName));
	VotesMessage(iClient, g_PlayersBans[iClient].type, sName);

	return Plugin_Handled;
}

Action Command_ShowBans(int iClient, int iArgs)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}

	if (iArgs != 1)
	{
		CReplyToCommand(iClient, "%t %t: sm_cvb_show <#userid|name|steamid>", "Tag", "Usage");
		return Plugin_Handled;
	}

	char sBuffer[100];
	GetCmdArg(1, sBuffer, sizeof(sBuffer));

	// use steamid to offlineban
	bool bIsOffline = ((StrContains(sBuffer, "STEAM_1", false) != -1) || (StrContains(sBuffer, "STEAM_0", false) != -1));
	int	 iTarget	= PlayerInGame(sBuffer);

	if (bIsOffline && iTarget == -1)
	{
		if (!g_bshowCooldown)
		{
			g_bshowCooldown = true;
			CreateTimer(3.0, Timer_ShowBans, _, TIMER_FLAG_NO_MAPCHANGE);
		}
		else
		{
			CReplyToCommand(iClient, "%t %t", "Tag", "Cooldown");
			return Plugin_Handled;
		}

		ReplaceString(sBuffer, sizeof(sBuffer), "STEAM_0", "STEAM_1", false);

		int iTypeBan = GetBans(0, sBuffer, true);
		if (iTypeBan == 0)
			CReplyToCommand(iClient, "%t %t", "Tag", "ShowNoBan");
		else
			VotesMessage(iClient, iTypeBan, sBuffer);
		return Plugin_Handled;
	}
	else if (iTarget == -1)
		iTarget = FindTarget(iClient, sBuffer, true);

	if (iTarget == -1)
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "PlayerNotFound");
		return Plugin_Handled;
	}

	if (g_PlayersBans[iTarget].type == 0)
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "ShowNoBan");
		return Plugin_Handled;
	}

	char sName[32];
	GetClientName(iTarget, sName, sizeof(sName));
	VotesMessage(iClient, g_PlayersBans[iTarget].type, sName);

	return Plugin_Handled;
}

Action Timer_ShowBans(Handle hTimer)
{
	g_bshowCooldown = false;
	return Plugin_Stop;
}

Action Command_Ban(int iClient, int iArgs)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}

	if (iArgs < 2)
	{
		CReplyToCommand(iClient, "%t %t: sm_cvb_ban <#userid|name|steamid> <TypeBans>", "Tag", "Usage");
		CReplyToCommand(iClient, "%t %t", "Tag", "SeeTypeBans");
		PrintToConsole(iClient, "%t", "TypeBans");
		return Plugin_Handled;
	}

	char sBuffer[100];
	GetCmdArg(1, sBuffer, sizeof(sBuffer));
	int iType = GetCmdArgInt(2);

	if (!IsVoteTypeValid(iType))
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "SeeTypeBans");
		PrintToConsole(iClient, "%t", "TypeBans");
		return Plugin_Handled;
	}

	// use steamid to offlineban
	bool bIsOffline = ((StrContains(sBuffer, "STEAM_1", false) != -1) || (StrContains(sBuffer, "STEAM_0", false) != -1));
	int	 iTarget	= PlayerInGame(sBuffer);

	if (bIsOffline && iTarget == -1)
	{
		ReplaceString(sBuffer, sizeof(sBuffer), "STEAM_0", "STEAM_1", false);

		if (GetBans(0, sBuffer, true) == 0)
		{
			if (CreateBan(iClient, 0, iType, sBuffer, true))
				CReplyToCommand(iClient, "%t %t", "Tag", "BanCreated");
			else
				CReplyToCommand(iClient, "%t %t", "Tag", "BanNotCreated");
		}
		else
		{
			if (UpdateBan(iClient, 0, iType, sBuffer, true))
				CReplyToCommand(iClient, "%t %t", "Tag", "BanUpdated");
			else
				CReplyToCommand(iClient, "%t %t", "Tag", "BanNotCreated");
		}
		return Plugin_Handled;
	}
	else if (iTarget == -1)
		iTarget = FindTarget(iClient, sBuffer, true);

	if (iTarget == -1)
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "PlayerNotFound");
		return Plugin_Handled;
	}

	// use target to onlineban
	if (g_PlayersBans[iTarget].type == 0)
	{
		if (CreateBan(iClient, iTarget, iType))
			CReplyToCommand(iClient, "%t %t", "Tag", "BanCreated");
		else
			CReplyToCommand(iClient, "%t %t", "Tag", "BanNotCreated");
	}
	else
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "PlayerAlreadyBanned");

		if (UpdateBan(iClient, iTarget, iType))
			CReplyToCommand(iClient, "%t %t", "Tag", "BanUpdated");
		else
			CReplyToCommand(iClient, "%t %t", "Tag", "BanNotCreated");
	}

	return Plugin_Handled;
}

Action Command_UnBan(int iClient, int iArgs)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}

	if (iArgs != 1)
	{
		CReplyToCommand(iClient, "%t %t: sm_cvb_unban <#userid|name|steamid>", "Tag", "Usage");
		return Plugin_Handled;
	}

	char sBuffer[100];
	GetCmdArg(1, sBuffer, sizeof(sBuffer));

	// use steamid to offline ban delete
	bool bIsOffline = ((StrContains(sBuffer, "STEAM_1", false) != -1) || (StrContains(sBuffer, "STEAM_0", false) != -1));
	int	 iTarget	= PlayerInGame(sBuffer);

	if (bIsOffline && iTarget == -1)
	{
		if (GetBans(0, sBuffer, true) == 0)
		{
			CReplyToCommand(iClient, "%t %t", "Tag", "ShowNoBan");
			return Plugin_Handled;
		}

		if (DeleteBan(0, sBuffer, true))
			CReplyToCommand(iClient, "%t %t", "Tag", "BanDeleted");
		else
			CReplyToCommand(iClient, "%t %t", "Tag", "BanNotDeleted");
		return Plugin_Handled;
	}
	else if (iTarget == -1)
		iTarget = FindTarget(iClient, sBuffer, true);

	if (iTarget == -1)
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "PlayerNotFound");
		return Plugin_Handled;
	}

	// use target to online ban delete
	if (g_PlayersBans[iTarget].type == 0)
		CReplyToCommand(iClient, "%t %t", "Tag", "ShowNoBan");
	else
	{
		if (DeleteBan(iTarget))
			CReplyToCommand(iClient, "%t %t", "Tag", "BanDeleted");
		else
			CReplyToCommand(iClient, "%t %t", "Tag", "BanNotCreated");
	}
	return Plugin_Handled;
}

public void OnClientPostAdminCheck(int iClient)
{
	if (!g_cvarEnable.BoolValue)
		return;

	if (IsFakeClient(iClient))
		return;

	if (!GetClientAuthId(iClient, AuthId_Steam2, g_PlayersBans[iClient].steamid2, MAX_AUTHID_LENGTH))
	{
		log(false, "Failed to get authid for client %N | %s", iClient, g_PlayersBans[iClient].steamid2);
		return;
	}

	int iTypeBan = GetBans(iClient);
	if (iTypeBan == 0)
	{
		log(true, "No bans for %N %s", iClient, g_PlayersBans[iClient].steamid2);
		return;
	}
	else
		g_PlayersBans[iClient].type = iTypeBan;
}

/*****************************************************************
			F O R W A R D   P L U G I N S
*****************************************************************/
public void CallVote_Start(int client, TypeVotes votes, int Target)
{
	if (!g_cvarEnable.BoolValue)
		return;

	if (g_PlayersBans[client].type == 0)
		return;

	if (IsVoteEnabled(g_PlayersBans[client].type, votes))
	{
		char sReason[255];
		Format(sReason, sizeof(sReason), "%t", "VoteBlocked");
		CallVote_Reject(client, sReason);
		log(true, "Vote blocked for %N %s", Target, g_PlayersBans[Target].steamid2);
		return;
	}
}

/*****************************************************************
			P L U G I N   F U N C T I O N S
*****************************************************************/

/**
 * Creates a ban for a player.
 *
 * @param iClient The client index of the banning player.
 * @param iTarget The client index of the player being banned.
 * @param iType The type of ban.
 * @param sSteamID The Steam ID of the player being banned. Optional if bOffline is true.
 * @param bOffline Specifies if the ban is an offline ban.
 * @return True if the ban was successfully created, false otherwise.
 */
bool CreateBan(int iClient, int iTarget, int iType, const char[] sSteamID = "", bool bOffline = false)
{
	char
		sAuth[MAX_AUTHID_LENGTH];

	if (bOffline)
		strcopy(sAuth, sizeof(sAuth), sSteamID);
	else
		strcopy(sAuth, sizeof(sAuth), g_PlayersBans[iTarget].steamid2);

	char sQuery[500];
	g_hDatabase.Format(sQuery, sizeof(sQuery), "INSERT INTO callvote_bans (authid, type, admin) VALUES ('%s', '%d', '%s')", g_PlayersBans[iClient].steamid2, iType, sAuth);

	if (!SQL_FastQuery(g_hDatabase, sQuery))
	{
		char sError[255];
		SQL_GetError(g_hDatabase, sError, sizeof(sError));
		log(false, "SQL Failed: %s\nQuery: ", sError, sQuery);
		return false;
	}

	if (bOffline)
		log(true, "offlineban created for %s | type: %d", sSteamID, iType);
	else
	{
		g_PlayersBans[iTarget].type = iType;
		log(true, "Ban created for %N %s | type: %d", iTarget, g_PlayersBans[iTarget].steamid2, iType);
	}
	return true;
}

/**
 * Updates the ban information for a player.
 *
 * @param iClient The client index of the admin performing the update.
 * @param iTarget The client index of the player being banned.
 * @param iType The type of ban to apply.
 * @param sSteamID The SteamID of the player being banned (optional, used for offline bans).
 * @param bOffline Specifies whether the ban is an offline ban or not.
 * @return True if the ban update was successful, false otherwise.
 */
bool UpdateBan(int iClient, int iTarget, int iType, const char[] sSteamID = "", bool bOffline = false)
{
	char
		sAuth[MAX_AUTHID_LENGTH];

	if (bOffline)
		strcopy(sAuth, sizeof(sAuth), sSteamID);
	else
		strcopy(sAuth, sizeof(sAuth), g_PlayersBans[iTarget].steamid2);

	char sQuery[500];
	g_hDatabase.Format(sQuery, sizeof(sQuery), "UPDATE callvote_bans SET type = '%d', admin = '%s' WHERE authid = '%s'", iType, g_PlayersBans[iClient].steamid2, sAuth);

	if (!SQL_FastQuery(g_hDatabase, sQuery))
	{
		char sError[255];
		SQL_GetError(g_hDatabase, sError, sizeof(sError));
		log(false, "SQL Failed: %s\nQuery: %s", sError, sQuery);
		return false;
	}

	if (bOffline)
		log(true, "Offline Ban updated for %s | type: %d", sSteamID, iType);
	else
	{
		g_PlayersBans[iTarget].type = iType;
		log(true, "Ban updated for %N %s | type: %d", iTarget, g_PlayersBans[iTarget].steamid2, iType);
	}
	return true;
}

/**
 * Deletes a ban from the callvote_bans table.
 *
 * @param iTarget The index of the player ban to delete.
 * @param sSteamID The Steam ID of the player to delete the ban for. Defaults to an empty string.
 * @param bOffline Specifies whether the ban is an offline ban. Defaults to false.
 * @return True if the ban was successfully deleted, false otherwise.
 */
bool DeleteBan(int iTarget, const char[] sSteamID = "", bool bOffline = false)
{
	char
		sAuth[MAX_AUTHID_LENGTH];

	if (bOffline)
		strcopy(sAuth, sizeof(sAuth), sSteamID);
	else
		strcopy(sAuth, sizeof(sAuth), g_PlayersBans[iTarget].steamid2);

	char sQuery[500];
	g_hDatabase.Format(sQuery, sizeof(sQuery), "DELETE FROM callvote_bans WHERE authid = '%s'", sAuth);

	if (!SQL_FastQuery(g_hDatabase, sQuery))
	{
		char sError[255];
		SQL_GetError(g_hDatabase, sError, sizeof(sError));
		log(false, "SQL Failed: %s\nQuery: %s", sError, sQuery);
		return false;
	}

	if (bOffline)
		log(true, "Offline Ban deleted for %s", sSteamID);
	else
	{
		g_PlayersBans[iTarget].type = 0;
		log(true, "Ban deleted for %N %s", iTarget, g_PlayersBans[iTarget].steamid2);
	}

	return true;
}

/**
 * Retrieves the ban type for a given client.
 *
 * @param iClient The client index.
 * @param sSteamID The SteamID of the client. Defaults to an empty string.
 * @param bOffline Specifies whether the client is offline. Defaults to false.
 * @return The ban type for the client. Returns 0 if the client is not banned.
 */
int GetBans(int iClient, const char[] sSteamID = "", bool bOffline = false)
{
	char
		sQuery[255];
	Format(sQuery, sizeof(sQuery), "SELECT `type` FROM callvote_bans WHERE `authid` = ?");

	if (g_hGetBans == null)
	{
		char sError[255];
		if ((g_hGetBans = SQL_PrepareQuery(g_hDatabase, sQuery, sError, sizeof(sError))) == null)
		{
			log(false, "DBStatement failed: %s", sError);
			return 0;
		}
	}

	if (bOffline)
		g_hGetBans.BindString(0, sSteamID, false);
	else
		g_hGetBans.BindString(0, g_PlayersBans[iClient].steamid2, false);

	if (!SQL_Execute(g_hGetBans))
	{
		char sSQLError[255];
		SQL_GetError(g_hGetBans, sSQLError, sizeof(sSQLError));
		log(false, "SQL failed: %s", sSQLError);
		delete g_hGetBans;
	}

	if (SQL_FetchRow(g_hGetBans))
		return SQL_FetchInt(g_hGetBans, 0);

	return 0;
}

/**
 * Displays a message containing the types of votes that are blocked.
 *
 * @param clientID The client ID to send the message to.
 * @param iTypeVotes The bitmask representing the types of votes that are blocked.
 * @param sName The name associated with the message.
 */
void VotesMessage(int clientID, int iTypeVotes, const char[] sName)
{
	char
		sMessage[300],
		sTraslation[32];

	int	 iBlockedVotes	= 0;

	char voteTraslation[7][] = {
		"VOTE_CHANGEDIFFICULTY",
		"VOTE_RESTARTGAME",
		"VOTE_KICK",
		"VOTE_CHANGEMISSION",
		"VOTE_RETURNTOLOBBY",
		"VOTE_CHANGECHAPTER",
		"VOTE_CHANGEALLTALK"
	};

	for (int i = 0; i < 7; i++)
	{
		if (iTypeVotes & (1 << i))
		{
			AddSeparator(sMessage, sizeof(sMessage), iBlockedVotes);
			Format(sTraslation, sizeof(sTraslation), "%t", voteTraslation[i]);
			StrCat(sMessage, sizeof(sMessage), sTraslation);
			iBlockedVotes++;
		}
	}

	if (iBlockedVotes == 1)
		CReplyToCommand(clientID, "%t %t", "Tag", "ShowBan", sName, sMessage);
	else
		CReplyToCommand(clientID, "%t %t", "Tag", "ShowBans", sName, sMessage);
}

/**
 * Checks if a player with the specified Steam ID is currently in the game.
 *
 * @param sSteamID The Steam ID of the player to check.
 * @return The client index of the player if they are in the game, or -1 if not found.
 */
int PlayerInGame(const char[] sSteamID)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i) || IsFakeClient(i))
			continue;

		char sAuth[MAX_AUTHID_LENGTH];
		if (!GetClientAuthId(i, AuthId_Steam2, sAuth, MAX_AUTHID_LENGTH))
			continue;

		if (StrEqual(sAuth, sSteamID, false))
			return i;
	}
	return -1;
}

void AddSeparator(char[] sMessage, int iSize, int iBlockedVotes)
{
	if (iBlockedVotes > 0)
	{
		char sSeparator[2];
		Format(sSeparator, sizeof(sSeparator), "%t", "Separator");
		StrCat(sMessage, iSize, sSeparator);
	}
}