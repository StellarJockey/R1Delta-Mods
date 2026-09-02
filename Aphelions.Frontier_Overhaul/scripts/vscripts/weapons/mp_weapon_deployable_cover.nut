const MAX_PROXIMITY_MINES_IN_WORLD = 3  // if more than this are thrown, the oldest one gets cleaned up
const THROW_POWER = 620
const ATTACH_SFX = "Weapon_ProximityMine_Land"
const WARNING_SFX = "Weapon_ProximityMine_ArmedBeep"

function ProximityMinePrecache()
{
	if ( WeaponIsPrecached( self ) )
		return

	PrecacheParticleSystem( "wpn_laser_blink" )

	if ( IsServer() )
	{
		PrecacheEntity( "npc_grenade_frag" )
	}
}
ProximityMinePrecache()

function OnWeaponActivate( activateParams )
{
}

function OnWeaponDeactivate( deactivateParams )
{
}

function OnWeaponTossReleaseAnimEvent( attackParams )
{
	if ( IsClient() && !self.ShouldPredictProjectiles() )
		return

	local player = self.GetWeaponOwner()

	local attackPos
	if ( IsValid( player ) )
		attackPos = GetProximityMineThrowStartPos( player, attackParams.pos )
	else
		attackPos = attackParams.pos

	local velocity = GetProximityMineThrowVelocity( player, attackParams.dir.GetAngles() )
	local angularVelocity = Vector( 600, RandomFloat( -300, 300 ), 0 )

	local fuseTime = 0	// infinite

	if( IsServer() )
	{
		// If already at the proximity mine in world limit, remove the oldest
		ArrayRemoveInvalid( player.s.activeProximityMines )
		if ( player.s.activeProximityMines.len() > MAX_PROXIMITY_MINES_IN_WORLD )
		{
			local oldestProximityMine = player.s.activeProximityMines[ 0 ]
			CleanupPlayerProximityMine( player, oldestProximityMine )
		}
	}

	local proximityMine = self.FireWeaponGrenade( attackPos, velocity, angularVelocity, fuseTime, damageTypes.Explosive, damageTypes.Explosive, PROJECTILE_PREDICTED, true, true )

	if ( proximityMine )
	{
		if ( IsServer() )
		{
			EmitSoundOnEntityExceptToPlayer( player, player, "weapon_proximitymine_throw" )
			Grenade_Init( proximityMine, self )
			local duration = self.GetWeaponModSetting( "fire_duration" )
			// thread ProximityMineSpawnShield( proximityMine, duration )
			
			// Start the cooldown system
			thread ManageDeployableCoverCooldown( self, player )
		}
	}
	return 1
}

function GetProximityMineThrowStartPos( player, baseStartPos )
{
	return player.OffsetPositionFromView( baseStartPos, Vector( 15.0, 0.0, 0.0 ) )	// forward, right, up
}

function GetProximityMineThrowVelocity( player, baseAngles )
{
	baseAngles += Vector( -10, 0, 0 )
	return baseAngles.AnglesToForward() * THROW_POWER
}

function OnProjectileCollision( collisionParams )
{
	local bounceDot = 1.0  // sets the dot of the normals it'll stick to
	local result = PlantStickyEntity( self, collisionParams, bounceDot, Vector( 90, 0, 0 ), false, Vector( 0, 0, -3.9 ) )

	if ( IsServer() )
	{
		local player = self.GetOwner()

		if ( !IsValid( player ) )
		{
			self.Kill()
			return
		}

		EmitSoundOnEntity( self, ATTACH_SFX )

		// start trap warning beep
		thread EnableTrapWarningSound( self, PROXIMITY_MINE_ARMING_DELAY, WARNING_SFX )

		// Spawn shield in its own thread (lifetime seconds)
		local duration = self.GetWeaponInfoFileKeyField( "fire_duration" )
		thread ProximityMineSpawnShield( self, duration )

		// if player is rodeoing a Titan and we stickied the mine onto the Titan, set lastAttackTime accordingly
		if ( result )
		{
			local entAttachedTo = self.GetParent()
			if ( !IsValid( entAttachedTo ) )
				return

			if ( !player.IsPlayer() ) //If an NPC Titan has vortexed a prox mine and fires it back out
				return

			local titanSoulRodeoed = player.GetTitanSoulBeingRodeoed()
			if ( !IsValid( titanSoulRodeoed ) )
				return

			local titan = titanSoulRodeoed.GetTitan()

			if ( IsAlive( titan ) && titan == entAttachedTo )
				titanSoulRodeoed.SetLastRodeoHitTime( Time() )
		}
	}
}

