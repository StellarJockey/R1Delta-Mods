////////////////////////////////////////////////////////////
/////////// BEHOLD, FRANKENSTEIN'S COMBAT DRONE ////////////
////////////////////////////////////////////////////////////
// This thing was vibe-coded to hell and back... but it works for now
// Everybody say "Thank you, Claude!"

const AI_COMBAT_DRONE_HEALTH = 350
const AI_COMBAT_DRONE_AIRSPEED = 1000
const AI_COMBAT_DRONE_ACCEL = 1.75
const AI_COMBAT_DRONE_YAWRATE = 60
const AI_COMBAT_DRONE_HOVER_HEIGHT = 150
const AI_COMBAT_DRONE_MAX_ENEMY_DIST = 12000

const AI_COMBAT_DRONE_TURRET_WEAPON = "mp_weapon_yh803_bullet"
const AI_COMBAT_DRONE_ROCKET_WEAPON = "mp_weapon_yh803"
const AI_COMBAT_DRONE_TURRET_HEALTH = 700

const COMBAT_DRONE_HOVER_LOOP_SFX = "Combat_Drone_Hover_Loop"

const AI_COMBAT_DRONE_TARGET_OFFSET_RADIUS = 700
const AI_COMBAT_DRONE_TARGET_OFFSET_HEIGHT = 60
const AI_COMBAT_DRONE_SEPARATION_RADIUS = 500
const AI_COMBAT_DRONE_SEPARATION_STRENGTH = 250

const AI_COMBAT_DRONE_ARRIVE_DIST_SQR = 65536       // 256 units: close enough, stop and hover
const AI_COMBAT_DRONE_RESUME_DIST_SQR = 202500      // 450 units: once idle, target must drift this far before moving again

const AI_COMBAT_DRONE_HULL_HALF_WIDTH = 64          // matches the cloak drone's own path trace hull
const AI_COMBAT_DRONE_HULL_HALF_HEIGHT = 64
const AI_COMBAT_DRONE_HULL_PADDING = 0              // extra safety margin on every trace (cloak drone uses none)
const AI_COMBAT_DRONE_WANDER_GROUND_TRACE = 2000    // how far below a wander spot to look for a floor
const AI_COMBAT_DRONE_WAYPOINT_RADIUS_SQR = 90000   // 300 units: "reached the waypoint"
const AI_COMBAT_DRONE_REPLAN_DEST_DIST_SQR = 640000 // 800 units: target moved enough to replan

const AI_COMBAT_DRONE_TURN_MIN_DIST_SQR = 90000     // 300 units: leg must be at least this long (horizontally) before heading may change
const AI_COMBAT_DRONE_TURN_DEADBAND = 10            // degrees: new travel direction must differ by more than this before we turn
const AI_COMBAT_DRONE_TURN_MIN_SPEED = 300          // must already be flying this fast (horizontal u/s) before heading may change

const AI_COMBAT_DRONE_WANDER_RADIUS = 3500          // max distance of a wander leg
const AI_COMBAT_DRONE_WANDER_MIN_DIST = 1200        // min distance of a wander leg
const AI_COMBAT_DRONE_WANDER_AIRSPEED = 600         // slow cruise while wandering
const AI_COMBAT_DRONE_WANDER_PAUSE_MIN = 2.0        // seconds hovering between legs
const AI_COMBAT_DRONE_WANDER_PAUSE_MAX = 6.0
const AI_COMBAT_DRONE_WANDER_PICK_TRIES = 6         // random spots to try per pick before giving up

const MINIMAP_COMBAT_DRONE_SCALE = 0.08
const DEG_TO_RAD = 0.0174532925

PrecacheModel( COMBAT_DRONE_MODEL )
PrecacheWeapon( AI_COMBAT_DRONE_TURRET_WEAPON )
PrecacheWeapon( AI_COMBAT_DRONE_ROCKET_WEAPON )

