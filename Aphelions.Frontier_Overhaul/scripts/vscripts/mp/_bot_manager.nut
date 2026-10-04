//=========================================================
// Bot slot manager
// Fills the match with script-driven pilot bots up to delta_bot_fill_target
// (humans + bots). A bot leaves whenever a human joins and comes back when one leaves.
//=========================================================

const BOT_RECONCILE_DELAY = 1.0

function main()
{
	Globalize( IsManagedBot )
	Globalize( BotManagerEnabledForMode )
	Globalize( GetBotFillTarget )
	Globalize( BotRandomizeLoadouts )

	RegisterSignal( "BotReconcile" )

	level.managedBots <- {}
	// Names of bots inside BotCreate: the engine runs the connect/first-spawn callbacks
	// before BotCreate returns, so this is how IsManagedBot recognises them that early.
	level.pendingBotNames <- {}
	file.reconcileQueued <- false
	file.watchStarted <- false

	if ( !BotManagerEnabledForMode() )
	{
		printt( "BotManager: disabled for game mode", GameRules.GetGameMode() )
		return
	}

	FlagSet( "PilotBot" )	// bots spawn as pilots and call titans themselves

	AddCallback_OnClientConnected( BotManager_OnClientConnected )
	AddCallback_OnClientDisconnected( BotManager_OnClientDisconnected )
	AddCallback_GameStateEnter( eGameState.Prematch, BotManager_OnMatchStateEnter )
	AddCallback_GameStateEnter( eGameState.Playing, BotManager_OnMatchStateEnter )
}

function BotManager_OnMatchStateEnter()
{
	if ( !file.watchStarted )
	{
		file.watchStarted = true
		thread BotFillTargetWatchThread()
	}
	QueueBotReconcile()
}

// delta_bot_fill_target can be changed from the console mid-match; nothing else would notice it.
function BotFillTargetWatchThread()
{
	local lastTarget = GetBotFillTarget()
	while ( true )
	{
		wait 1.0
		local target = GetBotFillTarget()
		if ( target == lastTarget )
			continue

		printt( "BotManager: fill target changed to", target )
		lastTarget = target
		QueueBotReconcile()
	}
}

function BotManagerEnabledForMode()
{
	// The bot natives come from the modified tier0.dll. With a stock DLL these scripts stay
	// installed but do nothing, so going back to the original DLL is enough to uninstall.
	if ( !( "BotCreate" in getroottable() ) )
		return false

	switch ( GameRules.GetGameMode() )
	{
		case ATTRITION:
		case TEAM_DEATHMATCH:
			return true
	}
	return false
}

function IsManagedBot( player )
{
	if ( player in level.managedBots )
		return true
	return player.IsBot() && ( player.GetPlayerName() in level.pendingBotNames )
}

function GetBotFillTarget()
{
	local target = GetConVarInt( "delta_bot_fill_target" )
	if ( target <= 0 )
		return 0

	// Always keep one slot open so a human can connect; the bot leaves right after.
	local maxPlayers = GetCurrentPlaylistVarInt( "max players", 12 )
	return min( target, maxPlayers - 1 )
}

function BotManager_OnClientConnected( player )
{
	if ( !player.IsBot() )
		QueueBotReconcile()
}

function BotManager_OnClientDisconnected( player )
{
	if ( player in level.managedBots )
		delete level.managedBots[ player ]

	if ( !player.IsBot() )
		QueueBotReconcile()
}

function QueueBotReconcile()
{
	if ( file.reconcileQueued )
		return

	file.reconcileQueued = true
	thread BotReconcileThread()
}

function BotReconcileThread()
{
	// Let connects/disconnects settle so counts are not off by the player in transit.
	wait BOT_RECONCILE_DELAY
	file.reconcileQueued = false

	local state = GetGameState()
	if ( state < eGameState.Prematch || state >= eGameState.WinnerDetermined )
		return

	local humans = []
	local bots = []
	foreach ( player in GetPlayerArray() )
	{
		if ( player.IsBot() )
		{
			if ( player in level.managedBots )
				bots.append( player )
		}
		else
		{
			humans.append( player )
		}
	}

	local desiredBots = max( 0, GetBotFillTarget() - humans.len() )

	while ( bots.len() > desiredBots )
	{
		local bot = ChooseBotToRemove( bots )
		ArrayRemove( bots, bot )
		RemoveManagedBot( bot )
	}

	for ( local count = bots.len(); count < desiredBots; count++ )
		AddManagedBot( GetTeamNeedingPlayer() )
}

function GetTeamNeedingPlayer()
{
	return GetTeamPlayerCount( TEAM_IMC ) <= GetTeamPlayerCount( TEAM_MILITIA ) ? TEAM_IMC : TEAM_MILITIA
}

// Remove from the larger team so the human who just joined keeps teams even.
// Within that team prefer a dead bot, then a pilot, and leave titan bots for last.
function ChooseBotToRemove( bots )
{
	local imcCount = GetTeamPlayerCount( TEAM_IMC )
	local militiaCount = GetTeamPlayerCount( TEAM_MILITIA )
	local preferredTeam = imcCount >= militiaCount ? TEAM_IMC : TEAM_MILITIA

	local best = null
	local bestScore = -1
	foreach ( bot in bots )
	{
		local score = 0
		if ( bot.GetTeam() == preferredTeam )
			score += 4
		if ( !IsAlive( bot ) )
			score += 2
		else if ( !bot.IsTitan() )
			score += 1

		if ( score > bestScore )
		{
			best = bot
			bestScore = score
		}
	}
	return best
}

