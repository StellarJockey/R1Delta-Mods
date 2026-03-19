function main()
{
	if ( IsServer() )
	{
		level.musicEvents <- {}
		level.musicEvents[ TEAM_IMC ] <- {}
		level.musicEvents[ TEAM_MILITIA ] <- {}

		Globalize( CreateTeamMusicEvent )
		Globalize( PlayCurrentTeamMusicEventsOnPlayer )

		Globalize( CreateLevelIntroMusicEvent )
		Globalize( CreateLevelWinnerDeterminedMusicEvent )

		GM_AddPreMatchFunc( CreateLevelIntroMusicEvent )
	}

}

function CreateTeamMusicEvent( team, musicPieceID, timeMusicStarted, shouldSeek = true )
{
	//printt( "Creating TeamMusicEvent. Team: " + team + ", musicPieceID: " + musicPieceID + ", timeMusicStarted: " + timeMusicStarted )

	Assert( !( shouldSeek == false && timeMusicStarted > 0 ), "Don't pass in timeMusicStarted when creating a TeamMusicEvent with shouldSeek set to false!" )

	local musicEvent = {}
	musicEvent.musicPieceID 	<- musicPieceID
	musicEvent.timeMusicStarted <- timeMusicStarted
	musicEvent.shouldSeek <- shouldSeek

	level.musicEvents[ team ] = musicEvent
}

function PlayCurrentTeamMusicEventsOnPlayer( player )
{
	//printt( "PlayCurrentTeamMusicEventsOnPlayer" )
	local team = player.GetTeam()
	local musicEvent = level.musicEvents[ team ]
	if (  musicEvent.len() == 0 ) //No current music event
		return

	Remote.CallFunction_NonReplay( player, "ServerCallback_PlayTeamMusicEvent", musicEvent.musicPieceID, musicEvent.timeMusicStarted, musicEvent.shouldSeek )
}

function CreateLevelIntroMusicEvent()
{
	//printt( "Creating LevelIntroMusicEvent" )
	CreateTeamMusicEvent( TEAM_IMC, eMusicPieceID.LEVEL_INTRO, Time() )
	CreateTeamMusicEvent( TEAM_MILITIA, eMusicPieceID.LEVEL_INTRO, Time() )
}

function CreateLevelWinnerDeterminedMusicEvent()
{
	//printt( "Creating CreateLevelWinnerDeterminedMusicEvent - Evac_Themes Override" )

	local winningTeam = GetWinningTeam()

	if (winningTeam)
	{
		local losingTeam = GetOtherTeam(winningTeam)
		printt( "Winning team: " + winningTeam + ", losing team: " + losingTeam )
		
		if ( winningTeam == TEAM_IMC )
		{
			CreateTeamMusicEvent( TEAM_IMC, eMusicPieceID.TF2_EPILOGUE_WIN_IMC, Time() )
			CreateTeamMusicEvent( TEAM_MILITIA, eMusicPieceID.TF2_EPILOGUE_LOSS_MILITIA, Time() )
		}
		else // TEAM_MILITIA
		{
			CreateTeamMusicEvent( TEAM_MILITIA, eMusicPieceID.TF2_EPILOGUE_WIN_MILITIA, Time() )
			CreateTeamMusicEvent( TEAM_IMC, eMusicPieceID.TF2_EPILOGUE_LOSS_IMC, Time() )
		}
	}
	else
	{
		CreateTeamMusicEvent( TEAM_MILITIA, eMusicPieceID.LEVEL_DRAW, Time() )
		CreateTeamMusicEvent( TEAM_IMC, eMusicPieceID.LEVEL_DRAW, Time() )
	}
}