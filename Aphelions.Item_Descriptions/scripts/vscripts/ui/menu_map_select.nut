
const MAP_LIST_VISIBLE_ROWS = 17 // FO
const MAP_LIST_SCROLL_SPEED = 0

function main()
{
	Globalize( InitMapsMenu )
	Globalize( OnOpenMapsMenu )
	Globalize( OnCloseMapsMenu )

	RegisterSignal( "OnCloseMapsMenu" )
}

function InitMapsMenu()
{
	file.menu <- GetMenu( "MapsMenu" )
	local menu = file.menu

	AddEventHandlerToButtonClass( menu, "MapButtonClass", UIE_GET_FOCUS, Bind( MapButton_Focused ) )
	AddEventHandlerToButtonClass( menu, "MapButtonClass", UIE_LOSE_FOCUS, Bind( MapButton_LostFocus ) )
	AddEventHandlerToButtonClass( menu, "MapButtonClass", UIE_CLICK, Bind( MapButton_Activate ) )
	AddEventHandlerToButtonClass( menu, "MapListScrollUpClass", UIE_CLICK, Bind( OnMapListScrollUp_Activate ) )
	AddEventHandlerToButtonClass( menu, "MapListScrollDownClass", UIE_CLICK, Bind( OnMapListScrollDown_Activate ) )

	file.starsLabel <- menu.GetChild( "StarsLabel" )
	file.star1 <- menu.GetChild( "MapStar0" )
	file.star2 <- menu.GetChild( "MapStar1" )
	file.star3 <- menu.GetChild( "MapStar2" )

	file.buttons <- GetElementsByClassname( menu, "MapButtonClass" )
	foreach ( button in file.buttons )
		button.s.dlcGroup <- null

	file.numMapButtonsOffScreen <- null
	file.mapListScrollState <- 0
}

function OnOpenMapsMenu()
{
	local buttons = file.buttons
	local mapsArray = GetPrivateMatchMaps()

	file.numMapButtonsOffScreen = mapsArray.len() - MAP_LIST_VISIBLE_ROWS
	Assert( file.numMapButtonsOffScreen >= 0 )

	foreach ( button in buttons )
	{
		local buttonID = button.GetScriptID().tointeger()

		if ( buttonID >= 0 && buttonID < mapsArray.len() )
		{
			if (GetModeNameForEnum(level.ui.privatematch_mode) == "campaign_carousel") {
				button.SetText( GetCampaignMapDisplayName( mapsArray[buttonID] ) )
			} else {
				button.SetText( GetMapDisplayName( mapsArray[buttonID] ) )
			}

			button.SetEnabled( true )
			button.s.dlcGroup = GetDLCMapGroupForMap( mapsArray[buttonID] )
		}
		else
		{
			button.SetText( "" )
			button.SetEnabled( false )
		}

		if ( buttonID < mapsArray.len() && mapsArray[buttonID] == GetPrivateMatchMapNameForEnum( level.ui.privatematch_map ) )
		{
			printt( buttonID, mapsArray[buttonID] )
			button.SetFocused()
		}
	}

	file.starsLabel.Hide()
	file.star1.Hide()
	file.star2.Hide()
	file.star3.Hide()

	RegisterButtonPressedCallback( MOUSE_WHEEL_UP, OnMapListScrollUp_Activate )
	RegisterButtonPressedCallback( MOUSE_WHEEL_DOWN, OnMapListScrollDown_Activate )

	UpdateDLCMapButtons()

	thread MonitorDLCAvailability()
}

function UpdateDLCMapButtons()
{
	local buttons = file.buttons

	foreach ( button in buttons )
	{
		if ( button.s.dlcGroup == null || button.s.dlcGroup < 1 )
			continue

		if ( ServerHasDLCMapGroupEnabled( button.s.dlcGroup ) )
			button.SetLocked( false )
		else
			button.SetLocked( true )

		if ( button.IsFocused() )
			UpdateMapButtonTooltip( button )
	}
}

