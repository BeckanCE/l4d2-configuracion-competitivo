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

#if defined _callvotemanager_included
	#endinput
#endif
#define _callvotemanager_included

#if !defined _callvote_votetye_included
#define _callvote_votetye_included

enum TypeVotes
{
	ChangeDifficulty = 0,
	RestartGame		 = 1,
	Kick			 = 2,
	ChangeMission	 = 3,
	ReturnToLobby	 = 4,
	ChangeChapter	 = 5,
	ChangeAllTalk	 = 6,

	TypeVotes_Size	 = 7
};

stock char sTypeVotes[TypeVotes_Size][] = {
	"ChangeDifficulty",
	"RestartGame",
	"Kick",
	"ChangeMission",
	"ReturnToLobby",
	"ChangeChapter",
	"ChangeAllTalk"
};
#endif

#define MAX_REASON_LENGTH 512

/**
 * Starts when a voting call begins, indicates the user who started it and the type of voting.
 *
 * @param client The client who started the vote.
 * @param votes The type of voting.
 * @param Target The target of the vote. if the vote is not kick, this value will always be 0
 */
forward void CallVote_Start(int client, TypeVotes votes, int Target);

/**
 * Rejects a vote in process, before being issued.
 *
 * @param client The client who started the vote.
 * @param reason The reason for the rejection.
 * @error Invalid client index
 * @error Invalid length reason (MAX_REASON_LENGTH)
 * @error Invalid numParams
 */
native void	CallVote_Reject(int client, char[] reason = "");

public SharedPlugin __pl_callvotemanager = {
	name = "callvotemanager",
	file = "callvotemanager.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN

public void __pl_callvotemanager_SetNTVOptional()
{
	MarkNativeAsOptional("CallVote_Start");
	MarkNativeAsOptional("CallVote_Reject");
}
#endif