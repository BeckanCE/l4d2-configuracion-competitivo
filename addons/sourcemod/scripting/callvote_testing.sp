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

#define PLUGIN_VERSION	"1.2"
#define TAG				"[{olive}CallVote Debug{default}]"

ConVar
	g_cvarForwardManager,
	g_cvarVoteStarted,
	g_cvarVoteEnded,
	g_cvarVoteChanged,
	g_cvarVotePassed,
	g_cvarVoteFailed,
	g_cvarVoteCastYes,
	g_cvarVoteCastNo,
	g_cvarVoteStart,
	g_cvarVotePass,
	g_cvarVoteFail,
	g_cvarVoteRegistered,
	g_cvarCallVoteFailed,
	g_cvarListenerVote,
	g_cvarListenerCallVote;

/*****************************************************************
			P L U G I N   I N F O
*****************************************************************/

/**
 * Plugin information properties. Plugins can declare a global variable with
 * their info. Example,
 * SourceMod will display this information when a user inspects plugins in the
 * console.
 */
public Plugin myinfo =
{
	name		= "Call Vote Testing",
	author		= "lechuga",
	description = "Performs callvote manager forward testing",
	version		= PLUGIN_VERSION,
	url			= "https://github.com/lechuga16/callvote_manager"

}

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/

/**
 * Called when the plugin is fully initialized and all known external references
 * are resolved. This is only called once in the lifetime of the plugin, and is
 * paired with OnPluginEnd().
 *
 * If any run-time error is thrown during this callback, the plugin will be marked
 * as failed.
 */