function UpdateMapButtonTooltip( button )
{
	local menu = file.menu

	if ( button.s.dlcGroup > 0 )
	{
		if ( !IsDLCMapGroupEnabledForLocalPlayer( button.s.dlcGroup ) )
			HandleLockedCustomMenuItem( menu, button, ["#DLC_REQUIRED"] )
		else if ( !ServerHasDLCMapGroupEnabled( button.s.dlcGroup ) )
			HandleLockedCustomMenuItem( menu, button, ["#NOT_OWNED_BY_ALL_PLAYERS"] )
		else
			HandleLockedCustomMenuItem( menu, button, [], true )
	}
}

function OnCloseMapsMenu()
{
	DeregisterButtonPressedCallback( MOUSE_WHEEL_UP, OnMapListScrollUp_Activate )
	DeregisterButtonPressedCallback( MOUSE_WHEEL_DOWN, OnMapListScrollDown_Activate )

	Signal( uiGlobal.signalDummy, "OnCloseMapsMenu" )
}

function MapButton_Focused( button )
{
	local buttonID = button.GetScriptID().tointeger()

	local menu = file.menu
	local nextMapImage = menu.GetChild( "NextMapImage" )
	local nextMapName = menu.GetChild( "NextMapName" )
	local nextMapDesc = menu.GetChild( "NextMapDesc" )

	// White text for readability
	nextMapName.SetColor( 255, 255, 255 )
	nextMapDesc.SetColor( 255, 255, 255 )

	local mapsArray = GetPrivateMatchMaps()
	local mapName = mapsArray[buttonID]
	local mapImage = "../ui/menu/lobby/lobby_image_" + mapName + "_v2"
	nextMapImage.SetImage( mapImage )
	
	/*
	if ( mapName == "mp_relic" || mapName == "mp_swampland" )
		nextMapImage.SetColor( 200, 200, 200 )
	else
		nextMapImage.SetColor( 255, 255, 255 )
	*/

	if (GetModeNameForEnum(level.ui.privatematch_mode) == "campaign_carousel") {
		nextMapName.SetText( GetCampaignMapDisplayName( mapName ) )

		local campaignDescriptions = {
			mp_fracture =    "1750 Hours, July 15, 2710\nThe 1st Militia Fleet arrives in orbit around Victor, desperately low on fuel. They've embedded a civilian trading convoy into their ranks, as to not trigger the IMC's orbital defense array. They'll either get the fuel or die trying."
			mp_colony =      "1604 Hours, July 20, 2710\nArriving in search of Militia fugitives, IMC recon satellites have found something far worse on planet Troy. But in trying to reclaim the Vice Admiral's lost ship, an old war hero is forced out of hiding..."
			mp_relic =       "1800 Hours, July 20, 2710\nMacAllan makes a deal with the Militia. Their mission is to get the surviving colonists out of harm's way. In exchange, they will receive the Odyssey's black box. If MacAllan is to be believed, it may hold the key to defeating the IMC..."
			mp_angel_city =  "1530 Hours, August 2, 2710\nAfter some digging, Bish has found the next part of MacAllan's plan: an air traffic controller in Angel City's harbor district. But the IMC's Spyglass Network is everywhere. Getting in is the easy part. Getting out will be... less so."
			mp_outpost_207 = "0105 Hours, August 4, 2710\nMacAllan's gambit during the Battle of Angel City paid off. The IMS Sentinel retreats to the drydock, guarded by Outpost 207. The Militia sends in a strike team to take out the ship, with the Vice Admiral still onbaord."
			mp_boneyard =    "1311 Hours, August 12, 2710\nAgainst his better judgement, Barker takes the Militia to the Boneyard, the site of an abandoned IMC research facility. Bish's job is to collect data on the tower before the IMC can scuttle the base."
			mp_airbase =     "0506 Hours, August 29, 2710\nAt the eleventh hour, IMC reinforcements prepare to lift off from Airbase Sierra. Commander Sarah Briggs leads a strike team inside the base, now armed with Bish's tower-crippling virus: a program he calls the 'Icepick.'"
			mp_o2 =          "0700 Hours, August 29, 2710\nThe 1st Militia Fleet launches its final assault on the gate-world of Demeter. While Bish leads a cyber-attack against the Spyglass Network, MacAllan and Vice Admiral Graves play out their long-awaited endgame..."
			mp_corporate =   "1530 Hours, December 5, 2710\nIn the epilogue of Demeter's destruction, Marcus Graves was court-martialed for lying under oath about the Odyssey. But after being rescued from a Colonial Navy black site, he now forms an uneasy alliance with the Militia."
		}

		if ( mapName in campaignDescriptions ) {
			nextMapDesc.SetText( campaignDescriptions[mapName] )
		} else {
			nextMapDesc.SetText( "#" + mapName + "_CAMPAIGN_MENU_DESC" )
		}
	}
	else
	{
		nextMapName.SetText( GetMapDisplayName( mapName ) )

		// --- CUSTOM MAP DESCRIPTION OVERRIDES ---
		local customDescriptions = {
			mp_fracture = "Planet Victor, Yuma System\nYears of aggressive fuel extracting have taken their toll on this former colony for the privileged. It has since been abandoned, with entire continents being turned upside down.",
			mp_nexus = "Planet Harmony, Freeport System\nIMC forces preform a routine search at a hydroponics outpost that is suspected of harboring Militia personnel. Unbeknownst to them, this planet is the Frontier Militia's current base of operations.",
			mp_overlook = "Planet Galen, Omaha System\nThis armament facility has been illegally repurposed by the IMC into a temporary prison complex. The Militia attempt to rescue a platoon being held in maximum security.",
			mp_o2 = "Planet Demeter, Demeter System\nThis world-spanning refinery is responsible for fueling both naval and commercial fleets entering and leaving the Frontier. While solar fields harvest energy from a dying red giant, nuclear reactors are kept on for emergency power in the event of a solar flare.",
			mp_outpost_207 = "Ino, moon of Harmony\nOrbital defense cannons are stationed at high altitude to fend off against incursions from hostile capital ships. This outpost is responsible defending an IMC shipyard in the Freeport System.",
			mp_airbase = "Despoina, fourth moon of Demeter\nAirbase Sierra is defended against local wildlife by the latest generation of repulsor towers. It is the single largest airfield in the Frontier, with ships requiring minimal fuel for takeoff due to the low gravity.",
			mp_relic = "Planet Troy, Sector Bravo-217\nParts from this IMC shipwreck are salvaged and sent to the valley below. Officially, this Andromeda-class carrier was reported lost after a \"Militia sabotage\", leading to the IMC's famous recruitment campaign: \"Remember the Odyssey.\"",
			mp_colony = "Planet Troy, Sector Bravo-217\nThis abandoned farm colony was built from the wreckage of the ghost ship, IMS Odyssey. During the trial of Marcus Graves, the IMC was forced to reveal the true fate of the Odyssey to the public - though no evidence of a \"Spectre massacre\" was found.",
			mp_angel_city = "Planet Angelia, Wichita System\nAngel City is one of the largest human settlements on the Froniter. When the IMC instituted martial law, massive walls were built to divide the city into smaller districts. It has recently entered the tenth year of its temporary \"two-week\" lockdown.",
			mp_smugglers_cove = "Planet Navaria, Freeport System\nPart arms bazaar and part pirate enclave, Smuggler's Cove is infamous for its selection of mercenaries and black-market kits. Visitors are searched by the 'welcoming committee' before being taken to the mainland.",
			mp_wargames = "OSET Server Cluster 05\nPilot Certification Simulators are networked together for multi-Pilot training sessions. Using data gathered from previous defeats, this advanced IMC program seeks to push Pilots even further.",
			mp_rise = "Planet Gridiron, Wichita System\nMilitia forces have set up a reconnaissance outpost in an abandoned IMC reservoir. Gridiron lies on the inner edge of its star's habitable zone, but the star has since expanded, leaving its surface baked by solar radiation.",
			mp_boneyard = "Planet Leviathan, Badlands System\nMany years ago, the first Dog-Whistle Tower was built at this IMC facility, using ultrasonic frequencies to repel hostile wildlife. Its existence has since been purged from all written records.",
			mp_training_ground = "Planet Gridiron, Wichita System\nWith \"Only the Strong Survive\" as its slogan, this Pilot training regiment claims to have a 98 percent fatality rate - but that assumes their numbers are to be trusted. The IMC are well known for their propaganda.",
			mp_haven = "Planet Harmony, Freeport System\nThis luxury retreat for the wealthy was built on the edge of a massive crater lake. Many of its frequenters have stocks in defense contracting, and are very interested in seeing the Frontier's war continue.",
			mp_swampland = "Planet Calidus, Sector Delta-139\nDrainage operations have revealed ancient ruins of unknown origin. Vice Admiral Spyglass dispatches a team to investigate, at the request of the IMC's secretive Archeological Research Division...",
			mp_runoff = "Planet Calidus, Sector Delta-139\nOnce owned by a neutral terraforming company, the IMC has forcefully taken this water treatment facility. This world has been chosen as the new Fleet Operations Base for the IMC Navy following the Battle of Demeter.",
			mp_harmony_mines = "Planet Harmony, Freeport System\nEnergy-rich ores are extracted at this mining facility owned by Kodai Industries. Lithium, cobalt, and tungsten carbide are instrumental for the Frontier's war machine.",
			mp_corporate = "Northwestern continent, Planet Galen\nApplied Robotics labs on the Frontier, such as this one, developed the first automated infantry \"Spectre\" units. Hammond Robotics is an IMC Premier Technology Company, with many secrets being hidden under NDAs.",
			mp_lagoon = "Planet Navaria, Freeport System\nAn IMC carrier makes an emergency landing on a small fishing village, though it is unlikely they're here to ask the locals for directions.",
			mp_backwater = "Planet Angelis, Wichita System\nHigh in the mountains, ex-IMC pilot Barker and his cohort made a comfortable living producing moonshine in this hidden bootlegging colony - prior to his abduction in Angel City. It brings memories of Earth and other worlds that were left behind.",
			mp_switchback = "Planet Harmony, Freeport System\nSituated near a Kodai mining facility, this mountainside settlement is responsible for cheaply transporting goods and materials. It harkens back to the Gold Rush-era boomtowns of centuries prior.",
			mp_zone_18 = "Planet Cybele, Dakota System\nHidden in a vast wilderness, an abandoned IMC research facility has been reactivated after the destruction of Hammond Robotics' corporate HQ. Intel suggests a new Spectre model is being developed here."
			mp_sandtrap = "Midas, desert moon of Cybele\nBeyond the Frontier's established shipping lanes, this facility holds deep reservoirs of unrefined fuel. This fuel creates a negative energy density that satisfies the Einstein-Alcubierre metric, allowing for faster-than-light travel.",
			mp_box = "-LOCATION UNAVAILABLE-\nHammond Robotics' \"Dev-Box\" Environment was an early proof of concept for using VR in combat simulations. It is now used for debugging and stress testing new features.",
			mp_npe = "MCS Alexandria, en route to Horizon Station\nSimulation Training Pods are used for Pilot certification exams, though many have been cracked and distributed by criminal networks. Remember, piracy is a crime.",
			mp_nest2 = "Planet Meridian, Everglades System\nFollowing a massive data breach, IMC operatives must infiltrate one of their own facilities to destroy critical information related to Project PERISCOPE before it can be leaked.",
			mp_mia = "Southern continent, Planet Demeter\nA group of IMC and Militia forces make their last stand on the outskirts of Demeter, near the crash site of the IMS Rubicon. After several days of holding out in the desert, rescue teams have finally arrived.",
		}

		if ( mapName in customDescriptions ) {
			nextMapDesc.SetText( customDescriptions[mapName] )
		} else {
			nextMapDesc.SetText( GetMapDisplayDesc( mapName ) )
		}
	}
	if ( !IsPrivateMatch() )
	{
		file.starsLabel.Show()
		UpdateSelectedMapStarData( menu, mapName, "coop" )
	}

	// Update window scrolling if we highlight a map not in view
	local minScrollState = clamp( buttonID - (MAP_LIST_VISIBLE_ROWS - 1), 0, file.numMapButtonsOffScreen )
	local maxScrollState = clamp( buttonID, 0, file.numMapButtonsOffScreen )

	if ( file.mapListScrollState < minScrollState )
		file.mapListScrollState = minScrollState
	if ( file.mapListScrollState > maxScrollState )
		file.mapListScrollState = maxScrollState

	UpdateMapListScroll()
	delaythread( 0.02 ) UpdateMapButtonTooltip( button ) // Hacky delay needed or tooltip position will use the button position prior to scroll offset
}

