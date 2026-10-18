////////////////////////////////////////////////////////////
////////////// BEHOLD, FRANKENSTEIN'S GUNSHIP //////////////
////////////////////////////////////////////////////////////
// This thing was vibe-coded to hell and back... but it works for now
// Everybody say "Thank you, Claude!"

const AI_GUNSHIP_HEALTH = 6000
const AI_GUNSHIP_AIRSPEED = 2500
const AI_GUNSHIP_ACCEL = 1.75
const AI_GUNSHIP_YAWRATE = 90
const AI_GUNSHIP_HOVER_HEIGHT = 700
const AI_GUNSHIP_MAX_ENEMY_DIST = 12000

const AI_GUNSHIP_TARGET_OFFSET_RADIUS = 700
const AI_GUNSHIP_TARGET_OFFSET_HEIGHT = 120
const AI_GUNSHIP_SEPARATION_RADIUS = 500
const AI_GUNSHIP_SEPARATION_RADIUS_SQR = 250000
const AI_GUNSHIP_SEPARATION_STRENGTH = 250

const AI_GUNSHIP_ARRIVE_DIST_SQR = 65536       // 256 units: close enough, stop and hover
const AI_GUNSHIP_RESUME_DIST_SQR = 202500      // 450 units: once idle, target must drift this far before moving again

const AI_GUNSHIP_HULL_HALF_WIDTH = 450
const AI_GUNSHIP_HULL_HALF_HEIGHT = 175
const AI_GUNSHIP_HULL_PADDING = 100            // safety margin on every trace
const AI_GUNSHIP_ROUTE_ALT_STEP = 250          // how much higher to try each time
const AI_GUNSHIP_ROUTE_ALT_MAX = 3500          // highest cruise altitude above start/dest
const AI_GUNSHIP_WAYPOINT_RADIUS_SQR = 90000   // 300 units: "reached the waypoint"
const AI_GUNSHIP_REPLAN_DEST_DIST_SQR = 640000 // 800 units: target moved enough to replan

const AI_GUNSHIP_TURN_MIN_DIST_SQR = 90000     // 300 units: leg must be at least this long (horizontally) before heading may change
const AI_GUNSHIP_TURN_DEADBAND = 10            // degrees: new travel direction must differ by more than this before we turn
const AI_GUNSHIP_DEBUG_YAW = false             // true = print mover vs gunship yaw every think tick

const AI_GUNSHIP_WANDER_RADIUS = 3500          // max distance of a wander leg
const AI_GUNSHIP_WANDER_MIN_DIST = 1200        // min distance of a wander leg
const AI_GUNSHIP_WANDER_HEIGHT_VARIATION = 0   // random +/- height change per leg
const AI_GUNSHIP_WANDER_AIRSPEED = 700         // slow cruise while wandering
const AI_GUNSHIP_WANDER_PAUSE_MIN = 2.0        // seconds hovering between legs
const AI_GUNSHIP_WANDER_PAUSE_MAX = 6.0
const AI_GUNSHIP_WANDER_PICK_TRIES = 6         // random spots to try per pick before giving up

const AI_GUNSHIP_JINK_ATTACK_MEMORY = 2.0      // seconds: shot by an enemy gunship this recently counts as "under fire"
const AI_GUNSHIP_JINK_COOLDOWN_MIN = 4.0       // seconds between dodges (random in this range)
const AI_GUNSHIP_JINK_COOLDOWN_MAX = 8.0
const AI_GUNSHIP_JINK_MIN_DIST = 800           // sideways hop distance
const AI_GUNSHIP_JINK_MAX_DIST = 1800
const AI_GUNSHIP_JINK_DEPTH = 300              // random +/- movement toward/away from the attacker
const AI_GUNSHIP_JINK_HEIGHT = 300             // random +/- height change
const AI_GUNSHIP_JINK_PICK_TRIES = 4           // random spots to try before giving up
const AI_GUNSHIP_JINK_MAX_TIME = 3.0           // safety: abandon a dodge that takes longer than this

const MINIMAP_GUNSHIP_SCALE = 0.12

PrecacheModel( STRATON_MODEL )
PrecacheModel( HORNET_MODEL )
PrecacheWeapon( "mp_weapon_yh803_bullet" )

