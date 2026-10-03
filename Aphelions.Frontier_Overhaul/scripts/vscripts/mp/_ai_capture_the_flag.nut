//////////////////////////////////////////////////////////////
//// Thanks to StoneCold and Claude for writing this code ////
//////////////////////////////////////////////////////////////

// CTF AI support constants. Declared at file scope so SpawnFrontlineSquad can see CTF_DEBUG
// (const name resolution was failing when these were declared near the CTF functions at the bottom).
const CTF_FLAGRUN_GOAL_RADIUS      = 192		// how close the squad needs to get before re-evaluating (tightened from 256)
const CTF_FLAGRUN_REEVAL_PERIOD    = 1.5		// seconds between re-evaluating the objective mid-push (tightened from 3.0)
const CTF_FLAGRUN_ESCORT_RADIUS    = 128		// tight assault radius when escorting a player flag carrier -- grunts stick close
const CTF_DEBUG                    = false		// set false to silence diagnostic prints for release
const CTF_FAKECAP_ENABLED          = true		// master switch for scripted grunt captures

// Fake-capture (grunt-delivered score) feature. Since NPCs cannot physically carry flags,
// we award a capture point when a friendly grunt reaches the enemy flag base. Heavily
// rate-limited to preserve match pacing and prevent grunts from winning the match outright.
const CTF_FAKECAP_TRIGGER_DIST     = 150		// grunt must be this close to enemy flag base to trigger (bumped 96->150)
const CTF_FAKECAP_TEAM_COOLDOWN    = 40.0		// seconds between successive fake-captures by the same team (bumped 30->40 per user feedback)
const CTF_FAKECAP_MAX_PER_TEAM     = 6			// max fake-captures per team per match (single-player-vs-AI framing: grunts can potentially deliver a full win)
const CTF_FAKECAP_CHECK_PERIOD     = 0.5		// how often the fake-cap watchdog polls grunt positions (tightened 1.0->0.5)

function main()
{
	Globalize( AssaultCTF )
	Globalize( GetCTFFlagOriginForTeam )
	Globalize( GetCTFObjectiveForTeam )
	Globalize( SquadFlagRunThink )
	Globalize( GetEnemyFlagCarrierForTeam )
	Globalize( CTFFakeCaptureWatchdog )
	Globalize( CTFFakeCaptureCheckTeam )
	Globalize( CTFAwardFakeCapture )
	Globalize( ShouldPrintFakeCapGateDiag )

	RegisterSignal( "FlagUpdate" )		// base-game CTF signal; defensively registered here in case our think starts before ctf.nut

	// Per-squad signals for SquadFlagRunThink. level.aiSquadCount is 3 by default; register
	// a safe upper bound of 8 per team to accommodate any future bump without code changes.
	for ( local i = 0; i < 8; i++ )
	{
		RegisterSignal( "SquadFlagRunThink_squad_imc" + i )
		RegisterSignal( "SquadFlagRunThink_squad_militia" + i )
	}
}

//=========================================================
// CTF AI SUPPORT
//=========================================================
// Dispatches squads with dynamic flag-state-driven objectives:
//   - Enemy flag at home      -> push toward enemy flag base (capture pressure)
//   - Enemy flag held by ally -> fall back to defend own flag base (escort intent)
//   - Enemy flag dropped      -> move to recover it
//   - Own flag held by enemy  -> hunt the carrier
//   - Own flag dropped        -> move to return point
// NPCs that physically touch the enemy flag WILL pick it up if the engine allows
// it (forceDisableFlagTouch is per-entity, which suggests it's gated this way).
// If NPCs cannot carry, grunts still provide defensive pressure and distraction.
// (Constants CTF_FLAGRUN_GOAL_RADIUS / CTF_FLAGRUN_REEVAL_PERIOD / CTF_DEBUG are
//  declared at the top of this file.)