function ManageDeployableCoverCooldown( weapon, player )
{
	Assert( IsServer() )
	
	if ( !IsValid( weapon ) || !IsValid( player ) )
		return
	
	// Get cooldown duration from weapon mod settings
	local cooldown = PlayerHasPassive( player, PAS_POWER_CELL) ? 16.67 : 25.0
	
	// Wait for cooldown to expire
	Wait( cooldown )
	
	// Restore ammo after cooldown
	if ( IsValid( weapon ) && IsValid( player ) )
	{
		weapon.SetWeaponPrimaryClipCount( 1 )
	}
}

function ProximityMineSpawnShield( mine, lifetime )
{
	Assert( IsServer() )

	// Wait until Planted signal
	if ( !("s" in mine) || !( "planted" in mine.s ) || !mine.s.planted )
		mine.WaitSignal( "Planted" )

	// Honor existing arming delay
	if ( typeof( PROXIMITY_MINE_ARMING_DELAY ) != "null" && PROXIMITY_MINE_ARMING_DELAY > 0.0 )
		Wait( PROXIMITY_MINE_ARMING_DELAY )

	// Abort if invalid or owner died
	if ( !IsValid( mine ) )
		return

	local owner = mine.GetOwner()
	if ( !IsValid( owner ) || (owner.IsPlayer() && !IsAlive( owner )) )
	{
		if ( IsValid( owner ) && owner.IsPlayer() )
			CleanupPlayerProximityMine( owner, mine )
		else
			mine.Kill()
		return
	}

	local origin = mine.GetOrigin()
	local angles = mine.GetAngles()
	local radius = typeof( MINION_BUBBLE_SHIELD_RADIUS ) != "null" ? MINION_BUBBLE_SHIELD_RADIUS : 160

	local vortexSphere = CreateEntity( "vortex_sphere" )
	vortexSphere.kv.spawnflags = 1 // SF_ABSORB_BULLETS 
	vortexSphere.kv.enabled = 0
	vortexSphere.kv.radius = radius
	vortexSphere.kv.bullet_fov = 360
	vortexSphere.kv.physics_pull_strength = 25
	vortexSphere.kv.physics_side_dampening = 6
	vortexSphere.kv.physics_fov = 360
	vortexSphere.kv.physics_max_mass = 2
	vortexSphere.kv.physics_max_size = 6

	vortexSphere.SetAngles( angles )
	vortexSphere.SetOrigin( origin )

	if ( IsValid( owner ) )
	{
		vortexSphere.SetOwner( owner )
		if ( typeof( owner.GetTeam ) == "function" )
			vortexSphere.SetTeam( owner.GetTeam() )
	}
	else
	{
		vortexSphere.SetOwner( mine )
	}

	vortexSphere.SetMaxHealth( 32000 )
	vortexSphere.SetHealth( 32000 )
	DispatchSpawn( vortexSphere, true )
	vortexSphere.Fire( "Enable" )

	// Control-point helper
	local cpoint = CreateEntity( "info_placement_helper" )
	cpoint.SetName( UniqueString( "shield_wall_controlpoint" ) )
	cpoint.SetOrigin( origin )
	DispatchSpawn( cpoint, false )

	// Create particle FX
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
		particleSystem.SetParent( mine )
		particleSystem.s.cpoint <- cpoint
		vortexSphere.s.shieldWallFX <- particleSystem
	}

	EmitSoundOnEntity( vortexSphere, "BubbleShield_Sustain_Loop" )

	// Centralized cleanup on thread end
	OnThreadEnd(
		function() : ( vortexSphere, particleSystem, cpoint, mine )
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

			// Kill the mine as well on completion or early termination
			if ( IsValid_ThisFrame( mine ) )
			{
				local finalOwner = mine.GetOwner()
				if ( IsValid( finalOwner ) && finalOwner.IsPlayer() )
					CleanupPlayerProximityMine( finalOwner, mine )
				else
					mine.Kill()
			}
		}
	)

	// Lifetime loop checking for owner validity
	local elapsed = 0.0
	local tick = 0.25
	while ( elapsed < lifetime )
	{
		Wait( tick )
		elapsed += tick

		if ( !IsValid( mine ) )
			return

		local curOwner = mine.GetOwner()
		if ( !IsValid( curOwner ) || (curOwner.IsPlayer() && !IsAlive( curOwner )) )
			return // Break out, let OnThreadEnd handle cleanup
	}
}