function main()
{
	// The cloak drone is a prop_dynamic, not an NPC, so GetNPCArrayEx can't find it.
	// Like the original, keep our own list of live drones.
	level.combatDronesManagedEntArrayID <- CreateScriptManagedEntArray()

	// Per-drone kill records, used by _score.nut to credit kills (and Attrition) even after the entity is gone
	level.combatDroneRecords <- []

	Globalize( SpawnAI_Combat_Drone )
	Globalize( AI_Combat_Drone_CanTarget )
	Globalize( AI_Combat_Drone_SelectTarget )
	Globalize( AI_Combat_Drone_HuntThink )
	Globalize( GetNPCCombatDrones )
	Globalize( GetCombatDroneRecords )
}

function GetNPCCombatDrones()
{
	return GetScriptManagedEntArray( level.combatDronesManagedEntArrayID )
}

function GetCombatDroneRecords()
{
	return level.combatDroneRecords
}

function SpawnAI_Combat_Drone( team, origin, angles = Vector( 0, 0, 0 ), squadname = null, health = AI_COMBAT_DRONE_HEALTH )
{
	local spawnOrigin = origin + Vector( 0, 0, AI_COMBAT_DRONE_HOVER_HEIGHT )

	local mover = CreateEntity( "script_mover" )
	mover.kv.solid = 6
	mover.kv.model = COMBAT_DRONE_MODEL
	mover.kv.SpawnAsPhysicsMover = 1
	mover.kv.CollisionGroup = 21
	mover.SetOrigin( spawnOrigin )
	mover.SetAngles( angles )
	DispatchSpawn( mover, true )
	mover.Hide()
	mover.NotSolid()

	mover.SetMaxSpeed( AI_COMBAT_DRONE_AIRSPEED )
	mover.SetAccelScale( AI_COMBAT_DRONE_ACCEL )
	mover.SetYawRate( AI_COMBAT_DRONE_YAWRATE )

	// Prevent the mover from initially falling or choosing an invalid path
	mover.SetMoveToPosition( spawnOrigin )

	// Same setup as the cloak drone: a prop_dynamic riding on the mover, with a fake health pool.
	// It is NOT an NPC, so there is no squad, no engine AI and no SetEnemy.
	local drone = CreatePropDynamic( COMBAT_DRONE_MODEL, spawnOrigin, angles, 2, 8000 )

	// These keys enable the global search drone damage handling (fake health, crashing, etc.)
	drone.s.searchShipMover <- mover
	drone.s.isSearchDrone <- true
	drone.s.fakeHealth <- health
	drone.s.fakeMaxHealth <- health
	drone.s.isHidden <- false
	drone.s.combatDrone <- true

	drone.SetTeam( team )
	drone.SetName( "Combat Drone" )
	drone.SetTitle( "Combat Drone" )
	drone.Fire( "SetAnimation", "idle" )
	drone.SetHealth( health )
	drone.SetDamageNotifications( true )
	drone.Solid()
	drone.Show()
	drone.SetParent( mover, "", true, 0 )
	drone.MarkAsNonMovingAttachment()
	drone.EnableAttackableByAI()

	EmitSoundOnEntity( drone, COMBAT_DRONE_HOVER_LOOP_SFX )
	EmitSoundOnEntity( drone, CLOAKED_DRONE_WARP_IN_SFX )

	SetObjectCanBeMeleed( drone, true )
	SetVisibleEntitiesInConeQueriableEnabled( drone, true )

	// Each drone hovers at its own spot around the target so they don't all stack up.
	local offsetAngle = ( drone.GetEntIndex() % 8 ) * 45.0 * DEG_TO_RAD

	drone.s.droneTarget <- null
	drone.s.droneTargetOffset <- Vector(
		cos( offsetAngle ) * AI_COMBAT_DRONE_TARGET_OFFSET_RADIUS,
		sin( offsetAngle ) * AI_COMBAT_DRONE_TARGET_OFFSET_RADIUS,
		RandomFloat( -AI_COMBAT_DRONE_TARGET_OFFSET_HEIGHT, AI_COMBAT_DRONE_TARGET_OFFSET_HEIGHT )
	)
	drone.s.droneIsIdle <- false
	drone.s.droneHeading <- AI_Combat_Drone_NormalizeYaw( angles.y )
	drone.s.droneRoute <- []
	drone.s.droneRouteDest <- null
	drone.s.droneWandering <- false
	drone.s.droneWanderDest <- null
	drone.s.droneWanderResumeTime <- 0.0
	drone.s.droneLastPos <- spawnOrigin
	drone.s.droneLastPosTime <- Time()
	drone.s.droneSpeed2D <- 0.0

	drone.Minimap_SetDefaultMaterial( "vgui/hud/combat_drone_minimap" )
	drone.Minimap_SetEnemyMaterial( "vgui/hud/combat_drone_minimap_orange" )
	drone.Minimap_SetFriendlyMaterial( "vgui/hud/combat_drone_minimap" )
	drone.Minimap_AlwaysShow( TEAM_IMC, null )
	drone.Minimap_AlwaysShow( TEAM_MILITIA, null )
	drone.Minimap_SetObjectScale( MINIMAP_COMBAT_DRONE_SCALE )
	drone.Minimap_SetAlignUpright( true )
	drone.Minimap_SetZOrder( 10 )

	ShowName( drone )
	AddToScriptManagedEntArray( level.combatDronesManagedEntArrayID, drone )

	// Drop old finished kill records, then add ours
	local records = level.combatDroneRecords
	for ( local i = records.len() - 1; i >= 0; i-- )
	{
		if ( records[i].deadTime != null && Time() - records[i].deadTime > 10.0 )
			records.remove( i )
	}
	local record = { drone = drone, team = team, deadTime = null, awarded = false }
	records.append( record )
	drone.s.combatRecord <- record

	// Turrets and the brain start last so all the state above exists when the first think tick runs.
	AI_Combat_Drone_AddTurrets( drone, team )

	thread AI_Combat_Drone_CleanupThink( drone, mover )

	if ( level.aiHuntThinkEnabled )
		thread AI_Combat_Drone_HuntThink( drone, team )

	return drone
}

