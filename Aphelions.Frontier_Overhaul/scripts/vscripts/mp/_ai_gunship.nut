////////////////////////////////////////////////////////////
////////////// BEHOLD, FRANKENSTEIN'S GUNSHIP //////////////
////////////////////////////////////////////////////////////
// This thing was vibe-coded to hell and back... but it works for now

const AI_GUNSHIP_HEALTH = 10000
const AI_GUNSHIP_AIRSPEED = 2000
const AI_GUNSHIP_ACCEL = 1.75
const AI_GUNSHIP_YAWRATE = 90
const AI_GUNSHIP_HOVER_HEIGHT = 700
const AI_GUNSHIP_MAX_ENEMY_DIST = 12000

const AI_GUNSHIP_TARGET_OFFSET_RADIUS = 700
const AI_GUNSHIP_TARGET_OFFSET_HEIGHT = 120
const AI_GUNSHIP_SEPARATION_RADIUS = 500
const AI_GUNSHIP_SEPARATION_RADIUS_SQR = 250000
const AI_GUNSHIP_SEPARATION_STRENGTH = 250

const MINIMAP_GUNSHIP_SCALE = 0.12

PrecacheModel( STRATON_MODEL )
PrecacheModel( HORNET_MODEL )
PrecacheWeapon( "mp_weapon_yh803_bullet" )

function SpawnAIGunship( team, origin, angles = Vector( 0, 0, 0 ), squadname = null, health = AI_GUNSHIP_HEALTH, warpAnimation = null )
{
	local spawnOrigin = origin + Vector( 0, 0, AI_GUNSHIP_HOVER_HEIGHT )

	local shipModel
	local title

	switch ( team )
	{
		case TEAM_MILITIA:
			shipModel = HORNET_MODEL
			title = "Militia Hornet"
			break

		case TEAM_IMC:
			shipModel = STRATON_MODEL
			title = "IMC Phantom"
			break

		default:
			printt( "[AI_GUNSHIP] invalid team:", team )
			return null
	}

	local mover = CreateEntity( "script_mover" )

	mover.kv.solid = 6
	mover.kv.model = shipModel
	mover.kv.SpawnAsPhysicsMover = 1
	mover.kv.CollisionGroup = 21
	mover.SetOrigin( spawnOrigin )
	mover.SetAngles( angles )
	DispatchSpawn( mover, true )
	mover.Hide()
	mover.NotSolid()

	mover.SetMaxSpeed( AI_GUNSHIP_AIRSPEED )
	mover.SetAccelScale( AI_GUNSHIP_ACCEL )
	mover.SetYawRate( AI_GUNSHIP_YAWRATE )

	// Prevent the mover from initially falling or choosing an invalid path
	mover.SetMoveToPosition( spawnOrigin )

	local gunship = CreateEntity( "npc_dropship" )
	gunship.s.dogfighter <- true

	gunship.kv.spawnflags = 0
	gunship.kv.vehiclescript = "scripts/vehicles/airvehicle_default.txt"
	gunship.kv.teamnumber = team
	gunship.kv.desiredSpeed = 1
	gunship.kv.maxEnemyDist = AI_GUNSHIP_MAX_ENEMY_DIST
	gunship.kv.CollisionGroup = 21

	if ( squadname == null )
		squadname = "gunship_squad_" + gunship.GetEntIndex()

	gunship.kv.squadname = squadname

	gunship.SetModel( shipModel )
	gunship.SetOrigin( spawnOrigin )
	gunship.SetAngles( angles )
	gunship.SetTitle( title )

	// Must happen after the entity's keyvalues/model are prepared
	DispatchSpawn( gunship, true )

	gunship.SetTeam( team )
	gunship.SetHealth( health )
	gunship.SetMaxHealth( health )
	gunship.Solid()

	// Store movement state on the real npc_dropship.
	gunship.s.gunshipMover <- mover
	gunship.s.gunshipTargetOffset <- null
	gunship.s.gunshipIsIdle <- false
	gunship.s.gunshipIdleAngles <- angles

	// The dropship is the authoritative entity. The mover owns translation
	gunship.SetParent( mover, "", true, 0 )
	gunship.MarkAsNonMovingAttachment()
	AI_GunshipAddTurrets( gunship, team )

	// Keep the entity visible and usable as a normal NPC dropship
	gunship.EnableRenderAlways()
	// gunship.EnableAttackableByAI() <- error literally says NOT to do this
	SetVisibleEntitiesInConeQueriableEnabled( gunship, true )
	gunship.SetAimAssistAllowed( false )

	gunship.Minimap_SetDefaultMaterial( "vgui/hud/gunship_minimap" )
	gunship.Minimap_SetEnemyMaterial( "vgui/hud/gunship_minimap_orange" )
	gunship.Minimap_SetFriendlyMaterial( "vgui/hud/gunship_minimap" )
	gunship.Minimap_AlwaysShow( TEAM_IMC, null )
	gunship.Minimap_AlwaysShow( TEAM_MILITIA, null )
	gunship.Minimap_SetObjectScale( MINIMAP_GUNSHIP_SCALE )
	gunship.Minimap_SetZOrder( 10 )

	if ( warpAnimation != null )
		thread AIGunshipWarpIn( gunship, warpAnimation, spawnOrigin, angles )

	if ( level.aiHuntThinkEnabled )
		thread AI_GunshipHuntThink( gunship, team )

	return gunship
}
Globalize( SpawnAIGunship )