function AssaultCTF( guys, index )
{
	if ( !guys.len() )
		return

	// give everyone proper squad name
	local team 		= guys[ 0 ].GetTeam()
	local squadName = MakeSquadName( team, index )

	foreach( guy in guys )
	{
		if ( IsValid( guy ) )
			SetSquad( guy, squadName )
	}

	// is our squad filled up yet?
	local squad = GetNPCArrayBySquad( squadName )

	if ( squad.len() > SQUADSIZE )
		return

	// 2:1 attacker bias -- squad indices 0 and 1 push the enemy flag, index 2 holds own base.
	// With level.aiSquadCount = 3, this gives 2 attacking squads vs 1 defending squad per team.
	local role = ( index < 2 ) ? "attack" : "defend"

	thread SquadFlagRunThink( squadName, team, role )
}

// Locates the flag base origin for the given team.
// Probes the known flag-storage surfaces in order: flagSpawnPoints array, then
// the flagSpawnPoint/flagReturnPoint legacy single-team vars, then a model scan.
// Successful lookups are cached on level.ctfFlagOriginCache since flag bases don't move.
// Returns a Vector or null.
function GetCTFFlagOriginForTeam( team )
{
	if ( !( "ctfFlagOriginCache" in level ) )
		level.ctfFlagOriginCache <- {}

	if ( team in level.ctfFlagOriginCache )
		return level.ctfFlagOriginCache[ team ]

	local found = null
	local foundVia = "none"	// for diagnostics

	// Preferred: flagSpawnPoints is a list with per-ent team info
	if ( "flagSpawnPoints" in level )
	{
		foreach ( sp in level.flagSpawnPoints )
		{
			if ( !IsValid( sp ) )
				continue
			if ( sp.GetTeam() == team )
			{
				found = sp.GetOrigin()
				foundVia = "flagSpawnPoints[]"
				break
			}
		}
	}

	// Legacy single-team globals. These are ambiguous about team ownership --
	// flagSpawnPoint tends to be "home" and flagReturnPoint the other.
	// Best-effort: if the var exists and its team matches, use it.
	if ( found == null && "flagSpawnPoint" in level && IsValid( level.flagSpawnPoint ) )
	{
		if ( level.flagSpawnPoint.GetTeam() == team )
		{
			found = level.flagSpawnPoint.GetOrigin()
			foundVia = "flagSpawnPoint"
		}
	}

	if ( found == null && "flagReturnPoint" in level && IsValid( level.flagReturnPoint ) )
	{
		if ( level.flagReturnPoint.GetTeam() == team )
		{
			found = level.flagReturnPoint.GetOrigin()
			foundVia = "flagReturnPoint"
		}
	}

	// Fallback: scan the world for the flag base model and match by team.
	// CTF_FLAG_BASE_MODEL is precached in _base_gametype.nut and is the visible pedestal.
	if ( found == null )
	{
		local candidates = GetEntArrayByClass_Expensive( "prop_dynamic" )
		foreach ( ent in candidates )
		{
			if ( !IsValid( ent ) )
				continue
			if ( ent.GetModelName() != CTF_FLAG_BASE_MODEL )
				continue
			if ( ent.GetTeam() == team )
			{
				found = ent.GetOrigin()
				foundVia = "model_scan"
				break
			}
		}
	}

	// Only cache successful lookups; a null result may just mean we ran too early.
	if ( found != null )
	{
		level.ctfFlagOriginCache[ team ] <- found
		if ( CTF_DEBUG )
			printt( "[CTF_AI] Flag base for team", team, "resolved via", foundVia, "at", found )
	}
	else if ( CTF_DEBUG )
	{
		printt( "[CTF_AI] WARNING: No flag base found for team", team, "-- squad will not have attack objective" )
	}

	return found
}

