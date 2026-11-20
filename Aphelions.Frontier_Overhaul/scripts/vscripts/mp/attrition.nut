function main() // FO
{
	Globalize( ScriptCallback_OnClientConnecting )
	Globalize( Attrition_OnPlayerOrNPCKilled )
	Globalize( ShowPlayerAttritionScoreEvent )

	AddCallback_PlayerOrNPCKilled( Attrition_OnPlayerOrNPCKilled )
	level.spawnRatingFunc_Pilot = RateFrontLinePlayerSpawnpoint
	level.spawnRatingFunc_Generic = RateFrontLinePlayerSpawnpoint

	SetGameModeAnnouncement( "GameModeAnnounce_AT" )
	AddCallback_OnTitanDoomed( Attrition_OnTitanDoomed )

	//thread MatchProgressThink()
}

function EntitiesDidLoad()
{
	//printl("running EntitiesDidLoad() in team_deathmatch.nut" )
	SetupAssaultPointKeyValues()

	//no turrets in TDM for now
	local turrets = GetNPCArrayByClass( "npc_turret_sentry" )
	foreach( turret in turrets )
	{
		turret.DisableTurret()
	}

	//monitor population and respawns
	thread SetupTeamDeathmatchNPCs()
}

function Attrition_OnTitanDoomed( victim, damageInfo )
{
	if ( !GamePlaying() )
		return

	local attacker = GetAttackerOrLastAttacker( victim, damageInfo )
	if ( !IsValid( attacker ) )
		return

	local scorer = GetAttackerPlayerOrBossPlayer( attacker )
	if ( !IsValid( scorer ) )
		scorer = attacker	// NPC with no owner: team score only

	if ( scorer.GetTeam() != GetOtherTeam(victim))
		return

	local scoreVal = ATTRITION_SCORE_TITAN
	GameScore.AddTeamScore( scorer.GetTeam(), scoreVal )

	if ( scorer.IsPlayer() )
	{
		ShowPlayerAttritionScoreEvent( scorer, scoreVal )
		scorer.SetAssaultScore( scorer.GetAssaultScore() + scoreVal )
	}
}

function ScriptCallback_OnClientConnecting( player )
{
}

function MatchProgressThink()
{
	FlagWait( "GamePlaying" )

	while ( GetGameState() == eGameState.Playing )
	{
		local militiaProgress = GetMatchProgress_Score( TEAM_MILITIA )
		if ( militiaProgress > 70 )
			FlagSet( "Disable_MILITIA" )

		local imcProgress = GetMatchProgress_Score( TEAM_IMC )
		if ( imcProgress > 70 )
			FlagSet( "Disable_IMC" )

		wait 0.1
	}
}

function Attrition_OnPlayerOrNPCKilled( victim, attacker, damageInfo )
{
    // Only players or NPCs can grant points
    if ( !( attacker.IsPlayer() ) && !( attacker.IsNPC() ) )
        return

    local attackerTeam = attacker.GetTeam()
    local victimTeam = victim.GetTeam()

    if ( victimTeam == attackerTeam )
        return

    if ( victimTeam != TEAM_MILITIA && victimTeam != TEAM_IMC )
        return

    if ( GetGameState() != eGameState.Playing )
        return

	if ( GetGameState() != eGameState.Playing )
		return

	if ( victim.IsTitan() && !victim.IsPlayer() )
	{
		if ( ( "isFO_Titan" in victim.s || "pilotIsNPCCaptain" in victim.s )
			&& !( "npcPilotEjected" in victim.s )
			&& !( "pilotHandledByExecution" in victim.s )
			&& damageInfo.GetDamageSourceIdentifier() != eDamageSourceId.titan_execution )
			Attrition_AwardPilotTermination( attacker, victim )

		return
	}

    if ( victim.IsMarvin() )
        return

    local scoreVal = GetAttritionScore( attacker, victim )

    // Show splash only to players or to their "boss player"
    if ( attacker.IsPlayer() )
    {
        ShowPlayerAttritionScoreEvent( attacker, scoreVal )
    }
    else if ( attacker.IsNPC() )
    {
        local bossPlayer = attacker.GetBossPlayer()
        if ( IsValid( bossPlayer ) )
            ShowPlayerAttritionScoreEvent( bossPlayer, scoreVal )
    }

    GameScore.AddTeamScore( attackerTeam, scoreVal )

    // Only players have AssaultScore
    if ( attacker.IsPlayer() )
        attacker.SetAssaultScore( attacker.GetAssaultScore() + scoreVal )
}

/* ORIGINAL FUNCTION FOR NON-SCORING NPCS
function Attrition_OnPlayerOrNPCKilled( victim, attacker, damageInfo )
{
	if ( !( attacker.IsPlayer() ) )
		return

	local attackerTeam = attacker.GetTeam()
	local victimTeam = victim.GetTeam()

	if ( victim.GetTeam() == attackerTeam )
		return

	if ( victimTeam != TEAM_MILITIA && victimTeam != TEAM_IMC )
		return

	if ( GetGameState() != eGameState.Playing )
		return

	if ( victim.IsTitan() && !victim.IsPlayer() )
		return

	if ( victim.IsMarvin() )
		return

 	local scoreVal = GetAttritionScore( attacker, victim )
	ShowPlayerAttritionScoreEvent( attacker, scoreVal )

	GameScore.AddTeamScore( attacker.GetTeam(), scoreVal )
	attacker.SetAssaultScore( attacker.GetAssaultScore() + scoreVal )
}
*/

function ShowPlayerAttritionScoreEvent( player, value )
{
	local event = ScoreEventFromName( "AttritionPoints" )
	local scoreEventInt = event.GetInt()

	Remote.CallFunction_NonReplay( player, "ServerCallback_PointSplash", scoreEventInt, null, value )
}

function Attrition_AwardPilotTermination( attacker, titan, isCaptain = false )
{
	if ( GameRules.GetGameMode() != ATTRITION )
		return

	if ( GetGameState() != eGameState.Playing )
		return

	if ( !IsValid( attacker ) )
		return

	local attackerTeam = attacker.GetTeam()

	if ( IsValid( titan ) && titan.GetTeam() == attackerTeam )
		return

	local scoreVal = ATTRITION_SCORE_PILOT
	if ( isCaptain || ( IsValid( titan ) && "pilotIsNPCCaptain" in titan.s ) )
		scoreVal = ATTRITION_SCORE_GRUNT

	if ( attacker.IsPlayer() )
	{
		ShowPlayerAttritionScoreEvent( attacker, scoreVal )
		attacker.SetAssaultScore( attacker.GetAssaultScore() + scoreVal )
	}
	else if ( attacker.IsNPC() )
	{
		local bossPlayer = attacker.GetBossPlayer()
		if ( IsValid( bossPlayer ) )
			ShowPlayerAttritionScoreEvent( bossPlayer, scoreVal )
	}
	GameScore.AddTeamScore( attackerTeam, scoreVal )
}
Globalize( Attrition_AwardPilotTermination )