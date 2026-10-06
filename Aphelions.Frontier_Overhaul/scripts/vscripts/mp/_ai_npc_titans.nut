//=========================================================
// MP spawner for NPC Titans in FO
//=========================================================

const NUKE_TITAN_PLAYER_DETECT_RANGE 	= 500
const NUKE_TITAN_RANGE_CHECK_SLEEP_SECS = 1.0
const NUKE_TITAN_DAMAGES_OTHER_NPCS = false

function main()
{
    Globalize( TitanHasPilotInTitan )
    Globalize( NPCIsPilot )
    Globalize( Execution )
    Globalize( NoPain )
    Globalize( GiveTitanPilot )
    Globalize( SetNPCAsPilot )
	Globalize( CreateCopyOfPilotModel )
    Globalize( GiveTitanPilotModel )
    Globalize( NPCPilotEmbarkTitan )
    Globalize( TrackTitan )

    Globalize( Spawn_TrackedPilotWithTitan )
    Globalize( CreateTitanForTeam )
    Globalize( TitanStandUpHandle )
    Globalize( GiveTitanRandomShoulderWeapon )
    Globalize( GiveTitanShoulderWeapon )
    Globalize( TitanDisableRocketPods )
    Globalize( TitanHasRocketPods )
    Globalize( TitanEnableRocketPods )
    Globalize( TitanLockRocketPods )
    Globalize( TitanUnlockRocketPods )
    Globalize( TitanShoulderWeaponThink )
    Globalize( RocketPodsFire_SalvoRockets )
    Globalize( RocketPodsFire_DumbfireRockets )
    Globalize( RocketPodsFire_ShoulderRockets )
    Globalize( RocketPodsFire_HomingRockets )
    Globalize( LockOntoEnemy )
    Globalize( GetFakedAttackParams )
    Globalize( SuperHotDropGenericTitan_DropIn )
    Globalize( OnReplacementTitanSecondStage )
    Globalize( OnReplacementTitanImpact )

	Globalize( SpawnPilotWithTitans )
	Globalize( ShouldSpawnPilotWithTitan )
	Globalize( Coop_SpawnTitansAfterDelay )

	Globalize( AutoTitan_NuclearPayload_DamageCallback )
	Globalize( AutoTitan_IsPlayerTitanInRange )
	Globalize( AutoTitan_CanDoRangeCheck )
	Globalize( AI_SpottingThink )
	Globalize( AI_HuntThink )
	Globalize( AI_SelectTarget )
	Globalize( AI_FindClosestValid )
	Globalize( AI_SendToRandomLocation )
	Globalize( DecayNPCDomeShield )

	file.debug <- 0
    
    file.pilotedtitans <- []
	file.pilots <- []
	file.pilotedtitanmodels <- {}
	file.spawnedtitans <- {}
	file.pilotmodels <- [
	"models/Humans/mcor_pilot/male_br/mcor_pilot_male_br.mdl",
	"models/Humans/mcor_pilot/male_cq/mcor_pilot_male_cq.mdl",
	"models/Humans/mcor_pilot/male_dm/mcor_pilot_male_dm.mdl",
	"models/Humans/imc_pilot/male_br/imc_pilot_male_br.mdl",
	"models/humans/imc_pilot/male_cq/imc_pilot_male_cq.mdl",
	"models/humans/imc_pilot/male_dm/imc_pilot_male_dm.mdl"
	]
	file.militiapilotmodels <- [
	"models/Humans/mcor_pilot/male_br/mcor_pilot_male_br.mdl",
	"models/Humans/mcor_pilot/male_cq/mcor_pilot_male_cq.mdl",
	"models/Humans/mcor_pilot/male_dm/mcor_pilot_male_dm.mdl"
	]
	file.imcpilotmodels <- [
	"models/Humans/imc_pilot/male_br/imc_pilot_male_br.mdl",
	"models/humans/imc_pilot/male_cq/imc_pilot_male_cq.mdl",
	"models/humans/imc_pilot/male_dm/imc_pilot_male_dm.mdl"
	]
	AddDamageByCallback( "npc_titan", Execution )
	AddDamageCallback( "npc_titan", NoPain )
	AddDamageCallback( "npc_soldier", NoPain )
	AddDamageCallback( "npc_titan", AutoTitan_NuclearPayload_DamageCallback )

	RegisterSignal( "TitanHotDropComplete" )
	RegisterSignal( "DisableRocketPods" )
	RegisterSignal( "OnLostTarget" )
	RegisterSignal( "BubbleShieldStatusUpdate" )
}


function TitanHasPilotInTitan( titan )
{
	local pilotedtitans = []
	foreach( npc in file.pilotedtitans )
	if ( IsValid( npc ) && IsAlive( npc ) )
	    pilotedtitans.append( npc )
	file.pilotedtitans = pilotedtitans
	foreach( npc in pilotedtitans )
	    if ( npc == titan )
	        return true

	return false
}

function NPCIsPilot( pilot )
{
	local pilots = []
	foreach( npc in file.pilots )
	if ( IsValid( npc ) && IsAlive( npc ) )
	    pilots.append( npc )
	file.pilots = pilots
	foreach( npc in pilots )
	    if ( npc == pilot )
	        return true

	return false
}

function Execution( ent, damageInfo )
{
	local attacker = damageInfo.GetAttacker()
	if ( !ent.IsTitan() || damageInfo.GetDamageSourceIdentifier() != eDamageSourceId.titan_melee || !TitanHasPilotInTitan( attacker ) || !ent.GetDoomedState() || !CodeCallback_IsValidMeleeExecutionTarget( attacker, ent ) )
	    return

    damageInfo.SetDamage( 0 )
	thread PlayerTriesExecutionMelee( attacker, ent )
}

function NoPain( ent, damageInfo )
{
    // If it's a Titan without a pilot, allow standard damage processing
    if ( ent.IsTitan() && !TitanHasPilotInTitan( ent ) )
        return

    // If it's a Pilot NPC, ensure they can still take damage
    if ( !ent.IsTitan() && NPCIsPilot( ent ) )
    {
        damageInfo.AddDamageFlags( DAMAGEFLAG_NOPAIN ) // Optional: prevents flinching
        return // Exit here so damage isn't set to 0
    }

    // Default behavior for other NPCs
    damageInfo.AddDamageFlags( DAMAGEFLAG_NOPAIN )
}

