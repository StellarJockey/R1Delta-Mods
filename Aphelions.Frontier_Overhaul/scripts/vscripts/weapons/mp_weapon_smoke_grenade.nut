const PILOT_SMOKE_FLIGHT_LIMIT = 5.0
const PILOT_SMOKE_DURATION = 7.0
const PILOT_SMOKE_TICK = 0.2
const PILOT_SMOKE_RADIUS = 210

function PilotSmokePrecache()
{
	if ( WeaponIsPrecached( self ) )
		return
	PrecacheParticleSystem( FX_ELECTRIC_SMOKESCREEN )
	if ( IsServer() )
		PrecacheEntity( "npc_grenade_frag" )
}
PilotSmokePrecache()

function OnWeaponTossPrep( prepParams )
{
	self.s.pilotSmokePrimed <- true
	self.EmitWeaponSound( "Weapon_SmokeGrenade_PinPull" )
}

function OnWeaponDeactivate( deactivateParams )
{
	self.s.pilotSmokePrimed <- false
}

function OnWeaponTossReleaseAnimEvent( attackParams )
{
	if ( !( "pilotSmokePrimed" in self.s ) || !self.s.pilotSmokePrimed )
		return 0
	self.s.pilotSmokePrimed = false

	local owner = self.GetWeaponOwner()
	if ( !IsValid( owner ) || !IsAlive( owner ) || !owner.IsPlayer() || owner.IsTitan() )
		return 0
	if ( owner.GetCinematicEventFlags() & ( CE_FLAG_CLASSIC_MP_SPAWNING | CE_FLAG_INTRO ) )
		return 0

	self.EmitWeaponSound( "Weapon_EMPGrenade_Throw" )
	if ( IsClient() && !self.ShouldPredictProjectiles() )
		return 1

	local angles = attackParams.dir.GetAngles()
	angles.x -= 8
	local velocity = angles.AnglesToForward() * 1100
	local spin = Vector( 1800, 0, 0 )
	local grenade = self.FireWeaponGrenade( attackParams.pos, velocity, spin, PILOT_SMOKE_FLIGHT_LIMIT + 0.4,
		damageTypes.Explosive, damageTypes.Explosive, PROJECTILE_PREDICTED, true, true )
	if ( !IsValid( grenade ) )
		return IsClient() ? 1 : 0

	if ( IsServer() )
	{
		Grenade_Init( grenade, self )
		thread PilotSmokeFlightTimeout( grenade )
	}
	else
		grenade.SetTeam( owner.GetTeam() )
	return 1
}

function OnProjectileCollision( collisionParams )
{
	if ( !IsServer() || collisionParams.normal.z < 0.55 )
		return
	local hit = collisionParams.hitent
	if ( IsValid( hit ) && ( hit.IsPlayer() || hit.IsNPC() || hit.IsTitan() ) )
		return
	PilotSmokeBurst( self, collisionParams.pos, "landing" )
}

function PilotSmokeFlightTimeout( grenade )
{
	grenade.EndSignal( "OnDestroy" )
	wait PILOT_SMOKE_FLIGHT_LIMIT
	if ( !IsValid( grenade ) )
		return
	local origin = grenade.GetOrigin()
	local floor = TraceLine( origin, origin - Vector( 0, 0, 64 ), [ grenade ], TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )
	PilotSmokeBurst( grenade, floor.fraction < 1.0 ? floor.endPos : origin, "timeout" )
}

function PilotSmokeBurst( grenade, impact, reason )
{
	if ( !IsValid( grenade ) || "pilotSmokeBurst" in grenade.s )
		return
	grenade.s.pilotSmokeBurst <- true
	local owner = grenade.GetOwner()
	local team = grenade.GetTeam()
	grenade.Kill()
	thread PilotSmokeCloud( impact + Vector( 0, 0, 12 ), owner, team )
}

function PilotSmokeCloud( origin, owner, team )
{
	local control = CreateEntity( "info_placement_helper" )
	control.SetName( UniqueString( "pilot_smoke_lifetime" ) )
	control.SetOrigin( Vector( PILOT_SMOKE_DURATION, 0, 0 ) )
	DispatchSpawn( control, false )
	control.Kill( PILOT_SMOKE_DURATION + 0.25 )
	PlayFXWithControlPoint( FX_ELECTRIC_SMOKESCREEN, origin, control )

	local blocker = CreateEntity( "trace_volume" )
	blocker.SetName( UniqueString( "pilot_smoke_blocker" ) )
	blocker.SetBox( Vector( -105, -105, -12 ), Vector( 105, 105, 140 ) )
	blocker.SetOrigin( origin )
	blocker.Kill( PILOT_SMOKE_DURATION )

	local damage = CreateEntity( "env_explosion" )
	damage.kv.spawnflags = ( SF_ENVEXPLOSION_NOSOUND | SF_ENVEXPLOSION_NODECAL |
		SF_ENVEXPLOSION_REPEATABLE | SF_ENVEXPLOSION_NOFIREBALL | SF_ENVEXPLOSION_NOSMOKE | SF_ENVEXPLOSION_NOSPARKS |
		SF_ENVEXPLOSION_NOPARTICLES | SF_ENVEXPLOSION_NOFIREBALLSMOKE | SF_ENVEXPLOSION_NODLIGHTS | SF_ENVEXPLOSION_MASK_BRUSHONLY )
	
	damage.kv.damageSourceId = eDamageSourceId.mp_weapon_smoke_grenade
	damage.kv.scriptDamageType = DF_ELECTRICAL | DF_NO_HITBEEP
	damage.kv.iMagnitude = 15
	damage.kv.iMagnitudeHeavyArmor = 30
	damage.kv.iInnerRadius = 50
	damage.kv.iRadiusOverride = PILOT_SMOKE_RADIUS
	damage.SetOrigin( origin )
	if ( IsValid( owner ) )
		damage.SetOwner( owner )
	damage.SetTeam( team )
	damage.s.weaponMods <- []
	DispatchSpawn( damage, false )
	damage.Kill( PILOT_SMOKE_DURATION )
	damage.EndSignal( "OnDestroy" )

	EmitSoundAtPosition( origin, "Grenade_ElectricSmoke_Deploy" )
	EmitSoundOnEntity( damage, SFX_SMOKE_LOOP )
	local endTime = Time() + PILOT_SMOKE_DURATION
	wait 0.8
	while ( Time() < endTime )
	{
		damage.Fire( "Explode" )
		wait PILOT_SMOKE_TICK
	}
}
