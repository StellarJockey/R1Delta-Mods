function main()
{
	if ( IsLobby() )
		return

	AddDamageCallback( "titan", GunshipTitanDebuff_OnDamage )
}

function GunshipTitanDebuff_OnDamage( victim, attacker, damageInfo )
{
	if ( !IsValid( victim ) || !victim.IsTitan() || !IsValid( attacker ) )
		return

	// Check if attacker is a turret belonging to a gunship
	if ( "isGunshipTurret" in attacker.s && attacker.s.isGunshipTurret )
	{
		local damage = damageInfo.GetDamage()
		damageInfo.SetDamage( damage * 0.5 ) // Titans will take 50% less damage from gunship turrets
		return
	}
}

main()