function main()
{
	Globalize( SpawnAIGunship )
	Globalize( AI_GunshipCanTarget )
	Globalize( AI_GunshipStopMover )
	Globalize( AI_GunshipHuntThink )

	Globalize( AI_GunshipMoveTo )
	Globalize( AI_GunshipSelectTarget )
	Globalize( AI_GunshipFindClosestValid )
	Globalize( OnAIGunshipDeath )
	Globalize( OnAIGunshipDamaged )
	Globalize( AIGunshipDestroyMoverAfterDeath )
	Globalize( AI_GunshipAddTurrets )
	Globalize( AI_GunshipDestroyTurrets )
	Globalize( AI_GunshipCreateTurret )

	Globalize( AI_GunshipLegIsClear )
	Globalize( AI_GunshipBuildRoute )
	Globalize( AI_GunshipEscapeIfStuck )

	AddDeathCallback( "npc_dropship", OnAIGunshipDeath )
	AddDamageCallback( "npc_dropship", OnAIGunshipDamaged )
}

function SpawnAIGunship( team, origin, angles = Vector( 0, 0, 0 ), squadname = null, health = AI_GUNSHIP_HEALTH )
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

	DispatchSpawn( gunship, true )
	gunship.Hide()
	gunship.NotSolid()

	thread AIGunshipRevealAfterWarp( gunship, spawnOrigin, team )

	gunship.kv.isUsingHoverNoise = true
	gunship.EngineEffectsEnable()

	gunship.SetTeam( team )
	gunship.SetHealth( health )
	gunship.SetMaxHealth( health )

	// Movement state lives on the real npc_dropship.
	// Each ship hovers at its own spot around the target so they don't all stack up.
	local offsetAngle = ( gunship.GetEntIndex() % 8 ) * 45.0 * 0.0174532925

	gunship.s.gunshipMover <- mover
	gunship.s.gunshipTargetOffset <- Vector(
		cos( offsetAngle ) * AI_GUNSHIP_TARGET_OFFSET_RADIUS,
		sin( offsetAngle ) * AI_GUNSHIP_TARGET_OFFSET_RADIUS,
		RandomFloat( -AI_GUNSHIP_TARGET_OFFSET_HEIGHT, AI_GUNSHIP_TARGET_OFFSET_HEIGHT )
	)
	gunship.s.gunshipIsIdle <- false
	gunship.s.gunshipHeading <- AI_GunshipNormalizeYaw( angles.y )
	gunship.s.gunshipRoute <- []
	gunship.s.gunshipRouteDest <- null
	gunship.s.gunshipWandering <- false
	gunship.s.gunshipWanderDest <- null
	gunship.s.gunshipWanderResumeTime <- 0.0
	gunship.s.gunshipLastAttacker <- null
	gunship.s.gunshipLastAttackedTime <- -999.0
	gunship.s.gunshipJinkDest <- null
	gunship.s.gunshipJinkEndTime <- 0.0
	gunship.s.gunshipNextJinkTime <- 0.0

	// The dropship is the authoritative entity. The mover owns translation
	gunship.SetParent( mover, "", true, 0 )
	gunship.MarkAsNonMovingAttachment()

	// Keep the entity visible and usable as a normal NPC dropship
	gunship.EnableRenderAlways()
	// Don't call EnableAttackableByAI() here; the engine errors if you do.
	SetVisibleEntitiesInConeQueriableEnabled( gunship, true )
	gunship.SetAimAssistAllowed( false )

	gunship.Minimap_SetDefaultMaterial( "vgui/hud/gunship_minimap" )
	gunship.Minimap_SetEnemyMaterial( "vgui/hud/gunship_minimap_orange" )
	gunship.Minimap_SetFriendlyMaterial( "vgui/hud/gunship_minimap" )
	gunship.Minimap_AlwaysShow( TEAM_IMC, null )
	gunship.Minimap_AlwaysShow( TEAM_MILITIA, null )
	gunship.Minimap_SetObjectScale( MINIMAP_GUNSHIP_SCALE )
	gunship.Minimap_SetZOrder( 10 )

	return gunship
}

