utils = {}


-- Water tile lookup table for fast O(1) checking
utils.WaterTiles = {
	["water"] = true,
	["deepwater"] = true,
	["water-green"] = true,
	["water-shallow"] = true,
	["water-mud"] = true,
	["deepwater-green"] = true
}

utils.DeepWaterTiles = {
	["deepwater"] = true,
	["deepwater-green"] = true
}

-- Adjacent position offsets for 8-directional search
utils.AdjacentOffsets = {
	{x =  0, y = -1}, -- north
	{x =  1, y = -1}, -- northeast
	{x =  1, y =  0}, -- east
	{x =  1, y =  1}, -- southeast
	{x =  0, y =  1}, -- south
	{x = -1, y =  1}, -- southwest
	{x = -1, y =  0}, -- west
	{x = -1, y = -1}  -- northwest
}


function utils.IsWaterTile(tileName)
	return utils.WaterTiles[tileName] == true
end

function utils.GetWaterDepthType(fluidname)
	-- return "shallow" or "deep" or nil if not water tile
	if utils.IsWaterTile(fluidname) then
		if utils.DeepWaterTiles[fluidname] then
			return "deep"
		else
			return "shallow"
		end
	end
	return nil
end


utils.Oceans = {"Arctic","Atlantic","Indian","Pacific","Southern"}
utils.Lakes = {"Alakol","Albano","Albert","Alexandrina","Amadeus","Amatitlán","Apanás","Argyle","Assal","Athabasca","Atitlán","Baikal","Balaton","Balkhash","Bangweulu","Baringo","Biel","Big Stone ","Biwa","Bled","Bosumtwi","Bracciano","Bras d’Or ","Buir","Burragorang","Chad","Champlain","Chapala","Chelan","Chiemsee","Chilka ","Chilwa","Chiuta","Chott El-Chergui","Chott El-Hodna","Chott El-Jarid","Chott Melrhir","Chrissie","Chūzenji","Coeur d’Alene","Como","Constance","Crater","Cuitzeo","Derwent","Dhebar","Dian","Dongting","Earn","Edward","Elton","Er","Erie","Eucumbene","Eyasi","Eyre","Faguibine","Fingers","Flathead","Frome","Gairdner","Garda","Gatun","Geneva","George","Great ","Great Bear","Great Salt","Great Slave","Grevelingen","Guier","Ḥammār","Hawea","Hawr Al-Ḥabbāniyyah","Hongze","Hornindals","Hövsgöl","Hulun","Hume Reservoir","Huron","IJsselmeer","Iliamna","Ilmen","Ilopango","Inari","Iseo","Island","Izabal","Kainji","Kariba","Kawartha","Kentucky","Khanka","Kisale","Kivu","Koko Nor","Kolleru","Königssee","Kyoga","Lac Débo","Lac la Ronge","Lac Saint-Jean","Ladoga","Laguna de Bay","Lanao","Last Mountain","Lauricocha","Lesser Slave","Llanquihue","Loch Awe","Loch Katrine","Loch Leven","Loch Lomond","Loch Ness","Loch Shiel","Lough Allen","Lough Corrib","Lough Derg","Lough Erne","Lough Mask","Lough Neagh","Lough Ree","Lucerne","Lugano","Magadi","Maggiore","Mai-Ndombe","Mainit","Mälar","Malebo Pool","Malombe","Managua","Manapouri","Manitoba","Manyara","Mapam","Mar Chiquita","Mead","Melville","Memphremagog","Menindee","Michigan","Mistassini","Mjøsa","Montenegro","Moosehead","Muskoka","Mweru","Mývatn","Nahuel Huapí","Naivasha","Nakuru","Näsi","Nasser","Natron","Naujan","Nemi","Neuchâtel","Neusiedler","Ngami","Nicaragua","Nipigon","Nipissing","Nyasa","Ohrid","Okeechobee","Onega","Ontario","Orta","Päijänne","Peipus","Pend Oreille","Petén Itzá","Pielinen","Pontchartrain","Poopó","Poyang","Prespa","Pukaki","Pulicat","Pyramid","Rainy","Rangeley","Reelfoot","Reindeer","River Tummel","Rotorua","Rudolf","Rukwa","Saimaa","Saint Clair","Sambhar Salt","Saranac","Scutari","Sea of Galilee","Sevan","Sevier","Shala","Siljan","Simcoe","Soap","Soda","Štrbské Pleso","Superior","Taal","Tahoe","Tai","Tana","Tanganyika","Taupo","Te Anau","Tegernsee","Tekapo","Tengiz","Teshekpuk","Texcoco","Thingvalla","Titicaca","Toba","Todos los Santos","Tonle Sap","Torrens","Towada","Trasimeno","Tumba","Tuz","Tyers","Tyri","Tyrrell","Ullswater","Urmia","Utah","Valencia","Van","Väner","Vätter","Victoria","Volta","Võrtsjärv","Waikaremoana","Wakatipu","Wanaka","Windermere","Winnipeg","Winnipegosis","Winnipesaukee","Wissel","Wollaston","Wular","Yellowstone","Yojoa","Ysyk","Zaysan","Zürich"}
utils.Seas = {"Adriatic","Aegean","Albemarle Sound","Alboran","Amundsen","Amundsen Gulf","Andaman","Arabian","Arafura","Archipelago","Arctic Ocean","Argentine","Argolic Gulf","Baffin Bay","Balearic","Bali","Baltic","Banda","Barents","Bass Strait","Bay of Bengal","Bay of Biscay","Bay of Campeche","Bay of Fundy","Beaufort","Bellingshausen","Bering","Bismarck","Black","Block Island Sound","Bohai","Bohol","Bothnian","Buzzards Bay","Camotes","Cantabrian","Cape Cod Bay","Caribbean","Celebes","Celtic","Central Baltic","Ceram","Chesapeake Bay","Chilean","Chukchi","Cilician","Cooperation","Coral","Cosmonauts","Davis","Davis Strait","Delaware Bay","Denmark Strait","Dering Harbor","Drake Passage","D'Urville","East China","East Siberian","English Channel","Fishers Island Sound","Flanders Bay","Flore","Florida Bay","Fort Pond Bay","Gardiners Bay","Golfo de los Mosquitos","Great Australian Bight","Greenland","Gulf of Aden","Gulf of Alaska","Gulf of Carpentaria","Gulf of Corinth","Gulf of Darién","Gulf of Genoa","Gulf of Gonâve","Gulf of Guinea","Gulf of Honduras","Gulf of Lion","Gulf of Maine","Gulf of Martaban","Gulf of Mexico","Gulf of Oman","Gulf of Paria","Gulf of Riga","Gulf of Sidra","Gulf of St. Lawrence","Gulf of Thailand","Gulf of Venezuela","Gulf St Vincent","Halmahera","Hudson Bay","Hudson Strait","Icarian","Inland","Investigator Strait","Ionian","Irish","Irminger","Jamaica Bay","James Bay","Java","Kara","King Haakon VII","Koro","Labrador","Laccadive","Laptev","Lazarev","Levantine","Libyan","Ligurian","Lincoln","Long Beach Bay","Long Island Sound","Lower New York Bay","Mar de Grau","Massachusetts Bay","Mawson","Mediterranean","Mobile Bay","Molucca","Mozambique Channel","Myrtoan","Nantucket Sound","Napeague Bay","Narragansett Bay","New York Bay","North","North  Harbor","North Euboean Gulf","Norwegian","Noyack Bay","Oresund Strait","Pamlico Sound","Pechora","Peconic Bay","Pensacola Bay","Persian Gulf","Philippine","Pipes Cove","Prince Gustav Adolf","Queen Victoria","Raritan Bay","Red","Rhode Island Sound","Riiser-Larsen","Ross","Sag Harbor Bay","Salish","Sandy Hook Bay","Saronic Gulf","Savu","Scotia","Seto Inland","Shelter Island Sound","Sibuyan","Solomon","Somov","South China","South Euboean Gulf","Southold Bay","Spencer Gulf","Sulu","Tampa Bay","Tasman","The Northwest Passages","Thermaic Gulf","Thracian","Three Mile Harbor","Timor","Tobaccolot Bay","Tyrrhenian","Upper New York Bay","Vermillion Bay","Vineyard Sound","Visayan","Wadden","Wandel","Weddell","White","Yellow"}