function AIGunshipWarpIn( gunship, animation, origin, angles )
{
	gunship.EndSignal( "OnDestroy" )
	gunship.EndSignal( "OnDeath" )

	WarpinEffect( gunship.GetModelName(), animation, origin, angles )
	gunship.Anim_Play( animation )
}
Globalize( AIGunshipWarpIn )

function AI_GunshipCanTarget( gunship, target )
{
	if ( !IsValid( target ) || !IsAlive( target ) )
		return false

	if ( "GetNoTarget" in target && target.GetNoTarget() )
		return false

	if ( IsCloaked( target ) )
		return false

	if ( !SimpleCanSeeEntity( gunship, target ) )
		return false

	return true
}


function AI_GunshipStopMover( gunship )
{
	if ( !IsValid( gunship ) || !( "gunshipMover" in gunship.s ) )
		return

	local mover = gunship.s.gunshipMover
	if ( !IsValid( mover ) )
		return

	// Preserve the heading the gunship had when it stopped.
	// The mover is the authoritative entity, so lock the mover itself.
	local lockedAngles = mover.GetAngles()

	mover.SetMoveToPosition( mover.GetOrigin() )
	mover.SetYawRate( 0 )
	mover.SetAngularVelocity( 0, 0, 0 )
	mover.SetAngles( lockedAngles )

	gunship.s.gunshipIdleAngles = lockedAngles
	gunship.s.gunshipIsIdle = true
}
Globalize( AI_GunshipStopMover )