function AIGunshipRevealAfterWarp( gunship, spawnOrigin, team )
{
	gunship.EndSignal( "OnDestroy" )
	gunship.EndSignal( "OnDeath" )

	EmitSoundAtPosition( spawnOrigin, "dropship_warpin" )
	
	gunship.Show()
	gunship.Solid()
	EmitSoundOnEntity( gunship, "Gunship_Hover_Loop" )
	AI_GunshipAddTurrets( gunship, team )

	if ( level.aiHuntThinkEnabled )
		thread AI_GunshipHuntThink( gunship, team )
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

// True if ent is one of our custom gunships (not a regular troop dropship).
function AI_GunshipIsGunship( ent )
{
	return IsValid( ent ) && ( "dogfighter" in ent.s )
}


// Returns the gunship's mover, or null if the gunship or mover is gone.
function AI_GunshipGetMover( gunship )
{
	if ( !IsValid( gunship ) || !( "gunshipMover" in gunship.s ) )
		return null

	local mover = gunship.s.gunshipMover
	return IsValid( mover ) ? mover : null
}

// Wrap a yaw into -180..180. VectorToAngles returns 0..360 while GetAngles can
// return negative values, so mixing them can make a mover think it is far from
// its target yaw and keep turning.
function AI_GunshipNormalizeYaw( yaw )
{
	while ( yaw > 180 )
		yaw -= 360
	while ( yaw <= -180 )
		yaw += 360
	return yaw
}

// Smallest angle between two yaws, in degrees (0..180).
function AI_GunshipYawDifference( a, b )
{
	return fabs( AI_GunshipNormalizeYaw( a - b ) )
}

// Fly toward dest.
// gunshipHeading is the ONE stored heading for this ship, and the only thing
// that ever gets sent to SetDesiredYaw. It only changes when the leg is long
// enough horizontally and points meaningfully away from the current heading.
// That means the straight-up climb, short hops, and jitter from separation or
// a moving target never rotate the ship. When it stops, it keeps this heading,
// i.e. the direction it was most recently travelling.
function AI_GunshipFlyTo( gunship, mover, dest )
{
	local flat = dest - mover.GetOrigin()
	flat.z = 0

	if ( flat.LengthSqr() >= AI_GUNSHIP_TURN_MIN_DIST_SQR )
	{
		local wanted = AI_GunshipNormalizeYaw( VectorToAngles( flat ).y )

		if ( AI_GunshipYawDifference( wanted, gunship.s.gunshipHeading ) > AI_GUNSHIP_TURN_DEADBAND )
			gunship.s.gunshipHeading = wanted
	}

	mover.SetDesiredYaw( gunship.s.gunshipHeading )

	gunship.s.gunshipIsIdle = false
	mover.SetMoveToPosition( dest )
}

// Hover in place and keep the last travel heading. Also drops any route.
// Safe to call every tick: the hold is only set up the first time, after that
// it just re-asserts the stored heading.
function AI_GunshipStopMover( gunship )
{
	local mover = AI_GunshipGetMover( gunship )
	if ( mover == null )
		return

	gunship.s.gunshipRoute = []
	gunship.s.gunshipRouteDest = null

	if ( !gunship.s.gunshipIsIdle )
	{
		gunship.s.gunshipIsIdle = true
		mover.SetMoveToPosition( mover.GetOrigin() )
	}

	mover.SetDesiredYaw( gunship.s.gunshipHeading )
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
		local target = gunship.GetEnemy()

		if ( IsValid( target ) && !AI_GunshipCanTarget( gunship, target ) )
		{
			gunship.SetEnemy( null )
			target = null
		}

		if ( !IsValid( target ) )
			target = AI_GunshipSelectTarget( gunship, gunshipTeam )

		if ( IsValid( target ) )
		{
			gunship.SetEnemy( target )

			// Dodging takes priority over chasing while an enemy gunship is shooting us.
			if ( !AI_GunshipJink( gunship ) )
				AI_GunshipMoveTo( gunship, target )
		}
		else
		{
			AI_GunshipWander( gunship )
		}

		if ( AI_GUNSHIP_DEBUG_YAW )
		{
			local m = AI_GunshipGetMover( gunship )
			if ( m != null )
				printt( "[AI_GUNSHIP] idle:", gunship.s.gunshipIsIdle, "heading:", gunship.s.gunshipHeading, "mover yaw:", m.GetAngles().y, "gunship yaw:", gunship.GetAngles().y )
		}

		wait 0.25
	}
}

