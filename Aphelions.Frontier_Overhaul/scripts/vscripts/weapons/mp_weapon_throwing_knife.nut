
function ThrowingKnifePrecache()
{
	if ( WeaponIsPrecached( self ) )
		return

	if ( IsServer() )
	{
		PrecacheEntity( "npc_grenade_frag" )
	}
}
ThrowingKnifePrecache()

function OnWeaponPrimaryAttack( attackParams )
{
	if ( self.s.startTime == null )
		return 0

	self.EmitWeaponSound( "Weapon_FragGrenade_Throw" )
	Knife_Throw( self, attackParams, 99 )
}

// Add this function to fire the projectile upon button release
function OnWeaponTossReleaseAnimEvent( tossParams )
{
	Knife_Throw( self, tossParams, 99 )
	return 1
}

function Knife_Throw( weapon, attackParams, baseFuseTime = DEFAULT_FUSE_TIME )
{
	if ( IsClient() && !weapon.ShouldPredictProjectiles() )
		return

	// If the weapon was deactivated (startTime set to null), abort the throw
	if ( !( "startTime" in weapon.s ) || weapon.s.startTime == null )
		return 0

	//TEMP FIX while Deploy anim is added to sprint
	if ( !( "startTime" in weapon.s ) )
		weapon.s.startTime <- null
	weapon.s.startTime = Time()

	local weaponOwner = weapon.GetWeaponOwner()
	local attackOrigin = weaponOwner.EyePosition() // attackParams.pos
	local attackAngles = attackParams.dir.GetAngles()
	attackAngles.x -= 5
	local forward = attackAngles.AnglesToForward()
	local velocity = (forward) * 1500
	local angularVelocity = Vector( 0, 0, 0 )
	local fuseTime = baseFuseTime - ( Time() - weapon.s.startTime )

	if ( fuseTime <= 0 )
		return 0


	local frag = weapon.FireWeaponGrenade( attackOrigin, velocity, angularVelocity, fuseTime, damageTypes.Ragdoll, damageTypes.Explosive, PROJECTILE_PREDICTED, true, true )

	if ( frag )
	{
		if ( IsServer() )
		{
			Grenade_Init( frag, weapon )
			thread TrapExplodeOnDamage( frag, 20, 0.0, 0.0 )
			thread FakeKnifeHit( attackParams, frag )
		}
		else
		{
			frag.SetTeam( weaponOwner.GetTeam()	)
		}
	}

	weaponOwner.Signal("ThrowGrenade")
	return 1
}

// Targets that get too close dont get hit by the actual projectile
function FakeKnifeHit( attackParams, frag )
{
	wait 0.25

	if ( !IsValid( self ) )
		return

	local owner = self.GetWeaponOwner()
	if ( !IsValid( owner ) )
		return

	local origin = owner.EyePosition()
	local angles = owner.EyeAngles()
	local forward = angles.AnglesToForward()
	
	local ignoreArray = []
	if ( IsValid( owner ) ) ignoreArray.append( owner )
	if ( IsValid( self ) ) ignoreArray.append( self )
	if ( IsValid( frag ) ) ignoreArray.append( frag )

	local result = TraceLine( origin, origin + forward * 2000, ignoreArray, TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE )

	local ent = result.hitEnt
	if ( ent && ent.IsHumanSized() && Distance( origin, ent.GetOrigin() ) <= 180 )
		ent.TakeDamage( self.GetWeaponModSetting( "damage_near_value" ), owner, owner, { scriptType = DF_RAGDOLL | DF_INSTANT | DF_KILLSHOT, damageSourceId = eDamageSourceId.mp_weapon_mega5 } )
}

function OnWeaponActivate( prepParams )
{
	self.EmitWeaponSound( "Weapon_ThrowingKnife_Draw" )
	if ( !( "startTime" in self.s ) )
		self.s.startTime <- null
	self.s.startTime = Time()

	//Grenade_Deploy( self, prepParams, 99 )
}

function OnWeaponDeactivate( deactivateParams )
{
	self.s.startTime = null
	Grenade_Deactivate( self, deactivateParams )
}

function OnProjectileCollision( collisionParams )
{
	local hitEnt = collisionParams.hitent
	local classname = ""
	if ( hitEnt != null )
		classname = hitEnt.GetClassname()

	// Check if it hits a live target OR their newly created ragdoll corpse
	if ( hitEnt != null && (hitEnt.IsPlayer() || hitEnt.IsNPC() || classname == "prop_ragdoll") )
	{
		if ( IsServer() )
		{
			self.ClearParent()
			
			// Instantly trace straight down to the floor to prevent the physics engine from bouncing it
			local origin = self.GetOrigin()
			local trace = TraceLine( origin, origin - Vector(0, 0, 1000), [ self, hitEnt ], TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )
			
			// Teleport it to the ground and freeze it in place
			self.SetOrigin( trace.endPos + Vector(0, 0, 2) ) 
			self.SetVelocity( Vector( 0, 0, 0 ) )
			self.kv.movetype = 0 
		}
	}
	else
	{
		local bounceDot = 1.0
		local result = PlantStickyEntity( self, collisionParams, bounceDot )
	}

	if ( hitEnt != null && IsServer() )
	{
		if ( "playedScans" in self.s )
			return

		EmitSoundOnEntity( self, "Default.WallCling_Attach" )

		local mods = self.GetMods()
		local owner = self.GetOwner()

		if ( owner && owner.IsPlayer() && ArrayContains( mods, "burn_mod_throwing_knife" ) )
		{
			LeechSurroundingSpectres( self.GetOrigin(), owner )
		}

		self.s.playedScans <- true
		
		thread MonitorKnifeRetrieval( self, owner )
	}
}

function MonitorKnifeRetrieval( knife, owner )
{
	knife.EndSignal( "OnDestroy" )
	
	local expireTime = Time() + 60.0 

	while ( Time() < expireTime )
	{
		if ( !IsValid( knife ) ) return
		
		if ( !IsValid( owner ) || !IsAlive( owner ) )
		{
			knife.Destroy()
			return
		}

		if ( Distance( knife.GetOrigin(), owner.GetOrigin() ) <= 75 )
		{
			local weapons = owner.GetOffhandWeapons()
			foreach ( weapon in weapons )
			{
				if ( weapon.GetWeaponClassName() == "mp_weapon_mega5" )
				{
					local currentAmmo = weapon.GetWeaponPrimaryClipCount()
					local maxAmmo = PlayerHasPassive( owner, PAS_ORDNANCE_PACK ) ? 3 : 2
					
					if ( currentAmmo < maxAmmo )
					{
						weapon.SetWeaponPrimaryClipCount( currentAmmo + 1 )
						EmitSoundOnEntity( owner, "Ammo_Pickup_Grenade_1P" )
						knife.Destroy()
						return
					}
				}
			}
		}
		wait 0.1
	}

	if ( IsValid( knife ) )
		knife.Destroy()
}