function AddManagedBot( team )
{
	local requestedName = GenerateBotName( team )
	level.pendingBotNames[ requestedName ] <- true
	local name = BotCreate( team, requestedName )
	delete level.pendingBotNames[ requestedName ]

	if ( name == "" )
	{
		printt( "BotManager: failed to create bot for team", team )
		return
	}

	foreach ( player in GetPlayerArray() )
	{
		if ( player.IsBot() && player.GetPlayerName() == name )
		{
			level.managedBots[ player ] <- true
			return
		}
	}
}

function RemoveManagedBot( bot )
{
	if ( bot in level.managedBots )
		delete level.managedBots[ bot ]

	BotClearInput( bot )
	ServerCommand( "kickid " + bot.GetUserId() )
}

//---------------------------------------------------------
// Names
//---------------------------------------------------------
const BOT_NAME_MAX_LEN = 31

function PickRandom( array )
{
	return array[ RandomInt( array.len() ) ]
}

function GenerateBotName( team )
{
	local name = ""

	local imcCodeNames = [
		"Alpha", "Bravo", "Charlie", "Echo", "Foxtrot", "Golf", "Hotel", "India", "Juliet", "Kilo", "Lima",
		"Mike", "November", "Oscar", "Papa", "Quebec", "Romeo", "Sierra", "Tango", "Uniform", "Victor", "Whiskey",
		"Xray", "Yankee", "Zulu", "Steel","Gold", "Silver", "Hawk", "Raven", "Falcon", "Crow", "Raptor", "Roach",
		"Io", "Ganymede", "Callisto", "Europa", "Phobos", "Deimos", "Red", "Blue", "Indigo", "White", "Black",
		"June", "August", "Four," "Five", "Six", "Seven", "Nine", "Case", "Knight", "Bishop", "Rook", "Ward", "Cross",
		"Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta", "Iota", "Kappa", "Lambda", "Mako",
		"Hammer", "Omicron", "Jester", "Rho", "Sigma", "Tau", "Upsilon", "Saber", "Hydra", "Psi", "Omega", 
	]
	local militiaNames = [
		"Adams", "Jackson", "Rodriguez", "Williams", "Dennings", "Moore", "Asgeirsson", "Lewis", "Clark", "Irons",
		"Radford", "Young", "Turner", "Carter", "Evans", "Hill", "Hawkins", "Campbell", "Hayes", "Stokes", "Osman",
		"Bohr", "Crane", "Turing", "Phillips", "Feynman", "Frey", "Wilkes", "Shaver", "Freeborn", "Gundyr", "Walker",
		"Barnes", "Hernandez", "Greene", "Higgins", "Burke", "Rodgers", "Chang", "Gore", "Vargas", "Gruzinsky",
		"Woods", "Everett", "Namir", "Hale", "Hermann", "Dutch", "Wayans", "Griffith", "Tanhausser", "Rooker",
		"Fisher", "Drake", "Saito", "Hawthorne", "Tomar", "Rivers", "Saunders", "Shepard", "Asadi", "Howe",
		"Winters", "Crowe", "Omar", "Maynard", "Easton", "Rao", "Jankowski", "Reed", 
	]

	if ( team == TEAM_IMC )
		name == "Pilot " + Random( imcCodeNames )
	else
		name == "Pilot " + Random( militiaNames )

	return name
}

//---------------------------------------------------------
// Loadouts: rolled once when the bot connects and kept for the whole match
//---------------------------------------------------------
function BotRandomizeLoadouts( player )
{
	local pilotTable = player.playerClassData[ level.pilotClass ]
	RandomizeBotLoadout( pilotTable, false )
	pilotTable.passive1 <- PassiveBitfieldFromEnum( PickRandomItemRef( itemType.PILOT_PASSIVE1 ) )
	pilotTable.passive2 <- PassiveBitfieldFromEnum( PickRandomItemRef( itemType.PILOT_PASSIVE2 ) )
	OverrideBotLoadout( pilotTable, false )

	local titanTable = player.playerClassData[ "titan" ]
	RandomizeBotLoadout( titanTable, true )
	titanTable.passive1 <- PassiveBitfieldFromEnum( PickRandomItemRef( itemType.TITAN_PASSIVE1 ) )
	titanTable.passive2 <- PassiveBitfieldFromEnum( PickRandomItemRef( itemType.TITAN_PASSIVE2 ) )
	OverrideBotLoadout( titanTable, true )

	printt( "BotManager:", player.GetPlayerName(), "pilot", pilotTable.primaryWeapon, pilotTable.secondaryWeapon,
		pilotTable.sidearmWeapon, pilotTable.offhandWeapons[0].weapon, pilotTable.offhandWeapons[1].weapon,
		"| titan", titanTable.playerSetFile, titanTable.primaryWeapon, titanTable.offhandWeapons[0].weapon,
		titanTable.offhandWeapons[1].weapon )
}

function PickRandomItemRef( type )
{
	return PickRandom( GetAllItemsOfType( type ) ).ref
}