// Is the straight line a -> b clear for the full (padded) hull?
// A swept hull trace already covers everything between a and b, so no
// segmenting is needed. With a == b this tells you if the hull is currently
// overlapping geometry.
function AI_GunshipLegIsClear( gunship, a, b )
{
	local w = AI_GUNSHIP_HULL_HALF_WIDTH + AI_GUNSHIP_HULL_PADDING
	local h = AI_GUNSHIP_HULL_HALF_HEIGHT + AI_GUNSHIP_HULL_PADDING

	local ignoreArray = [ gunship ]
	local mover = AI_GunshipGetMover( gunship )
	if ( mover != null )
		ignoreArray.append( mover )

	local trace = TraceHull(
		a,
		b,
		Vector( -w, -w, -h ),
		Vector(  w,  w,  h ),
		ignoreArray,
		TRACE_MASK_NPCWORLDSTATIC,
		TRACE_COLLISION_GROUP_NONE
	)

	if ( trace.startSolid || trace.allSolid )
		return false

	return trace.fraction >= 0.999
}

// Build a list of waypoints the mover will visit IN ORDER.
// Returns an array of positions, or null if nothing safe was found.
//
// The mover only flies in a straight line to whatever SetMoveToPosition it is
// given, so every leg we validate must be a leg it will actually fly. That's
// why waypoints are handed over one at a time instead of only the final point.
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

	if ( AI_GunshipLegIsClear( gunship, origin, origin ) )
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

			if ( !AI_GunshipLegIsClear( gunship, p, p ) )
				continue

			gunship.s.gunshipRoute = []
			gunship.s.gunshipRouteDest = null
			AI_GunshipFlyTo( gunship, mover, p )
			return true
		}
	}

	return false
}

function AI_GunshipMoveTo( gunship, target )
{
	local mover = AI_GunshipGetMover( gunship )
	if ( mover == null )
		return

	// A target showed up: back to full speed.
	if ( gunship.s.gunshipWandering )
		AI_GunshipEndWander( gunship, mover )

	// If we're already inside something, get out before planning anything.
	if ( AI_GunshipEscapeIfStuck( gunship, mover ) )
		return

	local start = mover.GetOrigin()
	// Airborne targets (other gunships) are already at altitude, so don't add hover height on top.
	local hoverHeight = AI_GunshipIsGunship( target ) ? 0 : AI_GUNSHIP_HOVER_HEIGHT
	local destination = target.GetOrigin() + Vector( 0, 0, hoverHeight ) + gunship.s.gunshipTargetOffset

	// ---- Separation from other gunships ----
	local nearby = GetNPCArrayEx( "npc_dropship", TEAM_IMC, start, AI_GUNSHIP_SEPARATION_RADIUS )
	nearby.extend( GetNPCArrayEx( "npc_dropship", TEAM_MILITIA, start, AI_GUNSHIP_SEPARATION_RADIUS ) )
	foreach ( other in nearby )
	{
		if ( other == gunship || !IsValid( other ) || !IsAlive( other ) ) continue
		local delta = start - other.GetOrigin()
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

	AI_GunshipNavigate( gunship, mover, destination )
}


// Steer toward destination along a collision-checked route.
// Returns true once the ship has arrived (or no safe route exists) and is
// holding position, false while it is still flying.
function AI_GunshipNavigate( gunship, mover, destination )
{
	local start = mover.GetOrigin()

	// Close enough: hover. Once idle, the destination has to drift much
	// further away before we move again, so we don't flip-flop at the boundary.
	local arriveDistSqr = gunship.s.gunshipIsIdle ? AI_GUNSHIP_RESUME_DIST_SQR : AI_GUNSHIP_ARRIVE_DIST_SQR

	if ( DistanceSqr( start, destination ) <= arriveDistSqr )
	{
		AI_GunshipStopMover( gunship )
		return true
	}

	// ---- Follow the current route if it's still valid ----
	local route = gunship.s.gunshipRoute
	local needsReplan = route.len() == 0
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

		// No safe route: hold position rather than fly into a wall.
		if ( route == null )
		{
			AI_GunshipStopMover( gunship )
			return true
		}

		gunship.s.gunshipRoute = route
		gunship.s.gunshipRouteDest = destination
	}

	// ---- Fly to the next waypoint only ----
	AI_GunshipFlyTo( gunship, mover, route[0] )
	return false
}