function AI_Combat_Drone_AddTurrets( drone, team )
{
	drone.s.droneTurrets <- []

	// Turret accuracy scales with the AI lethality setting
	local accuracyMultiplier = 2.0
	local weaponProficiency = 2

	switch ( Riff_AILethality() )
	{
		case eAILethality.TD_Low:    accuracyMultiplier = 0.75; break
		case eAILethality.TD_Medium: accuracyMultiplier = 2.5; weaponProficiency = 2.5; break
		case eAILethality.TD_High:
		case eAILethality.High:      accuracyMultiplier = 3.0; weaponProficiency = 3; break
		case eAILethality.VeryHigh:  accuracyMultiplier = 4.0; weaponProficiency = 4; break
	}

	local turret = CreateEntity( "npc_turret_sentry" )

	local droneWeapon = AI_COMBAT_DRONE_TURRET_WEAPON
	if ( RandomFloat( 0.0, 1.0 ) < 0.33 ) // 33% chance to have a rocket instead of a turret
		droneWeapon = AI_COMBAT_DRONE_ROCKET_WEAPON

	turret.kv.solid = 8
	turret.kv.spawnflags = 0
	turret.kv.model = SENTRY_TURRET_MODEL
	turret.kv.TurretRange = 2500 // match the "combat_drone_dmg" damage_far value
	turret.kv.FieldOfView = 0.4
	turret.kv.FieldOfViewAlert = 0.4
	turret.kv.reactChance = 100
	turret.kv.additionalequipment = droneWeapon
	turret.kv.CollisionGroup = TRACE_COLLISION_GROUP_NONE
	turret.kv.WeaponProficiency = weaponProficiency
	turret.kv.AccuracyMultiplier = accuracyMultiplier

	turret.SetOrigin( drone.GetOrigin() )
	turret.SetAngles( drone.GetAngles() )

	turret.SetTitle( "Combat Drone" )
	turret.s.skipTurretFX <- true
	turret.s.droneOwner <- drone
	turret.s.isCombatDroneGun <- true
	turret.SetAISettings( "turret_sentry" )

	DispatchSpawn( turret, true )

	turret.SetTeam( team )
	turret.SetHealth( AI_COMBAT_DRONE_TURRET_HEALTH )
	turret.SetMaxHealth( AI_COMBAT_DRONE_TURRET_HEALTH )
	turret.SetInvulnerable()

	// Preserve the drone as the damage/kill attribution owner.
	turret.SetOwner( drone )

	turret.SetParent( drone, "muzzle_flash", false )
	turret.SetLocalOrigin( Vector( -38.956, 0.006, -47.928 ) )
	turret.SetLocalAngles( Vector( 0, 0, 0 ) )
	turret.SetAimAssistAllowed( false )

	local activeWeapon = turret.GetActiveWeapon()
	if ( IsValid( activeWeapon ) )
	{
		activeWeapon.SetMods( [ "combat_drone_dmg" ] )
		activeWeapon.Hide()
	}

	turret.EnableTurret()
	turret.Hide()
	HideName( turret )
	turret.NotSolid()

	drone.s.droneTurrets.append( turret )
}

