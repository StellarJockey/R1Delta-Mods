//=========================================================
// MP spawner for fake NPC Pilots in FO
// Maybe one day we'll have actual bots... one day
//=========================================================

function main()
{
	Globalize( IsReskinnedPilot )
	Globalize( IsGhostPilot )
	Globalize( GhostPilotThink )
	Globalize( SpawnGhostPilot )
}


function GetRandomPilotName( team )
{
	local imcCodeNames = [
		"Alpha", "Bravo", "Charlie", "Echo", "Foxtrot", "Golf", "Hotel", "India", "Juliet", "Kilo", "Lima",
		"Mike", "November", "Oscar", "Papa", "Quebec", "Romeo", "Sierra", "Tango", "Uniform", "Victor", "Whiskey",
		"Xray", "Yankee", "Zulu", "Steel","Gold", "Silver", "Hawk", "Raven", "Falcon", "Crow", "Roach",
		"Io", "Ganymede", "Callisto", "Europa", "Phobos", "Demos", "Red", "Blue", "Indigo", "White", "Black",
		"June", "August", "Seven", "Nine", "Six", "Case", "Knight", "Bishop", "Rook", "Ward", "Cross",
		"Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta", "Iota", "Kappa", "Lambda", "Mu", "Nu",
		"Xi", "Omicron", "Pi", "Rho", "Sigma", "Tau", "Upsilon", "Phi", "Chi", "Psi", "Omega", 
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
		return "Pilot " + Random( imcCodeNames )
	else
		return "Pilot " + Random( militiaNames )
}
Globalize( GetRandomPilotName )

function ChoosePilotModelForWeapon( team, weapon )
{
    local pilotmodels = []
    local title = ""

    if ( team == TEAM_MILITIA ) {
        pilotmodels = [
            "models/Humans/mcor_pilot/male_br/mcor_pilot_male_br.mdl",
            "models/Humans/mcor_pilot/male_cq/mcor_pilot_male_cq.mdl",
            "models/Humans/mcor_pilot/male_dm/mcor_pilot_male_dm.mdl"
        ]
        
		title = GetRandomPilotName( team )
        
    } else {
        pilotmodels = [
            "models/Humans/imc_pilot/male_br/imc_pilot_male_br.mdl",
            "models/humans/imc_pilot/male_cq/imc_pilot_male_cq.mdl",
            "models/humans/imc_pilot/male_dm/imc_pilot_male_dm.mdl"
        ]
        
		title = GetRandomPilotName( team )
    }
    
	// Determine the correct model based on the weapon equipped
    local modelIndex = 0
    switch ( weapon )
    {
        case "mp_weapon_rspn101":
        case "mp_weapon_car":
        case "mp_weapon_lmg":
        case "mp_weapon_hemlok":
            modelIndex = 0 // br
            break

        case "mp_weapon_shotgun":
        case "mp_weapon_r97":
        case "mp_weapon_smart_pistol":
            modelIndex = 1 // cq
            break

        case "mp_weapon_dmr":
        case "mp_weapon_sniper":
        case "mp_weapon_g2":
        case "mp_weapon_mega1":
            modelIndex = 2 // dm
            break

        default:
            // fallback to first model if unknown weapon
            modelIndex = 0
            break
    }

    return pilotmodels[ modelIndex ]
}
Globalize( ChoosePilotModelForWeapon )


function IsReskinnedPilot( npc )
{
    return ( "s" in npc && "isPilot" in npc.s && npc.s.isPilot )
}

function SpawnPilotInfantry( team, squadName, origin, angles, alert = true, weapon = null, hidden = false )
{
    local pilotWeapons = [
		"mp_weapon_rspn101",
		"mp_weapon_shotgun",
		"mp_weapon_dmr",
		"mp_weapon_r97",
		"mp_weapon_hemlok",
		"mp_weapon_g2",
		"mp_weapon_car",
		"mp_weapon_mega1",
		"mp_weapon_lmg",
		"mp_weapon_sniper",
		"mp_weapon_smart_pistol",
	]

    if ( weapon == null )
        weapon = pilotWeapons[ RandomInt( pilotWeapons.len() ) ]

    local guy = SpawnGrunt( team, squadName, origin, angles, alert, weapon, hidden, false )

    local title = ""
    if ( team == TEAM_MILITIA )
        title = GetRandomPilotName( team )
    else
        title = GetRandomPilotName( team )

    // Determine the correct model based on the weapon equipped using centralized helper
    local model = ChoosePilotModelForWeapon( team, weapon )
    guy.SetModel( model )

    guy.SetTitle( title )

	if ( "s" in guy && "IsSoldier" in guy.s )
		guy.s.IsSoldier <- false
    guy.s.isPilot <- true

    guy.kv.health = 200
    guy.kv.max_health = 200
    // guy.kv.AccuracyMultiplier = 4
    // guy.kv.WeaponProficiency = 4
	guy.s.useRPGPreference = RPG_USE_ALWAYS
	guy.SetMoveSpeedScale( 1.15 )
	guy.PreferSprint( true )
	guy.SetHearingSensitivity( 10 )

    guy.AllowFlee( false )
	guy.AllowHandSignals( true )

    return guy
}
Globalize( SpawnPilotInfantry )

/////////////////////////////////////////////////////////
/////////////// NPC GHOST PILOT ENEMIES /////////////////
/////////////////////////////////////////////////////////

function IsGhostPilot( npc )
{
    return ( "s" in npc && "isGhostPilot" in npc.s && npc.s.isGhostPilot )
}

function SpawnGhostPilot( team, squadName, origin, angles, alert = true )
{
    // LMG intentionally excluded because it has no silencer 
    local pilotWeapons = [
        "mp_weapon_rspn101",
        "mp_weapon_shotgun",
        "mp_weapon_dmr",
        "mp_weapon_r97",
        "mp_weapon_hemlok",
        "mp_weapon_g2",
        "mp_weapon_car",
        "mp_weapon_mega1",
        "mp_weapon_sniper",
        "mp_weapon_smart_pistol",
    ]

    local chosenWeapon = Random( pilotWeapons )

    // Spawn with SpawnPilotInfantry so the model is chosen consistently for the weapon
    local ghostPilot = SpawnPilotInfantry( team, squadName, origin, angles, alert, chosenWeapon, false )
    if ( !IsAlive( ghostPilot ) )
        return null

    ghostPilot.SetTitle( "Ghost Pilot" )

	if ( "s" in ghostPilot && "isPilot" in ghostPilot.s )
		ghostPilot.s.isPilot <- false
	if ( "s" in ghostPilot && "IsSoldier" in ghostPilot.s )
		ghostPilot.s.IsSoldier <- false
	
	ghostPilot.s.isGhostPilot <- true

    ghostPilot.TakeActiveWeapon()
    local sightMod = "iron_sights"
    switch ( chosenWeapon )
    {
        case "mp_weapon_shotgun":
        case "mp_weapon_mega2":
        case "mp_weapon_autopistol":
        case "mp_weapon_semipistol":
        case "mp_weapon_smart_pistol":
        case "mp_weapon_wingman":
            sightMod = ""
            break

        case "mp_weapon_dmr":
        case "mp_weapon_sniper":
        case "mp_weapon_mega1":
            sightMod = "scope_6x"
            break
    }

    local mods = []
    if ( sightMod != "" )
        mods.append( sightMod )
    mods.append( "silencer" )

    if ( mods.len() > 0 )
        ghostPilot.GiveWeapon( chosenWeapon, mods )
    else
        ghostPilot.GiveWeapon( chosenWeapon )

    ghostPilot.kv.health = 250
    ghostPilot.kv.max_health = 250
    // ghostPilot.kv.AccuracyMultiplier = 4
    // ghostPilot.kv.WeaponProficiency = 4
    ghostPilot.s.useRPGPreference = RPG_USE_ALWAYS
    ghostPilot.SetAISettings( "fireteam_soldier" )
    CommonInit( ghostPilot )
    SetupSoldierForRPGs( ghostPilot, ghostPilot.GetTeam() )

    ghostPilot.SetMoveSpeedScale( 1.15 )
    ghostPilot.PreferSprint( true )
    ghostPilot.SetHearingSensitivity( 10 )

    ghostPilot.AllowFlee( false )
	ghostPilot.AllowHandSignals( true )

	ghostPilot.Minimap_Hide( TEAM_IMC, null )
    ghostPilot.Minimap_Hide( TEAM_MILITIA, null )

    // start the ghost cloak behavior thread defined in ai_game_modes
    thread GhostPilotThink( ghostPilot )

    return ghostPilot
}


function GhostPilotThink( ghostPilot )
{
    ghostPilot.EndSignal( "OnDeath" )
    ghostPilot.EndSignal( "OnDestroy" )

    // Script-side state tracking
    ghostPilot.s.cloaked <- true
    SniperCloak( ghostPilot )

    // Re-enforce minimap-hide in case other code tries to show them
    ghostPilot.Minimap_Hide( TEAM_IMC, null )
    ghostPilot.Minimap_Hide( TEAM_MILITIA, null )

    while ( true )
    {
        local enemy = ghostPilot.GetEnemy()
        local shouldDecloak = false

        if ( IsValid( enemy ) && IsAlive( enemy ) && ghostPilot.CanSee( enemy ) )
            shouldDecloak = true

        if ( shouldDecloak && ghostPilot.s.cloaked )
        {
            SniperDeCloak( ghostPilot )
            ghostPilot.s.cloaked = false

            // SniperDeCloak calls Minimap_AlwaysShow internally; immediately re-hide
            ghostPilot.Minimap_Hide( TEAM_IMC, null )
            ghostPilot.Minimap_Hide( TEAM_MILITIA, null )
        }
        else if ( !shouldDecloak && !ghostPilot.s.cloaked )
        {
            SniperCloak( ghostPilot )
            ghostPilot.s.cloaked = true

            // re-enforce (defensive)
            ghostPilot.Minimap_Hide( TEAM_IMC, null )
            ghostPilot.Minimap_Hide( TEAM_MILITIA, null )
        }

        wait 0.25
    }
}