// Called every think tick while there is nothing to hunt.
// Hover for a few seconds, pick a random reachable spot nearby, fly there
// slowly, repeat. Any target found by the hunt think cancels it (see MoveTo).
function AI_GunshipWander( gunship )
{
	local mover = AI_GunshipGetMover( gunship )
	if ( mover == null )
		return

	// First tick of wandering: slow down and hover briefly before the first leg.
	if ( !gunship.s.gunshipWandering )
	{
		gunship.s.gunshipWandering = true
		gunship.s.gunshipWanderDest = null
		gunship.s.gunshipWanderResumeTime = Time() + RandomFloat( AI_GUNSHIP_WANDER_PAUSE_MIN, AI_GUNSHIP_WANDER_PAUSE_MAX )
		mover.SetMaxSpeed( AI_GUNSHIP_WANDER_AIRSPEED )
	}

	if ( AI_GunshipEscapeIfStuck( gunship, mover ) )
		return

	// Resting between legs
	if ( gunship.s.gunshipWanderDest == null )
	{
		if ( Time() < gunship.s.gunshipWanderResumeTime )
		{
			AI_GunshipStopMover( gunship )
			return
		}

		if ( !AI_GunshipPickWanderDest( gunship, mover ) )
		{
			// Nothing reachable right now; hover and try again shortly.
			gunship.s.gunshipWanderResumeTime = Time() + 1.0
			AI_GunshipStopMover( gunship )
			return
		}
	}

	// Mid-leg: arrived, or blocked with no safe route, means rest and pick again.
	if ( AI_GunshipNavigate( gunship, mover, gunship.s.gunshipWanderDest ) )
	{
		gunship.s.gunshipWanderDest = null
		gunship.s.gunshipWanderResumeTime = Time() + RandomFloat( AI_GUNSHIP_WANDER_PAUSE_MIN, AI_GUNSHIP_WANDER_PAUSE_MAX )
	}
}


// Try a few random spots around the ship; accept the first one with a safe route.
function AI_GunshipPickWanderDest( gunship, mover )
{
	local start = mover.GetOrigin()

	for ( local i = 0; i < AI_GUNSHIP_WANDER_PICK_TRIES; i++ )
	{
		local angle = RandomFloat( 0, 360 ) * 0.0174532925
		local dist = RandomFloat( AI_GUNSHIP_WANDER_MIN_DIST, AI_GUNSHIP_WANDER_RADIUS )
		local spot = start + Vector(
			cos( angle ) * dist,
			sin( angle ) * dist,
			RandomFloat( -AI_GUNSHIP_WANDER_HEIGHT_VARIATION, AI_GUNSHIP_WANDER_HEIGHT_VARIATION )
		)

		local route = AI_GunshipBuildRoute( gunship, start, spot )
		if ( route == null )
			continue

		gunship.s.gunshipWanderDest = spot
		gunship.s.gunshipRoute = route
		gunship.s.gunshipRouteDest = spot
		return true
	}

	return false
}


// Leave wander mode: restore full speed and drop the wander route.
function AI_GunshipEndWander( gunship, mover )
{
	gunship.s.gunshipWandering = false
	gunship.s.gunshipWanderDest = null
	gunship.s.gunshipRoute = []
	gunship.s.gunshipRouteDest = null
	mover.SetMaxSpeed( AI_GUNSHIP_AIRSPEED )
}


// Records who is shooting us. Only enemy gunships matter here; the actual
// dodge is done from the hunt think so this callback stays cheap.
function OnAIGunshipDamaged( gunship, damageInfo )
{
	if ( !AI_GunshipIsGunship( gunship ) )
		return

	local attacker = damageInfo.GetAttacker()

	// Turret shots may be credited to the turret instead of its gunship.
	if ( IsValid( attacker ) && ( "isGunshipTurret" in attacker.s ) && IsValid( attacker.s.gunshipOwner ) )
		attacker = attacker.s.gunshipOwner

	if ( !AI_GunshipIsGunship( attacker ) || attacker.GetTeam() == gunship.GetTeam() )
		return

	gunship.s.gunshipLastAttacker = attacker
	gunship.s.gunshipLastAttackedTime = Time()
}