// True if ent is one of our custom drones (not a regular troop dropship).
function AI_IsCombatDrone( ent )
{
	return IsValid( ent ) && ( "combatDrone" in ent.s )
}

function AI_Combat_Drone_NormalizeYaw( yaw )
{
	while ( yaw > 180 )
		yaw -= 360
	while ( yaw <= -180 )
		yaw += 360
	return yaw
}

function AI_Combat_Drone_ClearRoute( drone )
{
	drone.s.droneRoute = []
	drone.s.droneRouteDest = null
}

function AI_Combat_Drone_CanTarget( drone, target )
{
	if ( !IsValid( target ) || !IsAlive( target ) )
		return false

	if ( AI_IsCombatDrone( target ) )
		return true

	if ( "GetNoTarget" in target && target.GetNoTarget() )
		return false

	if ( IsCloaked( target ) )
		return false

	return SimpleCanSeeEntity( drone, target )
}

function AI_Combat_Drone_FindClosestValid( drone, candidates, origin )
{
	local best = null
	local bestDist = 99999999.0

	foreach ( candidate in candidates )
	{
		if ( !AI_Combat_Drone_CanTarget( drone, candidate ) )
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

// Infantry and players first, then Titans, then enemy drones as a last resort.
// (The opposite of the gunship, which hunts drones and Titans first.)
function AI_Combat_Drone_SelectTarget( drone, team )
{
	local enemyTeam = GetOtherTeam( team )
	local origin = drone.GetOrigin()
	local maxDist = AI_COMBAT_DRONE_MAX_ENEMY_DIST

	// Stick with the current infantry/player target while it's still valid.
	local current = drone.s.droneTarget
	if ( AI_Combat_Drone_CanTarget( drone, current ) && !AI_IsCombatDrone( current ) && ( current.IsPlayer() || current.IsSoldier() || current.IsSpectre() ) )
		return current

	local preferred = GetNPCArrayEx( "npc_soldier", enemyTeam, origin, maxDist )
	preferred.extend( GetNPCArrayEx( "npc_spectre", enemyTeam, origin, maxDist ) )
	preferred.extend( GetPlayerArrayOfTeam( enemyTeam ) )

	local best = AI_Combat_Drone_FindClosestValid( drone, preferred, origin )
	if ( best )
		return best

	best = AI_Combat_Drone_FindClosestValid( drone, GetNPCArrayEx( "npc_titan", enemyTeam, origin, maxDist ), origin )
	if ( best )
		return best

	local rivals = []
	local maxDistSqr = maxDist * maxDist
	foreach ( enemy in GetNPCCombatDrones() )
	{
		if ( IsValid( enemy ) && enemy.GetTeam() == enemyTeam && DistanceSqr( enemy.GetOrigin(), origin ) <= maxDistSqr )
			rivals.append( enemy )
	}

	return AI_Combat_Drone_FindClosestValid( drone, rivals, origin )
}

// Horizontal speed of the mover, measured between think ticks (gates heading changes).
function AI_Combat_Drone_UpdateSpeed( drone, mover )
{
	local pos = mover.GetOrigin()
	local dt = Time() - drone.s.droneLastPosTime

	if ( dt > 0 )
	{
		local moved = pos - drone.s.droneLastPos
		moved.z = 0
		drone.s.droneSpeed2D = moved.Length() / dt
	}

	drone.s.droneLastPos = pos
	drone.s.droneLastPosTime = Time()
}

// The drone's brain. Runs every 0.25s until it dies
function AI_Combat_Drone_HuntThink( drone, team = null )
{
	if ( !IsValid( drone ) || !IsAlive( drone ) )
		return

	drone.EndSignal( "OnDeath" )
	drone.EndSignal( "OnDestroy" )
	drone.EndSignal( "DroneCrashing" )

	local mover = drone.s.searchShipMover
	if ( team == null )
		team = drone.GetTeam()

	while ( true )
	{
		if ( !IsValid( mover ) )
			return

		AI_Combat_Drone_UpdateSpeed( drone, mover )

		local target = AI_Combat_Drone_SelectTarget( drone, team )
		drone.s.droneTarget = target

		// The turrets pick their own targets and may not consider a drone valid,
		// so tell them explicitly what to shoot.
		if ( target != null )
		{
			foreach ( turret in drone.s.droneTurrets )
			{
				if ( IsValid( turret ) )
					turret.SetEnemy( target )
			}
		}

		// If the (padded) hull is overlapping geometry, every trace starts in solid and
		// fails, so pull the ship out first.
		if ( !AI_Combat_Drone_EscapeIfStuck( drone, mover ) )
		{
			if ( target != null )
			{
				// Leave wander mode, back to full speed.
				if ( drone.s.droneWandering )
				{
					drone.s.droneWandering = false
					drone.s.droneWanderDest = null
					AI_Combat_Drone_ClearRoute( drone )
					mover.SetMaxSpeed( AI_COMBAT_DRONE_AIRSPEED )
				}

				AI_Combat_Drone_MoveTo( drone, mover, target )
			}
			else
			{
				AI_Combat_Drone_Wander( drone, mover )
			}
		}

		wait 0.25
	}
}

// Is the straight line a -> b clear for the full (padded) hull?
// A swept hull trace covers everything between a and b. With a == b this tells
// you whether the hull is currently overlapping geometry.
function AI_Combat_Drone_LegIsClear( drone, a, b )
{
	local w = AI_COMBAT_DRONE_HULL_HALF_WIDTH + AI_COMBAT_DRONE_HULL_PADDING
	local h = AI_COMBAT_DRONE_HULL_HALF_HEIGHT + AI_COMBAT_DRONE_HULL_PADDING

	local trace = TraceHull(
		a,
		b,
		Vector( -w, -w, -h ),
		Vector(  w,  w,  h ),
		[ drone, drone.s.searchShipMover ],
		TRACE_MASK_NPCWORLDSTATIC,
		TRACE_COLLISION_GROUP_NONE
	)

	if ( trace.startSolid || trace.allSolid )
		return false

	return trace.fraction >= 0.999
}

// Build the waypoints the mover will visit IN ORDER, or null if nothing safe was found.
// The mover flies a straight line to each SetMoveToPosition, so every leg validated
// here is a leg it will actually fly.
//
// Cruise heights are measured from the DESTINATION (like the cloak drone's heights are
// measured from its target), never from the drone's current altitude, so a replan from
// a high position can't stack more height on top.
function AI_Combat_Drone_BuildRoute( drone, start, dest )
{
	if ( AI_Combat_Drone_LegIsClear( drone, start, dest ) )
		return [ dest ]

	// Climb/descend straight to a cruise height, fly level, then settle onto the destination.
	// Lower heights first, highest only as a last resort.
	foreach ( alt in [ -150, -75, 0, 150, 300, 800, 1500 ] )
	{
		local z = dest.z + alt
		local up   = Vector( start.x, start.y, z )
		local over = Vector( dest.x,  dest.y,  z )

		if ( AI_Combat_Drone_LegIsClear( drone, start, up )
			&& AI_Combat_Drone_LegIsClear( drone, up, over )
			&& AI_Combat_Drone_LegIsClear( drone, over, dest ) )
			return [ up, over, dest ]
	}

	return null
}

// If the hull is stuck in geometry, fly out to the nearest clear spot (the mover is
// NotSolid, so it can pass straight through walls).
// Returns true while escaping, false if not stuck (or no clear spot was found).
function AI_Combat_Drone_EscapeIfStuck( drone, mover )
{
	local origin = mover.GetOrigin()

	if ( AI_Combat_Drone_LegIsClear( drone, origin, origin ) )
		return false

	// Sideways first, straight up only as a last resort at each distance.
	local dirs = [
		Vector( 1, 0, 0 ),  Vector( -1, 0, 0 ),
		Vector( 0, 1, 0 ),  Vector( 0, -1, 0 ),
		Vector( 0.7, 0.7, 0 ),  Vector( -0.7, 0.7, 0 ),
		Vector( 0.7, -0.7, 0 ), Vector( -0.7, -0.7, 0 ),
		Vector( 0, 0, 1 )
	]

	for ( local d = 150; d <= 1800; d += 150 )
	{
		foreach ( dir in dirs )
		{
			local p = origin + dir * d

			if ( !AI_Combat_Drone_LegIsClear( drone, p, p ) )
				continue

			AI_Combat_Drone_ClearRoute( drone )
			drone.s.droneIsIdle = false
			mover.SetDesiredYaw( drone.s.droneHeading )
			mover.SetMoveToPosition( p )
			return true
		}
	}

	return false
}

// Hover in place and keep the last travel heading. Also drops any route.
// Safe to call every tick: the hold is only set up the first time.
function AI_Combat_Drone_StopMover( drone, mover )
{
	AI_Combat_Drone_ClearRoute( drone )

	if ( !drone.s.droneIsIdle )
	{
		drone.s.droneIsIdle = true
		mover.SetMoveToPosition( mover.GetOrigin() )
	}

	mover.SetDesiredYaw( drone.s.droneHeading )
}

// Fly toward target, spread out from nearby drones so they don't stack up.
function AI_Combat_Drone_MoveTo( drone, mover, target )
{
	local start = mover.GetOrigin()
	// Airborne targets (other drones) are already at altitude, so don't add hover height on top.
	local hoverHeight = AI_IsCombatDrone( target ) ? 0 : AI_COMBAT_DRONE_HOVER_HEIGHT
	local destination = target.GetOrigin() + Vector( 0, 0, hoverHeight ) + drone.s.droneTargetOffset

	foreach ( other in GetNPCCombatDrones() )
	{
		if ( other == drone || !IsValid( other ) || !IsAlive( other ) )
			continue

		local delta = start - other.GetOrigin()
		local dist = delta.Length()
		if ( dist > AI_COMBAT_DRONE_SEPARATION_RADIUS )
			continue

		if ( dist < 1 )
		{
			delta = Vector( RandomFloat( -1.0, 1.0 ), RandomFloat( -1.0, 1.0 ), 0 )
			dist = 1
		}
		delta.Normalize()
		destination += delta * ( AI_COMBAT_DRONE_SEPARATION_STRENGTH * ( 1.0 - dist / AI_COMBAT_DRONE_SEPARATION_RADIUS ) )
	}

	AI_Combat_Drone_Navigate( drone, mover, destination )
}

// Steer toward destination along a collision-checked route. Returns true once
// arrived (or no safe route exists) and holding, false while still flying.
// droneHeading is the only value ever sent to SetDesiredYaw; it changes only on a long,
// fast, clearly-different leg, so climbs, short hops and jitter never spin the ship.
function AI_Combat_Drone_Navigate( drone, mover, destination )
{
	local start = mover.GetOrigin()

	// Once idle, the destination has to drift much further away before we
	// move again, so we don't flip-flop at the boundary.
	local arriveDistSqr = drone.s.droneIsIdle ? AI_COMBAT_DRONE_RESUME_DIST_SQR : AI_COMBAT_DRONE_ARRIVE_DIST_SQR

	if ( DistanceSqr( start, destination ) <= arriveDistSqr )
	{
		AI_Combat_Drone_StopMover( drone, mover )
		return true
	}

	local route = drone.s.droneRoute
	local needsReplan = route.len() == 0
		|| DistanceSqr( drone.s.droneRouteDest, destination ) > AI_COMBAT_DRONE_REPLAN_DEST_DIST_SQR

	if ( !needsReplan )
	{
		// Drop waypoints we've already reached (always keep the last one)
		while ( route.len() > 1 && DistanceSqr( start, route[0] ) < AI_COMBAT_DRONE_WAYPOINT_RADIUS_SQR )
			route.remove( 0 )

		// Re-check the leg we're about to fly every tick
		needsReplan = !AI_Combat_Drone_LegIsClear( drone, start, route[0] )
	}

	if ( needsReplan )
	{
		route = null

		// If the ideal hover spot is inside geometry, try a few spots above it.
		foreach ( lift in [ 0, 300, 600 ] )
		{
			route = AI_Combat_Drone_BuildRoute( drone, start, destination + Vector( 0, 0, lift ) )
			if ( route != null )
				break
		}

		// No safe route: hold position rather than fly into a wall.
		if ( route == null )
		{
			AI_Combat_Drone_StopMover( drone, mover )
			return true
		}

		drone.s.droneRoute = route
		drone.s.droneRouteDest = destination
	}

	local flat = route[0] - start
	flat.z = 0

	if ( flat.LengthSqr() >= AI_COMBAT_DRONE_TURN_MIN_DIST_SQR && drone.s.droneSpeed2D >= AI_COMBAT_DRONE_TURN_MIN_SPEED )
	{
		local wanted = AI_Combat_Drone_NormalizeYaw( VectorToAngles( flat ).y )

		if ( fabs( AI_Combat_Drone_NormalizeYaw( wanted - drone.s.droneHeading ) ) > AI_COMBAT_DRONE_TURN_DEADBAND )
			drone.s.droneHeading = wanted
	}

	mover.SetDesiredYaw( drone.s.droneHeading )
	drone.s.droneIsIdle = false
	mover.SetMoveToPosition( route[0] )
	return false
}

function AI_Combat_Drone_WanderPauseEnd()
{
	return Time() + RandomFloat( AI_COMBAT_DRONE_WANDER_PAUSE_MIN, AI_COMBAT_DRONE_WANDER_PAUSE_MAX )
}

// A hover spot AI_COMBAT_DRONE_HOVER_HEIGHT above whatever floor lies below pos,
// or null if pos is inside geometry or there is no floor nearby.
function AI_Combat_Drone_HoverSpot( drone, pos )
{
	local trace = TraceLine( pos, pos - Vector( 0, 0, AI_COMBAT_DRONE_WANDER_GROUND_TRACE ), [ drone, drone.s.searchShipMover ], TRACE_MASK_NPCWORLDSTATIC, TRACE_COLLISION_GROUP_NONE )

	if ( trace.startSolid || trace.fraction >= 1.0 )
		return null

	return Vector( pos.x, pos.y, trace.endPos.z + AI_COMBAT_DRONE_HOVER_HEIGHT )
}

// Accept the first random spot that has a safe route. Returns true if one was found.
// Spots are ground-relative, so a drone that ended up high settles back to hover height.
function AI_Combat_Drone_PickWanderLeg( drone, start )
{
	for ( local i = 0; i < AI_COMBAT_DRONE_WANDER_PICK_TRIES; i++ )
	{
		local angle = RandomFloat( 0, 360 ) * DEG_TO_RAD
		local dist = RandomFloat( AI_COMBAT_DRONE_WANDER_MIN_DIST, AI_COMBAT_DRONE_WANDER_RADIUS )
		local spot = AI_Combat_Drone_HoverSpot( drone, start + Vector( cos( angle ) * dist, sin( angle ) * dist, 0 ) )
		if ( spot == null )
			continue

		local route = AI_Combat_Drone_BuildRoute( drone, start, spot )
		if ( route == null )
			continue

		drone.s.droneWanderDest = spot
		drone.s.droneRoute = route
		drone.s.droneRouteDest = spot
		return true
	}

	return false
}

// Called every think tick while there is nothing to hunt.
// Hover for a few seconds, pick a random reachable spot nearby, fly there
// slowly, repeat. Any target found by the hunt think cancels it.
function AI_Combat_Drone_Wander( drone, mover )
{
	// First tick of wandering: slow down and hover briefly before the first leg.
	if ( !drone.s.droneWandering )
	{
		drone.s.droneWandering = true
		drone.s.droneWanderDest = null
		drone.s.droneWanderResumeTime = AI_Combat_Drone_WanderPauseEnd()
		mover.SetMaxSpeed( AI_COMBAT_DRONE_WANDER_AIRSPEED )
	}

	if ( drone.s.droneWanderDest == null )
	{
		// Pick a new leg once the pause is over; if nothing is reachable, retry shortly.
		if ( Time() >= drone.s.droneWanderResumeTime && !AI_Combat_Drone_PickWanderLeg( drone, mover.GetOrigin() ) )
			drone.s.droneWanderResumeTime = Time() + 1.0

		// Still pausing (or nothing reachable): hover.
		if ( drone.s.droneWanderDest == null )
		{
			AI_Combat_Drone_StopMover( drone, mover )
			return
		}
	}

	// Arrived, or blocked with no safe route: rest and pick again.
	if ( AI_Combat_Drone_Navigate( drone, mover, drone.s.droneWanderDest ) )
	{
		drone.s.droneWanderDest = null
		drone.s.droneWanderResumeTime = AI_Combat_Drone_WanderPauseEnd()
	}
}

// There's no death callback for this: the global search drone handling kills/crashes
// the drone. We just clean up our own stuff when that happens.
function AI_Combat_Drone_CleanupThink( drone, mover )
{
	local record = drone.s.combatRecord

	drone.EndSignal( "OnDestroy" )
	drone.EndSignal( "OnDeath" )
	drone.EndSignal( "DroneCrashing" )

	OnThreadEnd(
		function() : ( drone, mover, record )
		{
			record.deadTime = Time()

			if ( IsValid( drone ) )
			{
				StopSoundOnEntity( drone, COMBAT_DRONE_HOVER_LOOP_SFX )

				foreach ( turret in drone.s.droneTurrets )
				{
					if ( IsValid( turret ) )
						turret.Destroy()
				}
			}

			thread AI_Combat_Drone_DestroyMoverLater( drone, mover )
		}
	)

	while ( true )
		wait 1.0
}

// The mover parents the drone, so don't pull it out from under a crashing drone.
// Wait for the drone to go away (or give up after a while), then remove the mover.
function AI_Combat_Drone_DestroyMoverLater( drone, mover )
{
	local endTime = Time() + 15.0

	while ( IsValid( drone ) && Time() < endTime )
		wait 0.5

	if ( IsValid( mover ) )
		mover.Destroy()
}