function GiveTitanPilot( titan, trueorfalse )
{
	local pilotedtitans = []
	foreach( npc in file.pilotedtitans )
	if ( IsValid( npc ) && IsAlive( npc ) )
	pilotedtitans.append( npc )
	if ( !IsValid( titan ) || !IsAlive( titan ) )
	return
	if ( trueorfalse == true )
	pilotedtitans.append( titan )
	if ( trueorfalse == false )
	{
		local newpilotedtitans
		foreach( npc in pilotedtitans )
		if ( npc != titan )
		newpilotedtitans.append( titan )
		pilotedtitans = newpilotedtitans
	}
	file.pilotedtitans = pilotedtitans
}
Globalize( GiveTitanPilot )

function SetNPCAsPilot( pilot, trueorfalse )
{
	local pilots = []
	foreach( npc in file.pilots )
	if ( IsValid( npc ) && IsAlive( npc ) )
	pilots.append( npc )
	if ( !IsValid( pilot ) || !IsAlive( pilot ) )
	return
	if ( trueorfalse == true )
	pilots.append( pilot )
	if ( trueorfalse == false )
	{
		local newpilots
		foreach( npc in pilots )
		if ( npc != pilot )
		newpilots.append( pilot )
		pilots = newpilots
	}
	file.pilots = pilots
}

function CreateCopyOfPilotModel( titan )
{
	local model = Random( file.pilotmodels )
	if ( titan in file.pilotedtitanmodels )
	    model = file.pilotedtitanmodels[ titan ]
	local prop = CreatePropDynamic( model )
	prop.SetTeam( titan.GetTeam() )
	return prop
}

function GiveTitanPilotModel( titan, model )
{
	file.pilotedtitanmodels[ titan ] <- model
}

function NPCPilotEmbarkTitan( pilot, title, titan )
{
    pilot.EndSignal( "OnDestroy" )
    pilot.EndSignal( "OnDeath" )
    titan.EndSignal( "OnDestroy" )
    titan.EndSignal( "OnDeath" )

    // Make absolutely certain AI cannot take control during embark.
    pilot.DisableBehavior( "Assault" )
    pilot.DisableBehavior( "Follow" )
    pilot.SetInvulnerable()

    // A pilot can still be mid-traverse (ledge climb / jump) when told to embark.
    // Scripted anims are rejected during a traverse, so let it finish first.
    // No timeout needed: the OnDeath/OnDestroy EndSignals above end this thread if the pilot or Titan dies.
    while ( !pilot.IsInterruptable() )
        wait 0

    pilot.Anim_Stop()

    local embarkSet = FindBestEmbark( pilot, titan )
    while( embarkSet == null )
    {
        wait 0.1

        if ( !IsValid( pilot ) || !IsAlive( pilot ) ||
             !IsValid( titan ) || !IsAlive( titan ) )
            return

        embarkSet = FindBestEmbark( pilot, titan )
    }

    local animation = embarkSet.animSet.titanKneelingAnim
    local titanSubClass = GetSoulTitanType( titan.GetTitanSoul() )
    local Audio = GetAudioFromAlias( titanSubClass, embarkSet.audioSet.thirdPersonKneelingAudioAlias )

    local sequence = CreateFirstPersonSequence()
    sequence.attachment = "hijack"
    sequence.useAnimatedRefAttachment = embarkSet.action.useAnimatedRefAttachment
    sequence.thirdPersonAnim = GetAnimFromAlias( titanSubClass, embarkSet.animSet.thirdPersonKneelingAlias )

    local pilotmodel = pilot.GetModelName()

    thread FirstPersonSequence( sequence, pilot, titan )

    EmitSoundOnEntity( titan, Audio )
    waitthread PlayAnimGravity( titan, animation )

    SetStanceStand( titan.GetTitanSoul() )
    DecayNPCDomeShield( titan, 0.0 )

    GiveTitanPilot( titan, true )
    GiveTitanPilotModel( titan, pilotmodel )

    if ( IsValid( pilot ) )
        pilot.Destroy()
}


function TrackTitan( titan )
{
    if ( !IsValid( titan ) )
        return

    local team = titan.GetTeam()

    // If the Titan is destroyed for any reason, release its spawn slot.
    OnThreadEnd(
        function() : ( team )
        {
            if ( team in file.spawnedtitans )
                file.spawnedtitans[ team ] <- max( 0, file.spawnedtitans[ team ] - 1 )
        }
    )

    titan.EndSignal( "OnDestroy" )
    titan.WaitSignal( "OnDeath" )
}


function Spawn_TrackedPilotWithTitan( team, spawnPoint )
{
	if ( GameRules.GetGameMode() != COOPERATIVE && !IsNPCSpawningEnabled() )
		return

	if ( !spawnPoint )
		return

	if ( "inUse" in spawnPoint.s )
   		spawnPoint.s.inUse <- true

	local spawned = CreateTitanForTeam( team, spawnPoint, spawnPoint.GetOrigin(), spawnPoint.GetAngles() )
	if ( "inUse" in spawnPoint.s )
		spawnPoint.s.inUse <- false

	return spawned
}


