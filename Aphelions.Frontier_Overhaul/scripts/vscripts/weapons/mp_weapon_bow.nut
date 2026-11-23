// Bocek compound bow, ported from Apex Legends (mp_weapon_bow in R5Flowstate).
// Hold attack to draw and release to loose. The draw sets the arrow's speed and how much
// its damage is scaled up (applied in weapons/_bow.nut). The numbers are in
// scripts/weapons/mp_weapon_bow.txt.

const BOW_DRAW_SOUND = "Weapon_Bow.Draw"
// The releases short of full draw, by charge level (the viewmodel's activities, after
// "ACT_VM_"): Apex's charged_lv1 to charged_lv4. A full draw plays the attack.
BOW_LOW_RELEASES <- [ "RELOAD_LATE1", "RELOAD_LATE2", "RELOAD_LATE3", "RELOADEMPTY_LATE1" ]
// held in one hand, Apex has one release short of full draw
const BOW_LOW_RELEASE_ONEHANDED = "ACT_VM_ONEHANDED_RELOAD_LATE1"

function OnWeaponPrimaryAttack( attackParams )
{
	self.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	local draw = GetBowDraw()
	PlayBowRelease( draw )
	return FireArrow( attackParams, draw, true )
}

// Short of full draw, plays Apex's release for the charge level over the attack. Apex has
// five levels below full, a fifth of the draw each (charge_levels 6); the lowest two share
// an animation.
function PlayBowRelease( draw )
{
	if ( draw >= 1.0 )
		return
	local owner = self.GetWeaponOwner()
	if ( owner.IsWallHanging() || owner.GetTitanSoulBeingRodeoed() != null )
	{
		owner.Weapon_StartCustomActivity( BOW_LOW_RELEASE_ONEHANDED, false )
		return
	}
	local level = max( 0, min( BOW_LOW_RELEASES.len() - 1, floor( draw * 5.0 ) - 1 ) )
	owner.Weapon_StartCustomActivity( "ACT_VM_" + BOW_LOW_RELEASES[level], false )
}

// How far the string is drawn, 0 to 1. The engine's charge only counts the seconds attack
// has been held (see charge_time in the weapon file).
function GetBowDraw()
{
	local heldTime = self.GetWeaponChargeFraction() * self.GetWeaponInfoFileKeyField( "charge_time" )
	return min( 1.0, heldTime / self.GetWeaponInfoFileKeyField( "bow_draw_time" ) )
}

function OnWeaponNpcPrimaryAttack( attackParams )
{
	self.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	// NPCs do not charge weapons; they loose at full draw
	return FireArrow( attackParams, 1.0, false )
}

function FireArrow( attackParams, draw, playerFired )
{
	local owner = self.GetWeaponOwner()

	if ( !IsValid( owner ) || !IsAlive( owner ) )
		return
	
	local shouldCreateProjectile = IsServer() || self.ShouldPredictProjectiles()
	if ( IsClient() && !playerFired )
		shouldCreateProjectile = false

	if ( !shouldCreateProjectile )
		return 1

	local minSpeed = self.GetWeaponInfoFileKeyField( "projectile_launch_speed" )
	local maxSpeed = self.GetWeaponInfoFileKeyField( "projectile_launch_speed_full_charge" )
	local speed = Graph( draw, 0.0, 1.0, minSpeed, maxSpeed )

	local arrow = self.FireWeaponBolt( attackParams.pos, attackParams.dir, speed, damageTypes.LargeCaliber, damageTypes.LargeCaliber, playerFired )
	arrow.kv.gravity = self.GetWeaponInfoFileKeyField( "projectile_gravity_scale" )
	arrow.kv.bounceFrac = 0.0

	if ( IsServer() )
	{
		// The weapon file's damage is an arrow with no draw; a full draw deals damage_full_charge
		local base = self.GetWeaponModSetting( "damage_near_value" ).tofloat()
		local baseTitan = self.GetWeaponModSetting( "damage_near_value_titanarmor" ).tofloat()
		arrow.s.drawDamageScale <- Graph( draw, 0.0, 1.0, 1.0, self.GetWeaponInfoFileKeyField( "damage_full_charge" ) / base )
		arrow.s.drawDamageScaleTitan <- Graph( draw, 0.0, 1.0, 1.0, self.GetWeaponInfoFileKeyField( "damage_full_charge_titanarmor" ) / baseTitan )
	}

	return 1
}

function OnWeaponChargeBegin( chargeParams )
{
	if ( IsClient() && InPrediction() && !IsFirstTimePredicted() )
		return

	if ( IsClient() )
		EmitSoundOnEntity( self, BOW_DRAW_SOUND )
	else
		EmitSoundOnEntityExceptToPlayer( self, self.GetWeaponOwner(), BOW_DRAW_SOUND )
}

function OnWeaponChargeEnd( chargeParams )
{
	if ( IsClient() && InPrediction() && !IsFirstTimePredicted() )
		return

	StopSoundOnEntity( self, BOW_DRAW_SOUND )
}

function OnWeaponStartZoomIn()
{
	HandleWeaponSoundZoomIn( self, "Weapon_Bow.ADS_In" )
}

function OnWeaponStartZoomOut()
{
	HandleWeaponSoundZoomOut( self, "Weapon_Bow.ADS_Out" )
}

function OnClientAnimEvent( name )
{
	GlobalClientEventHandler( name )
}