// Dogfight dodge. While an enemy gunship is shooting us, hop to a new spot
// off to the side of it, then wait a few seconds before dodging again.
// Returns true while a dodge is in progress (the caller should not steer).
function AI_GunshipJink( gunship )
{
	local mover = AI_GunshipGetMover( gunship )
	if ( mover == null )
		return false

	// Dodge already underway
	if ( gunship.s.gunshipJinkDest != null )
	{
		if ( Time() < gunship.s.gunshipJinkEndTime && !AI_GunshipNavigate( gunship, mover, gunship.s.gunshipJinkDest ) )
			return true

		// Arrived, blocked, or timed out: resume hunting with a fresh route.
		gunship.s.gunshipJinkDest = null
		gunship.s.gunshipRoute = []
		gunship.s.gunshipRouteDest = null
		return false
	}

	// Cooldown, and only react to recent fire from a live enemy gunship.
	if ( Time() < gunship.s.gunshipNextJinkTime )
		return false

	if ( Time() - gunship.s.gunshipLastAttackedTime > AI_GUNSHIP_JINK_ATTACK_MEMORY )
		return false

	local attacker = gunship.s.gunshipLastAttacker
	if ( !AI_GunshipIsGunship( attacker ) || !IsAlive( attacker ) )
		return false

	// A target showed up while wandering: back to full speed before dodging.
	if ( gunship.s.gunshipWandering )
		AI_GunshipEndWander( gunship, mover )

	// Hop sideways relative to the line between us and the attacker.
	local start = mover.GetOrigin()
	local away = start - attacker.GetOrigin()
	away.z = 0
	if ( away.LengthSqr() < 1 )
		away = Vector( 1, 0, 0 )
	away.Normalize()
	local side = Vector( -away.y, away.x, 0 )

	for ( local i = 0; i < AI_GUNSHIP_JINK_PICK_TRIES; i++ )
	{
		local sign = RandomInt( 0, 2 ) == 0 ? -1 : 1
		local sideways = side * ( sign * RandomFloat( AI_GUNSHIP_JINK_MIN_DIST, AI_GUNSHIP_JINK_MAX_DIST ) )
		local depth = away * RandomFloat( -AI_GUNSHIP_JINK_DEPTH, AI_GUNSHIP_JINK_DEPTH )
		local lift = Vector( 0, 0, RandomFloat( -AI_GUNSHIP_JINK_HEIGHT, AI_GUNSHIP_JINK_HEIGHT ) )
		local spot = start + sideways + depth + lift

		local route = AI_GunshipBuildRoute( gunship, start, spot )
		if ( route == null )
			continue

		gunship.s.gunshipJinkDest = spot
		gunship.s.gunshipJinkEndTime = Time() + AI_GUNSHIP_JINK_MAX_TIME
		gunship.s.gunshipNextJinkTime = Time() + RandomFloat( AI_GUNSHIP_JINK_COOLDOWN_MIN, AI_GUNSHIP_JINK_COOLDOWN_MAX )
		gunship.s.gunshipRoute = route
		gunship.s.gunshipRouteDest = spot

		AI_GunshipNavigate( gunship, mover, spot )
		return true
	}

	// Boxed in; try again shortly.
	gunship.s.gunshipNextJinkTime = Time() + 1.0
	return false
}


function AI_GunshipSelectTarget( gunship, team )
{
	local enemyTeam = GetOtherTeam( team )
	local origin = gunship.GetOrigin()

	// Titans and enemy gunships are equal-priority heavy targets; the closest wins.
	local heavyTargets = GetNPCArrayEx( "npc_titan", enemyTeam, origin, AI_GUNSHIP_MAX_ENEMY_DIST )
	foreach ( enemy in GetNPCArrayEx( "npc_dropship", enemyTeam, origin, AI_GUNSHIP_MAX_ENEMY_DIST ) )
	{
		if ( AI_GunshipIsGunship( enemy ) )
			heavyTargets.append( enemy )
	}

	local bestTarget = AI_GunshipFindClosestValid( gunship, heavyTargets, origin )
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

	local gunshipOrigin = gunship.GetOrigin()
	EmitSoundAtPosition( gunshipOrigin, "Gunship_Explode" )

	gunship.EngineEffectsDisable()
	StopSoundOnEntity( gunship, "Gunship_Hover_Loop" )

	AI_GunshipDestroyTurrets( gunship )
	local mover = AI_GunshipGetMover( gunship )
	if ( mover != null )
		thread AIGunshipDestroyMoverAfterDeath( mover )
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
			accuracyMultiplier = 2.0
			weaponProficiency = 2
			break

		case eAILethality.TD_Low:
			accuracyMultiplier = 0.75
			weaponProficiency = 2
			break

		case eAILethality.TD_Medium:
			accuracyMultiplier = 2.5
			weaponProficiency = 2.5
			break

		case eAILethality.TD_High:
		case eAILethality.High:
			accuracyMultiplier = 3.0
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
	{
		activeWeapon.SetMods( [ "gunship_dmg" ] )
		activeWeapon.Hide()
	}

	turret.EnableTurret()
	turret.Hide()
	HideName( turret )

	return turret
}