function CreateTitanForTeam( team, spawnPoint, spawnOrigin, spawnAngles )
{
    local isTitanBrawl = ( GameRules.GetGameMode() == TITAN_BRAWL )
    local pilot = null
    local title = ""

	local pilotmodels = file.pilotmodels
    if ( team == TEAM_MILITIA )
        pilotmodels = file.militiapilotmodels
    else if ( team == TEAM_IMC )
        pilotmodels = file.imcpilotmodels

    // PILOT SETUP (obvisouly skips in Titan Brawl)
    if ( !isTitanBrawl )
    {
		pilot = CreateEntity( "npc_soldier" )
		DispatchSpawn( pilot )
		pilot.SetOrigin( spawnOrigin )
		pilot.SetTeam( team )
		pilot.SetModel( Random( pilotmodels ) )

		if ( "s" in pilot && "IsSoldier" in pilot.s )
			pilot.s.IsSoldier <- false

		pilot.s.isPilot <- true
		SetNPCAsPilot( pilot, true )

		GiveMinionWeapon( pilot, "mp_weapon_rspn101" )
		pilot.SetMaxHealth( 200 )
		pilot.SetHealth( 200 )

		// Pilot is a scripted prop, not an autonomous NPC.
		pilot.DisableBehavior( "Assault" )
		pilot.DisableBehavior( "Follow" )
		pilot.Anim_Stop()

		// Keep it hidden/invulnerable until the embark.
		pilot.SetInvulnerable()
		SniperCloak( pilot )
		pilot.SetCloakDuration( 0, 5.0, 2.0 )

		if ( team == TEAM_IMC || team == TEAM_MILITIA )
			title = GetRandomPilotName( team )

		SetNPCAsPilot( pilot, true )
    }

    // TITAN CREATION
    local titanDataTable = GetRandomTitanLoadout()
    local titans = Random(["titan_stryder", "titan_atlas", "titan_ogre", ])
	
    titanDataTable.setFile = titans
    local settings = titanDataTable.setFile

    titanDataTable.primary = Random([
        "mp_titanweapon_arc_cannon",
        "mp_titanweapon_rocket_launcher",
        "mp_titanweapon_40mm",
        "mp_titanweapon_sniper",
        "mp_titanweapon_triple_threat",
        "mp_titanweapon_xo16",
        "mp_titanweapon_shotgun",
		"mp_weapon_mega3",
    ])

    local titan = CreateNPCTitanFromSettings( settings, team, spawnOrigin, spawnAngles )
    
    if ( !("nukeTitanDamagesOtherTitans" in titan.s) )
        titan.s.nukeTitanDamagesOtherTitans <- true

    // 10% chance to become a Nuke Titan
    if ( RandomFloat( 0.0, 1.0 ) <= 0.1 )
    {
        NPC_SetNuclearPayload( titan, true )
        titan.SetSubclass( eSubClass.nukeTitan )
    }

    if ( titans == "titan_stryder" )
        titan.SetTitle( "#CHASSIS_STRYDER_NAME" )
    else if ( titans == "titan_atlas" )
        titan.SetTitle( "#CHASSIS_ATLAS_NAME" )
    else if ( titans == "titan_ogre" )
        titan.SetTitle( "#CHASSIS_OGRE_NAME" )
	else if ( titans == "titan_ctt" )
		titan.SetTitle( "Destroyer" )
    
	titan.s.isTitan <- true
	titan.s.isFO_Titan <- true

    local weaponMods = []
    local weaponModPools = {
        mp_titanweapon_40mm            = [ null, null, "burst", "burst", "extended_ammo", "extended_ammo", "burn_mod_titan_40mm", ],
        mp_titanweapon_xo16            = [ null, null, "extended_ammo", "extended_ammo", "burst", "burst", "accelerator", "accelerator", "burn_mod_titan_xo16", ],
        mp_titanweapon_sniper          = [ null, "extended_ammo", ],
        mp_titanweapon_arc_cannon      = [ null, null, "capacitor", "capacitor", "burn_mod_titan_arc_cannon", ],  
        mp_titanweapon_rocket_launcher = [ null, null, "rapid_fire_missiles", "rapid_fire_missiles", "extended_ammo", "extended_ammo", "burn_mod_titan_rocket_launcher", ],
        mp_titanweapon_triple_threat   = [ null, null, "mine_field", "mine_field", "extended_ammo", "extended_ammo", "burn_mod_titan_triple_threat", ],
        mp_titanweapon_shotgun         = [ null, "extended_ammo", "shredder_rounds", ],
		mp_weapon_mega3                = [ null, "extended_ammo", ],
    }

    local primaryWeapon = titanDataTable.primary
    if ( primaryWeapon in weaponModPools )
    {
        local availableMods = weaponModPools[primaryWeapon]
        local selectedMod = Random( availableMods ) 

        if ( selectedMod != null )
        {
            weaponMods.append( selectedMod )
        }
    }

	if ( isTitanBrawl )
    {
        GiveTitanPilot( titan, true )
        GiveTitanPilotModel( titan, Random( pilotmodels ) )
        titan.SetEfficientMode( false )
    }

    titan.GiveWeapon( titanDataTable.primary, weaponMods )
    titan.SetLookDist( 120000 )
    titan.kv.faceEnemyWhileMovingDistSq = 1024 * 1024

    GiveTitanRandomShoulderWeapon( titan )
	AllowTeamRodeo( titan, true )

	local tacChoice = RandomInt( 3 )
    if ( tacChoice == 0 )
    {
        titan.GiveOffhandWeapon( "mp_titanability_bubble_shield", TAC_ABILITY_WALL, [] )
        titan.SetTacticalAbility( titan.GetOffhandWeapon( TAC_ABILITY_WALL ), TTA_WALL )
    }
    else if ( tacChoice == 1 )
    {
        titan.GiveOffhandWeapon( "mp_titanability_smoke", TAC_ABILITY_SMOKE, [] )
        titan.SetTacticalAbility( titan.GetOffhandWeapon( TAC_ABILITY_SMOKE ), TTA_SMOKE )
    }
    else
    {
        titan.SetTacticalAbility( titan.GetOffhandWeapon( TAC_ABILITY_VORTEX ), TTA_VORTEX )
    }
   
    // DROP SEQUENCE LOGIC
    thread TrackTitan( titan )
    
    // TITAN BRAWL: Use ScriptedHotDrop with instant dome shield decay
    if ( isTitanBrawl )
    {
        waitthread ScriptedHotDrop( titan, spawnOrigin, spawnAngles, "at_hotdrop_drop_2knee_turbo" )
        
        // Dome shield decays instantly (0.0 delay) - no dome shield mechanic
        DecayNPCDomeShield( titan, 0.0 )
        
        waitthread PlayAnimGravity( titan, "at_hotdrop_quickstand" )
        SetStanceStand( titan.GetTitanSoul() )

        if ( level.aiHuntThinkEnabled )
        {
            thread AI_HuntThink( titan, team )
            thread AI_SpottingThink( titan, team )
        }
        return titan
    }
    
    // Standard Modes: Use SuperHotDropGenericTitan_DropIn (original behavior)
    waitthread SuperHotDropGenericTitan_DropIn( titan, spawnOrigin, spawnAngles )

    // Standard Modes Finish
    thread PlayAnim( titan, "at_MP_embark_idle_blended" )
    if ( IsValid( pilot ) && IsValid( titan ) && IsAlive( pilot ) && IsAlive( titan ) )
    {
        pilot.SetOrigin( titan.GetOrigin() )
        thread NPCPilotEmbarkTitan( pilot, title, titan )
        thread TitanStandUpHandle( pilot, titan )

        return titan
    }
	else if ( IsValid( titan ) && IsAlive( titan ) )
    {
        // The pilot is dead, so the Titan stands up on its own
        waitthread PlayAnimGravity( titan, "at_hotdrop_quickstand" )
        SetStanceStand( titan.GetTitanSoul() )
        
        // Shield decays instantly
        DecayNPCDomeShield( titan, 0.0 )
    }

    if ( level.aiHuntThinkEnabled )
    {
        thread AI_HuntThink( titan, team )
        thread AI_SpottingThink( titan, team )
    }
	return titan
}


