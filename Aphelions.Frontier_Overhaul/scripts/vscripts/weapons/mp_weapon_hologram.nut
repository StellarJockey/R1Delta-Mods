const HOLOGRAM_DEFAULT_WEAPON = "mp_weapon_rspn101"
const HOLOGRAM_RUN_DISTANCE = 500   // units; Tune to taste (1 ft is about 16 units)

function OnWeaponPrimaryAttack( attackParams )
{
	local ownerPlayer = self.GetWeaponOwner()
	if ( !IsValid( ownerPlayer ) || !ownerPlayer.IsPlayer() )
		return 0

	local flags = ownerPlayer.GetCinematicEventFlags()
	if ( flags & CE_FLAG_CLASSIC_MP_SPAWNING || flags & CE_FLAG_INTRO )
		return 0

	if ( IsServer() )
		thread StartHologram( ownerPlayer, self.GetWeaponModSetting( "fire_duration" ) )

	return 1
}

function StartHologram( player, duration )
{
	// one hologram per player
	if ( "hologram" in player.s && IsValid( player.s.hologram ) )
		thread HologramKill( player.s.hologram )

	local hologram = CreateHologram( player )
	player.s.hologram <- hologram

	hologram.EndSignal( "OnDestroy" )
	hologram.EndSignal( "OnDeath" )
	player.EndSignal( "OnDeath" )
	player.EndSignal( "OnDestroy" )

	OnThreadEnd( function() : ( hologram ) {
		thread HologramKill( hologram )   // no-op if already dying
	})

	wait duration
}

function CreateHologram( player )
{
	local weaponName = GetHologramWeaponName( player )
	local atWeaponName = GetHologramATWeaponName( player )
	local hologram = CreateEntity( "npc_soldier" )
	local playerModel = player.GetModelName()
	local hologramModel = playerModel
	local team = player.GetTeam()
	local name = player.GetPlayerName()

	// female models don't want to work... for some reason
	if ( team == TEAM_IMC )
	{
		if ( playerModel == IMC_FEMALE_BR )
			hologramModel = IMC_MALE_BR
		else if ( playerModel == IMC_FEMALE_CQ )
			hologramModel = IMC_MALE_CQ
		else if ( playerModel == IMC_FEMALE_DM )
			hologramModel = IMC_MALE_DM
	}
	else // militia, default
	{
		if ( playerModel == MILITIA_FEMALE_BR )
			hologramModel = MILITIA_MALE_BR
		else if ( playerModel == MILITIA_FEMALE_CQ )
			hologramModel = MILITIA_MALE_CQ
		else if ( playerModel == MILITIA_FEMALE_DM )
			hologramModel = MILITIA_MALE_DM
	}

	hologram.SetModel( hologramModel )
	hologram.SetOrigin( player.GetOrigin() )
	hologram.SetAngles( player.GetAngles() )
	hologram.SetTeam( player.GetTeam() )
	hologram.SetTitle( name )
	hologram.SetName( name )

	if ( !IsCloaked( player ) )
		thread PlayerTempCloakOn( player )

	hologram.s.isHologram <- true
	hologram.s.IsSoldier <- false
	hologram.s.isPilot <- false
	SetNPCAsPilot( hologram, true )
	hologram.kv.allowshoot = 0

	GiveMinionWeapon( hologram, weaponName )
	if ( atWeaponName )
	{
		hologram.TakeActiveWeapon()
		hologram.GiveWeapon( atWeaponName )     // no mods, that's what crashed before
		hologram.s.atWeapon <- atWeaponName     // rocket system uses this instead of a random AT weapon
		SetupSoldierForRPGs( hologram, hologram.GetTeam() )
		hologram.s.useRPGPreference = RPG_USE_ALWAYS   // set after, since SetupSoldierForRPGs overwrites it
	}

	hologram.SetMaxHealth( 1000 )
	hologram.SetHealth( 1000 )
	hologram.SetInvulnerable()
	hologram.SetMoveSpeedScale( 1.20 )
	hologram.SetAISettings( "fireteam_pilot" )
	hologram.PreferSprint( true )
	hologram.SetHearingSensitivity( 10 )
	hologram.AllowFlee( false )
	hologram.AllowHandSignals( true )

	DispatchSpawn( hologram )

	thread HologramRushForward( hologram, player )
	return hologram
}

function PlayerTempCloakOn( player )
{
	SniperCloak( player )
	EmitSoundOnEntity( player, "Cloak_On" )
	EmitSoundOnEntity( player, "Cloak_Sustain_Loop" )
	player.SetCloakDuration( 1.0, 3.0, 1.0 )

	thread HandleCloakEnd( player )
}

