/**
 * vim: set ts=4 sw=4 tw=99 noet :
 * =============================================================================
 * SourceMod (C)2004-2014 AlliedModders LLC.  All rights reserved.
 * =============================================================================
 *
 * This file is part of the SourceMod/SourcePawn SDK.
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */

#if defined _callvotemanager_sql_included
	#endinput
#endif
#define _callvotemanager_sql_included

/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

ConVar
	g_cvarSQL;

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/

public void OnPluginStart_SQL()
{
	g_cvarSQL = CreateConVar("sm_cvm_sql", "0", "logging flags <dificulty:1, restartgame:2, kick:4, changemission:8, lobby:16, chapter:32, alltalk:64, ALL:127>", FCVAR_NOTIFY, true, 0.0, true, 127.0);
	RegAdminCmd("sm_cvkl_sql_install", Command_CreateSQL, ADMFLAG_ROOT, "Install SQL tables");

	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), DIR_CALLVOTE);
	g_hDatabase = Connect("callvote");
}

Action Command_CreateSQL(int iClient, int iArgs)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}

	char sQuery[600];
	Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `callvote_log` ( \
        `id` int(6) NOT NULL auto_increment, \
        `authid` varchar(64) character set utf8 NOT NULL default '' COMMENT 'Client calling for a vote', \
        `created` int(11) NOT NULL default '0' COMMENT 'Creation date in unix format', \
        `type` int(6) NOT NULL default '0' COMMENT 'Voting type', \
        `authidTarget` varchar(64) character set utf8 NOT NULL default '' COMMENT 'Objective of a kick vote', \
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

void OnConfigsExecuted_SQL()
{
	if (!g_cvarSQL.BoolValue)
		return;

	g_hDatabase = Connect("callvote");
}

/*****************************************************************
			P L U G I N   F U N C T I O N S
*****************************************************************/

bool sqllog(TypeVotes type, int client, int target = 0)
{
	if (!g_cvarSQL.BoolValue)
		return false;

	char
		sSteamID_Client[32],
		sSteamID_Target[32];

	GetClientAuthId(client, AuthId_Engine, sSteamID_Client, sizeof(sSteamID_Client));

	if (type == Kick)
		GetClientAuthId(target, AuthId_Engine, sSteamID_Target, sizeof(sSteamID_Target));
	else
		Format(sSteamID_Target, sizeof(sSteamID_Target), "");

	char sQuery[600];
	g_hDatabase.Format(sQuery, sizeof(sQuery), "INSERT INTO `callvote_log` (`authid`, `created`, `type`, `authidTarget`) VALUES ('%s', '%d', '%d', '%s')",
		   sSteamID_Client, GetTime(), view_as<int>(type), sSteamID_Target);

	if (!SQL_FastQuery(g_hDatabase, sQuery))
	{
		char sError[255];
		SQL_GetError(g_hDatabase, sError, sizeof(sError));
		log(false, "SQL failed: %s", sError);
		log(false, "Query: %s", sQuery);
		return false;
	}
	return true;
}
