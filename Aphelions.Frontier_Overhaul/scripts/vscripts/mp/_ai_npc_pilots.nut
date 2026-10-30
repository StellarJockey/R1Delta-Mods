//=========================================================
// MP spawner for fake NPC Pilots in FO
// Maybe one day we'll have actual bots... one day
//=========================================================

// ---- NPC pilot tactical ability tuning ----
const NPC_TAC_COOLDOWN        = 10.0   // seconds AFTER an ability finishes before the next use
const NPC_TAC_TRIGGER_RANGE   = 2200   // only react to enemies this close
const NPC_TAC_CLOAK_DURATION  = 9.0
const NPC_TAC_CLOAK_CHANCE    = 0.65   // roll each time the pilot is "spotted"
const NPC_TAC_STIM_DURATION   = 5.0
const NPC_TAC_STIM_SPEED      = 1.35   // multiplier on the pilot's normal move speed scale
const NPC_TAC_STIM_TICK       = 1.25   // health top-up interval
const NPC_TAC_COVER_LIFETIME  = 10.0
const NPC_TAC_COVER_CHANCE    = 0.50   // 50% roll each time the pilot is "spotted"
const NPC_TAC_COVER_RADIUS    = 160
const NPC_TAC_COVER_HEALTH    = 32000
const NPC_TAC_HOLO_DURATION   = 8.0
const NPC_TAC_BASE_MOVESPEED  = 1.20

function main()
{
    Minimap_PrecacheMaterial( "vgui/hud/threathud_runner_friendly" )
    Minimap_PrecacheMaterial( "vgui/hud/threathud_runner_enemy" )

	Globalize( IsReskinnedPilot )
	Globalize( IsGhostPilot )
	Globalize( GhostPilotThink )
	Globalize( SpawnGhostPilot )
	Globalize( AssignNPCPilotTacAbility )
	Globalize( UseNPCPilotTacAbility )
}


