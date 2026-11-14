
self.s.pilotDamageRatio <- 1.0

function YH803Precache()
{
	if ( WeaponIsPrecached( self ) )
		return

	PrecacheParticleSystem( "wpn_muzzleflash_xo_rocket" )
}
YH803Precache()

function OnWeaponActivate( activateParams )
{

}


const YH803_MISSILE_SPEED = 1800 

function OnWeaponPrimaryAttack( attackParams )
{
	self.EmitWeaponSound( "Drone_Rocket.Fire" )
	self.EmitWeaponSound( "Weapon_bulletCasing.Single" )
	self.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	if ( IsClient() && !self.ShouldPredictProjectiles() )
		return 1

	YH803_FireMissile( attackParams, PROJECTILE_PREDICTED )
	return 1
}

function OnWeaponNpcPrimaryAttack( attackParams )
{
	self.EmitWeaponSound( "Drone_Rocket.Fire" )
	self.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	self.PlayWeaponEffect( "wpn_muzzleflash_xo_rocket", "wpn_muzzleflash_xo_rocket", "muzzle_flash" )

	if ( IsClient() && !self.ShouldPredictProjectiles() )
		return 1

	YH803_FireMissile( attackParams, PROJECTILE_NOT_PREDICTED )
}

function YH803_FireMissile( attackParams, predicted )
{
	local weaponOwner = self.GetWeaponOwner()

	local missile = self.FireWeaponMissile( attackParams.pos, attackParams.dir, YH803_MISSILE_SPEED, damageTypes.Explosive | DF_IMPACT, damageTypes.Explosive, false, predicted )

	if ( missile )
	{
		missile.SetTeam( weaponOwner.GetTeam() )
		InitDumbfireRocket( missile, self )
	}
}

function InitDumbfireRocket( missile, weapon )
{
	missile.s.innerRadius 					<- self.GetWeaponModSetting( "explosion_inner_radius" )
	missile.s.outerRadius 					<- self.GetWeaponModSetting( "explosionradius" )
	missile.s.explosionDamage 				<- self.GetWeaponModSetting( "explosion_damage" )
	missile.s.explosionDamageHeavyArmor 	<- self.GetWeaponModSetting( "explosion_damage_heavy_armor" )
	missile.s.npcExplosionDamage 			<- self.GetWeaponModSetting( "npc_explosion_damage" )
	missile.s.npcExplosionDamageHeavyArmor 	<- self.GetWeaponModSetting( "npc_explosion_damage_heavy_armor" )
}