public void OnPluginStart()
{
	CreateConVar("sm_cvt_version", PLUGIN_VERSION, "Plugin version", FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);
	g_cvarLog			   = CreateConVar("sm_cvt_logs", "1", "Enable logging", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarDebug			   = CreateConVar("sm_cvt_debug", "0", "Enable debug", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarForwardManager   = CreateConVar("sm_cvt_forwardmanager", "1", "Enable manager forwards", FCVAR_NONE, true, 0.0, true, 1.0);

	g_cvarVoteStarted	   = CreateConVar("sm_cvt_votestarted", "1", "Enable vote_started event", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarVoteEnded		   = CreateConVar("sm_cvt_voteended", "1", "Enable vote_ended event", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarVoteChanged	   = CreateConVar("sm_cvt_votechanged", "1", "Enable vote_changed event", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarVotePassed	   = CreateConVar("sm_cvt_votepassed", "1", "Enable vote_passed event", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarVoteFailed	   = CreateConVar("sm_cvt_votefailed", "1", "Enable vote_failed event", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarVoteCastYes	   = CreateConVar("sm_cvt_votecastyes", "1", "Enable vote_cast_yes event", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarVoteCastNo	   = CreateConVar("sm_cvt_votecastno", "1", "Enable vote_cast_no event", FCVAR_NONE, true, 0.0, true, 1.0);

	g_cvarVoteStart		   = CreateConVar("sm_cvt_votestart", "1", "Enable VoteStart message", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarVotePass		   = CreateConVar("sm_cvt_votepass", "1", "Enable VotePass message", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarVoteFail		   = CreateConVar("sm_cvt_votefail", "1", "Enable VoteFail message", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarVoteRegistered   = CreateConVar("sm_cvt_voteregistered", "1", "Enable VoteRegistered message", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarCallVoteFailed   = CreateConVar("sm_cvt_callvotefailed", "1", "Enable CallVoteFailed message", FCVAR_NONE, true, 0.0, true, 1.0);

	g_cvarListenerVote	   = CreateConVar("sm_cvt_listenervote", "0", "Enable Vote listener", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarListenerCallVote = CreateConVar("sm_cvt_listenercallvote", "0", "Enable CallVote listener", FCVAR_NONE, true, 0.0, true, 1.0);

	HookEvent("vote_started", Event_VoteStarted);
	HookEvent("vote_ended", Event_VoteEnded);
	HookEvent("vote_changed", Event_VoteChanged);
	HookEvent("vote_passed", Event_VotePassed);
	HookEvent("vote_failed", Event_VoteFailed);
	HookEvent("vote_cast_yes", Event_VoteCastYes);
	HookEvent("vote_cast_no", Event_VoteCastNo);

	HookUserMessage(GetUserMessageId("VoteStart"), Message_VoteStart);
	HookUserMessage(GetUserMessageId("VotePass"), Message_VotePass);
	HookUserMessage(GetUserMessageId("VoteFail"), Message_VoteFail);
	HookUserMessage(GetUserMessageId("VoteRegistered"), Message_VoteRegistered);
	HookUserMessage(GetUserMessageId("CallVoteFailed"), Message_CallVoteFailed);

	AddCommandListener(Listener_Vote, "Vote");
	AddCommandListener(Listener_CallVote, "callvote");

	// Build log path
	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), DIR_CALLVOTE);
}

public void CallVote_Start(int iClient, TypeVotes votes, int iTarget)
{
	if (!g_cvarForwardManager.BoolValue)
		return;

	// Get the client's SteamID
	char sSteamID[MAX_AUTHID_LENGTH];
	GetClientAuthId(iClient, AuthId_Engine, sSteamID, MAX_AUTHID_LENGTH);

	char
		sMessage[255];

	if (votes == Kick)
	{
		Format(sMessage, sizeof(sMessage), "%s CallVoteManager {green}%s{default}: {blue}%N{default} ({blue}%s{default}) ({blue}%N{default}) called the vote.", TAG, sTypeVotes[votes], iClient, sSteamID, iTarget);
		CPrintToChatAll(sMessage);
		CRemoveTags(sMessage, sizeof(sMessage));
		log(false, sMessage);
	}
	else
	{
		Format(sMessage, sizeof(sMessage), "%s CallVoteManager {green}%s{default}: {blue}%N{default} ({blue}%s{default}) called the vote.", TAG, sTypeVotes[votes], iClient, sSteamID);
		CPrintToChatAll(sMessage);
		CRemoveTags(sMessage, sizeof(sMessage));
		log(false, sMessage);
	}
}

/*
 * vote_started
 *
 *	"issue"                 "string"
 *	"param1"                "string"
 *	"team"                  "byte"
 *	"initiator"             "long" // entity id of the player who initiated the vote
 *
 */
public void Event_VoteStarted(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_cvarVoteStarted.BoolValue)
		return;

	char sIssue[128];
	char sParam1[128];

	hEvent.GetString("issue", sIssue, 128);
	hEvent.GetString("param1", sParam1, 128);
	int iTeam	   = hEvent.GetInt("team");
	int iInitiator = hEvent.GetInt("initiator");
	CPrintToChatAll("%s VoteStarted: issue: %s, param1: %s, team: %d, initiator: %d", TAG, sIssue, sParam1, iTeam, iInitiator);
	log(false, "VoteStarted: issue: %s, param1: %s, team: %d, initiator: %d", sIssue, sParam1, iTeam, iInitiator);
}

/*
 * vote_ended"
 */
public void Event_VoteEnded(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_cvarVoteEnded.BoolValue)
		return;

	CPrintToChatAll("%s VoteEnded", TAG);
	log(false, "VoteEnded");
}

/*
 * vote_changed"
 *
 *	"yesVotes"		"byte"
 *	"noVotes"		"byte"
 *	"potentialVotes"	"byte"
 *
 */
public void Event_VoteChanged(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_cvarVoteChanged.BoolValue)
		return;

	int iYesVotes		= hEvent.GetInt("yesVotes");
	int iNoVotes		= hEvent.GetInt("noVotes");
	int iPotentialVotes = hEvent.GetInt("potentialVotes");
	CPrintToChatAll("%s VoteChanged: yesVotes: %d, noVotes: %d, potentialVotes: %d", TAG, iYesVotes, iNoVotes, iPotentialVotes);
	log(false, "VoteChanged: yesVotes: %d, noVotes: %d, potentialVotes: %d", iYesVotes, iNoVotes, iPotentialVotes);
}

/*
 * vote_passed
 *
 *	"details"               "string"
 *	"param1"                "string"
 *	"team"                  "byte"
 *
 */
public void Event_VotePassed(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_cvarVotePassed.BoolValue)
		return;

	char sDetails[128];
	char sParam1[128];

	hEvent.GetString("details", sDetails, 128);
	hEvent.GetString("param1", sParam1, 128);
	int iTeam = hEvent.GetInt("team");
	CPrintToChatAll("%s VotePassed: details: %s, param1: %s, team: %d", TAG, sDetails, sParam1, iTeam);
	log(false, "VotePassed: details: %s, param1: %s, team: %d", sDetails, sParam1, iTeam);
}

/*
 * vote_failed
 *
 *	"team"                  "byte"
 *
 */
public void Event_VoteFailed(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_cvarVoteFailed.BoolValue)
		return;

	int iTeam = hEvent.GetInt("team");
	CPrintToChatAll("%s VoteFailed: team: %d", TAG, iTeam);
	log(false, "VoteFailed: team: %d", iTeam);
}

/*
 * vote_cast_yes
 *
 *	"team"			"byte"
 *	"entityid"		"long"	// entity id of the voter
 *
 */
public void Event_VoteCastYes(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_cvarVoteCastYes.BoolValue)
		return;

	int iEntityid = hEvent.GetInt("entityid");
	int iTeam	  = GetClientTeam(iEntityid);

	if (!IsValidClientIndex(iEntityid))
		return;

	log(false, "VoteCastYes: team: %d, entityid: %d", iTeam, iEntityid);
	CPrintToChatAll("%s VoteCastYes: team: %d, entityid: %d", TAG, iTeam, iEntityid);
}

/*
 * vote_cast_no
 *
 * "team"			"byte"
 * "entityid"		"long"	// entity id of the voter
 *
 */
public void Event_VoteCastNo(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_cvarVoteCastNo.BoolValue)
		return;

	int iEntityid = hEvent.GetInt("entityid");
	int iTeam	  = GetClientTeam(iEntityid);

	if (!IsValidClientIndex(iEntityid))
		return;

	log(false, "VoteCastNo: team: %d, entityid: %d", iTeam, iEntityid);
	CPrintToChatAll("%s VoteCastNo: team: %d, entityid: %d", TAG, iTeam, iEntityid);
}

/*
 * VoteStart Structure
 *	- Byte      Team index voting
 *	- Byte      Unknown, always 1 for Yes/No, always 99 for Multiple Choice
 *	- String    Vote issue id
 *	- String    Vote issue text
 *	- Bool      false for Yes/No, true for Multiple choice
 */
public Action Message_VoteStart(UserMsg hMsg_id, BfRead hBf, const int[] iPlayers, int iPlayersNum, bool bReliable, bool bInit)
{
	if (!g_cvarVoteStart.BoolValue)
		return Plugin_Continue;

	char sIssue[128];
	char sParam1[128];
	char sInitiatorName[128];

	int	 iTeam		= BfReadByte(hBf);
	int	 iInitiator = BfReadByte(hBf);
	hBf.ReadString(sIssue, 128);
	hBf.ReadString(sParam1, 128);
	hBf.ReadString(sInitiatorName, 128);

	DataPack hdataPack;
	CreateDataTimer(0.1, Timer_CallVote_Start, hdataPack, TIMER_FLAG_NO_MAPCHANGE);
	hdataPack.WriteCell(iPlayersNum);
	hdataPack.WriteCell(iTeam);
	hdataPack.WriteCell(iInitiator);
	hdataPack.WriteString(sIssue);
	hdataPack.WriteString(sParam1);
	hdataPack.WriteString(sInitiatorName);

	log(false, "VoteStart(sent to %d users): team: %d, initiator: %d, issue: %s, param1: %s, initiatorName: %s", iPlayersNum, iTeam, iInitiator, sIssue, sParam1, sInitiatorName);
	return Plugin_Continue;
}

Action Timer_CallVote_Start(Handle timer, DataPack datapack)
{
	datapack.Reset();
	int
		iPlayersNum = datapack.ReadCell(),
		iTeam		= datapack.ReadCell(),
		iInitiator	= datapack.ReadCell();
	char
		sIssue[128],
		sParam1[128],
		sInitiatorName[128];

	datapack.ReadString(sIssue, 128);
	datapack.ReadString(sParam1, 128);
	datapack.ReadString(sInitiatorName, 128);

	CPrintToChatAll("%s VoteStart(sent to %d users): team: %d, initiator: %d, issue: %s, param1: %s, initiatorName: %s", TAG, iPlayersNum, iTeam, iInitiator, sIssue, sParam1, sInitiatorName);
	return Plugin_Stop;
}

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
	if (!g_cvarVotePass.BoolValue)
		return Plugin_Continue;

	char sIssue[128];
	char sParam1[128];
	int	 iTeam = hBf.ReadByte();
	hBf.ReadString(sIssue, 128);
	hBf.ReadString(sParam1, 128);

	DataPack hdataPack;
	CreateDataTimer(0.1, Timer_CallVote_Pass, hdataPack, TIMER_FLAG_NO_MAPCHANGE);
	hdataPack.WriteCell(iPlayersNum);
	hdataPack.WriteCell(iTeam);
	hdataPack.WriteString(sIssue);
	hdataPack.WriteString(sParam1);

	log(false, "VotePass(sent to %d users): team: %d, issue: %s, param1: %s", iPlayersNum, iTeam, sIssue, sParam1);
	return Plugin_Continue;
}

Action Timer_CallVote_Pass(Handle timer, DataPack datapack)
{
	datapack.Reset();
	int
		iPlayersNum = datapack.ReadCell(),
		iTeam		= datapack.ReadCell();
	char
		sIssue[128],
		sParam1[128];

	datapack.ReadString(sIssue, 128);
	datapack.ReadString(sParam1, 128);

	CPrintToChatAll("%s VotePass(sent to %d users): team: %d, issue: %s, param1: %s", TAG, iPlayersNum, iTeam, sIssue, sParam1);
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
	if (!g_cvarVoteFail.BoolValue)
		return Plugin_Continue;

	char sIssue[128];
	char sParam1[128];
	int	 iTeam = hBf.ReadByte();
	hBf.ReadString(sIssue, 128);
	hBf.ReadString(sParam1, 128);

	DataPack hdataPack;
	CreateDataTimer(0.1, Timer_CallVote_Fail, hdataPack, TIMER_FLAG_NO_MAPCHANGE);
	hdataPack.WriteCell(iPlayersNum);
	hdataPack.WriteCell(iTeam);
	hdataPack.WriteString(sIssue);
	hdataPack.WriteString(sParam1);

	log(false, "VotePass(sent to %d users): team: %d, issue: %s, param1: %s", iPlayersNum, iTeam, sIssue, sParam1);
	return Plugin_Continue;
}

Action Timer_CallVote_Fail(Handle timer, DataPack datapack)
{
	datapack.Reset();
	int
		iPlayersNum = datapack.ReadCell(),
		iTeam		= datapack.ReadCell();
	char
		sIssue[128],
		sParam1[128];

	datapack.ReadString(sIssue, 128);
	datapack.ReadString(sParam1, 128);

	CPrintToChatAll("%s VoteFail(sent to %d users): team: %d, issue: %s, param1: %s", TAG, iPlayersNum, iTeam, sIssue, sParam1);
	return Plugin_Stop;
}

/*
 * CallVoteFailed
 *    - Byte		Team index voting
 *   - Short		Failure reason code
 */
public Action Message_CallVoteFailed(UserMsg hMsg_id, BfRead hBf, const int[] iPlayers, int iPlayersNum, bool bReliable, bool bInit)
{
	if (!g_cvarCallVoteFailed.BoolValue)
		return Plugin_Continue;

	int		 iReason	= BfReadByte(hBf);
	int		 iTime		= BfReadShort(hBf);
	int		 iBytesLeft = BfReadByte(hBf);

	DataPack hdataPack;
	CreateDataTimer(0.1, Timer_CallVoteFailed, hdataPack, TIMER_FLAG_NO_MAPCHANGE);
	hdataPack.WriteCell(iPlayersNum);
	hdataPack.WriteCell(iReason);
	hdataPack.WriteCell(iTime);
	hdataPack.WriteCell(iBytesLeft);

	log(false, "CallVoteFailed(sent to %d users): reason: %d, time: %d, bytes: %d", iPlayersNum, iReason, iTime, iBytesLeft);
	return Plugin_Continue;
}

Action Timer_CallVoteFailed(Handle timer, DataPack datapack)
{
	datapack.Reset();
	int
		iPlayersNum = datapack.ReadCell(),
		iReason		= datapack.ReadCell(),
		iTime		= datapack.ReadCell(),
		iBytesLeft	= datapack.ReadCell();

	CPrintToChatAll("%s CallVoteFailed(sent to %d users): reason: %d, time: %d, bytes: %d", TAG, iPlayersNum, iReason, iTime, iBytesLeft);
	return Plugin_Stop;
}

/*
 * VoteRegistered
 *    - Byte		Item selected
 */
public Action Message_VoteRegistered(UserMsg hMsg_id, BfRead hBf, const int[] iPlayers, int iPlayersNum, bool bReliable, bool bInit)
{
	if (!g_cvarVoteRegistered.BoolValue)
		return Plugin_Continue;

	int		 iItem = BfReadByte(hBf);

	DataPack hdataPack;
	CreateDataTimer(0.1, Timer_VoteRegistered, hdataPack, TIMER_FLAG_NO_MAPCHANGE);
	hdataPack.WriteCell(iPlayersNum);
	hdataPack.WriteCell(iItem);

	log(false, "VoteRegistered(sent to %d users): item: %d", iPlayersNum, iItem);
	return Plugin_Continue;
}

Action Timer_VoteRegistered(Handle timer, DataPack datapack)
{
	datapack.Reset();
	int
		iPlayersNum = datapack.ReadCell(),
		iItem		= datapack.ReadCell();

	CPrintToChatAll("%s VoteRegistered(sent to %d users): item: %d", TAG, iPlayersNum, iItem);
	return Plugin_Stop;
}

/**
 * Listener_Vote - Called when a vote is casted by a player.
 *
 * @param iClient The client index of the player who casted the vote.
 * @param sCommand The command string that triggered the vote.
 * @param iArgc The number of arguments passed with the vote command.
 *
 * @return Plugin_Continue to allow other plugins to process the vote, Plugin_Handled to stop other plugins from processing the vote.
 */
public Action Listener_Vote(int iClient, const char[] sCommand, int iArgc)
{
	if (!g_cvarListenerVote.BoolValue)
		return Plugin_Continue;

	char sVote[255];
	GetCmdArg(1, sVote, 255);

	CPrintToChatAll("%s Vote: client: %N, vote: %s", TAG, iClient, sVote);
	log(false, "Vote: client: %N, vote: %s", iClient, sVote);
	return Plugin_Continue;
}

/**
 * Listener_CallVote - Called when a player calls a vote.
 *
 * @param iClient The client index of the player who called the vote.
 * @param sCommand The command string that was used to call the vote.
 * @param iArgc The number of arguments passed with the command.
 *
 * @return Plugin_Continue to allow other plugins to process the vote, or Plugin_Handled to stop processing.
 */
public Action Listener_CallVote(int iClient, const char[] sCommand, int iArgc)
{
	if (!g_cvarListenerCallVote.BoolValue)
		return Plugin_Continue;

	char sVoteType[32];
	char sVoteArgument[32];

	GetCmdArg(1, sVoteType, sizeof(sVoteType));
	GetCmdArg(2, sVoteArgument, sizeof(sVoteArgument));

	CPrintToChatAll("%s CallVote: client: %N, votetype: %s, sVoteArgument: %s", TAG, iClient, sVoteType, sVoteArgument);
	log(false, "CallVote: client: %N, votetype: %s, sVoteArgument: %s", iClient, sVoteType, sVoteArgument);
	return Plugin_Continue;
}