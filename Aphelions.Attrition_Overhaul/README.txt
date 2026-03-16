(Thank you to ASILLYNEKO for making this mod and FRANN for expanding upon it!)

This is a modified version (of a modified version) of Extended Attrition. This is meant to be a more hardcore solo experience for Attrition, like playing the TF|2 campaign on Master difficulty. This mod currently includes spectre rodeos, nade-tossing minions, and sniper/suicide spectres that spawn in the mid-late game.
NPCs are now an actual threat that will kill you if you aren't careful! You'll need to pick and choose your battles, use cover, and retreat when necessary to survive.
If you want to experiment or plan on sing this mod for a server, here are some settings you can change:

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


TITANS PER TEAM
* Go into \scripts\vscripts\mp\_ai_game_modes
* ctrl + f to find:
 	function ShouldSpawnPilotWithTitan( team ) // Titan Spawns per Team

The limits will be inside the function. By default, your team will cap at 2 npc Titans. Enemy team will cap at 5.


TITAN SPAWN TIMER
* Go into \scripts\vscripts\mp\_ai_game_modes
* ctrl + f to find:
	// Titan spawn delay in seconds
	wait RandomFloat( 20, 90 )

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
    	// Wait until the 3.5-minute mark before starting waves
    	wait 210.0 


Good luck, have fun!