function MapButton_LostFocus( button )
{
	HandleLockedCustomMenuItem( file.menu, button, [], true )
}

function MapButton_Activate( button )
{
	if ( button.IsLocked() )
	{
		if ( !IsDLCMapGroupEnabledForLocalPlayer( button.s.dlcGroup ) )
			ShowDLCStore()

		return
	}

	local mapsArray = GetPrivateMatchMaps()
	local mapID = button.GetScriptID().tointeger()
	local mapName = mapsArray[mapID]

	printt( mapName, mapID )

	SetCoopCreateAMatchMapname( mapName )

	ClientCommand( "SetCustomMap " + mapName )
	CloseTopMenu()
}

function MonitorDLCAvailability()
{
	EndSignal( uiGlobal.signalDummy, "OnCloseMapsMenu" )

	local available = [ null, null, null ]
	local lastAvailable = clone available
	local doUpdate

	while ( 1 )
	{
		doUpdate = false

		for ( local i = 0; i < 3; i++ )
		{
			available[i] = ServerHasDLCMapGroupEnabled( i + 1 ) // 1-3

			if ( available[i] != lastAvailable[i] )
			{
				lastAvailable[i] = available[i]
				doUpdate = true
			}
		}

		if ( doUpdate )
			UpdateDLCMapButtons()

		WaitFrameOrUntilLevelLoaded()
	}
}