// Locates the nearest living enemy flag carrier (player or NPC) for the given team.
// "Enemy carrier" from my perspective means someone on the enemy team carrying MY flag.
// Returns an entity or null.
function GetEnemyFlagCarrierForTeam( team )
{
	local enemyTeam = ( team == TEAM_IMC ) ? TEAM_MILITIA : TEAM_IMC

	// Check players first -- by far the most common case
	foreach ( player in GetPlayerArrayOfTeam( enemyTeam ) )
	{
		if ( !IsValid( player ) || !IsAlive( player ) )
			continue
		// PlayerHasEnemyFlag from the carrier's perspective: does this enemy have OUR flag?
		// From our perspective they have "our" flag; from theirs it's the "enemy" flag. Same check.
		if ( PlayerHasEnemyFlag( player ) )
			return player
	}

	// Also check NPCs on the enemy team in case engine allows NPC carry
	local npcs = GetNPCArray()
	foreach ( npc in npcs )
	{
		if ( !IsValid( npc ) || !IsAlive( npc ) )
			continue
		if ( npc.GetTeam() != enemyTeam )
			continue
		if ( PlayerHasEnemyFlag( npc ) )
		{
			if ( CTF_DEBUG )
				printt( "[CTF_AI] ENEMY NPC IS CARRYING OUR FLAG:", npc, "class:", npc.GetClassname(), "team:", npc.GetTeam(), "origin:", npc.GetOrigin() )
			return npc
		}
	}

	return null
}

// Determines what objective the squad should pursue based on current flag state.
// Returns a table { origin = Vector, radius = int } or null if no sensible objective exists.
// `team` is the squad's own team. `role` is "attack" or "defend".
function GetCTFObjectiveForTeam( team, role )
{
	local enemyTeam  = ( team == TEAM_IMC ) ? TEAM_MILITIA : TEAM_IMC
	local ownBase    = GetCTFFlagOriginForTeam( team )
	local enemyBase  = GetCTFFlagOriginForTeam( enemyTeam )

	// If own flag is being carried by an enemy, hunt the carrier regardless of role.
	local theirCarrier = GetEnemyFlagCarrierForTeam( team )
	if ( IsValid( theirCarrier ) )
		return { origin = theirCarrier.GetOrigin(), radius = CTF_FLAGRUN_GOAL_RADIUS }

	// Defenders bias toward own base unless own flag is actually away.
	if ( role == "defend" )
	{
		if ( ownBase != null )
			return { origin = ownBase, radius = CTF_FLAGRUN_GOAL_RADIUS }
		// fall through if we can't find our base
	}

	// Attackers (and defenders with no home to defend) push the enemy flag.
	// If a friendly is carrying the enemy flag, escort them directly with a tight radius.
	local ourCarrier = null
	foreach ( player in GetPlayerArrayOfTeam( team ) )
	{
		if ( IsValid( player ) && IsAlive( player ) && PlayerHasEnemyFlag( player ) )
		{
			ourCarrier = player
			break
		}
	}
	if ( !IsValid( ourCarrier ) )
	{
		local npcs = GetNPCArray()
		foreach ( npc in npcs )
		{
			if ( !IsValid( npc ) || !IsAlive( npc ) )
				continue
			if ( npc.GetTeam() != team )
				continue
			if ( PlayerHasEnemyFlag( npc ) )
			{
				if ( CTF_DEBUG )
					printt( "[CTF_AI] FRIENDLY NPC IS CARRYING ENEMY FLAG:", npc, "class:", npc.GetClassname(), "team:", npc.GetTeam(), "origin:", npc.GetOrigin() )
				ourCarrier = npc
				break
			}
		}
	}

	if ( IsValid( ourCarrier ) )
	{
		// Escort mode -- stick close to the carrier with a tight radius so grunts
		// actually form a protective bubble rather than drifting to the home base.
		return { origin = ourCarrier.GetOrigin(), radius = CTF_FLAGRUN_ESCORT_RADIUS }
	}

	// Default: push the enemy flag base
	if ( enemyBase != null )
		return { origin = enemyBase, radius = CTF_FLAGRUN_GOAL_RADIUS }

	// Last resort: if we literally can't find any flag base, hold position
	return null
}

