function main()
{
	if ( IsLobby() )
		return

	AddDamageCallback( "player", Skull_Pierce_Damage )
	AddDamageCallback( "npc_soldier", Skull_Pierce_Damage )
	AddDamageCallback( "npc_spectre", Skull_Pierce_Damage )
}

function Skull_Pierce_Damage( victim, damageInfo )
{
	if ( !IsValid( victim ) )
		return

	if ( !victim.IsPlayer() && !victim.IsSoldier() && !victim.IsSpectre() )
		return

	if ( !( damageInfo.GetCustomDamageType() & DF_HEADSHOT ) )
		return

	local hasSkullPiercer = false
	foreach ( mod in GetWeaponModsFromDamageInfo( damageInfo ) )
	{
		if ( mod == "skull_piercer" )
		{
			hasSkullPiercer = true
			break
		}
	}

	if ( hasSkullPiercer )
		damageInfo.SetDamage( victim.GetMaxHealth() + 1 )
}

main()