function AI_GunshipHuntThink( gunship, team = null )
{
	if ( !IsValid( gunship ) || !IsAlive( gunship ) )
		return

	gunship.EndSignal( "OnDeath" )
	gunship.EndSignal( "OnDestroy" )

	local gunshipTeam = team != null ? team : gunship.GetTeam()

	while ( true )
	{
		if ( !IsValid( gunship ) || !IsAlive( gunship ) )
			return

		local currentTarget = gunship.GetEnemy()

		if ( IsValid( currentTarget ) && !AI_GunshipCanTarget( gunship, currentTarget ) )
		{
			gunship.SetEnemy( null )
			currentTarget = null
		}

		local target = currentTarget

		if ( !IsValid( target ) )
			target = AI_GunshipSelectTarget( gunship, gunshipTeam )

		if ( IsValid( target ) )
		{
			gunship.SetEnemy( target )
			AI_GunshipMoveTo( gunship, target )
		}
		else if ( "gunshipMover" in gunship.s )
		{
			local mover = gunship.s.gunshipMover
			if ( IsValid( mover ) )
			{
				if ( !gunship.s.gunshipIsIdle )
					AI_GunshipStopMover( gunship )
				else if ( "gunshipIdleAngles" in gunship.s )
				{
					// Keep the idle heading rigid. This prevents the physics mover
					// from accumulating or retaining a residual yaw rotation.
					mover.SetMoveToPosition( mover.GetOrigin() )
					mover.SetYawRate( 0 )
					mover.SetAngularVelocity( 0, 0, 0 )
					mover.SetAngles( gunship.s.gunshipIdleAngles )
				}
			}
		}

		wait 0.25
	}
}
Globalize( AI_GunshipHuntThink )

function AI_GunshipPathIsClear( gunship, start, destination, scale = 1.0 )
{
	local mins = gunship.GetBoundingMins()
	local maxs = gunship.GetBoundingMaxs()

	local halfExtent = fabs( mins.x )
	if ( fabs( maxs.x ) > halfExtent ) halfExtent = fabs( maxs.x )
	if ( fabs( mins.y ) > halfExtent ) halfExtent = fabs( mins.y )
	if ( fabs( maxs.y ) > halfExtent ) halfExtent = fabs( maxs.y )

	halfExtent *= scale

	mins = Vector( -halfExtent, -halfExtent, mins.z * scale )
	maxs = Vector(  halfExtent,  halfExtent, maxs.z * scale )

	local ignoreArray = [ gunship ]
	if ( "gunshipMover" in gunship.s )
		ignoreArray.append( gunship.s.gunshipMover )

	local trace = TraceHull(
		start,
		destination,
		mins,
		maxs,
		ignoreArray,
		TRACE_MASK_NPCWORLDSTATIC,
		TRACE_COLLISION_GROUP_NONE
	)

	if ( trace.startSolid || trace.allSolid )
		return false

	return trace.fraction >= 0.99
}

