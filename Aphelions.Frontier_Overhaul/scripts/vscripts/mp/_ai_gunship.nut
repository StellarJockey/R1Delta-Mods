////////////////////////////////////////////////////////////
////////////// BEHOLD, FRANKENSTEIN'S GUNSHIP //////////////
////////////////////////////////////////////////////////////
// This thing was vibe-coded to hell and back... but it works for now

const AI_GUNSHIP_HEALTH = 7000
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

const AI_GUNSHIP_HULL_HALF_WIDTH = 450
const AI_GUNSHIP_HULL_HALF_HEIGHT = 175
const AI_GUNSHIP_HULL_PADDING = 100          // safety margin on every trace
const AI_GUNSHIP_ROUTE_ALT_STEP = 250        // how much higher to try each time
const AI_GUNSHIP_ROUTE_ALT_MAX = 3500        // highest cruise altitude above start/dest
const AI_GUNSHIP_WAYPOINT_RADIUS_SQR = 90000 // 300 units: "reached the waypoint"
const AI_GUNSHIP_REPLAN_DEST_DIST_SQR = 640000 // 800 units: target moved enough to replan

const MINIMAP_GUNSHIP_SCALE = 0.12

PrecacheModel( STRATON_MODEL )
PrecacheModel( HORNET_MODEL )
PrecacheWeapon( "mp_weapon_yh803_bullet" )

function main()
{
	Globalize( SpawnAIGunship )
	Globalize( AIGunshipWarpIn )
	Globalize( AI_GunshipCanTarget )
	Globalize( AI_GunshipStopMover )
	Globalize( AI_GunshipHuntThink )
	Globalize( AI_GunshipPathIsClear )

	Globalize( AI_GunshipMoveTo )
	Globalize( AI_GunshipSelectTarget )
	Globalize( AI_GunshipFindClosestValid )
	Globalize( OnAIGunshipDeath )
	Globalize( AIGunshipDestroyMoverAfterDeath )
	Globalize( AI_GunshipAddTurrets )
	Globalize( AI_GunshipDestroyTurrets )
	Globalize( AI_GunshipCreateTurret )

    Globalize( AI_GunshipTraceHull )
    Globalize( AI_GunshipLegIsClear )
    Globalize( AI_GunshipBuildRoute )
    Globalize( AI_GunshipEscapeIfStuck )

	AddDeathCallback( "npc_dropship", OnAIGunshipDeath )
}

function SpawnAIGunship( team, origin, angles = Vector( 0, 0, 0 ), squadname = null, health = AI_GUNSHIP_HEALTH, warpAnimation = null )
{
	local spawnOrigin = origin + Vector( 0, 0, AI_GUNSHIP_HOVER_HEIGHT )

	local shipModel
	local title = ""

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
	gunship.SetName( title )
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
	gunship.s.gunshipRoute <- []
    gunship.s.gunshipRouteDest <- null

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

function AIGunshipWarpIn( gunship, animation, origin, angles )
{
	gunship.EndSignal( "OnDestroy" )
	gunship.EndSignal( "OnDeath" )

	WarpinEffect( gunship.GetModelName(), animation, origin, angles )
	gunship.Anim_Play( animation )
}


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
	mover.SetYawRate( 0.01 )
	mover.SetAngularVelocity( 0, 0, 0 )
	mover.SetAngles( lockedAngles )

	gunship.s.gunshipIdleAngles = lockedAngles
	gunship.s.gunshipIsIdle = true
}

function AI_GunshipHoldHeading( gunship )
{
	if ( !IsValid( gunship ) || !( "gunshipMover" in gunship.s ) )
		return

	local mover = gunship.s.gunshipMover
	if ( !IsValid( mover ) )
		return

	mover.SetMoveToPosition( mover.GetOrigin() )
	mover.SetYawRate( 0.01 )
	mover.SetAngularVelocity( 0, 0, 0 )
	mover.SetAngles( gunship.s.gunshipIdleAngles )
}

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
		else
		{
			if ( !gunship.s.gunshipIsIdle )
				AI_GunshipStopMover( gunship )
		}

		// Re-assert the locked heading every tick while idle, target or not.
		if ( gunship.s.gunshipIsIdle )
			AI_GunshipHoldHeading( gunship )

		wait 0.25
	}
}


function AI_GunshipTraceHull( gunship, start, end )
{
	local w = AI_GUNSHIP_HULL_HALF_WIDTH + AI_GUNSHIP_HULL_PADDING
	local h = AI_GUNSHIP_HULL_HALF_HEIGHT + AI_GUNSHIP_HULL_PADDING

	local ignoreArray = [ gunship ]
	if ( "gunshipMover" in gunship.s )
		ignoreArray.append( gunship.s.gunshipMover )

	return TraceHull(
		start,
		end,
		Vector( -w, -w, -h ),
		Vector(  w,  w,  h ),
		ignoreArray,
		TRACE_MASK_NPCWORLDSTATIC,
		TRACE_COLLISION_GROUP_NONE
	)
}


// Is the straight line a -> b clear for the full hull?
// A swept hull trace already covers everything between a and b,
// so no segmenting is needed.
function AI_GunshipLegIsClear( gunship, a, b )
{
	local trace = AI_GunshipTraceHull( gunship, a, b )

	if ( trace.startSolid || trace.allSolid )
		return false

	return trace.fraction >= 0.999
}


