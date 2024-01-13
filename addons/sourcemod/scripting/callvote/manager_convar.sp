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

#if defined _callvotemanager_convar_included
	#endinput
#endif
#define _callvotemanager_convar_included

/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

ConVar
	sv_vote_issue_change_difficulty_allowed,
	sv_vote_issue_restart_game_allowed,
	sv_vote_issue_kick_allowed,
	sv_vote_issue_change_mission_allowed,
	sv_vote_kick_ban_duration,
	sv_vote_creation_timer,
	sv_vote_timer_duration,
	sv_allow_votes,

	z_difficulty;

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/

public void OnPluginStart_ConVar()
{
	sv_vote_issue_change_difficulty_allowed = FindConVar("sv_vote_issue_change_difficulty_allowed");
	sv_vote_issue_change_difficulty_allowed.AddChangeHook(ConVarChanged_Difficulty);
	g_cvarDifficulty.AddChangeHook(ConVarChanged_Difficulty);

	sv_vote_issue_restart_game_allowed = FindConVar("sv_vote_issue_restart_game_allowed");
	sv_vote_issue_restart_game_allowed.AddChangeHook(ConVarChanged_Restart);
	g_cvarRestart.AddChangeHook(ConVarChanged_Restart);

	sv_vote_issue_change_mission_allowed = FindConVar("sv_vote_issue_change_mission_allowed");
	sv_vote_issue_change_mission_allowed.AddChangeHook(ConVarChanged_Mission);
	g_cvarMission.AddChangeHook(ConVarChanged_Mission);

	sv_vote_issue_kick_allowed = FindConVar("sv_vote_issue_kick_allowed");
	sv_vote_issue_kick_allowed.AddChangeHook(ConVarChanged_Kick);
	g_cvarKick.AddChangeHook(ConVarChanged_Kick);

	sv_vote_kick_ban_duration = FindConVar("sv_vote_kick_ban_duration");
	sv_vote_kick_ban_duration.AddChangeHook(ConVarChanged_BanDuration);
	g_cvarBanDuration.AddChangeHook(ConVarChanged_BanDuration);

	g_cvarAdminInmunity.AddChangeHook(ConVarChanged_AdminInmunity);
	g_cvarVipInmunity.AddChangeHook(ConVarChanged_VipInmunity);

	sv_vote_creation_timer = FindConVar("sv_vote_creation_timer");
	sv_vote_creation_timer.AddChangeHook(ConVarChanged_CreationTimer);
	g_cvarCreationTimer.AddChangeHook(ConVarChanged_CreationTimer);

	sv_vote_timer_duration = FindConVar("sv_vote_timer_duration");
	sv_vote_timer_duration.AddChangeHook(ConVarChanged_VoteDuration);
	g_cvarVoteDuration.AddChangeHook(ConVarChanged_VoteDuration);

	sv_allow_votes = FindConVar("sv_allow_votes");
	sv_allow_votes.AddChangeHook(ConVarChanged_AllowVotes);
	g_cvarEnable.AddChangeHook(ConVarChanged_AllowVotes);

	z_difficulty = FindConVar("z_difficulty");
}

public void ConVarChanged_Difficulty(Handle hConVar, const char[] sOldValue, const char[] sNewValue)
{
	bool bNewValue = view_as<bool>(StringToInt(sNewValue));

	g_cvarDifficulty.SetBool(bNewValue);
	sv_vote_issue_change_difficulty_allowed.SetBool(bNewValue);
}

public void ConVarChanged_Restart(Handle hConVar, const char[] sOldValue, const char[] sNewValue)
{
	bool bNewValue = view_as<bool>(StringToInt(sNewValue));

	g_cvarRestart.SetBool(bNewValue);
	sv_vote_issue_restart_game_allowed.SetBool(bNewValue);
}

public void ConVarChanged_Kick(Handle hConVar, const char[] sOldValue, const char[] sNewValue)
{
	bool bNewValue = view_as<bool>(StringToInt(sNewValue));

	g_cvarKick.SetBool(bNewValue);
	sv_vote_issue_kick_allowed.SetBool(bNewValue);
}

public void ConVarChanged_Mission(Handle hConVar, const char[] sOldValue, const char[] sNewValue)
{
	bool bNewValue = view_as<bool>(StringToInt(sNewValue));

	g_cvarMission.SetBool(bNewValue);
	sv_vote_issue_change_mission_allowed.SetBool(bNewValue);
}