function AI_GunshipMoveTo( gunship, target )
{
	if ( !( "gunshipMover" in gunship.s ) )
		return

	local mover = gunship.s.gunshipMover
	if ( !IsValid( mover ) )
		return

	if ( !AI_GunshipCanTarget( gunship, target ) )
		return

	local start = mover.GetOrigin()

	// Calculate target destination with offset
	if ( gunship.s.gunshipTargetOffset == null )
	{
		local angle = ( gunship.GetEntIndex() % 8 ) * 45.0 * 0.0174532925
		gunship.s.gunshipTargetOffset = Vector(
			cos( angle ) * AI_GUNSHIP_TARGET_OFFSET_RADIUS,
			sin( angle ) * AI_GUNSHIP_TARGET_OFFSET_RADIUS,
			RandomFloat( -AI_GUNSHIP_TARGET_OFFSET_HEIGHT, AI_GUNSHIP_TARGET_OFFSET_HEIGHT )
		)
	}

	local destination = target.GetOrigin() + Vector( 0, 0, AI_GUNSHIP_HOVER_HEIGHT ) + gunship.s.gunshipTargetOffset

	// Apply separation
	local nearby = GetNPCArrayEx( "npc_dropship", TEAM_IMC, gunship.GetOrigin(), AI_GUNSHIP_SEPARATION_RADIUS )
	nearby.extend( GetNPCArrayEx( "npc_dropship", TEAM_MILITIA, gunship.GetOrigin(), AI_GUNSHIP_SEPARATION_RADIUS ) )
	foreach ( other in nearby )
	{
		if ( other == gunship || !IsValid( other ) || !IsAlive( other ) ) continue
		local delta = gunship.GetOrigin() - other.GetOrigin()
		local distanceSqr = delta.LengthSqr()
		if ( distanceSqr >= AI_GUNSHIP_SEPARATION_RADIUS_SQR ) continue

		if ( distanceSqr < 1 ) {
			delta = Vector( RandomFloat( -1.0, 1.0 ), RandomFloat( -1.0, 1.0 ), 0 )
			distanceSqr = 1
		}
		delta.Normalize()
		local strength = 1.0 - ( sqrt( distanceSqr ) / AI_GUNSHIP_SEPARATION_RADIUS )
		destination += delta * ( AI_GUNSHIP_SEPARATION_STRENGTH * strength )
	}

	if ( DistanceSqr( start, destination ) <= 65536 )
	{
		if ( !gunship.s.gunshipIsIdle )
			AI_GunshipStopMover( gunship )
		return
	}

	// Try finding a clear path (normal, or elevated)
	local heightOffsets = [0, -150, -300, 150, 300, 600, 1000, 1500]
	local validDest = null

	foreach ( heightOffset in heightOffsets )
	{
		local elevatedDestination = destination + Vector( 0, 0, heightOffset )
		local verticalStart = start + Vector( 0, 0, heightOffset )

		if ( heightOffset != 0 && !AI_GunshipPathIsClear( gunship, start, verticalStart ) )
			continue

		if ( AI_GunshipPathIsClear( gunship, verticalStart, elevatedDestination ) )
		{
			validDest = elevatedDestination
			break
		}
	}

	if ( validDest == null )
	{
		// Retry with a shrunken hull, lets us squeeze through tight canyons.
		foreach ( heightOffset in heightOffsets )
		{
			local elevatedDestination = destination + Vector( 0, 0, heightOffset )
			if ( AI_GunshipPathIsClear( gunship, start, elevatedDestination, 0.5 ) )
			{
				validDest = elevatedDestination
				break
			}
		}
	}

	if ( validDest == null )
	{
		// Last resort: hand the destination to the mover anyway and let its
		// physics slide us along geometry. Better than being frozen at spawn.
		validDest = destination
	}

	// While travelling, let the mover rotate toward its direction of travel.
	mover.SetYawRate( AI_GUNSHIP_YAWRATE )
	gunship.s.gunshipIsIdle = false
	mover.SetMoveToPosition( validDest )
}

function AI_GunshipSelectTarget( gunship, team )
{
	local enemyTeam = GetOtherTeam( team )
	local origin = gunship.GetOrigin()

	local bestTarget = AI_GunshipFindClosestValid( gunship, GetNPCArrayEx( "npc_titan", enemyTeam, origin, AI_GUNSHIP_MAX_ENEMY_DIST ), origin )
	if ( bestTarget )
		return bestTarget

	bestTarget = AI_GunshipFindClosestValid( gunship, GetPlayerArrayOfTeam( enemyTeam ), origin )
	if ( bestTarget )
		return bestTarget

	local infantry = GetNPCArrayEx( "npc_soldier", enemyTeam, origin, AI_GUNSHIP_MAX_ENEMY_DIST )
	infantry.extend( GetNPCArrayEx( "npc_spectre", enemyTeam, origin, AI_GUNSHIP_MAX_ENEMY_DIST ) )
	return AI_GunshipFindClosestValid( gunship, infantry, origin )
}
Globalize( AI_GunshipSelectTarget )

function AI_GunshipFindClosestValid( gunship, candidates, origin )
{
	local best = null
	local bestDist = 99999999.0

	foreach ( candidate in candidates )
	{
		if ( !AI_GunshipCanTarget( gunship, candidate ) ) continue
		local dist = DistanceSqr( candidate.GetOrigin(), origin )
		if ( dist < bestDist ) {
			best = candidate
			bestDist = dist
		}
	}

	return best
}

