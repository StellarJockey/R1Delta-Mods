(Thank you to ASILLYNEKO and FRANN for making the original Extended Attrition mod!)

This is a modified version of Extended Attrition. This is meant to be a more hardcore solo experience, like playing the TF|2 campaign on Master difficulty. NPCs are now an actual threat that will kill you if you aren't careful! You'll need to pick and choose your battles, use cover, and retreat when necessary to survive.

This mod currently includes:
>Spectre rodeos and grenade-tossing minions
>Sniper spectres, suicide spectres, and cloak drones that spawn in the mid-late game
>Sniper spectres will only de-cloak when they have line of sight on an enemy
>Suicide spectres are now extremely tanky, but any form of electric/arc damage will insta-kill them
>Works for Attrition, Hardpoint, Campaign, and Titan Brawl
>Evac sequence will trigger if you lose a game (and will take off as soon as you get in!)
>In the campaign, the evac will run regardless of if you win or lose, since the cutscene triggers depend on it
>The rework for the Thunderbolt Titan minigun, a full-auto test mod for the WYS-0404, and a rework for the XO-16 burst and SMR tank buster mods

If you want to experiment (or plan on using this mod for a server), here are some settings you can change:

MAX NUMBER OF NPCS
* Go into \scripts\vscripts\mp\_ai_game_modes
* ctrl + f to find:
 	level.max_npc_per_side       <- 28
	level.max_npc_per_side_small <- 21

To me, 28 feels about right for most maps, but you can raise or lower it to whatever you feel like. 21 is for smaller maps that feel overcrowded with lots of minions.


ADJUST ENEMY AI
* Go into \scripts\vscripts\mp\_ai_soldiers
* You will see:
 	const AI_SPECTRE_ACCURACY = 100
 	const AI_SOLDIER_ACCURACY = 20
 	const AI_SPECTRE_PROFICIENCY = 4
 	const AI_SOLDIER_PROFICIENCY = 4

Default values were 1, 0.6, 2, and 2 originally. 


AI TITANS PER TEAM
* Go into \scripts\vscripts\mp\_ai_game_modes
* ctrl + f to find:
 	function ShouldSpawnPilotWithTitan( team ) // Titan Spawns per Team

The limits will be inside the function. By default, your team will cap at 2 npc Titans. Enemy team will cap at 5.
(Numbers will be 5 and 6 for Titan Brawl)


AI TITAN SPAWN TIMER
* Go into \scripts\vscripts\mp\_ai_game_modes
* ctrl + f to find:
	wait RandomFloat( 20, 90 )  // Titan spawn delay in seconds

This makes it so that Titans don't immediately spawn when the game starts or when they are killed. Default value is anywhere from 20-90 seconds.


SNIPER SPECTRE SPAWNS
* Go into \scripts\vscripts\mp\_ai_game_modes
* ctrl + f to find:
	if ( shouldSpawnSpectre )
    		{
        	if ( allowSnipers && roll < 0.40 ) // (40% chance)


SUICIDE SPECTRE WAVES
* Go into \scripts\vscripts\mp\_ai_game_modes
* ctrl + f to find:
function SuicideSpectreWaveThink( team )
{
    	// Wait until the 4-minute mark before starting waves
    	wait 240.0 


Good luck, have fun!