function TitanStandUpHandle( pilot, titan )
{
	pilot.EndSignal( "OnDestroy" )
	pilot.EndSignal( "OnDeath" )
	titan.EndSignal( "OnDestroy" )
	titan.EndSignal( "OnDeath" )
	OnThreadEnd(
		function() : ( titan )
		{
			if ( IsValid( titan ) && IsAlive( titan ) && !TitanHasPilotInTitan( titan ) )
			thread PlayAnimGravity( titan, "at_hotdrop_quickstand" )
		}
	)
	WaitForever()
}


function GiveTitanRandomShoulderWeapon( titan )
{
	local weapons = [
		"mp_titanweapon_salvo_rockets",
		"mp_titanweapon_dumbfire_rockets",
		"mp_titanweapon_shoulder_rockets",
		"mp_titanweapon_homing_rockets",
		]

	GiveTitanShoulderWeapon( titan, Random( weapons ) )
}

function GiveTitanShoulderWeapon( titan, shoulderWeapon )
{
	titan.GiveOffhandWeapon( shoulderWeapon, 0 )
	thread CreateTitanRocketPods( titan.GetTitanSoul(), titan )
	thread TitanShoulderWeaponThink( titan )
}


function TitanDisableRocketPods( titan )
{
	if ( "lockedRocketPods" in titan.s && titan.s.lockedRocketPods )
		return

	titan.Signal( "DisableRocketPods" )
}


function TitanHasRocketPods( titan )
{
	return IsValid( titan.GetOffhandWeapon( 0 ) )
}


function TitanEnableRocketPods( titan )
{
	if ( "lockedRocketPods" in titan.s && titan.s.lockedRocketPods )
		return

	Assert( IsValid( titan.GetOffhandWeapon( 0 ) ) )
	thread TitanShoulderWeaponThink( titan )
}


function TitanLockRocketPods( titan )
{
	if ( !( "lockedRocketPods" in titan.s ) )
		titan.s.lockedRocketPods <- false

	titan.s.lockedRocketPods = true
}


function TitanUnlockRocketPods( titan )
{
	if ( !( "lockedRocketPods" in titan.s ) )
		titan.s.lockedRocketPods <- false

	titan.s.lockedRocketPods = false
}

function TitanShoulderWeaponThink( titan )
{
	local weapon = titan.GetOffhandWeapon( 0 )

	titan.EndSignal( "OnDeath" )
	titan.EndSignal( "OnDestroy" )
	titan.EndSignal( "Doomed" )
	titan.EndSignal( "DisableRocketPods" )
	weapon.EndSignal( "OnDestroy" )

	local fireFunc

	switch ( weapon.GetClassname() )
	{
		case "mp_titanweapon_salvo_rockets":
			fireFunc = RocketPodsFire_SalvoRockets
			break

		case "mp_titanweapon_dumbfire_rockets":
			fireFunc = RocketPodsFire_DumbfireRockets
			break

		case "mp_titanweapon_shoulder_rockets":
			fireFunc = RocketPodsFire_ShoulderRockets
			break

		case "mp_titanweapon_homing_rockets":
			fireFunc = RocketPodsFire_HomingRockets
			break

		default:
			Assert( 0 , "shoulder weapon " + shoulderWeapon + " not setup for NPC titan use.")
			break
	}

	local max_range 			= weapon.GetWeaponInfoFileKeyField( "npc_max_range" )
	local max_range_sqr 		= pow( max_range, 2 )

	while( 1 )
	{
		wait 0.5

		if ( !titan.GetEnemy() )
			titan.WaitSignal( "OnFoundEnemy" )

		local enemy = titan.GetEnemy()

		if ( !IsValid( enemy ) || !enemy.IsTitan() )
			continue

		if ( DistanceSqr( enemy.GetOrigin(), titan.GetOrigin() ) > max_range_sqr )
			continue

		if ( !titan.CanSee( enemy ) )
			continue

		if ( !IsFacingEnemy( titan, enemy ) )
			continue

		local results = {}
		results.numRocketsFired <- 0
		results.maxRockets 		<- 12
		results.targetLockon 	<- false
		results.cooldown 		<- 0

		local soul = enemy.GetTitanSoul()
		Assert( soul != null )

		waitthread fireFunc( titan, weapon, soul, results )

		if ( !results.numRocketsFired )
			continue

		wait results.cooldown
	}
}


/**************************************************************************\
	salvo rockets
\**************************************************************************/
function RocketPodsFire_SalvoRockets( titan, weapon, soul, results )
{
	titan.EndSignal( "OnDeath" )
	titan.EndSignal( "OnDestroy" )
	titan.EndSignal( "Doomed" )
	titan.EndSignal( "DisableRocketPods" )
	titan.EndSignal( "OnLostEnemy" )
	soul.EndSignal( "OnTitanDeath" )
  	soul.EndSignal( "OnDestroy" )

	local numRockets 			= weapon.GetWeaponModSetting( "burst_fire_count" )
	local fireRate 				= 0//weapon.GetWeaponModSetting( "fire_rate" ) * 0.01

	results.maxRockets 		= numRockets
	results.cooldown 		= weapon.GetWeaponModSetting( "burst_fire_delay" )
	results.numRocketsFired = numRockets

	local attackParams = GetFakedAttackParams( weapon, soul )

	for ( local i = 0; i < numRockets; i++ )
	{
		attackParams.burstIndex = i
		weapon.SetWeaponBurstFireCount( numRockets )
		weapon.GetScriptScope().OnWeaponPrimaryAttack( attackParams )
		wait fireRate
	}
}


/**************************************************************************\
	dumb fire rockets
\**************************************************************************/
function RocketPodsFire_DumbfireRockets( titan, weapon, soul, results )
{
	titan.EndSignal( "OnDeath" )
	titan.EndSignal( "OnDestroy" )
	titan.EndSignal( "Doomed" )
	titan.EndSignal( "DisableRocketPods" )
	titan.EndSignal( "OnLostEnemy" )
	soul.EndSignal( "OnTitanDeath" )
  	soul.EndSignal( "OnDestroy" )

	results.maxRockets 		= 1
	results.cooldown 		= 1.0 / weapon.GetWeaponModSetting( "fire_rate" )
	results.numRocketsFired = 1

	local attackParams = GetFakedAttackParams( weapon, soul )

	weapon.GetScriptScope().OnWeaponPrimaryAttack( attackParams )
}

