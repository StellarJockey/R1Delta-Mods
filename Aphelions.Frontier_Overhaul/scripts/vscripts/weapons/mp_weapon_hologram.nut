const HOLOGRAM_DEFAULT_WEAPON = "mp_weapon_rspn101"
const HOLOGRAM_RUN_DISTANCE = 1024   // units; Tune to taste (1 ft is about 16 units)

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
	hologram.s.isPilot <- true
	SetNPCAsPilot( hologram, true )
	hologram.kv.allowshoot = 0

	GiveMinionWeapon( hologram, weaponName )
	if ( atWeaponName )
	{
		hologram.TakeActiveWeapon()
		hologram.GiveWeapon( atWeaponName )     // no mods, that's what crashed before
		hologram.kv.additionalequipment = atWeaponName
		hologram.s.atWeapon <- atWeaponName     // rocket system uses this instead of a random AT weapon
	}

	hologram.SetMaxHealth( 32000 )
	hologram.SetHealth( 32000 )
	hologram.SetInvulnerable()
	hologram.NotSolid()
	hologram.kv.squadname = "hologram_" + player.GetEntIndex()

	DispatchSpawn( hologram )

	hologram.SetAISettings( "fireteam_pilot" )
	hologram.SetMoveSpeedScale( 1.20 )
	hologram.PreferSprint( true )
	hologram.SetHearingSensitivity( 10 )
	hologram.AllowFlee( false )
	hologram.AllowHandSignals( false )

	local best = FindForwardPoint( hologram, player )
	if ( best == null )
		best = hologram.GetOrigin() + Vector( 0, player.GetAngles().y, 0 ).AnglesToForward() * 200  // see note below

	thread RandomFlicker( hologram )
	thread HologramRushForward( hologram, best )

	return hologram
}

function RandomFlicker( hologram )
{
	hologram.EndSignal( "OnDestroy" )
	hologram.EndSignal( "OnDeath" )

	local flicker = RandomFloat( 0.2, 0.4 )
	wait 1.0
	
    while ( IsValid( hologram ) && !( "dying" in hologram.s ) )
    {
		if ( RandomFloat( 0.0, 1.0 ) < 0.25 ) // small chance to flicker like they're a HUD glitch
			SniperCloak( hologram )
		
		hologram.SetCloakDuration( flicker, 0, flicker )

		wait RandomFloat( 1.0, 5.0 )
	}
}

function PlayerTempCloakOn( player )
{
	SniperCloak( player )
	EmitSoundOnEntity( player, "Cloak_On" )
	EmitSoundOnEntity( player, "Cloak_Sustain_Loop" )
	player.SetCloakDuration( 1.0, 3.0, 1.0 )

	thread HandleCloakEnd( player )
}

function FindForwardPoint( hologram, player )
{
	local origin = hologram.GetOrigin()
	local forward = Vector( 0, player.GetAngles().y, 0 ).AnglesToForward()
	local eyeOffset = Vector( 0, 0, 32 )

	// walk from far to near; first valid, unobstructed node wins
	for ( local dist = HOLOGRAM_RUN_DISTANCE; dist >= 150; dist -= 75 )
	{
		local target = origin + forward * dist
		local node = GetNearestNodeToPos( target )
		if ( node == null || node < 0 )
			continue

		local pos = GetNodePos( node, HULL_HUMAN )
		if ( Distance( pos, target ) > 150 )
			continue   // snapped too far from where we wanted to go

		local dx = pos.x - origin.x
		local dy = pos.y - origin.y
		local flat = sqrt( dx * dx + dy * dy )
		if ( flat < 100 || ( dx * forward.x + dy * forward.y ) / flat < 0.85 )
			continue   // not actually in front

		// reject if a wall is in the way (swap in whatever trace helper your other files use)
		if ( TraceLineSimple( origin + eyeOffset, pos + eyeOffset, hologram ) < 1.0 )
			continue

		return pos
	}
	return null
}

function HologramRushForward( hologram, best )
{
	hologram.EndSignal( "OnDestroy" )
	hologram.EndSignal( "OnDeath" )

	hologram.Anim_Stop()
	hologram.AllowFlee( false )
	hologram.AllowHandSignals( false )

	// strict: no diversion, no timeout. This is the same entity GotoOrigin uses
	local assaultEnt = CreateStrictAssaultEnt( best, null, 64 )

	OnThreadEnd( function() : ( assaultEnt ) {
		if ( IsValid( assaultEnt ) )
			assaultEnt.Kill()
	})

	hologram.AssaultPointEnt( assaultEnt )

	// strict + nevertimeout never finishes by itself, so cap the run
	local timeout = Time() + 5.0
	while ( Time() < timeout && Distance( hologram.GetOrigin(), best ) > 96 )
		wait 0.1

	// stay on the assault ent (holding at the destination) until the hologram dies.
	// The EndSignals above trigger OnThreadEnd, which cleans the ent up.
	WaitForever()
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