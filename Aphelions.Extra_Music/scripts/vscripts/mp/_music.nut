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
    CreateTeamMusicEvent( TEAM_IMC, eMusicPieceID.LEVEL_INTRO, Time() )
    CreateTeamMusicEvent( TEAM_MILITIA, eMusicPieceID.LEVEL_INTRO, Time() )

    local imcLongPool = [
        "Music_IMC_Intro_Long_1",
        "Music_IMC_Intro_Long_2",
    ]

    local militiaLongPool = [
        "Music_Militia_Intro_Long_1",
        "Music_Militia_Intro_Long_2",
    ]

    HandleTeamIntro( TEAM_IMC, "Music_IMC_Intro_Standard", imcLongPool )
    HandleTeamIntro( TEAM_MILITIA, "Music_Militia_Intro_Standard", militiaLongPool )
}

function HandleTeamIntro( team, standardAlias, longPool )
{
    local totalOptions = longPool.len() + 1
    local choice = RandomInt( totalOptions )
    local players = GetPlayerArrayOfTeam( team )

    foreach ( player in players )
    {
        if ( choice == 0 )
        {
            // Play standard 25s track
            EmitSoundOnEntity( player, standardAlias )
        }
        else
        {
            // Pick from the long pool and start the fade thread
            local selectedAlias = longPool[ choice - 1 ]
            thread PlayAndFadeCustomTrack( player, selectedAlias )
        }
    }
}

function PlayAndFadeCustomTrack( player, alias )
{
    if ( !IsValid( player ) )
        return

    EmitSoundOnEntity( player, alias )

    // Total 25s length (20s full volume + 5s fade)
    wait 20
    FadeOutSoundOnEntity( player, alias, 5.0 )

    wait 6.0
    StopSoundOnEntity( player, alias )
}


function CreateLevelWinnerDeterminedMusicEvent()
{
	//printt( "Creating CreateLevelWinnerDeterminedMusicEvent" )

	local winningTeam = GetWinningTeam()

	if (winningTeam)
	{
		local losingTeam = GetOtherTeam(winningTeam)
		printt( "Winning team: " + winningTeam + ", losing team: " + losingTeam )
		CreateTeamMusicEvent( winningTeam, eMusicPieceID.LEVEL_WIN, Time() )
		CreateTeamMusicEvent( losingTeam, eMusicPieceID.LEVEL_LOSS, Time() )
	}
	else
	{
		CreateTeamMusicEvent( TEAM_MILITIA, eMusicPieceID.LEVEL_DRAW, Time() )
		CreateTeamMusicEvent( TEAM_IMC, eMusicPieceID.LEVEL_DRAW, Time() )
	}
}

function PlayAndFadeIMCIntro( player )
{
    // Ensure we are talking to a valid player entity
    if ( !IsValid( player ) )
        return

    local soundAlias = "Music_Custom_IMC_Intro"

    EmitSoundOnEntity( player, soundAlias )

    wait 15.0

    FadeOutSoundOnEntity( player, soundAlias, 5.0 )
	
    wait 5.5
    StopSoundOnEntity( player, soundAlias )
}