/**************************************************************************\
	shoulder rockets -> multi target ( 12x misslies )
\**************************************************************************/
function RocketPodsFire_ShoulderRockets( titan, weapon, soul, results )
{
	titan.EndSignal( "OnDeath" )
	titan.EndSignal( "OnDestroy" )
	titan.EndSignal( "Doomed" )
	titan.EndSignal( "DisableRocketPods" )
	titan.EndSignal( "OnLostEnemy" )
	soul.EndSignal( "OnTitanDeath" )
  	soul.EndSignal( "OnDestroy" )

	local maxRockets 			= weapon.GetWeaponModSetting( "smart_ammo_target_max_locks_titan" )
	local minRockets 			= ( maxRockets / 3 ).tointeger()
	local numRockets 			= RandomInt( minRockets, maxRockets + 1 )
	local targeting_time_max 	= weapon.GetWeaponModSetting( "smart_ammo_targeting_time_max" )
	local targetTime 			= numRockets * targeting_time_max

	results.maxRockets 	= maxRockets

	waitthread LockOntoEnemy( titan, weapon, soul, targetTime, results )
	if ( !results.targetLockon )
		return

	local attackParams = GetFakedAttackParams( weapon, soul )

	weapon.SmartAmmo_Enable()
	weapon.SetWeaponBurstFireCount( numRockets )
	weapon.SmartAmmo_SetTarget( soul, numRockets )  // hack: fraction is the number of rockets; same as player weapon

	for ( local i = 0; i < numRockets; i++ )
	{
		attackParams.burstIndex = i
		weapon.GetScriptScope().OnWeaponPrimaryAttack( attackParams )
	}

	local cooldown_time 	= weapon.GetWeaponModSetting( "charge_cooldown_time" )
	local cooldown_delay 	= weapon.GetWeaponModSetting( "charge_cooldown_delay" )
	local rocketFrac 		= numRockets / maxRockets
	cooldown_time *= rocketFrac

	results.cooldown 		= cooldown_time
	results.numRocketsFired = numRockets

	weapon.SmartAmmo_Clear( true )
	if ( IsValid( soul.GetBossPlayer() ) )
		SmartAmmo_ClearCustomFractionSource( weapon, soul.GetBossPlayer() )
}

/**************************************************************************\
	homing rockets -> slaved warheads ( 4x 3-missiles )
\**************************************************************************/
function RocketPodsFire_HomingRockets( titan, weapon, soul, results )
{
	titan.EndSignal( "OnDeath" )
	titan.EndSignal( "OnDestroy" )
	titan.EndSignal( "Doomed" )
	titan.EndSignal( "DisableRocketPods" )
	titan.EndSignal( "OnLostEnemy" )
	soul.EndSignal( "OnTitanDeath" )
  	soul.EndSignal( "OnDestroy" )

	local fireRate 				= 1.0 / weapon.GetWeaponModSetting( "fire_rate" )
	local numRockets 			= 12
	local numBursts 			= weapon.GetWeaponModSetting( "smart_ammo_max_targeted_burst" )
	local rocketsPerBurst 		= ( numRockets / numBursts ).tointeger()
	local targetTime 			= weapon.GetWeaponModSetting( "smart_ammo_targeting_time_max" )

	results.maxRockets 	= numRockets
	results.cooldown 	= weapon.GetWeaponModSetting( "burst_fire_delay" )

	waitthread LockOntoEnemy( titan, weapon, soul, targetTime, results )
	if ( !results.targetLockon )
		return

	weapon.SmartAmmo_SetTarget( soul, rocketsPerBurst )
	results.numRocketsFired = numRockets

	for ( local i = 0; i < numBursts; i++ )
	{
		local attackParams = GetFakedAttackParams( weapon, soul )

		attackParams.burstIndex = i
		weapon.SmartAmmo_Enable()
		weapon.SetWeaponBurstFireCount( rocketsPerBurst )
		weapon.GetScriptScope().OnWeaponPrimaryAttack( attackParams )

		wait fireRate

		if ( !( soul.GetTitan().IsPlayer() ) && IsValid( soul.GetBossPlayer() ) )
			SmartAmmo_ClearCustomFractionSource( weapon, soul.GetBossPlayer() )
	}

	weapon.SmartAmmo_Clear( true )
	if ( IsValid( soul.GetBossPlayer() ) )
		SmartAmmo_ClearCustomFractionSource( weapon, soul.GetBossPlayer() )
}


/**************************************************************************\
	HACKED LOCK ON FOR NPCS
\**************************************************************************/
function LockOntoEnemy( titan, weapon, soul, targetTime, results )
{
	titan.EndSignal( "OnDeath" )
	titan.EndSignal( "OnDestroy" )
	titan.EndSignal( "Doomed" )
	titan.EndSignal( "DisableRocketPods" )
	titan.EndSignal( "OnLostEnemy" )
	soul.EndSignal( "OnTitanDeath" )
  	soul.EndSignal( "OnDestroy" )
	titan.EndSignal( "OnLostTarget" )

	local currTargetTime 	= 0.0
	local humanFakedDelay 	= 1.5
	local giveUpTime 		= 4.0
	local giveUpTargetTime 	= Time() + targetTime + giveUpTime + humanFakedDelay

	thread SetSignalDelayed( titan, "OnLostTarget", giveUpTargetTime )

	local customFractionSource = []
	OnThreadEnd(
		function() : ( titan, weapon, soul, giveUpTargetTime, customFractionSource )
		{
			if ( !IsValid( weapon ) )
				return

			if ( !customFractionSource.len() )
				return

			Assert( customFractionSource.len() == 1 )

			if ( !IsValid( customFractionSource[ 0 ] ) )
				return

			SmartAmmo_ClearCustomFractionSource( weapon, customFractionSource[ 0 ] )
		}
	)

	local interval 			= 0.2
	while( 1 )
	{
		local newLock = true
		local lockWasPlayer = false
		local lockIsPlayer = false

		while( titan.CanSee( soul.GetTitan() ) && IsFacingEnemy( titan, soul.GetTitan() ) )
		{
			if ( soul.GetTitan().IsPlayer() )
				lockIsPlayer = true

			if ( lockWasPlayer != lockIsPlayer )
				newLock = true

			if ( newLock )
			{
				if ( soul.GetTitan().IsPlayer() )
				{
					customFractionSource.append( soul.GetBossPlayer() )
					SmartAmmo_SetCustomFractionSource( weapon, customFractionSource[ 0 ], targetTime )
				}
				else if ( customFractionSource.len() )
				{
					SmartAmmo_ClearCustomFractionSource( weapon, customFractionSource[ 0 ] )
					Assert( customFractionSource.len() == 1 )
					customFractionSource.remove( 0 )
				}

				lockWasPlayer = true
				lockIsPlayer = true
				newLock = false
			}

			if ( currTargetTime >= targetTime + humanFakedDelay )
			{
				results.targetLockon = true
				return
			}

			wait interval
			currTargetTime += interval
		}

		while( !titan.CanSee( soul.GetTitan() ) || !IsFacingEnemy( titan, soul.GetTitan() ) )
		{
			if ( customFractionSource.len() )
			{
				SmartAmmo_ClearCustomFractionSource( weapon, customFractionSource[ 0 ] )
				Assert( customFractionSource.len() == 1 )
				customFractionSource.remove( 0 )
			}

			wait interval
			currTargetTime -= interval * 1.5
			if ( currTargetTime < 0 )
				currTargetTime = 0.0
		}
	}
}