// Squad think loop for CTF. Re-evaluates objective every CTF_FLAGRUN_REEVAL_PERIOD
// seconds or whenever level.ent signals "FlagUpdate", whichever comes first.
// Uses a per-squad signal name so starting a fresh think for one squad doesn't
// cancel sibling squads on the same team (we have up to level.aiSquadCount per team).
function SquadFlagRunThink( squadName, team, role )
{
	local signalString = "SquadFlagRunThink_" + squadName

	level.ent.Signal( signalString )
	level.ent.EndSignal( signalString )

	if ( !GetNPCSquadSize( squadName ) )
		return

	local lastGoal = null

	while ( true )
	{
		local squad = GetNPCArrayBySquad( squadName )
		ArrayRemoveDead( squad )

		if ( !squad.len() )
			return

		local goal = GetCTFObjectiveForTeam( team, role )

		if ( goal != null )
		{
			// only reissue orders if the goal meaningfully moved, to avoid spamming assault ents.
			// use the tightest common radius (escort radius) as the "moved enough" threshold so
			// escort squads actually re-home on the carrier every tick rather than lagging behind.
			if ( lastGoal == null || Distance( goal.origin, lastGoal ) > CTF_FLAGRUN_ESCORT_RADIUS )
			{
				if ( CTF_DEBUG )
					printt( "[CTF_AI] squad", squadName, "role=" + role, "new goal:", goal.origin, "radius:", goal.radius )
				SquadAssaultOrigin( squad, goal.origin, goal.radius )
				lastGoal = goal.origin
			}
		}

		// Wait either for the periodic re-eval or a flag state change, whichever comes first.
		// waitthread on a helper so we get race-free select semantics.
		waitthread CTFFlagRunWaitTick()
	}
}
Globalize( SquadFlagRunThink )

// Helper: wait for either FlagUpdate signal or the reeval period, whichever is first.
function CTFFlagRunWaitTick()
{
	level.ent.EndSignal( "FlagUpdate" )
	wait CTF_FLAGRUN_REEVAL_PERIOD
}
Globalize( CTFFlagRunWaitTick )

//=========================================================
// CTF FAKE-CAPTURE (grunt-delivered score)
//=========================================================
// Since NPCs cannot physically pick up flags, we simulate a "capture" when a friendly
// grunt reaches the enemy flag base. This awards a team score point but does not trigger
// the visual flag attachment or the full capture sequence (announcer, VFX, flag reset).
//
// Safety rails:
//   - Only fires when the enemy flag is at home (no player/NPC carrying it)
//   - Hard cap of CTF_FAKECAP_MAX_PER_TEAM captures per team per match
//   - Per-team cooldown of CTF_FAKECAP_TEAM_COOLDOWN seconds between fires
//   - Never fires if awarding the point would end the match (preserves "let a player
//     finish the match" intent; grunt help is assistance, not victory delivery)

function CTFFakeCaptureWatchdog()
{
	printt( "[CTF_AI] WATCHDOG: entered function body" )

	// Per-team bookkeeping. Initialize first so downstream helpers can rely on these being present.
	level.ctfFakeCapCount       <- { [TEAM_IMC] = 0, [TEAM_MILITIA] = 0 }
	printt( "[CTF_AI] WATCHDOG: ctfFakeCapCount initialized" )

	level.ctfFakeCapLastTime    <- { [TEAM_IMC] = 0.0, [TEAM_MILITIA] = 0.0 }
	printt( "[CTF_AI] WATCHDOG: ctfFakeCapLastTime initialized" )

	level.ctfFakeCapLastDiagTime <- { [TEAM_IMC] = 0.0, [TEAM_MILITIA] = 0.0 }	// used by ShouldPrintFakeCapGateDiag( team ) for throttled logging

	printt( "[CTF_AI] fake-capture watchdog started (max per team:", CTF_FAKECAP_MAX_PER_TEAM, "cooldown:", CTF_FAKECAP_TEAM_COOLDOWN, "s)" )

	local loopCount = 0
	local prevGameState = GetGameState()

	while ( true )
	{
		wait CTF_FAKECAP_CHECK_PERIOD

		loopCount = loopCount + 1
		// every 20 iterations, print a heartbeat so we know the thread is alive (~10s wallclock at 0.5s polls)
		if ( loopCount % 20 == 0 )
			printt( "[CTF_AI] WATCHDOG: heartbeat loop=", loopCount, "state=", GetGameState() )

		local curGameState = GetGameState()

		// Round-transition reset. CTF is switch-sides round-based: gamestate goes
		// Playing -> SwitchingSides -> Playing for round 2. When we re-enter Playing from any
		// non-Playing state, wipe the per-team cap counters and cooldowns so round 2 starts
		// fresh -- otherwise the previous round's cooldown-free state lets grunts cap rapidly
		// in the opening seconds of the new round.
		if ( curGameState == eGameState.Playing && prevGameState != eGameState.Playing )
		{
			printt( "[CTF_AI] round transition detected (", prevGameState, "->", curGameState, ") - resetting fake-cap bookkeeping" )
			level.ctfFakeCapCount[ TEAM_IMC ]     = 0
			level.ctfFakeCapCount[ TEAM_MILITIA ] = 0
			level.ctfFakeCapLastTime[ TEAM_IMC ]     = Time()
			level.ctfFakeCapLastTime[ TEAM_MILITIA ] = Time()
			// Setting LastTime to now means the 30s cooldown is effectively re-armed at round start.
			// That gives players a grace period to engage before grunts can start capping.
		}

		prevGameState = curGameState

		if ( curGameState != eGameState.Playing )
			continue

		CTFFakeCaptureCheckTeam( TEAM_IMC )
		CTFFakeCaptureCheckTeam( TEAM_MILITIA )
	}
}
Globalize( CTFFakeCaptureWatchdog )

