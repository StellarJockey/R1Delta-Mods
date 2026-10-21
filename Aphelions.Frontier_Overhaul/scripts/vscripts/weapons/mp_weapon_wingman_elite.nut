
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


HCOG_AIM_RAISE <- 0.031   // rise over run

// This is to correct the wonky sight offset
// Without it, the bullet lines up with the iron sights, not the HCOG

function FireWeaponPlayerAndNPC( attackParams, playerFired )
{
	local fireDir = attackParams.dir

	if ( playerFired )
	{
		local zoom = self.GetWeaponOwner().GetZoomFrac()
		if ( zoom > 0 )
		{
			local d = attackParams.dir
			local h = sqrt( d.x * d.x + d.y * d.y )   // horizontal length of the aim direction

			if ( h > 0.01 )   // skip when aiming almost straight up or down
			{
				// unit vector perpendicular to d, pointing up in the vertical plane
				local up = Vector( -d.x * d.z / h, -d.y * d.z / h, h )

				local nd = d + up * ( HCOG_AIM_RAISE * zoom )
				local len = sqrt( nd.x * nd.x + nd.y * nd.y + nd.z * nd.z )
				fireDir = nd * ( 1.0 / len )
			}
		}
	}

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