function GetFakedAttackParams( weapon, enemySoul )
{
	local titan 	= weapon.GetWeaponOwner()
	local soul = titan.GetTitanSoul()
	Assert( IsValid( soul ) && IsValid( soul.rocketPod ) )

	local model		= soul.rocketPod.model
	local attachID 	= model.LookupAttachment( "muzzle_flash" )
	local origin 	= model.GetAttachmentOrigin( attachID )
	local vec 		= null

	local enemy 	= enemySoul.GetTitan()

	if ( enemy )
	{
		vec = enemy.EyePosition() - titan.EyePosition()
		vec.Normalize()
	}
	else
	{
		vec = titan.GetViewVector()
	}

	local attackParams = {}
	attackParams.burstIndex <- 0
	attackParams.pos <- origin
	attackParams.dir <- vec

	return attackParams
}


function SuperHotDropGenericTitan_DropIn( titan, origin, angles )
{
	titan.EndSignal( "OnDeath" )

    //	printt( "TitanHotDrop" )
    //origin = Vector(-2257.346924, -2599.757080, -275.556885)
    //angles = Vector(0.000000, -177.883041, 0.000000)

    //	printt( "origin: " + origin )
    //	printt( "angles: " + angles )
	titan.s.disableAutoTitanConversation <- true

	OnThreadEnd(
		function() : ( titan )
		{
			if ( !IsValid( titan ) )
				return

			//delete titan.s.disableAutoTitanConversation //Don't delete here, otherwise Auto Titan will start talking about engaging enemy soldiers while kneeling down.
			titan.DisableRenderAlways()

			DeleteAnimEvent( titan, "titan_impact", OnReplacementTitanImpact )
			DeleteAnimEvent( titan, "second_stage", OnReplacementTitanSecondStage )
		}
	)

	HideName( titan )
	titan.UnsetUsable() //Stop titan embark before it lands
	AddAnimEvent( titan, "titan_impact", OnReplacementTitanImpact )
	AddAnimEvent( titan, "second_stage", OnReplacementTitanSecondStage, origin )
	HideTitanEyePartial( titan )

	local animation
	local sfxFirstPerson = "titan_hot_drop_turbo_begin"
	local sfxThirdPerson = "titan_hot_drop_turbo_begin_3P"

	animation = "at_hotdrop_drop_2knee_turbo"

	local impactTime = GetHotDropImpactTime( titan, animation )
	local result = titan.Anim_GetAttachmentAtTime( animation, "OFFSET", impactTime )
	local maxs = titan.GetBoundingMaxs()
	local mins = titan.GetBoundingMins()
	local mask = titan.GetPhysicsSolidMask()
	ModifyOriginForDrop( origin, mins, maxs, result.position, mask )


	titan.SetInvulnerable() // Make Titan invulnerable until bubble shield is up

	//DrawArrow( origin, angles, 10, 150 )
	titan.EnableRenderAlways()

	EmitSoundAtPosition( origin, sfxThirdPerson )

	SetStanceKneel( titan.GetTitanSoul() )

	waitthread PlayAnimTeleport( titan, animation, origin, angles )

	titan.ClearInvulnerable() //Make Titan vulnerable again once he's landed
}

function OnReplacementTitanSecondStage( titan, origin )
{
	local sfxFirstPerson = "titan_drop_pod_turbo_landing"
	local sfxThirdPerson = "titan_drop_pod_turbo_landing_3P"
	local player = titan.GetBossPlayer()
	EmitDifferentSoundsAtPositionForPlayerAndWorld( sfxFirstPerson, sfxThirdPerson, origin, player )
}

function OnReplacementTitanImpact( titan )
{
	ShowName( titan )
	thread CreateGenericBubbleShield( titan, titan.GetOrigin(), titan.GetAngles() )
	OnHotdropImpact( titan )
}



function Spawn_TrackedPilotWithTitan_Delayed( team, spawnPoint )
{
	local mode = GameRules.GetGameMode()
	if ( mode != TITAN_BRAWL && mode != LAST_TITAN_STANDING && mode != COOPERATIVE )
	{
		// ensure at least 40s have elapsed plus a random 20-90s delay (earliest spawn ~1 min)
		local waitTime = max( 0.0, 40.0 - GameTime.PlayingTime() )
		wait waitTime + RandomFloat( 20.0, 90.0 )
	}
	else if ( mode == COOPERATIVE )
	{
		wait RandomFloat( 0.0, 60.0 )
	}

    local spawned = Spawn_TrackedPilotWithTitan( team, spawnPoint )
    
    // If the spawn aborted and returned an empty array or null, free the slot
	if ( typeof spawned == "null" || (typeof spawned == "array" && spawned.len() == 0) )
    {
        if ( team in file.spawnedtitans )
            file.spawnedtitans[team] <- max(0, file.spawnedtitans[team] - 1)
    }
}

