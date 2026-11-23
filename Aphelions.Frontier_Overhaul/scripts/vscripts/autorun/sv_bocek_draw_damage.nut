function main()
{
	if ( IsLobby() || !IsServer() )
		return

	AddDamageCallbackSourceID( eDamageSourceId.mp_weapon_bow, Bow_ScaleDamageByDraw )
}

function Bow_ScaleDamageByDraw( ent, damageInfo )
{
	local arrow = damageInfo.GetInflictor()
	if ( !IsValid( arrow ) || !( "drawDamageScale" in arrow.s ) )
		return

	local scale = ent.IsTitan() ? arrow.s.drawDamageScaleTitan : arrow.s.drawDamageScale
	damageInfo.SetDamage( damageInfo.GetDamage() * scale )
}

main()