public void ConVarChanged_BanDuration(Handle hConVar, const char[] sOldValue, const char[] sNewValue)
{
	bool bNewValue = view_as<bool>(StringToInt(sNewValue));

	g_cvarBanDuration.SetBool(bNewValue);
	sv_vote_kick_ban_duration.SetBool(bNewValue);
}

public void ConVarChanged_AdminInmunity(Handle hConVar, const char[] sOldValue, const char[] sNewValue)
{
	char sTempAdmin[32];
	g_cvarAdminInmunity.GetString(sTempAdmin, sizeof(sTempAdmin));
	g_iFlagsAdmin = ReadFlagString(sTempAdmin);
}

public void ConVarChanged_VipInmunity(Handle hConVar, const char[] sOldValue, const char[] sNewValue)
{
	char sTempVip[32];
	g_cvarVipInmunity.GetString(sTempVip, sizeof(sTempVip));
	g_iFlagsVip = ReadFlagString(sTempVip);
}

public void ConVarChanged_CreationTimer(Handle hConVar, const char[] sOldValue, const char[] sNewValue)
{
	bool bNewValue = view_as<bool>(StringToInt(sNewValue));

	g_cvarCreationTimer.SetBool(bNewValue);
	sv_vote_creation_timer.SetBool(bNewValue);
}

public void ConVarChanged_VoteDuration(Handle hConVar, const char[] sOldValue, const char[] sNewValue)
{
	bool bNewValue = view_as<bool>(StringToInt(sNewValue));

	g_cvarVoteDuration.SetBool(bNewValue);
	sv_vote_timer_duration.SetBool(bNewValue);
}

public void ConVarChanged_AllowVotes(Handle hConVar, const char[] sOldValue, const char[] sNewValue)
{
	bool bNewValue = view_as<bool>(StringToInt(sNewValue));

	g_cvarEnable.SetBool(bNewValue);
	sv_allow_votes.SetBool(bNewValue);
}

public void OnConfigsExecuted_ConVar()
{
	if (g_cvarDifficulty.BoolValue != sv_vote_issue_change_difficulty_allowed.BoolValue)
		sv_vote_issue_change_difficulty_allowed.SetBool(g_cvarDifficulty.BoolValue);

	if (g_cvarRestart.BoolValue != sv_vote_issue_restart_game_allowed.BoolValue)
		sv_vote_issue_restart_game_allowed.SetBool(g_cvarRestart.BoolValue);


	if (g_cvarKick.BoolValue != sv_vote_issue_kick_allowed.BoolValue)
		sv_vote_issue_kick_allowed.SetBool(g_cvarKick.BoolValue);


	if (g_cvarMission.BoolValue != sv_vote_issue_change_mission_allowed.BoolValue)
		sv_vote_issue_change_mission_allowed.SetBool(g_cvarMission.BoolValue);

	if(g_cvarEnable.BoolValue != sv_allow_votes.BoolValue)
		sv_allow_votes.SetBool(g_cvarEnable.BoolValue);

	if (g_cvarBanDuration.IntValue > -1 && (g_cvarBanDuration.IntValue != sv_vote_kick_ban_duration.IntValue))
		sv_vote_kick_ban_duration.SetInt(g_cvarBanDuration.IntValue);

	if (g_cvarCreationTimer.IntValue > -1 && (g_cvarCreationTimer.IntValue != sv_vote_creation_timer.IntValue))
		sv_vote_creation_timer.SetInt(g_cvarCreationTimer.IntValue);

	if (g_cvarVoteDuration.IntValue > -1 && (g_cvarVoteDuration.IntValue != sv_vote_timer_duration.IntValue))
		sv_vote_timer_duration.SetInt(g_cvarVoteDuration.IntValue);
	else if (g_cvarVoteDuration.IntValue == -1)
		sv_vote_timer_duration.RestoreDefault();

	char
		sTempAdmin[32],
		sTempVip[32];
	g_cvarAdminInmunity.GetString(sTempAdmin, sizeof(sTempAdmin));
	g_iFlagsAdmin = ReadFlagString(sTempAdmin);

	g_cvarVipInmunity.GetString(sTempVip, sizeof(sTempVip));
	g_iFlagsVip = ReadFlagString(sTempVip);
}