function OnAIGunshipDeath( gunship, damageInfo )
{
	if ( !IsValid( gunship ) || !( "dogfighter" in gunship.s ) )
		return

	AI_GunshipDestroyTurrets( gunship )

	if ( "gunshipMover" in gunship.s )
	{
		local mover = gunship.s.gunshipMover
		if ( IsValid( mover ) )
			thread AIGunshipDestroyMoverAfterDeath( mover )
	}
}
Globalize( OnAIGunshipDeath )
AddDeathCallback( "npc_dropship", OnAIGunshipDeath )

function AIGunshipDestroyMoverAfterDeath( mover )
{
	wait 0.1
	if ( IsValid( mover ) )
		mover.Destroy()
}

function AI_GunshipAddTurrets( gunship, team )
{
	if ( !IsValid( gunship ) )
		return
	gunship.s.gunshipTurrets <- []

	local mounts = [ "l_exhaust_front_1", "r_exhaust_front_1" ]
	foreach ( mount in mounts )
	{
		local turret = AI_GunshipCreateTurret( gunship, team, mount )
		if ( IsValid( turret ) )
		{
			turret.NotSolid()
			gunship.s.gunshipTurrets.append( turret )
		}
	}
}

function AI_GunshipDestroyTurrets( gunship )
{
	if ( !IsValid( gunship ) || !( "gunshipTurrets" in gunship.s ) )
		return

	foreach ( turret in gunship.s.gunshipTurrets )
		if ( IsValid( turret ) )
			turret.Destroy()

	gunship.s.gunshipTurrets.clear()
}

function AI_GunshipCreateTurret( gunship, team, attachment, weaponName = "mp_weapon_yh803_bullet", health = 700 )
{
	if ( !IsValid( gunship ) )
		return null

	local turret = CreateEntity( "npc_turret_sentry" )

	turret.kv.solid = 8
	turret.kv.spawnflags = 0
	turret.kv.model = SENTRY_TURRET_MODEL

	turret.kv.TurretRange = AI_GUNSHIP_MAX_ENEMY_DIST
	turret.kv.FieldOfView = 0.4
	turret.kv.FieldOfViewAlert = 0.4
	turret.kv.additionalequipment = weaponName
	turret.kv.CollisionGroup = 21

	local accuracyMultiplier
	local weaponProficiency

	switch ( Riff_AILethality() )
	{
		case eAILethality.Default:
			accuracyMultiplier = 1.0
			weaponProficiency = 2
			break

		case eAILethality.TD_Low:
			accuracyMultiplier = 0.75
			weaponProficiency = 2
			break

		case eAILethality.TD_Medium:
			accuracyMultiplier = 1.0
			weaponProficiency = 2
			break

		case eAILethality.TD_High:
		case eAILethality.High:
			accuracyMultiplier = 2.0
			weaponProficiency = 3
			break

		case eAILethality.VeryHigh:
			accuracyMultiplier = 4.0
			weaponProficiency = 4
			break
	}

	turret.kv.WeaponProficiency = weaponProficiency
	turret.kv.AccuracyMultiplier = accuracyMultiplier

	turret.SetOrigin( gunship.GetOrigin() )
	turret.SetAngles( gunship.GetAngles() )


	turret.SetTitle( team == TEAM_MILITIA ? "Militia Hornet" : "IMC Phantom" )
	turret.s.skipTurretFX <- true
	turret.s.gunshipOwner <- gunship
	turret.s.isGunshipTurret <- true

	turret.SetAISettings( "turret_shoulder" )

	DispatchSpawn( turret, true )

	turret.SetTeam( team )
	turret.SetHealth( health )
	turret.SetMaxHealth( health )
	turret.SetInvulnerable()

	// Preserve the gunship as the damage/kill attribution owner.
	turret.SetOwner( gunship )

	turret.SetParent( gunship, attachment, false )
	turret.SetAimAssistAllowed( false )

	local activeWeapon = turret.GetActiveWeapon()

	if ( IsValid( activeWeapon ) )
		activeWeapon.Hide()

	turret.EnableTurret()
	turret.Hide()
	HideName( turret )

	return turret
}
