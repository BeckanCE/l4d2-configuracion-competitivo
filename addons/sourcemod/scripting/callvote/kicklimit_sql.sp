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

#if defined _callvotekicklimit_sql_included
	#endinput
#endif
#define _callvotekicklimit_sql_included

/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

ConVar
	g_cvarSQL;

DBStatement
	g_hPrepareQuery = null;

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/
public void OnPluginStart_SQL()
{
	g_cvarSQL = CreateConVar("sm_cvkl_sql", "0", "Enables kick counter registration to the database, if disabled it uses local memory.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
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
	Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `callvote_kicklimit` ( \
        `id` int(6) NOT NULL auto_increment, \
        `authid` varchar(64) character set utf8 NOT NULL default '' COMMENT 'Client calling for a vote', \
        `created` int(11) NOT NULL default '0' COMMENT 'Creation date in unix format', \
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

/*****************************************************************
			P L U G I N   F U N C T I O N S
*****************************************************************/

bool sqlinsert(const char[] sClientID, const char[] sTargetID)
{
	if (!g_cvarSQL.BoolValue)
		return false;

	char sQuery[600];
	FormatEx(sQuery, sizeof(sQuery), "INSERT INTO `callvote_kicklimit` (`authid`, `created`, `authidTarget`) VALUES ('%s', '%d', '%s')", sClientID, GetTime(), sTargetID);

	if (!SQL_FastQuery(g_hDatabase, sQuery))
	{
		char sError[255];
		SQL_GetError(g_hDatabase, sError, sizeof(sError));
		log(false, "Query failed: %s", sError);
		log(false, "Query dump: %s", sQuery);
		return false;
	}

	return true;
}

bool GetCountKick(int iClient, const char[] sSteamID)
{
	char error[255];

	/* Check if we haven't already created the statement */
	if (g_hPrepareQuery == null)
	{
		g_hPrepareQuery = SQL_PrepareQuery(g_hDatabase, "SELECT COUNT(*) FROM callvote_kicklimit WHERE created >= UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 1 DAY)) AND authid = ?", error, sizeof(error));
		if (g_hPrepareQuery == null)
		{
			log(false, "Failed to Prepare Query: %s", error);
			return false;
		}
	}

	g_hPrepareQuery.BindString(0, sSteamID, false);
	if (!SQL_Execute(g_hPrepareQuery))
	{
		SQL_GetError(g_hPrepareQuery, error, sizeof(error));
		log(false, "Failed to execute query: %s", error);
		return false;
	}

	/* Get some info here */
	while (SQL_FetchRow(g_hPrepareQuery))
	{
		g_Players[iClient].Kick = SQL_FetchInt(g_hPrepareQuery, 0);
	}
	return true;
}