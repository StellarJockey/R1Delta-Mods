function OnWeaponPrimaryAttack( attackParams )
{
	self.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	self.FireWeaponBullet( attackParams.pos, attackParams.dir, 1, damageTypes.Electric | DF_STOPS_TITAN_REGEN )
}

function OnWeaponNpcPrimaryAttack( attackParams )
{
	self.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	self.FireWeaponBullet( attackParams.pos, attackParams.dir, 1, damageTypes.Electric | DF_STOPS_TITAN_REGEN )
}

function OnWeaponStartZoomIn()
{
	HandleWeaponSoundZoomIn( self, "Weapon_R97.ADS_In" )
}

function OnWeaponStartZoomOut()
{
	HandleWeaponSoundZoomOut( self, "Weapon_R97.ADS_Out" )
}

function OnWeaponActivate( activateParams )
{
	local weaponOwner = self.GetWeaponOwner()
	if ( !IsValid_ThisFrame( weaponOwner ) )
		return

	if ( self.HasMod( "silencer" ) )
	{
		SetLoopingWeaponSound_1p3p( "Weapon_R1SMG1.FirstShotSuppressed", "Weapon_R1SMG1.LoopSuppressed", "Weapon_R1SMG1.LoopSuppressedEnd",
		                            "Weapon_R1SMG1.FirstShotSuppressed_3P", "Weapon_R1SMG1.LoopSuppressed_3P", "Weapon_R1SMG1.LoopSuppressedEnd_3P" )
	}
	else if ( !self.HasMod( "burst" ) )
	{
		if ( weaponOwner.IsPlayer() )
		{
			SetLoopingWeaponSound_1p3p( "Weapon_R1SMG1.FirstShot", "Weapon_R1SMG1.Loop", "Weapon_R1SMG1.LoopEnd",
			                            "Weapon_R1SMG1.FirstShot", "Weapon_R1SMG1.Loop_3P", "Weapon_R1SMG1.LoopEnd_3P" )
		}
	}
}

function OnWeaponDeactivate( deactivateParams )
{
	self.ClearLoopingWeaponSound()
}