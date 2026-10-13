function main()
{
	if ( IsLobby() )
		return

	AddDamageCallback( "player", Hologram_NoDamage )
	AddDamageCallback( "npc_soldier", Hologram_NoDamage )
	AddDamageCallback( "npc_spectre", Hologram_NoDamage )
	AddDamageCallback( "npc_titan", Hologram_NoDamage )
}

function Hologram_NoDamage( victim, damageInfo )
{
	local attacker = damageInfo.GetAttacker()
	if ( IsValid( attacker ) && "s" in attacker && "isHologram" in attacker.s )
		damageInfo.SetDamage( 0 )
}

main()