// Throttle for gate-diagnostic prints. Returns true once every ~5 seconds PER TEAM so we can see
// per-team status (closest NPC distance, etc) without spamming the console every tick.
function ShouldPrintFakeCapGateDiag( team )
{
	if ( Time() - level.ctfFakeCapLastDiagTime[ team ] >= 5.0 )
	{
		level.ctfFakeCapLastDiagTime[ team ] = Time()
		return true
	}
	return false
}

function CTFFakeCaptureCheckTeam( team )
{
	// Hard cap check -- short-circuit if this team has already used all its fake captures
	if ( level.ctfFakeCapCount[ team ] >= CTF_FAKECAP_MAX_PER_TEAM )
	{
		if ( CTF_DEBUG && ShouldPrintFakeCapGateDiag( team ) )
			printt( "[CTF_AI] GATE team", team, "CAP REACHED (", level.ctfFakeCapCount[ team ], "/", CTF_FAKECAP_MAX_PER_TEAM, ")" )
		return
	}

	// Cooldown check
	local timeSinceLast = Time() - level.ctfFakeCapLastTime[ team ]
	if ( timeSinceLast < CTF_FAKECAP_TEAM_COOLDOWN )
	{
		if ( CTF_DEBUG && ShouldPrintFakeCapGateDiag( team ) )
			printt( "[CTF_AI] GATE team", team, "COOLDOWN (", timeSinceLast, "s /", CTF_FAKECAP_TEAM_COOLDOWN, "s)" )
		return
	}

	local enemyTeam = ( team == TEAM_IMC ) ? TEAM_MILITIA : TEAM_IMC
	local enemyBase = GetCTFFlagOriginForTeam( enemyTeam )

	if ( enemyBase == null )
	{
		if ( CTF_DEBUG && ShouldPrintFakeCapGateDiag( team ) )
			printt( "[CTF_AI] GATE team", team, "NO ENEMY BASE RESOLVED" )
		return
	}

	// Require that the enemy flag is actually at home (not being carried).
	foreach ( player in GetPlayerArray() )
	{
		if ( IsValid( player ) && IsAlive( player ) && PlayerHasEnemyFlag( player ) )
		{
			if ( CTF_DEBUG && ShouldPrintFakeCapGateDiag( team ) )
				printt( "[CTF_AI] GATE team", team, "PLAYER CARRYING FLAG:", player )
			return
		}
	}
	local allNpcs = GetNPCArray()
	foreach ( npc in allNpcs )
	{
		if ( IsValid( npc ) && IsAlive( npc ) && PlayerHasEnemyFlag( npc ) )
		{
			if ( CTF_DEBUG && ShouldPrintFakeCapGateDiag( team ) )
				printt( "[CTF_AI] GATE team", team, "NPC CARRYING FLAG:", npc )
			return
		}
	}

	// NOTE: match-end guard removed by user request 2026-04-17 -- grunt captures are now allowed to
	// deliver the winning point. Previously we suppressed fake caps when currentScore+1 >= scoreLimit
	// so players would always get the final kill. Per user feedback the 2-per-team cap was already
	// limiting grunt contribution enough; letting them close out the match feels fine.

	// Position check: find the CLOSEST friendly grunt to the enemy base. Report distance
	// for diagnostics so we can tell if grunts are ever getting close enough.
	local triggeringGrunt = null
	local closestNpc = null
	local closestDist = 999999.0
	local candidateCount = 0

	foreach ( npc in allNpcs )
	{
		if ( !IsValid( npc ) || !IsAlive( npc ) )
			continue
		if ( npc.GetTeam() != team )
			continue
		if ( !npc.IsNPC() )
			continue
		candidateCount = candidateCount + 1

		local dist = Distance( npc.GetOrigin(), enemyBase )
		if ( dist < closestDist )
		{
			closestDist = dist
			closestNpc  = npc
		}
		if ( dist <= CTF_FAKECAP_TRIGGER_DIST )
		{
			triggeringGrunt = npc
			break
		}
	}

	// Telemetry print so we can see what the closest friendly NPC to the enemy base is
	if ( CTF_DEBUG && ShouldPrintFakeCapGateDiag( team ) )
	{
		if ( closestNpc != null )
			printt( "[CTF_AI] GATE team", team, "closest-of-", candidateCount, "NPC at dist", closestDist, "to enemyBase (trigger threshold:", CTF_FAKECAP_TRIGGER_DIST, ") --", closestNpc )
		else
			printt( "[CTF_AI] GATE team", team, "NO LIVING FRIENDLY NPCs at all (candidateCount=", candidateCount, ")" )
	}

	if ( !IsValid( triggeringGrunt ) )
		return

	// All gates passed -- award the capture
	CTFAwardFakeCapture( team, triggeringGrunt )
}