// Kept so anything else that calls the old name still works.
// (The old "scale" argument is gone on purpose: shrinking the hull is
// what let the ships squeeze into walls.)
function AI_GunshipPathIsClear( gunship, start, destination, scale = 1.0 )
{
	return AI_GunshipLegIsClear( gunship, start, destination )
}


// Build a list of waypoints the mover will visit IN ORDER.
// Returns an array of positions, or null if nothing safe was found.
//
// The key point: the mover only flies in a straight line to whatever
// SetMoveToPosition it is given. So every leg we validate must be a leg the
// mover will actually fly, which means we have to hand it the waypoints one
// at a time instead of only the final point.


function AI_GunshipBuildRoute( gunship, start, dest )
{
	// 1. Straight shot
	if ( AI_GunshipLegIsClear( gunship, start, dest ) )
		return [ dest ]

	// 2. Climb straight up, cruise level, then descend onto the destination.
	//    Try the lowest cruise altitude first so we don't fly higher than needed.
	local baseZ = start.z > dest.z ? start.z : dest.z

	for ( local alt = AI_GUNSHIP_ROUTE_ALT_STEP; alt <= AI_GUNSHIP_ROUTE_ALT_MAX; alt += AI_GUNSHIP_ROUTE_ALT_STEP )
	{
		local z = baseZ + alt
		local up   = Vector( start.x, start.y, z )
		local over = Vector( dest.x,  dest.y,  z )

		// If we can't climb this high, we can't climb any higher either
		// (ceiling / overhang), so stop searching.
		if ( !AI_GunshipLegIsClear( gunship, start, up ) )
			break

		if ( !AI_GunshipLegIsClear( gunship, up, over ) )
			continue

		if ( !AI_GunshipLegIsClear( gunship, over, dest ) )
			continue

		return [ up, over, dest ]
	}

	return null
}


// If the (padded) hull is currently overlapping geometry, nothing else can
// work: every trace starts in solid and fails. Pull the ship out first.
// The mover is NotSolid, so it can fly straight out through the wall.
function AI_GunshipEscapeIfStuck( gunship, mover )
{
	local origin = mover.GetOrigin()
	local here = AI_GunshipTraceHull( gunship, origin, origin )

	if ( !here.startSolid && !here.allSolid )
		return false

	local dirs = [
		Vector( 0, 0, 1 ),
		Vector( 1, 0, 0 ),  Vector( -1, 0, 0 ),
		Vector( 0, 1, 0 ),  Vector( 0, -1, 0 ),
		Vector( 0.7, 0.7, 0 ),  Vector( -0.7, 0.7, 0 ),
		Vector( 0.7, -0.7, 0 ), Vector( -0.7, -0.7, 0 )
	]

	for ( local d = 150; d <= 1800; d += 150 )
	{
		foreach ( dir in dirs )
		{
			local p = origin + dir * d
			local t = AI_GunshipTraceHull( gunship, p, p )

			if ( t.startSolid || t.allSolid )
				continue

			gunship.s.gunshipRoute = []
			gunship.s.gunshipRouteDest = null
			gunship.s.gunshipIsIdle = false
			mover.SetYawRate( AI_GUNSHIP_YAWRATE )
			mover.SetMoveToPosition( p )
			return true
		}
	}

	return false
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

	// If we're already inside something, get out before planning anything.
	if ( AI_GunshipEscapeIfStuck( gunship, mover ) )
		return

	// ---- Destination with per-ship offset (unchanged) ----
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

	// ---- Separation from other gunships (unchanged) ----
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

	// Once idle, require the destination to drift well away (450 units)
	// before moving again, so we don't flip-flop at the 256 boundary.
	local arriveDistSqr = gunship.s.gunshipIsIdle ? 202500 : 65536

	if ( DistanceSqr( start, destination ) <= arriveDistSqr )
	{
		gunship.s.gunshipRoute = []
		if ( !gunship.s.gunshipIsIdle )
			AI_GunshipStopMover( gunship )
		return
	}

	// ---- Follow the current route if it's still valid ----
	local route = gunship.s.gunshipRoute
	local needsReplan = route.len() == 0
		|| gunship.s.gunshipRouteDest == null
		|| DistanceSqr( gunship.s.gunshipRouteDest, destination ) > AI_GUNSHIP_REPLAN_DEST_DIST_SQR

	if ( !needsReplan )
	{
		// Drop waypoints we've already reached (always keep the last one)
		while ( route.len() > 1 && DistanceSqr( start, route[0] ) < AI_GUNSHIP_WAYPOINT_RADIUS_SQR )
			route.remove( 0 )

		// Re-check the leg we're about to fly every tick
		if ( !AI_GunshipLegIsClear( gunship, start, route[0] ) )
			needsReplan = true
	}

	// ---- Replan ----
	if ( needsReplan )
	{
		route = null

		// If the ideal hover spot is inside geometry, try a few spots above it.
		foreach ( lift in [ 0, 300, 600, 1000 ] )
		{
			route = AI_GunshipBuildRoute( gunship, start, destination + Vector( 0, 0, lift ) )
			if ( route != null )
				break
		}

		if ( route == null )
		{
			// No safe route: hold position rather than fly into a wall.
			gunship.s.gunshipRoute = []
			gunship.s.gunshipRouteDest = null
			AI_GunshipStopMover( gunship )
			return
		}

		gunship.s.gunshipRoute = route
		gunship.s.gunshipRouteDest = destination
	}

	// ---- Fly to the next waypoint only ----
	mover.SetYawRate( AI_GUNSHIP_YAWRATE )
	gunship.s.gunshipIsIdle = false
	mover.SetMoveToPosition( route[0] )
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
