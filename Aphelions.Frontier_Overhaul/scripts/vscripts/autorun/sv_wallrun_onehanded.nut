function main()
{
	if ( IsLobby() )
		return

	AddCallback_GameStateEnter( eGameState.Playing, WallrunOnehanded_Playing )

	AddDamageCallback( "player", EnhancedParkourBuff_OnDamage )
}

function EnhancedParkourBuff_OnDamage( player, damageInfo )
{
	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	// Check for the passive AND if they are in one of the parkour states
	if ( PlayerHasPassive( player, PAS_WALL_RUNNER ) && 
	     ( player.IsWallRunning() || player.IsDoubleJumping() || player.IsWallHanging() || player.IsZiplining() ) )
	{
		local damage = damageInfo.GetDamage()
		damageInfo.SetDamage( damage * 0.5 ) // 50% damage reduction
	}
}

function WallrunOnehanded_Playing()
{
	thread WallrunOnehanded_Think()
}

function WallrunOnehanded_Think()
{
	for( ;; )
	{
		foreach( player in GetLivingPlayers() )
		{
			if ( player.IsBot() )
				continue

			if ( player.IsWallRunning() ) //|| ( player.IsOnGround() && player.IsCrouched() && player.GetVelocity().Length() >= 300 ) )
			{
				player.SetOneHandedWeaponUsageOn()
			}
			else
			{
				// GetTitanSoulBeingRodeoed() means "is this player rodeoing someone?"
				if ( !player.IsWallHanging() && !player.IsZiplining() && player.GetTitanSoulBeingRodeoed() == null )
				{
					player.SetOneHandedWeaponUsageOff()
				}
			}
		}

		wait 0
	}
}

main()