function CTFAwardFakeCapture( team, grunt )
{
	GameScore.AddTeamScore( team, 1 )

	level.ctfFakeCapCount[ team ]    = level.ctfFakeCapCount[ team ] + 1
	level.ctfFakeCapLastTime[ team ] = Time()

	// Notify players with a HUD message. SendHudMessage params:
	//   (player, text, x, y, r, g, b, a, fadeIn, holdTime, fadeOut)
	// x=-1 means horizontally centered, y is vertical anchor (0 top, 1 bottom).
	// Friendly = bright green, enemy = red, both prominently placed.
	
	/*
	foreach ( player in GetPlayerArray() )
	{
		if ( !IsValid( player ) )
			continue

		local playerTeam = player.GetTeam()
		local msg
		local r = 255
		local g = 255
		local b = 255

		if ( IsValid( grunt ) && grunt.IsNPC() && playerTeam == team )
		{
			msg = "Friendly squad captured the enemy flag!"
			r = 80; g = 255; b = 80		// green
		}
		else if ( IsValid( grunt ) && grunt.IsNPC() && playerTeam != team )
		{
			msg = "Enemy squad captured our flag!"
			r = 255; g = 80; b = 80		// red
		}

		SendHudMessage( player, msg, -1, 0.3, r, g, b, 255, 0.2, 4.0, 0.5 )
	}
	*/

	// Play the proper "flag captured" announcer lines. The dialogue system registers
	// friendly_captured_flag / enemy_captured_flag for each team -- playing one per team
	// makes each player hear the appropriate side (their team's friendly line, or the
	// enemy's enemy line). This fires the same triumphant "we captured the enemy flag!"
	// VO that plays on a real player capture.
	foreach ( listener in GetPlayerArray() )
	{
		if ( !IsValid( listener ) )
			continue

		local alias = ( listener.GetTeam() == team ) ? "friendly_captured_flag" : "enemy_captured_flag"
		PlayConversationToPlayer( alias, listener )
	}

	if ( CTF_DEBUG )
	{
		local newScore = GameRules.GetTeamScore( team )
		printt( "[CTF_AI] *** FAKE CAPTURE *** team", team, "grunt", grunt, "at", grunt.GetOrigin(),
				"-- team score now", newScore, "(grunt-caps used:", level.ctfFakeCapCount[ team ], "/", CTF_FAKECAP_MAX_PER_TEAM, ")" )
	}
}