function HologramRushForward( hologram, player )
{
	hologram.EndSignal( "OnDestroy" )
	hologram.EndSignal( "OnDeath" )

	local yaw = player.GetAngles().y
	local forward = Vector( 0, yaw, 0 ).AnglesToForward()
	local origin = hologram.GetOrigin()

	local startNode = GetNearestNodeToPos( origin )
	if ( startNode == null || startNode < 0 )
		return   // nowhere reachable in front: just let normal AI take over

	local neighbors = GetNeighborNodes( startNode, 5, HULL_HUMAN )
	local best = null
	local bestDist = 0

	foreach ( index in neighbors )
	{
		if ( index == null || index < 0 )
			continue

		local pos = GetNodePos( index, HULL_HUMAN )
		local dist = Distance( origin, pos )
		if ( dist < 100 || dist > HOLOGRAM_RUN_DISTANCE * 1.3 )
			continue

		// how closely this node lines up with the player's facing (flat, -1 to 1)
		local dx = pos.x - origin.x
		local dy = pos.y - origin.y
		local alignment = ( dx * forward.x + dy * forward.y ) / dist
		if ( alignment < 0.5 )
			continue

		// prefer the farthest node that is still in front
		if ( dist > bestDist )
		{
			best = pos
			bestDist = dist
		}
	}

	if ( best == null )
		return   // nowhere reachable in front: just let normal AI take over

	hologram.AssaultPoint( best )

	local timeout = Time() + 4.0
	while ( Time() < timeout && Distance( hologram.GetOrigin(), best ) > 80 )
		wait 0.2

	hologram.DisableBehavior( "Assault" )
}

function GetHologramWeaponName( player )
{
	local weapon = player.GetActiveWeapon()
	if ( !IsValid( weapon ) )
		return HOLOGRAM_DEFAULT_WEAPON

	local name = weapon.GetClassname()

	switch ( name )
	{
		case "mp_weapon_rspn101":
		case "mp_weapon_car":
		case "mp_weapon_lmg":
		case "mp_weapon_hemlok":
		case "mp_weapon_shotgun":
		case "mp_weapon_r97":
		case "mp_weapon_smart_pistol":
		case "mp_weapon_dmr":
		case "mp_weapon_sniper":
		case "mp_weapon_g2":
		case "mp_weapon_mega1":
		case "mp_weapon_mega9":
		
		case "mp_weapon_semipistol":
		case "mp_weapon_autopistol":
		case "mp_weapon_wingman":
		case "mp_weapon_mega2":
		
			return name
	}

	return HOLOGRAM_DEFAULT_WEAPON
}

function GetHologramATWeaponName( player )
{
	local weapon = player.GetActiveWeapon()
	if ( !IsValid( weapon ) )
		return null

	local name = weapon.GetClassname()
	switch ( name )
	{
		case "mp_weapon_rocket_launcher":
		case "mp_weapon_smr":
		case "mp_weapon_mgl":
		case "mp_weapon_defender":
			return name
	}
	return null
}

// Single removal path for timeout, player death, and replacement
function HologramKill( hologram )
{
	if ( !IsValid( hologram ) || "dying" in hologram.s )
		return
	hologram.s.dying <- true

	local weapon = hologram.GetActiveWeapon()
	if ( IsValid( weapon ) )
		weapon.Destroy()
	hologram.SetTitle( "" )

	EmitSoundAtPosition( hologram.GetOrigin(), "Object_Dissolve" )
	// your unique hologram FX here

	hologram.Dissolve( ENTITY_DISSOLVE_CHAR, Vector( 0, 0, 0 ), 0 )
	wait 1.0
	if ( IsValid( hologram ) )
		hologram.Destroy()
}

function HandleCloakEnd( player )
{
	player.EndSignal( "OnDeath" )
	player.EndSignal( "Disconnected" )
	player.EndSignal( "OnEMPPilotHit" )
	player.EndSignal( "OnChangedPlayerClass" )
	player.Signal( "OnStartCloak" )
	player.EndSignal( "OnStartCloak" )

	local duration = player.GetCloakEndTime() - Time()

	OnThreadEnd(
		function() : ( player )
		{
			if ( !IsValid( player ) )
				return

			StopSoundOnEntity( player, "Cloak_Sustain_Loop" ) // broken w/ looping sounds
			FadeOutSoundOnEntity( player, "Cloak_Sustain_Loop", 0.1 )
			if ( !IsCloaked( player ) )
				return

			if ( !IsAlive( player ) || !player.IsHuman() )
			{
				DisableCloak( player )
				return
			}

			local duration = player.GetCloakEndTime() - Time()
			if ( duration <= 0 )
			{
				DisableCloak( player )
			}
		}
	)

	local soundBufferTime = 3.45

	if ( duration > soundBufferTime )
	{
		wait ( duration - soundBufferTime )
		if ( !IsCloaked( player ) )
			return
		EmitSoundOnEntity( player, "Cloak_WarningToEnd" )
		wait soundBufferTime
	}
	else
	{
		wait duration
	}
}