function GetRandomPilotName( team )
{
	local imcCodeNames = [
		"Alpha", "Bravo", "Charlie", "Echo", "Foxtrot", "Golf", "Hotel", "India", "Juliet", "Kilo", "Lima",
		"Mike", "November", "Oscar", "Papa", "Quebec", "Romeo", "Sierra", "Tango", "Uniform", "Victor", "Whiskey",
		"Xray", "Yankee", "Zulu", "Steel", "Gold", "Silver", "Hawk", "Raven", "Falcon", "Crow", "Raptor", "Roach",
		"Io", "Ganymede", "Callisto", "Europa", "Phobos", "Deimos", "Red", "Blue", "Indigo", "White", "Black",
		"June", "August", "Four", "Five", "Six", "Seven", "Nine", "Case", "Knight", "Bishop", "Rook", "Ward", "Cross",
		"Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta", "Iota", "Kappa", "Lambda", "Mako", "Blackwell",
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
		return "Pilot " + Random( imcCodeNames )
	else
		return "Pilot " + Random( militiaNames )
}
Globalize( GetRandomPilotName )

function ChoosePilotModelForWeapon( team, weapon )
{
    local pilotmodels = []

    if ( team == TEAM_MILITIA )
    {
        pilotmodels = [
            "models/Humans/mcor_pilot/male_br/mcor_pilot_male_br.mdl",
            "models/Humans/mcor_pilot/male_cq/mcor_pilot_male_cq.mdl",
            "models/Humans/mcor_pilot/male_dm/mcor_pilot_male_dm.mdl"
        ]
    }
    else
    {
        pilotmodels = [
            "models/Humans/imc_pilot/male_br/imc_pilot_male_br.mdl",
            "models/humans/imc_pilot/male_cq/imc_pilot_male_cq.mdl",
            "models/humans/imc_pilot/male_dm/imc_pilot_male_dm.mdl"
        ]
    }

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
		case "mp_weapon_mega9":
            modelIndex = 1 // cq
            break

        case "mp_weapon_dmr":
        case "mp_weapon_sniper":
        case "mp_weapon_g2":
        case "mp_weapon_sr_valkyrie":
            modelIndex = 2 // dm
            break

        default:
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

function SpawnPilotInfantry( team, squadName, origin, angles, alert = true, weapon = null, hidden = false, giveTacAbility = true )
{
    local pilotWeapons = [
		"mp_weapon_rspn101",
		"mp_weapon_shotgun",
		"mp_weapon_dmr",
		"mp_weapon_r97",
		"mp_weapon_hemlok",
		"mp_weapon_g2",
		"mp_weapon_car",
		"mp_weapon_sr_valkyrie",
		"mp_weapon_lmg",
		"mp_weapon_sniper",
		"mp_weapon_smart_pistol",
		"mp_weapon_mega9",
	]

    if ( weapon == null )
        weapon = pilotWeapons[ RandomInt( pilotWeapons.len() ) ]

    local guy = SpawnGrunt( team, squadName, origin, angles, alert, weapon, hidden, false )

    local title = GetRandomPilotName( team )

    // Determine the correct model based on the weapon equipped using centralized helper
    local model = ChoosePilotModelForWeapon( team, weapon )
    guy.SetModel( model )
    guy.SetTitle( title )
    guy.SetName( title )

	if ( "s" in guy && "IsSoldier" in guy.s )
		guy.s.IsSoldier <- false
    guy.s.isPilot <- true

    guy.kv.health = 200
    guy.kv.max_health = 200
	guy.s.useRPGPreference = RPG_USE_ALWAYS
	guy.SetMoveSpeedScale( 1.20 ) // 1.15
    guy.SetAISettings( "fireteam_pilot" )
	guy.PreferSprint( true )
	guy.SetHearingSensitivity( 10 )

    guy.AllowFlee( false )
	guy.AllowHandSignals( true )

    guy.Minimap_SetDefaultMaterial( "vgui/hud/threathud_runner_friendly" )
	guy.Minimap_SetEnemyMaterial( "vgui/hud/threathud_runner_enemy" )
	guy.Minimap_SetFriendlyMaterial( "vgui/hud/threathud_runner_friendly" )

	guy.s.pilotName <- title   // hologram copies this (NPCs have no GetPlayerName)

	if ( giveTacAbility )
		AssignNPCPilotTacAbility( guy )

	thread NPCPilotRoamThink( guy )
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
        "mp_weapon_sr_valkyrie",
        "mp_weapon_sniper",
        "mp_weapon_smart_pistol",
        "mp_weapon_mega8",
		"mp_weapon_mega9",
    ]

    local chosenWeapon = Random( pilotWeapons )

    // Spawn with SpawnPilotInfantry so the model is chosen consistently for the weapon
    local ghostPilot = SpawnPilotInfantry( team, squadName, origin, angles, alert, chosenWeapon, false, false )
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
        case "mp_weapon_twinb_shotgun":
        case "mp_weapon_autopistol":
        case "mp_weapon_semipistol":
        case "mp_weapon_smart_pistol":
        case "mp_weapon_wingman":
        case "mp_weapon_mega8":
            sightMod = ""
            break

        case "mp_weapon_dmr":
        case "mp_weapon_sniper":
        case "mp_weapon_sr_valkyrie":
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
    ghostPilot.s.useRPGPreference = RPG_USE_ALWAYS
    ghostPilot.SetAISettings( "fireteam_pilot" )
    CommonInit( ghostPilot )
    SetupSoldierForRPGs( ghostPilot, ghostPilot.GetTeam() )

    ghostPilot.SetMoveSpeedScale( 1.20 )
    ghostPilot.PreferSprint( true )
    ghostPilot.SetHearingSensitivity( 10 )

    ghostPilot.AllowFlee( false )
	ghostPilot.AllowHandSignals( true )

    ghostPilot.Minimap_SetDefaultMaterial( "vgui/hud/threathud_runner_friendly" )
	ghostPilot.Minimap_SetEnemyMaterial( "vgui/hud/threathud_runner_enemy" )
	ghostPilot.Minimap_SetFriendlyMaterial( "vgui/hud/threathud_runner_friendly" )
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


/////////////////////////////////////////////////////////
//////////// NPC PILOT TACTICAL ABILITIES ///////////////
/////////////////////////////////////////////////////////

// 1-in-5: cloak / stim / cover / hologram / nothing
function AssignNPCPilotTacAbility( npc )
{
	local abilities = ["cloakPilot", "stimPilot", "coverPilot", "hologramPilot"]
	local choice = RandomInt( 5 )
	
	if ( choice >= 4 )
		return // null: no ability, no watcher thread

	npc.s[abilities[choice]] <- true
	npc.s.tacNextUseTime <- Time() + RandomFloat( 3.0, 6.0 )
	thread NPCPilotTacThink( npc )
}

// Watches for "I've got an enemy and we can see each other" and fires the ability
function NPCPilotTacThink( npc )
{
	npc.EndSignal( "OnDeath" )
	npc.EndSignal( "OnDestroy" )

	while ( true )
	{
		wait 0.5

		if ( Time() < npc.s.tacNextUseTime )
			continue

		local enemy = npc.GetEnemy()
		if ( !IsValid( enemy ) || !IsAlive( enemy ) )
			continue
		if ( Distance( npc.GetOrigin(), enemy.GetOrigin() ) > NPC_TAC_TRIGGER_RANGE )
			continue
		if ( !npc.CanSee( enemy ) )
			continue

		UseNPCPilotTacAbility( npc )
	}
}

// Starts the ability (threads the long stuff) and sets the next-use time
function UseNPCPilotTacAbility( npc )
{
	local enemy = npc.GetEnemy()
	local duration = 0.0

	if ( "cloakPilot" in npc.s )
	{
		if ( RandomFloat( 0.0, 1.0 ) > NPC_TAC_CLOAK_CHANCE )
		{
			npc.s.tacNextUseTime = Time() + 2.0 // failed the roll, try again soon
			return
		}
		duration = NPC_TAC_CLOAK_DURATION
		thread NPCPilotCloak( npc, enemy, duration )
	}
	else if ( "stimPilot" in npc.s )
	{
		duration = NPC_TAC_STIM_DURATION
		thread NPCPilotStim( npc, enemy, duration )
	}
	else if ( "coverPilot" in npc.s )
	{
		if ( RandomFloat( 0.0, 1.0 ) > NPC_TAC_COVER_CHANCE )
		{
			// skipped: wait out a full cooldown before rolling again
			npc.s.tacNextUseTime = Time() + NPC_TAC_COVER_LIFETIME + NPC_TAC_COOLDOWN
			return
		}
		duration = NPC_TAC_COVER_LIFETIME
		thread NPCPilotDeployCover( npc, duration )
	}
	else if ( "hologramPilot" in npc.s )
	{
		duration = NPC_TAC_HOLO_DURATION
		// hologram copies the pilot while still visible, then the pilot cloaks
		thread StartHologram( npc, duration )
		thread NPCPilotHologramWatch( npc, duration )
		thread NPCPilotHologramCloak( npc )
	}
	else return

	npc.s.tacNextUseTime = Time() + duration + NPC_TAC_COOLDOWN
}

function NPCPilotCloak( npc, enemy, duration )
{
	npc.EndSignal( "OnDeath" )
	npc.EndSignal( "OnDestroy" )

	// relocate away from the enemy while cloaked (same approach as stim)
	local assaultEnt = null
	if ( IsValid( enemy ) )
	{
		local pos = FindNPCTacRelocationPoint( npc, enemy )
		if ( pos != null )
			assaultEnt = CreateStrictAssaultEnt( pos, null, 64 )
	}

	OnThreadEnd( function() : ( npc, assaultEnt )
	{
		if ( IsValid( assaultEnt ) ) assaultEnt.Kill()
		if ( IsValid( npc ) && IsAlive( npc ) && "tacCloaked" in npc.s && npc.s.tacCloaked )
		{
			SniperDeCloak( npc )
			npc.s.tacCloaked = false
		}
	})

	SniperCloak( npc )
	npc.s.tacCloaked <- true
	if ( assaultEnt != null )
		npc.AssaultPointEnt( assaultEnt )

	wait duration
}

// Kills the pilot's hologram when the pilot dies/is destroyed (or when its time is up).
function NPCPilotHologramWatch( npc, duration )
{
	local hologram = "hologram" in npc.s ? npc.s.hologram : null
	if ( !IsValid( hologram ) )
		return

	npc.EndSignal( "OnDeath" )
	npc.EndSignal( "OnDestroy" )

	OnThreadEnd( function() : ( hologram )
	{
		if ( IsValid( hologram ) )
			thread HologramKill( hologram )
	})

	wait duration + 0.5
}

// Same timing the player hologram uses: fade in 1.0, hold 3.0, fade out 1.0
function NPCPilotHologramCloak( npc )
{
	npc.EndSignal( "OnDeath" )
	npc.EndSignal( "OnDestroy" )

	OnThreadEnd( function() : ( npc )
	{
		if ( IsValid( npc ) && IsAlive( npc ) && "tacCloaked" in npc.s && npc.s.tacCloaked )
		{
			SniperDeCloak( npc )
			npc.s.tacCloaked = false
		}
	})

	SniperCloak( npc )
	npc.s.tacCloaked <- true
	npc.SetCloakDuration( 1.0, 3.0, 1.0 )

	wait 5.0
}

function NPCPilotStim( npc, enemy, duration )
{
	npc.EndSignal( "OnDeath" )
	npc.EndSignal( "OnDestroy" )

	local baseSpeed = NPC_TAC_BASE_MOVESPEED
	local assaultEnt = null
	if ( IsValid( enemy ) )
	{
		local pos = FindNPCTacRelocationPoint( npc, enemy )
		if ( pos != null )
			assaultEnt = CreateStrictAssaultEnt( pos, null, 64 )
	}

	OnThreadEnd( function() : ( npc, assaultEnt, baseSpeed )
	{
		if ( IsValid( assaultEnt ) ) assaultEnt.Kill()
		if ( IsValid( npc ) ) npc.SetMoveSpeedScale( baseSpeed )
	})

	npc.SetMoveSpeedScale( baseSpeed * NPC_TAC_STIM_SPEED )
	if ( assaultEnt != null )
		npc.AssaultPointEnt( assaultEnt )

	local endTime = Time() + duration
	while ( Time() < endTime )
	{
		local maxHealth = npc.GetMaxHealth()
		if ( npc.GetHealth() < maxHealth ) npc.SetHealth( maxHealth )
		wait NPC_TAC_STIM_TICK
	}
}

function FindNPCTacRelocationPoint( npc, enemy )
{
	local origin = npc.GetOrigin()
	local awayAngles = VectorToAngles( origin - enemy.GetOrigin() )

	for ( local i = 0; i < 6; i++ )
	{
		local ang = Vector( 0, awayAngles.y + RandomFloat( -70, 70 ), 0 )
		local target = origin + ang.AnglesToForward() * RandomFloat( 400, 800 )

		local node = GetNearestNodeToPos( target )
		if ( node == null || node < 0 )
			continue

		local pos = GetNodePos( node, HULL_HUMAN )
		if ( Distance( pos, target ) > 150 || Distance( pos, origin ) < 250 )
			continue

		return pos
	}
	return null
}

// Mine-less version of ProximityMineSpawnShield (mp_weapon_deployable_cover.nut): same entities,
function NPCPilotDeployCover( npc, lifetime )
{
	npc.EndSignal( "OnDestroy" )

	local origin = npc.GetOrigin()
	local angles = npc.GetAngles()
	local enemy = npc.GetEnemy()
	if ( IsValid( enemy ) )
		angles = Vector( 0, VectorToAngles( enemy.GetOrigin() - origin ).y, 0 )

	local vortexSphere = CreateEntity( "vortex_sphere" )
	vortexSphere.kv.spawnflags = 1 | 2    // SF_ABSORB_BULLETS | SF_BLOCK_OWNER_WEAPON
	vortexSphere.kv.enabled = 0
	vortexSphere.kv.radius = NPC_TAC_COVER_RADIUS
	vortexSphere.SetAngles( angles )
	vortexSphere.SetOrigin( origin )

	local blocker = CreateEntity( "prop_dynamic" )
	blocker.kv.model = "models/fx/xo_shield.mdl"
	blocker.kv.solid = 6
	blocker.kv.CollisionGroup = 21   // blocks bullets/projectiles, not players or AI
	blocker.SetOrigin( origin )
	blocker.SetAngles( angles )
	if ( npc.IsPlayer() )
		blocker.SetBossPlayer( npc )   // only valid on players
	DispatchSpawn( blocker )
	blocker.Hide()

	vortexSphere.SetMaxHealth( NPC_TAC_COVER_HEALTH )
	vortexSphere.SetHealth( NPC_TAC_COVER_HEALTH )
	DispatchSpawn( vortexSphere, true )
	EmitSoundOnEntity( blocker, "ShieldWall_Deploy" )
	vortexSphere.Fire( "Enable" )

	local cpoint = CreateEntity( "info_placement_helper" )
	cpoint.SetName( UniqueString( "shield_wall_controlpoint" ) )
	cpoint.SetOrigin( origin )
	DispatchSpawn( cpoint, false )

	local fxname = typeof( FX_SPECTRE_BUBBLESHIELD ) != "null" ? FX_SPECTRE_BUBBLESHIELD : "wpn_laser_blink"
	local particleSystem = CreateEntity( "info_particle_system" )
	particleSystem.kv.start_active = 1
	particleSystem.kv.VisibilityFlags = 7
	particleSystem.kv.effect_name = fxname
	particleSystem.SetName( UniqueString() )
	particleSystem.SetOrigin( origin )
	DispatchSpawn( particleSystem, false )

	if ( IsValid( particleSystem ) )
	{
		particleSystem.SetParent( blocker )
		particleSystem.s.cpoint <- cpoint
		vortexSphere.s.shieldWallFX <- particleSystem
	}

	EmitSoundOnEntity( vortexSphere, "BubbleShield_Sustain_Loop" )

	OnThreadEnd( function() : ( vortexSphere, particleSystem, cpoint, blocker )
	{
		if ( IsValid_ThisFrame( particleSystem ) )
		{
			particleSystem.ClearParent()
			particleSystem.Fire( "StopPlayEndCap" )
			particleSystem.Kill( 1.0 )
		}
		if ( IsValid_ThisFrame( vortexSphere ) )
		{
			StopSoundOnEntity( vortexSphere, "BubbleShield_Sustain_Loop" )
			EmitSoundOnEntity( vortexSphere, "BubbleShield_End" )
			vortexSphere.Kill()
		}
		if ( IsValid_ThisFrame( cpoint ) )
			cpoint.Kill()
		if ( IsValid_ThisFrame( blocker ) )
			blocker.Kill()
	})

	local elapsed = 0.0
	while ( elapsed < lifetime )
	{
		wait 0.25
		elapsed += 0.25

		if ( !IsValid( vortexSphere ) || vortexSphere.GetHealth() <= 0 )
			return   // shield broke
		if ( !IsValid( npc ) || !IsAlive( npc ) )
			return   // owner died
	}
}


///////////////////////////////////
///////// PILOT ROAMING ///////////
///////////////////////////////////

function NPCPilotRoamThink( npc )
{
	npc.EndSignal( "OnDeath" )
	npc.EndSignal( "OnDestroy" )

	local lastPos = npc.GetOrigin()

	while ( true )
	{
		wait RandomFloat( 6.0, 12.0 )

		local pos = npc.GetOrigin()
		local moved = Distance( pos, lastPos )
		lastPos = pos

		if ( moved > 150 )
			continue   // already on the move (includes stim/cloak relocations)

		local dest = FindNPCRoamPoint( npc )
		if ( dest != null )
			SendAIToAssaultPoint( npc, dest, null, 256 )
	}
}

function FindNPCRoamPoint( npc )
{
	local origin = npc.GetOrigin()
	local enemy = npc.GetEnemy()

	// flank: perpendicular to the enemy if we have one, otherwise any direction
	local baseYaw = RandomFloat( 0, 360 )
	if ( IsValid( enemy ) )
		baseYaw = VectorToAngles( enemy.GetOrigin() - origin ).y + ( RandomInt( 2 ) == 0 ? 90 : -90 )

	for ( local i = 0; i < 6; i++ )
	{
		local ang = Vector( 0, baseYaw + RandomFloat( -40, 40 ), 0 )
		local target = origin + ang.AnglesToForward() * RandomFloat( 500, 1000 )

		local node = GetNearestNodeToPos( target )
		if ( node == null || node < 0 )
			continue

		local pos = GetNodePos( node, HULL_HUMAN )
		if ( Distance( pos, target ) > 150 || Distance( pos, origin ) < 300 )
			continue

		return pos
	}
	return null
}
