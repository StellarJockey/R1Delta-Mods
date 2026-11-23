// Bocek arrow. An arrow that hits the world stays stuck in it for a while.

const BOW_ARROW_MODEL = "models/weapons/bullets/w_arrow_projectile.mdl"
const BOW_ARROW_STICK_TIME = 30.0		// seconds a stuck arrow stays in the world
const BOW_ARROW_STICK_MAX = 48			// stuck arrows kept at once, oldest removed first
const BOW_ARROW_STICK_DEPTH = 2.0		// inches the arrow head sinks into the surface (the model's origin is at its tip)

if ( IsServer() )
{
	PrecacheModel( BOW_ARROW_MODEL )

	if ( !( "bowStuckArrows" in level ) )
		level.bowStuckArrows <- []
}

function OnProjectileCollision( collisionParams )
{
	if ( IsClient() )
		return

	if ( collisionParams.hitent == level.worldspawn )
		StickArrowInWorld( collisionParams )
}

function StickArrowInWorld( collisionParams )
{
	local forward = self.GetVelocity()
	forward.Norm()

	local arrow = CreatePropDynamic( BOW_ARROW_MODEL, collisionParams.pos + forward * BOW_ARROW_STICK_DEPTH, forward.GetAngles() )

	local stuck = level.bowStuckArrows
	stuck.append( arrow )
	if ( stuck.len() > BOW_ARROW_STICK_MAX )
	{
		local oldest = stuck.remove( 0 )
		if ( IsValid( oldest ) )
			oldest.Destroy()
	}

	thread RemoveStuckArrow( arrow )
}

function RemoveStuckArrow( arrow )
{
	arrow.EndSignal( "OnDestroy" )

	wait BOW_ARROW_STICK_TIME

	ArrayRemove( level.bowStuckArrows, arrow )
	arrow.Destroy()
}