function GetPrivateMatchMaps()
{
	local modeName = GetModeNameForEnum( level.ui.privatematch_mode )
	if ( modeName == "campaign_carousel" )
	{
		return [
			"mp_fracture",
			"mp_colony",
			"mp_relic",
			"mp_angel_city",
			"mp_outpost_207",
			"mp_boneyard",
			"mp_airbase",
			"mp_o2",
			"mp_corporate",
		]
	}

	local mapsArray = []
	mapsArray.resize( getconsttable().ePrivateMatchMaps.len() )

	foreach ( mapName, mapID in getconsttable().ePrivateMatchMaps )
		mapsArray[mapID] = mapName

	if ( modeName != VARIETY_PACK && modeName != "all_mini" )
		return mapsArray

	local supportedMaps = {}
	foreach ( combo in GetPlaylistCombos( modeName ) )
	{
		if ( !( combo.mapName in supportedMaps ) )
			supportedMaps[combo.mapName] <- true
	}

	local filteredMaps = []
	foreach ( mapName in mapsArray )
	{
		if ( mapName in supportedMaps )
			filteredMaps.append( mapName )
	}

	return filteredMaps
}

function OnMapListScrollUp_Activate(...)
{
	if( GetModeNameForEnum( level.ui.privatematch_mode ) == "campaign_carousel" )
		return

	file.mapListScrollState--
	if ( file.mapListScrollState < 0 )
		file.mapListScrollState = 0

	UpdateMapListScroll()
}

function OnMapListScrollDown_Activate(...)
{
	if( GetModeNameForEnum( level.ui.privatematch_mode ) == "campaign_carousel" )
		return

	file.mapListScrollState++
	if ( file.mapListScrollState > file.numMapButtonsOffScreen )
		file.mapListScrollState = file.numMapButtonsOffScreen

	UpdateMapListScroll()
}

function UpdateMapListScroll()
{
	local buttons = file.buttons
	local basePos = buttons[0].GetBasePos()
	local offset = buttons[0].GetHeight() * file.mapListScrollState

	buttons[0].SetPos( basePos[0], basePos[1] - offset )
}