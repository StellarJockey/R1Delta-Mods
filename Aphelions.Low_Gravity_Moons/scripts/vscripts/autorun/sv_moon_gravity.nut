function main()
{
	if ( IsLobby() )
		return

	thread MoonGravity()
}

function MoonGravity()
{
	local mapname = GetMapName()
	if ( mapname == "mp_airbase" )
	{
		ServerCommand( "sv_gravity 500" ) // Lower gravity for moon-based maps
		ServerCommand( "superjump_max_height 120" )
	}
	else if ( mapname == "mp_outpost_207" || mapname == "mp_sandtrap" )
	{
		ServerCommand( "sv_gravity 400" )  // The smaller the moon, the less gravity there is
		ServerCommand( "superjump_max_height 130" )
	}
	else
	{
		// Reset to defaults for all other maps
		ServerCommand( "sv_gravity 750" )
		ServerCommand( "superjump_max_height 80" )
	}
}

main()
