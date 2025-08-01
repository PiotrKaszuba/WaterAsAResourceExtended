require("modules.utils")

waterbodies = {}

function waterbodies.initWaterBodiesAndTiles()
    if storage.WaterBodies == nil then
        storage.WaterBodies = {}
		storage.NextWaterBodyId = 1
		storage.ValidWaterBodies = {} -- waterBodyId -> true
    end
    if storage.WaterTiles == nil then
        storage.WaterTiles = {} -- surfaceId -> gridKey -> waterBodyId
    end
end

function waterbodies.getValidWaterBodies()
    return storage.ValidWaterBodies
end

function waterbodies.initSurface(surfaceId)
    if storage.WaterTiles[surfaceId] == nil then
        storage.WaterTiles[surfaceId] = {} -- gridKey -> waterBodyId
    end
end

function waterbodies.getSurfaceMaxWaterbodies()
	return settings.startup["Surface-Max-Waterbodies"].value
end

function waterbodies.getMaxWaterBodySize()
    return settings.global["FluidArea-MaxFluidAreaSize"].value
end


-- optional waterBodyId argument to link to a water body
-- if not present use as waterbodies.addNewWaterTile(position, surfaceId, -1)
function waterbodies.addNewWaterTile(gridKey, surfaceId, waterBodyId)
    waterbodies.initSurface(surfaceId)

    storage.WaterTiles[surfaceId][gridKey] = waterBodyId or -1
end

function waterbodies.getWaterTile(gridKey, surfaceId)
    waterbodies.initSurface(surfaceId)
    return storage.WaterTiles[surfaceId][gridKey]
end

function waterbodies.checkIfWaterTileExists(gridKey, surfaceId)
    return waterbodies.getWaterTile(gridKey, surfaceId) ~= nil
end

function waterbodies.checkIfTileIsNotAssignedToWaterBody(gridKey, surfaceId)
    local waterBodyId = waterbodies.getWaterTile(gridKey, surfaceId)
    if waterBodyId == nil or waterBodyId == -1 then
		return true
	end
	local waterBody = waterbodies.getWaterBody(waterBodyId)
	if waterBody and waterBody.valid then
		return false
	end
	return true
end

function waterbodies.getWaterTilePercentageWaterUsed(gridKey, surfaceId)
	local waterBodyId = waterbodies.getWaterTile(gridKey, surfaceId)
	if waterBodyId == nil or waterBodyId == -1 then
		return 0
	end
	local waterBody = waterbodies.getWaterBody(waterBodyId)
	if waterBody and waterBody.valid == false then
		return waterBody.PercentageWaterUsed
	end
	return 0
end

function waterbodies.getNextFreeWaterBodyId()
    local waterBodyId = storage.NextWaterBodyId
    while storage.WaterBodies[waterBodyId] ~= nil do
        waterBodyId = waterBodyId + 1
    end
	storage.NextWaterBodyId = waterBodyId + 1
    return waterBodyId
end

function waterbodies.addNewWaterBodyAndSetId(waterBody)
    local waterBodyId = waterbodies.getNextFreeWaterBodyId()
    storage.WaterBodies[waterBodyId] = waterBody
    waterBody.waterBodyId = waterBodyId
	storage.ValidWaterBodies[waterBodyId] = true
    return waterBodyId
end

function waterbodies.getWaterBody(waterBodyId)
	if waterBodyId == nil then
		return nil
	end
    return storage.WaterBodies[waterBodyId]
end

function waterbodies.checkWaterBodyExists(waterBodyId)
	if waterBodyId == nil then
		return false
	end
    return storage.WaterBodies[waterBodyId] ~= nil
end