function SpawnPilotWithTitans( team )
{
    while( true )
    {
        local mode = GameRules.GetGameMode()

		if ( GameRules.GetGameMode() != COOPERATIVE && !IsNPCSpawningEnabled() )
            return

        local titanSpawnPoints = SpawnPoints_GetTitan()

        if ( titanSpawnPoints.len() <= 0 )
        {
            wait level.npcRespawnWait
            continue
        }

        local shouldSpawnPilotWithTitan = ShouldSpawnPilotWithTitan( team )

        if ( shouldSpawnPilotWithTitan )
        {
            local SpawnPoints = []

            foreach( spawnpoint in titanSpawnPoints )
            {
                if ( IsValid( spawnpoint ) && IsSpawnpointValidDrop( spawnpoint, team ) )
                    SpawnPoints.append( spawnpoint )
            }

            if ( SpawnPoints.len() <= 0 )
            {
                wait level.npcRespawnWait
                continue
            }

            local spawnPoint = Random( SpawnPoints )

            if ( team in file.spawnedtitans )
                file.spawnedtitans[team] <- file.spawnedtitans[team] + 1
            else
                file.spawnedtitans[team] <- 1

            thread Spawn_TrackedPilotWithTitan_Delayed( team, spawnPoint )
        }

        if ( mode == TITAN_BRAWL || mode == LAST_TITAN_STANDING )
            wait 0.5
        else
            wait level.npcRespawnWait
    }
}


function ShouldSpawnPilotWithTitan( team ) // Titan Spawns per Team
{
    if ( !(team in file.spawnedtitans) )
        file.spawnedtitans[team] <- 0

    local players = GetPlayerArray()
    if ( players.len() == 0 )
        return false // If no player is in yet, don't spawn
    
    local playerTeam = players[0].GetTeam()
    
    // Titan NPC spawn limit
    local limit = 0
	switch ( GameRules.GetGameMode() )
	{
		case TITAN_BRAWL:
		case LAST_TITAN_STANDING:
			limit = ( team == playerTeam ) ? 5 : 6   // 5 for your team, 6 for enemy team
			break

		case COOPERATIVE:
			limit = ( team == playerTeam ) ? 3 : 0   // 3 for your team in Frontier Defense
			break
			
		default: // Attrition, Hardpoint, Campaign, etc.
			if ( Riff_AILethality() == eAILethality.Default )
				limit = ( team == playerTeam ) ? 3 : 4   // 3 for your team, 4 for enemy team
			else if ( Riff_AILethality() == eAILethality.High )
				limit = ( team == playerTeam ) ? 3 : 5  
			else if ( Riff_AILethality() == eAILethality.VeryHigh )
				limit = ( team == playerTeam ) ? 3 : 5 
			break
	}

	local mapName = GetMapName()
	if ( mapName == "mp_npe" )
	{
		limit = ( team == playerTeam ) ? 2 : 3
	}		

    return file.spawnedtitans[team] < limit
}

function Coop_SpawnTitansAfterDelay()
{
	// Wait 60 in-game seconds
	wait 60.0
	
	// Start spawning Titans for friendly team (TEAM_MILITIA in Coop)
	thread SpawnPilotWithTitans( TEAM_MILITIA )
}

function AutoTitan_NuclearPayload_DamageCallback( titan, damageInfo )
{
	if ( !IsAlive( titan ) )
		return

	local titanOwner = titan.GetBossPlayer()
	if ( IsValid( titanOwner ) )
	{
		Assert( titanOwner.IsPlayer() )
		Assert( GetPlayerTitanInMap( titanOwner ) == titan )
		return
	}

	local nuclearPayload = NPC_GetNuclearPayload( titan )
	if ( !nuclearPayload )
		return

	if ( !titan.GetDoomedState() )
		return

	if ( titan.GetTitanSoul().IsEjecting() )
		return

	// - if a player titan is nearby, try to nuke right next to him
	if ( !AutoTitan_IsPlayerTitanInRange( titan, NUKE_TITAN_PLAYER_DETECT_RANGE ) )
	{
		// Otherwise try to nuke at a semirandom doomed state health fraction. (Like a player, more random.)
		if ( !( "doomedStateNukeTriggerHealth" in titan.s ) )
		{
			local lowEnd = floor( ( titan.GetMaxHealth() * 0.95 ) + 0.5 )
			local highEnd = floor( ( titan.GetMaxHealth() * 0.99 ) + 0.5 )

			titan.s.doomedStateNukeTriggerHealth <- RandomInt( lowEnd, highEnd )
		}

		if ( titan.GetHealth() > titan.s.doomedStateNukeTriggerHealth )
		{
			//printt( "titan health:", titan.GetHealth(), "health to nuke:", titan.s.doomedStateNukeTriggerHealth )
			return
		}

		printt( "NUKE TITAN DOOMED TRIGGER HEALTH REACHED, NUKING! Health:", titan.s.doomedStateNukeTriggerHealth )
	}
	else
	{
		printt( "PLAYER TITAN IN RANGE, NUKING!" )
	}

	thread TitanEjectPlayer( titan )
}

function AutoTitan_IsPlayerTitanInRange( autoTitan, maxDist )
{
	// Distance checks are expensive, don't do them as often as a damage callback could happen (every frame)
	if ( !AutoTitan_CanDoRangeCheck( autoTitan ) )
		return false

	local testOrg = autoTitan.GetOrigin()
	foreach ( player in GetPlayerArray() )
	{
		local playerTitan = player
		if ( !player.IsTitan() )
		{
			playerTitan = GetPlayerTitanInMap( player )

			if ( !playerTitan )
				continue
		}

		if ( Distance( testOrg, playerTitan.GetOrigin() ) <= maxDist )
			return true
	}

	return false
}

function AutoTitan_CanDoRangeCheck( autoTitan )
{
	if ( !( "nextPlayerTitanRangeCheckTime" in autoTitan.s ) )
		autoTitan.s.nextPlayerTitanRangeCheckTime <- -1

	if ( Time() < autoTitan.s.nextPlayerTitanRangeCheckTime )
	{
		return false
	}
	else
	{
		autoTitan.s.nextPlayerTitanRangeCheckTime = Time() + NUKE_TITAN_RANGE_CHECK_SLEEP_SECS
		return true
	}
}

//=========================================================
// Ripped this stuff down here from Auto Titan Brawl to make the Titans more aggressive
// ...Look man, don't ask questions. It just works
//=========================================================