utils.WaterBodyTypesToName = {
	[0] = "Puddle",
	[1] = "Well",
	[2] = "Pond",
	[3] = "Lake",
	[4] = "Great Lake",
	[5] = "Sea",
	[6] = "Ocean"
}

utils.WaterBodyTypeToWaterBonusValue = {
	[0] = 0.01,
	[1] = 0.5,
	[2] = 1,
	[3] = 1.5,
	[4] = 2,
	[5] = 2.5,
	[6] = 3
}

-- max area of water body, has to strictly increase
utils.WaterBodyTypeThresholdArea = {
	[0] = 3,
	[1] = 4,
	[2] = 200,
	[3] = 6000,
	[4] = 60000,
	[5] = 600000,
	[6] = math.huge
}

utils.WaterBodyTypeToNamesCollection = {
	[3] = utils.Lakes,
	[4] = utils.Lakes,
	[5] = utils.Seas,
	[6] = utils.Oceans
}

--local WaterBodyType = storage.WaterGlobalArea[a]["WaterBodyType"]
function utils.GetWaterBodyName(WaterBodyType) --Random Name Function

	local nameSuffix = utils.WaterBodyTypesToName[WaterBodyType]
	--check whether we have name collection for this water body type
	if utils.WaterBodyTypeToNamesCollection[WaterBodyType] ~= nil then
		local randAmount = #utils.WaterBodyTypeToNamesCollection[WaterBodyType]
		local rand = math.random(1,randAmount)
		local name = utils.WaterBodyTypeToNamesCollection[WaterBodyType][rand]
			.. nameSuffix
		return name
	end

	return nameSuffix