function waterbodies.getWaterAreaArray(waterBody)
    local waterArea = {}
    for _, tileData in pairs(waterBody.gridsData.waterGridWithData) do
        waterArea[#waterArea + 1] = tileData
    end
    return waterArea
end

function waterbodies.addTileToWaterGrid(waterBody, position, tileName)
    local gridKey = utils.PositionToString(position)
    waterBody.gridsData.waterGridWithData[gridKey] = {
        name = tileName,
        position = position,
        originalName = tileName
    }
end

function waterbodies.removeTileFromWaterGrid(waterBody, gridKey)
    waterBody.gridsData.waterGridWithData[gridKey] = nil
end

function waterbodies.InitSearchData()
	return {
		searchQueue = utils.Queue:new(),
		searchedPositions = {}, -- indicator table, position key
		totalArea = 0,
		finished = false,
	}
end

function waterbodies.initGridsData()
	return {
		waterGridWithData = {}, -- table with position, name, originalName for tiles, also used as indicator table, position key
		edgeGrid = {}, -- indicator table, position key
	}
end

function waterbodies.initEntitiesData()
	return {
		pumps = {}, -- unit_number -> true -> indicator table for pumps - get pump in entities.getTrackedEntity(unit_number)
		forces = {}, -- indicator table that stores force name -> true
	}
end

function waterbodies.initShapeData()
    return {
        ["MinX"] = 0,
        ["MaxX"] = 0,
        ["MinY"] = 0,
        ["MaxY"] = 0,
        ["Hdif"] = 0,
        ["Vdif"] = 0,     
		["Hyp"] = 0,
    }
end

function waterbodies.initWaterBodyTileCountData()
    return {
        ["ShallowWater"] = 0,
        ["DeepWater"] = 0,
        ["ShallowWater-Shallow"] = 0,
        ["ShallowWater-Mud"] = 0,
    }   
end

function waterbodies.initWaterAreaData()
    return {
		["ToCalculate"] = true,
        ["WaterBodyType"] = 0,
        ["BonusValue"] = 0,
        ["AmountWtr"] = 0,
        ["RegenAmount"] = 0,
        ["TotalArea"] = 0,
    }
end

function waterbodies.initWaterUsageTickStats()
	local waterUsageTickStats = {}
	local numTicks = storage.LoopNumTicks

	for i = 1, numTicks do
		waterUsageTickStats[i] = 0
	end

	return waterUsageTickStats
end


function waterbodies.initWaterBodyStateData()
    return {
        ["WaterUsed"] = 0,	-- the actual water used synchronized on 'big updates'
        ["WaterUsedPrev"] = 0,	-- the actual water used on the previous 'big update'

		["TempAvailableWater"] = 0,	-- the available water that can be used before the next 'big update' 
		["TempUsedWater"] = 0,	-- the water used since the last 'big update' - used for small updates - if >= TempAvailableWater - the water body is depleted and triggers instant update

		
		["WaterUsedPenalty"] = 0,	-- the water used penalty that is applied to the water body - it occurs when waterbody is created on the water tiles that had been used in previous waterbody depleted to some extent

		["WaterUsedPenaltyRestored"] = 0,	-- the restored water (above WaterUsed) that can negate the WaterUsedPenalty (up to that amount)


        ["Depleted"] = false,	-- if true - the water body is depleted and all pumps are deactivated
		
		-- alarm flags
		["Fired50"] = false,
		["Fired75"] = false,
		["Fired90"] = false,
		["Fired95"] = false,
		["Fired97"] = false,
		["Fired98"] = false,
		["Fired99"] = false,

		["FiredCreated"] = false, -- if true - the water body was created and the message was already sent to the players

		["DriedTiles"] = 0, -- the current number of tiles that are dried - used for gradual depletion appearance

		["ScanLoopCount"] = 0,  -- the number of big updates since started scanning
		["OrphanedBigUpdateCount"] = 0, -- the number of big updates since the water body was orphaned

		-- TODO: create class for map marker that will handle all the map marker logic
		-- and have .destroy() ethod
        ["MapMarkers"] = {},
    }
end

-- TODO: port more params from above
-- IDEA: make them separate 'structures' such as SearchData, TileData, MapMarker, WaterBodyState (for changing values such as depleted), AlarmData, PositionData (minX, maxX, minY, maxY) etc.
function waterbodies.InitWaterBody(
    surfaceId,
	waterAreaData,
	gridsData,
	entitiesData,

    waterBodyShapeData,
    waterBodyTileCountData,
	searchData,
	waterBodyStateData,

    waterBodyId,
    waterBodyName

)
	return {
		valid = true, -- if false, the water body is not valid and should be deleted

        surfaceId = surfaceId or nil,
        waterBodyId = waterBodyId or nil,
        waterBodyName = waterBodyName or nil,

		waterAreaData = waterAreaData or waterbodies.initWaterAreaData(),
		gridsData = gridsData or waterbodies.initGridsData(),
		entitiesData = entitiesData or waterbodies.initEntitiesData(),
		waterBodyShapeData = waterBodyShapeData or waterbodies.initShapeData(),
		waterBodyTileCountData = waterBodyTileCountData or waterbodies.initWaterBodyTileCountData(),
		searchData = searchData or waterbodies.InitSearchData(),
		waterBodyStateData = waterBodyStateData or waterbodies.initWaterBodyStateData(),

		waterBodyTileCountPercentagePenalty = waterbodies.initWaterBodyTileCountData(),
		waterUsageTickStats = waterbodies.initWaterUsageTickStats(),


	}
end

function waterbodies.simpleInitWaterBody(surfaceId)
	return waterbodies.InitWaterBody(surfaceId, nil, nil, nil, nil, nil, nil, nil, nil)
end


function waterbodies.isWaterBodyEmpty(waterBody)
    for _, count in pairs(waterBody.waterBodyTileCountData) do
        if count > 0 then
            return false
        end
    end
    return true
end

function waterbodies.isWaterBodyOrphaned(waterBody)
    local hasPumps = next(waterBody.entitiesData.pumps) ~= nil
    return not hasPumps
end

function waterbodies.updateWaterBodyForces(waterBody)
    waterBody.entitiesData.forces = {}
    for _, pump_data in pairs(waterBody.entitiesData.pumps) do
        waterBody.entitiesData.forces[pump_data.force] = true
    end
end

waterbodies.Oceans = {"Arctic","Atlantic","Indian","Pacific","Southern"}
waterbodies.Lakes = {"Alakol","Albano","Albert","Alexandrina","Amadeus","Amatitlán","Apanás","Argyle","Assal","Athabasca","Atitlán","Baikal","Balaton","Balkhash","Bangweulu","Baringo","Biel","Big Stone ","Biwa","Bled","Bosumtwi","Bracciano","Bras d’Or ","Buir","Burragorang","Chad","Champlain","Chapala","Chelan","Chiemsee","Chilka ","Chilwa","Chiuta","Chott El-Chergui","Chott El-Hodna","Chott El-Jarid","Chott Melrhir","Chrissie","Chūzenji","Coeur d’Alene","Como","Constance","Crater","Cuitzeo","Derwent","Dhebar","Dian","Dongting","Earn","Edward","Elton","Er","Erie","Eucumbene","Eyasi","Eyre","Faguibine","Fingers","Flathead","Frome","Gairdner","Garda","Gatun","Geneva","George","Great ","Great Bear","Great Salt","Great Slave","Grevelingen","Guier","Ḥammār","Hawea","Hawr Al-Ḥabbāniyyah","Hongze","Hornindals","Hövsgöl","Hulun","Hume Reservoir","Huron","IJsselmeer","Iliamna","Ilmen","Ilopango","Inari","Iseo","Island","Izabal","Kainji","Kariba","Kawartha","Kentucky","Khanka","Kisale","Kivu","Koko Nor","Kolleru","Königssee","Kyoga","Lac Débo","Lac la Ronge","Lac Saint-Jean","Ladoga","Laguna de Bay","Lanao","Last Mountain","Lauricocha","Lesser Slave","Llanquihue","Loch Awe","Loch Katrine","Loch Leven","Loch Lomond","Loch Ness","Loch Shiel","Lough Allen","Lough Corrib","Lough Derg","Lough Erne","Lough Mask","Lough Neagh","Lough Ree","Lucerne","Lugano","Magadi","Maggiore","Mai-Ndombe","Mainit","Mälar","Malebo Pool","Malombe","Managua","Manapouri","Manitoba","Manyara","Mapam","Mar Chiquita","Mead","Melville","Memphremagog","Menindee","Michigan","Mistassini","Mjøsa","Montenegro","Moosehead","Muskoka","Mweru","Mývatn","Nahuel Huapí","Naivasha","Nakuru","Näsi","Nasser","Natron","Naujan","Nemi","Neuchâtel","Neusiedler","Ngami","Nicaragua","Nipigon","Nipissing","Nyasa","Ohrid","Okeechobee","Onega","Ontario","Orta","Päijänne","Peipus","Pend Oreille","Petén Itzá","Pielinen","Pontchartrain","Poopó","Poyang","Prespa","Pukaki","Pulicat","Pyramid","Rainy","Rangeley","Reelfoot","Reindeer","River Tummel","Rotorua","Rudolf","Rukwa","Saimaa","Saint Clair","Sambhar Salt","Saranac","Scutari","Sea of Galilee","Sevan","Sevier","Shala","Siljan","Simcoe","Soap","Soda","Štrbské Pleso","Superior","Taal","Tahoe","Tai","Tana","Tanganyika","Taupo","Te Anau","Tegernsee","Tekapo","Tengiz","Teshekpuk","Texcoco","Thingvalla","Titicaca","Toba","Todos los Santos","Tonle Sap","Torrens","Towada","Trasimeno","Tumba","Tuz","Tyers","Tyri","Tyrrell","Ullswater","Urmia","Utah","Valencia","Van","Väner","Vätter","Victoria","Volta","Võrtsjärv","Waikaremoana","Wakatipu","Wanaka","Windermere","Winnipeg","Winnipegosis","Winnipesaukee","Wissel","Wollaston","Wular","Yellowstone","Yojoa","Ysyk","Zaysan","Zürich"}
waterbodies.Seas = {"Adriatic","Aegean","Albemarle Sound","Alboran","Amundsen","Amundsen Gulf","Andaman","Arabian","Arafura","Archipelago","Arctic Ocean","Argentine","Argolic Gulf","Baffin Bay","Balearic","Bali","Baltic","Banda","Barents","Bass Strait","Bay of Bengal","Bay of Biscay","Bay of Campeche","Bay of Fundy","Beaufort","Bellingshausen","Bering","Bismarck","Black","Block Island Sound","Bohai","Bohol","Bothnian","Buzzards Bay","Camotes","Cantabrian","Cape Cod Bay","Caribbean","Celebes","Celtic","Central Baltic","Ceram","Chesapeake Bay","Chilean","Chukchi","Cilician","Cooperation","Coral","Cosmonauts","Davis","Davis Strait","Delaware Bay","Denmark Strait","Dering Harbor","Drake Passage","D'Urville","East China","East Siberian","English Channel","Fishers Island Sound","Flanders Bay","Flore","Florida Bay","Fort Pond Bay","Gardiners Bay","Golfo de los Mosquitos","Great Australian Bight","Greenland","Gulf of Aden","Gulf of Alaska","Gulf of Carpentaria","Gulf of Corinth","Gulf of Darién","Gulf of Genoa","Gulf of Gonâve","Gulf of Guinea","Gulf of Honduras","Gulf of Lion","Gulf of Maine","Gulf of Martaban","Gulf of Mexico","Gulf of Oman","Gulf of Paria","Gulf of Riga","Gulf of Sidra","Gulf of St. Lawrence","Gulf of Thailand","Gulf of Venezuela","Gulf St Vincent","Halmahera","Hudson Bay","Hudson Strait","Icarian","Inland","Investigator Strait","Ionian","Irish","Irminger","Jamaica Bay","James Bay","Java","Kara","King Haakon VII","Koro","Labrador","Laccadive","Laptev","Lazarev","Levantine","Libyan","Ligurian","Lincoln","Long Beach Bay","Long Island Sound","Lower New York Bay","Mar de Grau","Massachusetts Bay","Mawson","Mediterranean","Mobile Bay","Molucca","Mozambique Channel","Myrtoan","Nantucket Sound","Napeague Bay","Narragansett Bay","New York Bay","North","North  Harbor","North Euboean Gulf","Norwegian","Noyack Bay","Oresund Strait","Pamlico Sound","Pechora","Peconic Bay","Pensacola Bay","Persian Gulf","Philippine","Pipes Cove","Prince Gustav Adolf","Queen Victoria","Raritan Bay","Red","Rhode Island Sound","Riiser-Larsen","Ross","Sag Harbor Bay","Salish","Sandy Hook Bay","Saronic Gulf","Savu","Scotia","Seto Inland","Shelter Island Sound","Sibuyan","Solomon","Somov","South China","South Euboean Gulf","Southold Bay","Spencer Gulf","Sulu","Tampa Bay","Tasman","The Northwest Passages","Thermaic Gulf","Thracian","Three Mile Harbor","Timor","Tobaccolot Bay","Tyrrhenian","Upper New York Bay","Vermillion Bay","Vineyard Sound","Visayan","Wadden","Wandel","Weddell","White","Yellow"}

waterbodies.WaterBodyTypesToName = {
	[0] = "Puddle",
	[1] = "Well",
	[2] = "Pond",
	[3] = "Lake",
	[4] = "Great Lake",
	[5] = "Sea",
	[6] = "Ocean"
}

waterbodies.WaterBodyTypeToWaterBonusValue = {
	[0] = 0.01,
	[1] = 0.5,
	[2] = 1,
	[3] = 1.5,
	[4] = 2,
	[5] = 2.5,
	[6] = 3
}

-- max area of water body, has to strictly increase
waterbodies.WaterBodyTypeThresholdArea = {
	[0] = 3,
	[1] = 4,
	[2] = 200,
	[3] = 6000,
	[4] = 60000,
	[5] = 600000,
	[6] = math.huge
}

waterbodies.WaterBodyTypeToNamesCollection = {
	[3] = waterbodies.Lakes,
	[4] = waterbodies.Lakes,
	[5] = waterbodies.Seas,
	[6] = waterbodies.Oceans
}

--local WaterBodyType = storage.WaterGlobalArea[a]["WaterBodyType"]
function waterbodies.GenerateWaterBodyName(WaterBodyType) --Random Name Function

	local nameSuffix = waterbodies.WaterBodyTypesToName[WaterBodyType]
	--check whether we have name collection for this water body type
	if waterbodies.WaterBodyTypeToNamesCollection[WaterBodyType] ~= nil then
		local randAmount = #waterbodies.WaterBodyTypeToNamesCollection[WaterBodyType]
		local rand = math.random(1,randAmount)
		local name = waterbodies.WaterBodyTypeToNamesCollection[WaterBodyType][rand]
			.. nameSuffix
		return name
	end

	return nameSuffix

end


waterbodies.WaterBodyTileTypesToAmountWaterTypes = {
	["ShallowWater"] = "TileFluidAmount-Shallow",
	["DeepWater"] = "TileFluidAmount-Deep",
	["ShallowWater-Shallow"] = "TileFluidAmount-Shallow",
	["ShallowWater-Mud"] = "TileFluidAmount-Shallow"
}

waterbodies.WaterBodyTileTypesToAmountWaterMultiplier = {
	["ShallowWater"] = 1,
	["DeepWater"] = 1,
	["ShallowWater-Shallow"] = 0.5,
	["ShallowWater-Mud"] = 0.25
}

waterbodies.WaterTileToWaterBodyTileType = {
	["water"] = "ShallowWater",
	["water-green"] = "ShallowWater",
	["water-shallow"] = "ShallowWater-Shallow",
	["water-mud"] = "ShallowWater-Mud",
	["deepwater"] = "DeepWater",
	["deepwater-green"] = "DeepWater",
}

waterbodies.EdgeTileNameMap = {
	["water"] = "lake-shallow",
	["water-green"] = "lake-shallow",
	["water-shallow"] = "lake-shallow",
	["water-mud"] = "lake-shallow",
	["deepwater"] = "lake-deep",
	["deepwater-green"] = "lake-deep",
}

function waterbodies.GetAmountWaterForWaterBodyTileType(tileType, include_multiplier)
	local multiplier = include_multiplier and waterbodies.WaterBodyTileTypesToAmountWaterMultiplier[tileType] or 1
	return settings.global[waterbodies.WaterBodyTileTypesToAmountWaterTypes[tileType]].value * multiplier
end


function waterbodies.CalculateWaterBodyTotalAreaAndWater(waterBody)
	local totalArea = 0
	local totalWater = 0
	local penaltyWaterUsed = 0
	for tileType, multiplier in pairs(waterbodies.WaterBodyTileTypesToAmountWaterMultiplier) do
		local amount = waterBody.waterBodyTileCountData[tileType]
		if amount ~= nil then
			totalArea = totalArea + amount
			local amountWater = amount * waterbodies.GetAmountWaterForWaterBodyTileType(tileType) * multiplier
			totalWater = totalWater + amountWater
		end
		local penalty_amount = waterBody.waterBodyTileCountPercentagePenalty[tileType]
		if penalty_amount ~= nil then
			local amountWaterPenalty = penalty_amount * waterbodies.GetAmountWaterForWaterBodyTileType(tileType) * multiplier
			penaltyWaterUsed = penaltyWaterUsed + amountWaterPenalty
		end
	end
	return totalArea, totalWater, penaltyWaterUsed
end

function waterbodies.GetWaterBodyType(totalArea)
	for waterBodyType, thresholdArea in pairs(waterbodies.WaterBodyTypeThresholdArea) do
		if totalArea < thresholdArea then
			return waterBodyType
		end
	end
end

function waterbodies.GetWaterBodyRegen(totalArea)
	local regenRate = settings.global["FluidArea-RegenRate"].value / 10000
	return regenRate * totalArea
end

function waterbodies.CalculateAndUpdateWaterBodyAreaData(waterBody)
	
	local totalArea, totalWater, penaltyWaterUsed = waterbodies.CalculateWaterBodyTotalAreaAndWater(waterBody)
	local waterBodyType = waterbodies.GetWaterBodyType(totalArea)
	local bonusValue = waterbodies.WaterBodyTypeToWaterBonusValue[waterBodyType]
	local amountWater = totalWater * bonusValue

	local regenAmount = waterbodies.GetWaterBodyRegen(totalArea)

	waterBody.waterAreaData.TotalArea = totalArea
    waterBody.waterAreaData.BonusValue = bonusValue
	waterBody.waterAreaData.AmountWtr = amountWater
	waterBody.waterAreaData.RegenAmount = regenAmount
	waterBody.waterAreaData.WaterBodyType = waterBodyType
	
	waterBody.waterBodyStateData.WaterUsedPenalty = penaltyWaterUsed
	waterBody.waterBodyStateData.TempAvailableWater = waterbodies.calculateRemainingWater(waterBody)

	waterBody.waterAreaData.ToCalculate = false

end


function waterbodies.createNewWaterBody(surfaceId)
    local waterBody = waterbodies.simpleInitWaterBody(surfaceId)
    waterbodies.addNewWaterBodyAndSetId(waterBody)
    return waterBody
end


function waterbodies.calculateDimensions(shape_data)
	shape_data["Hdif"] = shape_data["MaxX"] - shape_data["MinX"]
	shape_data["Vdif"] = shape_data["MaxY"] - shape_data["MinY"]
	shape_data["Hyp"] = math.sqrt((shape_data["Hdif"]^2) + (shape_data["Vdif"]^2))
end

-- Update water body bounding box (internal helper)
function waterbodies.updateBoundingBox(shape_data, position)
	if shape_data["MinX"] == 0 or position.x < shape_data["MinX"] then
		shape_data["MinX"] = position.x
	end
	if shape_data["MaxX"] == 0 or position.x > shape_data["MaxX"] then
		shape_data["MaxX"] = position.x
	end
	if shape_data["MinY"] == 0 or position.y < shape_data["MinY"] then
		shape_data["MinY"] = position.y
	end
	if shape_data["MaxY"] == 0 or position.y > shape_data["MaxY"] then
		shape_data["MaxY"] = position.y
	end
	waterbodies.calculateDimensions(shape_data)
end

function waterbodies.signalPerPlayer(water_body, signal_func, additional_args)
	local water_body_forces = water_body.entitiesData.forces
	for force_name, v in pairs(water_body_forces) do
		if v then
			for player_idx, _ in pairs(game.forces[force_name].players) do
				signal_func(water_body, game.forces[force_name], player_idx, additional_args)
			end
		end
	end
end

function waterbodies.initCleanedWaterBody(water_body)
	return {
		["PercentageWaterUsed"] = waterbodies.calculatePercentageWaterUsed(water_body),
		["valid"] = false,
		["waterBodyId"] = water_body.waterBodyId,
		["surfaceId"] = water_body.surfaceId,
		["waterBodyName"] = water_body.waterBodyName,
	}
end

function waterbodies.destroyMapMarkers(waterBodyStateData)
	for _, marker in pairs(waterBodyStateData.MapMarkers) do
		if marker then
			marker:destroy()
		end
	end
end

function waterbodies.removeWaterBody(waterBody)
	waterBody.valid = false
	
	waterbodies.destroyMapMarkers(waterBody.waterBodyStateData)
	
	-- Clean up tile assignments to this water body
    -- waterbodies.cleanupWaterBodyTiles(waterBody)

	 -- Remove most data from water body (garbage collection)
	 storage.WaterBodies[waterBody.waterBodyId] = waterbodies.initCleanedWaterBody(waterBody)
	 storage.ValidWaterBodies[waterBody.waterBodyId] = nil
end

function waterbodies.cleanupWaterBodyTiles(waterBody)
    local surfaceId = waterBody.surfaceId
    
    -- Remove tile assignments for this water body
    for gridKey, _ in pairs(waterBody.gridsData.waterGridWithData) do
        if waterbodies.getWaterTile(gridKey, surfaceId) == waterBody.waterBodyId then
            waterbodies.addNewWaterTile(gridKey, surfaceId, -1)
        end
    end
end

function waterbodies.calculateTotalWaterUsed(waterbody)
	local total_water_used = waterbody.waterBodyStateData.WaterUsed + waterbody.waterBodyStateData.WaterUsedPenalty - waterbody.waterBodyStateData.WaterUsedPenaltyRestored
	return total_water_used
end

function waterbodies.calculateRemainingWater(waterbody)
	local total_water_available = waterbody.waterAreaData.AmountWtr
	local total_water_used = waterbodies.calculateTotalWaterUsed(waterbody)
	return total_water_available - total_water_used
end

function waterbodies.calculatePercentageWaterUsed(waterbody)
	local total_water_used = waterbodies.calculateTotalWaterUsed(waterbody)
	local total_water_available = waterbody.waterAreaData.AmountWtr
	if total_water_available == 0 then return 100 end
	return math.max(math.min(total_water_used / total_water_available, 1), 0) * 100
end


waterbodies.MapMarker = {}
waterbodies.MapMarker.__index = waterbodies.MapMarker

function waterbodies.MapMarker:new(force, surfaceId, position, text, icon)
    local tag = force.add_chart_tag(utils.GetSurface(surfaceId), {position = position, text = text, icon = icon})
    local instance = {tag = tag, force=force, surfaceId=surfaceId, position=position, text=text, icon=icon}
    setmetatable(instance, waterbodies.MapMarker)
    return instance
end

function waterbodies.MapMarker:valid()
    return self.tag and self.tag.valid
end

function waterbodies.MapMarker:destroy()
    if self:valid() then self.tag.destroy() end
end

function waterbodies.MapMarker:update(position, text, icon)
    if not self:valid() then return end
    if position then self.position = position end
    if text then self.text = text end
    if icon then self.icon = icon end
    if position or text or icon then
        -- tag is read only so we need to destroy and create a new one
        self:destroy()
        self.tag = self.force.add_chart_tag(utils.GetSurface(self.surfaceId), {position = self.position, text = self.text, icon = self.icon})
    end
end
