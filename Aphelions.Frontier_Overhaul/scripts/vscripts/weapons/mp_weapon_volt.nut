const BEAM_FX = "wpn_laser_beam"
const BEAM_ATTACH = "laser_beam"
const BEAM_RANGE = 2400
const BEAM_TIME = 0.05

PrecacheParticleSystem( BEAM_FX )

function CustomWeapon_GetBeamEnd( owner, eyePos, aimDir )
{
    local endPos = eyePos + ( aimDir * BEAM_RANGE )
    local fraction = TraceLineSimple( eyePos, endPos, owner )
    return eyePos + ( aimDir * ( BEAM_RANGE * fraction ) )
}

function CustomWeapon_FireBeam( weapon, attackParams )
{
    if ( !IsClient() )
        return

    local weaponOwner = weapon.GetWeaponOwner()
    if ( !IsValid( weaponOwner ) )
        return

    local fxEnt = weapon
    local attachID = 0

    if ( weaponOwner == GetLocalViewPlayer() )
    {
        local viewModel = weaponOwner.GetViewModelEntity()
        if ( IsValid( viewModel ) )
        {
            local viewAttachID = viewModel.LookupAttachment( BEAM_ATTACH )
            if ( viewAttachID > 0 )
            {
                fxEnt = viewModel
                attachID = viewAttachID
            }
        }
    }

    if ( attachID <= 0 )
    {
        fxEnt = weapon
        attachID = fxEnt.LookupAttachment( BEAM_ATTACH )
    }

    if ( attachID <= 0 )
        return

    local aimDir = attackParams.dir
    aimDir.Norm()
    local endPos = CustomWeapon_GetBeamEnd( weaponOwner, attackParams.pos, aimDir )

    local handle = StartParticleEffectOnEntity( fxEnt, GetParticleSystemIndex( BEAM_FX ), FX_PATTACH_POINT_FOLLOW, attachID )
    if ( handle <= 0 )
        return

    EffectSetControlPointVector( handle, 1, Vector( 0, 120, 250 ) )
    EffectSetControlPointVector( handle, 2, endPos )

    thread CustomWeapon_UpdateBeam( handle, weaponOwner )
}

function CustomWeapon_UpdateBeam( handle, owner )
{
    wait BEAM_TIME

    if ( EffectDoesExist( handle ) )
        EffectStop( handle, true, true )
}

function OnWeaponPrimaryAttack( attackParams )
{
    self.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
       
    local damageType = damageTypes.Bullet
    if ( self.HasMod( "burn_mod_volt" ) )
        damageType = damageType | damageTypes.Electric

	self.FireWeaponBullet( attackParams.pos, attackParams.dir, 1, damageType )

    if ( self.HasMod( "laser_sight" ) || self.HasMod( "burn_mod_volt" ) )
        CustomWeapon_FireBeam( self, attackParams )
}

function OnWeaponNpcPrimaryAttack( attackParams )
{
    self.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
    self.FireWeaponBullet( attackParams.pos, attackParams.dir, 1, damageTypes.Bullet )

    if ( self.HasMod( "laser_sight" ) )
        CustomWeapon_FireBeam( self, attackParams )
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
    else
    {
           SetLoopingWeaponSound_1p3p( "Weapon_R1SMG1.FirstShotSuppressed", "Weapon_Volt.Loop", "Weapon_R1SMG1.LoopSuppressedEnd",
                                    "Weapon_R1SMG1.FirstShotSuppressed_3P", "Weapon_Volt.Loop_3P", "Weapon_R1SMG1.LoopSuppressedEnd_3P" )
    }
}

function OnWeaponDeactivate( deactivateParams )
{

}