end

-- for reference
-- function CreateWaterArea()
-- 	storage.WaterGlobalArea[#storage.WaterGlobalArea+1] = {["WGAID"] = 0, ["WtrName"] = "None",["Surface"] = nil, ["ToSearch"] = nil, ["HasSearched"] = nil,["LoopCount"] = 0, ["AmountWtr"] = 0,["AmountBonusValue"] = 0,["RegenAmount"] = 0,["Depleted"] = 0,["ShallowWater"] = 0, ["DeepWater"] = 0,["ShallowWater-Shallow"] = 0,["ShallowWater-Mud"] = 0,["Percent"] = 0,["PercentPrev"] = 0,["Fired50"] = false, ["Fired75"] = false, ["Fired90"] = false, ["Fired95"] = false, ["Fired97"] = false,["Fired98"] = false,["Fired99"] = false,["RandPercent"] = 79, ["BTF"] = 0,["BTFE"] = 0,["Below80"] = 0, ["WaterRepArea"] = {},["WaterEdgeArea"] = {},["WaterEdgeGrid"] = {},["WaterEdgeAreaY"] = {},["WaterEdgeAreaX"] = {},["MinX"] = 0, ["MaxX"] = 0, ["MinY"] = 0, ["MaxY"] = 0, ["Hdif"] = 0, ["Vdif"] = 0, ["Hyp"] = 0, ["TilesSet"] = "N",["OPs"] = {},["OPsA"] = {},["ODs"] = {}, ["ODsA"] = {}, ["WtrUsed"] = 0,["WtrAdd"] = {}, ["WaterBodyType"] = 0, ["FluidType"] = nil, ["MapMarker"] = {}, ["MapMarkerPlaced"] = false, ["TechYRBoost"] = 1}
-- 	a = #storage.WaterGlobalArea
-- 	storage.WGAID = storage.WGAID + 1
-- 	storage.WaterGlobalArea[a]["WGAID"] = storage.WGAID
-- 	GetWaterArea(a)
-- 	CalculatedWaterTotal(a)
-- 	if storage.WaterGlobalArea[a]["ToSearch"] == nil then
-- 		if storage.WaterGlobalArea[a]["WtrName"] == "None" or storage.WaterGlobalArea[a]["WtrName"] == "Puddle" or storage.WaterGlobalArea[a]["WtrName"] == "Well" or storage.WaterGlobalArea[a]["WtrName"] == "Pond"  then
-- 			waterbodies.WtrName(a)
-- 		end
-- 		game.print(string.format("%s created, with %sL of %s with regen %sL.", storage.WaterGlobalArea[a]["WtrName"], comma_value(storage.WaterGlobalArea[a]["AmountWtr"]), storage.WaterGlobalArea[a]["FluidType"], storage.WaterGlobalArea[a]["RegenAmount"]))
-- 	end
-- 	MapMarkerPlace(a)
-- 	a = 0
-- end


function utils.InitWaterBody(
	surfaceId,
	waterBodyType,
	waterBodyName,
	amountWtr,
	amountBonusValue,
	regenAmount,
	shallowWater,
	shallowWaterShallow,
	shallowWaterMud,
	deepWater,
	searchData,
	mapMarker,
	mapMarkerPlaced,
	techYRBoost,

	totalArea

)
	return {
		surfaceId = surfaceId or nil,
		waterBodyType = waterBodyType or nil,
		waterBodyName = waterBodyName or nil,
		AmountWtr = amountWtr or 0,
		AmountBonusValue = amountBonusValue or 0,
		RegenAmount = regenAmount or 0,
		["ShallowWater"] = shallowWater or 0,
		["ShallowWater-Shallow"] = shallowWaterShallow or 0,
		["ShallowWater-Mud"] = shallowWaterMud or 0,
		["DeepWater"] = deepWater or 0,
		searchData = searchData or utils.InitSearchData(),
		mapMarker = mapMarker or nil,
		mapMarkerPlaced = mapMarkerPlaced or false,
		techYRBoost = techYRBoost or 1.0,
		TotalArea = totalArea or 0,

	}
end


utils.WaterBodyTileTypesToAmountWaterTypes = {
	["ShallowWater"] = "TileFluidAmount-Shallow",
	["DeepWater"] = "TileFluidAmount-Deep",
	["ShallowWater-Shallow"] = "TileFluidAmount-Shallow",
	["ShallowWater-Mud"] = "TileFluidAmount-Shallow"
}

utils.WaterBodyTileTypesToAmountWaterMultiplier = {
	["ShallowWater"] = 1,
	["DeepWater"] = 1,
	["ShallowWater-Shallow"] = 0.5,
	["ShallowWater-Mud"] = 0.25
}

function utils.GetAmountWaterForTileType(tileType)
	return settings.global[utils.WaterBodyTileTypesToAmountWaterTypes[tileType]].value
end

function utils.CalculateWaterBodyTotalAreaAndWater(waterBody)
	local totalArea = 0
	local totalWater = 0
	for tileType, multiplier in pairs(utils.WaterBodyTileTypesToAmountWaterMultiplier) do
		local amount = waterBody[tileType]
		if amount ~= nil then
			totalArea = totalArea + amount
			totalWater = totalWater + amount * utils.GetAmountWaterForTileType(tileType) * multiplier
		end
	end
	return totalArea, totalWater
end

function utils.GetWaterBodyType(totalArea)
	for waterBodyType, thresholdArea in pairs(utils.WaterBodyTypeThresholdArea) do
		if totalArea < thresholdArea then
			return waterBodyType
		end
	end
end

function utils.GetWaterBodyRegen(totalArea)
	local regenOff = settings.global["Disable-FluidArea-RegenRate"].value
	if regenOff == false then
		local regenRate = settings.global["FluidArea-RegenRate"].value / 10000
		return regenRate * totalArea
	else
		return 0
	end
end

function utils.CalculateWaterBodyType(waterBody)
	
	local totalArea, totalWater = utils.CalculateWaterBodyTotalAreaAndWater(waterBody)
	local waterBodyType = utils.GetWaterBodyType(totalArea)
	
	local amountWater = totalWater * utils.WaterBodyTypeToWaterBonusValue[waterBodyType]

	local regenAmount = utils.GetWaterBodyRegen(totalArea)

	-- TODO update or create water body


end



function utils.ReadWaterBodyData(WaterBodyId, Key)
	return storage.WaterGlobalArea[WaterBodyId][Key]
end

function utils.WriteWaterBodyData(WaterBodyId, Key, Value)
	storage.WaterGlobalArea[WaterBodyId][Key] = Value
end

function utils.PositionToString (position)
	return string.format ("%.1f , %.1f", position.x , position.y)	-- Print SearchPosition X, Y CoOrds as String
end


function utils.GetSurface(surfaceId)
	return game.surfaces[surfaceId]
end

function utils.GetTile(position, surfaceId)
	return utils.GetSurface(surfaceId).get_tile(position.x, position.y)
end

function utils.IsThereWater(position, surfaceId)
	local tile = utils.GetTile(position, surfaceId)
	if tile.valid == true then
		return utils.WaterTiles[tile.name] == true
	else
		-- shouldn't happen so show warning
		game.print("Invalid Tile")
		return false
	end
end

function utils.InitPlayerForces(name)
	return {
		name = name,
		water_yield_regen_boost = 1.0,
	}
end

function utils.InitSearchData()
	return {
		searchQueue = {},
		searched = {},
		edgeGrid = {}
	}
end

function utils.EdgePattern(searchPosition, surfaceId, searchData)
	local edgeFound = false
	
	-- Check all 8 adjacent positions using shared offsets
	for _, offset in pairs(utils.AdjacentOffsets) do
		local position = {x = searchPosition.x + offset.x, y = searchPosition.y + offset.y}
		local gridKey = utils.PositionToString(position)
		
		if not searchData.searched[gridKey] then
			local tile = utils.GetTile(position, surfaceId)
			if tile.valid then
				if utils.IsWaterTile(tile.name) then
					-- Water tile: add to search queue
					searchData.searchQueue[#searchData.searchQueue + 1] = {x = tile.position.x, y = tile.position.y}
				else
					-- Non-water tile: mark as edge using actual tile position
					local edgePosition = {x = tile.position.x, y = tile.position.y}
					local edgeKey = utils.PositionToString(edgePosition)
					searchData.searched[edgeKey] = true
					searchData.edgeGrid[edgeKey] = true
					edgeFound = true
				end
			end
		end
	end
	
	return edgeFound
end

utils.TechYieldRegenBoostName = "waar-yield-regen-boost-"
utils.TechYieldRegenBoostLevels = {
	[1] = 1.2,
	[2] = 1.4,
	[3] = 1.6,
	[4] = 1.8,
	[5] = 2.0
}


function utils.CheckSubstring(string, substring)
	return string.find(string, substring, 1, true) ~= nil
end

function utils.RemovePrefix(string, prefix)
	return string.sub(string, #prefix + 1)
end

function utils.GetMaxKey(table)
	local maxKey = 0
	for key, _ in pairs(table) do
		if key > maxKey then
			maxKey = key
		end
	end
end

utils.TechYieldRegenBoostLevelInfiniteBoost = 0.2

function utils.GetTechYRBoost(research_name, research_level)
	if utils.CheckSubstring(research_name, utils.TechYieldRegenBoostName) then
		local maxLevel = utils.GetMaxKey(utils.TechYieldRegenBoostLevels)
		local boostLevel = tonumber(utils.RemovePrefix(research_name, utils.TechYieldRegenBoostName))
		
		local boost = 1.0
		if boostLevel > maxLevel then
			boost = utils.TechYieldRegenBoostLevels[maxLevel] + (utils.TechYieldRegenBoostLevelInfiniteBoost * (research_level - maxLevel))
		else
			boost = utils.TechYieldRegenBoostLevels[boostLevel]
		end
		return boost
	end
	return nil
end


function utils.UpdateForceTechYRBoost(force_name, research_name, research_level)
	local boost = utils.GetTechYRBoost(research_name, research_level)
	if boost ~= nil then
		-- TODO: Update force tech yield regen boost
	end
end