function AI_SpottingThink( titan, team = null )
{
	// Unified spotting logic that works for any NPC Titan
	titan.EndSignal( "OnDeath" )
	titan.EndSignal( "OnDestroy" )

	local titanTeam = team != null ? team : titan.GetTeam()
	if ( !("aiSpottedPlayers" in level) )
		level.aiSpottedPlayers <- {}
	
	if ( !(titanTeam in level.aiSpottedPlayers) )
		level.aiSpottedPlayers[titanTeam] <- {}

	while ( true )
	{
		local enemyTeam = GetOtherTeam( titanTeam )
		local enemyPlayers = GetPlayerArrayOfTeam( enemyTeam )
		
		foreach ( player in enemyPlayers )
		{
			if ( !IsValid( player ) || !IsAlive( player ) )
				continue
			
			// Skip if already spotted by this team
			if ( player in level.aiSpottedPlayers[titanTeam] )
				continue
			
			// Check if titan is facing the player
			local toPlayer = player.GetOrigin() - titan.GetOrigin()
			toPlayer.Norm()
			local facing = titan.GetForwardVector()
			local dot = facing.Dot( toPlayer )
			
			// Within ~90 degree cone
			if ( dot > 0.0 )
			{
				// Check line of sight
				local traceResult = TraceLine( titan.EyePosition(), player.EyePosition(), [titan], TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE )
				
				if ( traceResult.fraction >= 0.99 || traceResult.hitEnt == player )
				{
					// Player spotted globally
					level.aiSpottedPlayers[titanTeam][player] <- true
					if ( file.debug & DEBUG_NPC_FRONTLINE )
						printt( "[AI] Titan spotted enemy:", player.GetPlayerName() )
				}
			}
		}
		
		wait 0.5  // Check twice per second
	}
}

function AI_HuntThink( titan, team = null )
{
    if ( !IsValid( titan ) || !IsAlive( titan ) )
        return

    titan.EndSignal( "OnDeath" )
    titan.EndSignal( "OnDestroy" )

    local titanTeam = team != null ? team : titan.GetTeam()

    if ( !IsValid( titan ) || !IsAlive( titan ) )
        return

    local lastValidTargetTime = Time()
    local lastPosition = titan.GetOrigin()
    local lastPositionCheckTime = Time()
    local stuckThreshold = 2.0
    local minMovementDistance = 100.0

    while ( true )
    {
        // Titan may have been destroyed between waits.
        if ( !IsValid( titan ) || !IsAlive( titan ) )
            return

        local currentTime = Time()
        local currentPosition = titan.GetOrigin()
        local timeSinceLastCheck = currentTime - lastPositionCheckTime

        if ( timeSinceLastCheck >= stuckThreshold )
        {
            local distanceMoved = Distance( currentPosition, lastPosition )

            if ( distanceMoved < minMovementDistance )
            {
                if ( IsValid( titan ) && IsAlive( titan ) )
                    AI_SendToRandomLocation( titan, titanTeam )

                lastValidTargetTime = currentTime
            }

            lastPosition = currentPosition
            lastPositionCheckTime = currentTime
        }

        if ( !IsValid( titan ) || !IsAlive( titan ) )
            return

        local target = AI_SelectTarget( titan, titanTeam )

        if ( IsValid( target ) )
        {
            if ( !IsValid( titan ) || !IsAlive( titan ) )
                return

            titan.SetEnemy( target )
            SendAIToAssaultPoint( titan, target.GetOrigin(), null, 256 )
            lastValidTargetTime = currentTime
        }
        else
        {
            local timeSinceLastTarget = currentTime - lastValidTargetTime

            if ( timeSinceLastTarget >= 1.0 )
            {
                if ( !IsValid( titan ) || !IsAlive( titan ) )
                    return

                AI_SendToRandomLocation( titan, titanTeam )
                lastValidTargetTime = currentTime
            }
        }

        wait RandomFloat( 1.5, 3.0 )
    }
}

function AI_SelectTarget( titan, team )
{
	if ( !IsValid( titan ) || !IsAlive( titan ) )
        return null

	local enemyTeam = GetOtherTeam( team )
	local origin = titan.GetOrigin()
	local highPriority = []

	// Priority 1: Spotted players and enemy titans
	if ( team in level.aiSpottedPlayers )
	{
		local enemyPlayers = GetPlayerArrayOfTeam( enemyTeam )
		foreach ( player in enemyPlayers )
		{
			if ( player in level.aiSpottedPlayers[team] )
				highPriority.append( player )
		}
	}

	// Add ALL enemy titans
	highPriority.extend( GetNPCArrayEx( "npc_titan", enemyTeam, origin, -1 ) )

	local best = AI_FindClosestValid( highPriority, origin )
	if ( best != null )
		return best

	// Priority 2: Low priority NPCs
	local lowPriority = []
	lowPriority.extend( GetNPCArrayEx( "npc_soldier", enemyTeam, origin, -1 ) )
	lowPriority.extend( GetNPCArrayEx( "npc_spectre", enemyTeam, origin, -1 ) )

	return AI_FindClosestValid( lowPriority, origin )
}

function AI_FindClosestValid( candidates, origin )
{
	local best = null
	local bestDist = 99999999.0

	foreach ( candidate in candidates )
	{
		if ( !IsValid( candidate ) )
			continue
		if ( candidate.IsPlayer() && !IsAlive( candidate ) )
			continue

		local dist = DistanceSqr( candidate.GetOrigin(), origin )
		if ( dist < bestDist )
		{
			best = candidate
			bestDist = dist
		}
	}

	return best
}

function AI_SendToRandomLocation( titan, team )
{
	local enemyTeam = GetOtherTeam( team )
	local assaultPoints = GetEntArrayByClass_Expensive( "info_frontline" )

	if ( assaultPoints.len() > 0 )
	{
		local randomPoint = assaultPoints[ RandomInt( assaultPoints.len() ) ]
		SendAIToAssaultPoint( titan, randomPoint.GetOrigin(), null, 512 )
		return
	}

	local enemySpawns = SpawnPoints_GetTitanStart( enemyTeam )
	if ( enemySpawns.len() > 0 )
	{
		local randomSpawn = enemySpawns[ RandomInt( enemySpawns.len() ) ]
		SendAIToAssaultPoint( titan, randomSpawn.GetOrigin(), null, 512 )
		return
	}

	local currentPos = titan.GetOrigin()
	local randomOffset = Vector( RandomFloat( -1000, 1000 ), RandomFloat( -1000, 1000 ), 0 )
	SendAIToAssaultPoint( titan, currentPos + randomOffset, null, 256 )
}


////////////////////////////////////////////////////////////
/////////////// DOME SHIELD SHENANIGANS ////////////////////
////////////////////////////////////////////////////////////
function DecayNPCDomeShield( titan, delay )
{
    titan.EndSignal( "OnDeath" )
    titan.EndSignal( "OnDestroy" )

    wait delay

    // Ensure the Titan has a valid soul and shield before trying to destroy it
    if ( IsValid( titan ) && IsValid( titan.GetTitanSoul() ) )
    {
        local soul = titan.GetTitanSoul()
        if ( IsValid( soul.bubbleShield ) )
        {
            soul.bubbleShield.Destroy()
        }
    }
}