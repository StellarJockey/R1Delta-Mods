
AMMO_BODYGROUP_COUNT <- self.GetWeaponInfoFileKeyField( "ammo_clip_size" )

function SniperPrecache()
{
	if ( WeaponIsPrecached( self ) )
		return

}
SniperPrecache()

function OnWeaponActivate( activateParams )
{
	if ( !( "zoomTimeIn" in self.s ) )
		self.s.zoomTimeIn <- self.GetWeaponModSetting( "zoom_time_in" )

	if ( !IsClient() )
		return

	if ( self.GetWeaponOwner() != GetLocalViewPlayer() )
		return

	//if ( self.HasMod( "sniper_assist" ) )
	CreateSniperVGUI( GetLocalViewPlayer(), self )
}

function OnWeaponOwnerChanged( changeParams )
{
	if ( !IsClient() )
		return

	if ( changeParams.oldOwner == GetLocalViewPlayer() && changeParams.newOwner != GetLocalViewPlayer() )
		DestroySniperVGUI( self )
}

function OnWeaponDeactivate( deactivateParams )
{
	if ( !IsClient() )
		return

	DestroySniperVGUI( self )
	SmartAmmo_Stop( self )
}

function OnWeaponReload( reloadParams )
{
}


function OnWeaponPrimaryAttack( attackParams )
{
	local player = self.GetWeaponOwner()

	if( self.HasMod("silencer") )
		self.EmitWeaponSound( "Anti_Titan_Rifle.SingleSuppressed" )
	else
		self.EmitWeaponSound( "Anti_Titan_Rifle.Single" )

	self.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	return FireWeaponPlayerAndNPC( attackParams, true )
}

function OnWeaponNpcPrimaryAttack( attackParams )
{
	self.EmitWeaponSound( "Weapon_XO16.Single" )
	self.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	return FireWeaponPlayerAndNPC( attackParams, false )
}

function FireWeaponPlayerAndNPC( attackParams, playerFired )
{
	local fireDir = attackParams.dir

	self.FireWeaponBullet( attackParams.pos, fireDir, 1, damageTypes.LargeCaliber )
	return 1
}


function OnWeaponStartZoomIn()
{
	HandleWeaponSoundZoomIn( self, "Weapon_B3.ADS_In" )
}


function OnWeaponStartZoomOut()
{
	HandleWeaponSoundZoomOut( self, "Weapon_B3.ADS_Out" )
}
