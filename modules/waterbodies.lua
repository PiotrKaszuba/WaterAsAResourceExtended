require("modules.utils")
require("modules.hot_utils")

waterbodies = {}

function waterbodies.initWaterBodiesAndTiles()
    if storage.WaterBodies == nil then
        storage.WaterBodies = {}
		storage.NextWaterBodyId = 1
		storage.RecycledWaterBodyIds = {} -- array of waterBodyIds
		storage.ValidWaterBodies = {} -- waterBodyId -> waterBody (reference)

        storage.WaterTiles = {} -- surfaceName -> gridKey -> waterBodyId
		storage.WaterBodyToNumTiles = {} -- waterBodyId -> numTiles

		storage.OrphanedDryTilesOriginalName = {} -- surfaceName -> gridKey -> originalName
	end
end

function waterbodies.getValidWaterBodies()
    return storage.ValidWaterBodies
end

-- these functions use surfaceName instead of surface
function waterbodies.initSurface(surfaceName)
    if storage.WaterTiles[surfaceName] == nil then
        storage.WaterTiles[surfaceName] = {} -- gridKey -> waterBodyId
    end
	if storage.OrphanedDryTilesOriginalName[surfaceName] == nil then
		storage.OrphanedDryTilesOriginalName[surfaceName] = {} -- gridKey -> originalName
	end
end

function waterbodies.getWaterTile(gridKey, surface)
	local surfaceName = surface.name
    waterbodies.initSurface(surfaceName)
    return storage.WaterTiles[surfaceName][gridKey]
end


function waterbodies.getSurfaceMaxWaterbodies()
	return settings.startup["Surface-Max-Waterbodies"].value
end

function waterbodies.getMaxWaterBodySize()
    return settings.global["FluidArea-MaxFluidAreaSize"].value
end

function waterbodies.checkIfWaterBodyIdBelongsToValid(waterBodyId)
	if waterBodyId == nil or waterBodyId == -1 then
		return false
	end
	local waterBody = waterbodies.getWaterBody(waterBodyId)
	if waterBody and waterBody.valid then
		return true
	end
	return false
end

function waterbodies.checkIfTileIsNotAssignedToWaterBody(gridKey, surface)
    local waterBodyId = waterbodies.getWaterTile(gridKey, surface)
    return not waterbodies.checkIfWaterBodyIdBelongsToValid(waterBodyId)
end

function waterbodies.getNextFreeWaterBodyId()
	if #storage.RecycledWaterBodyIds > 0 then
		local recycledWaterBodyId = table.remove(storage.RecycledWaterBodyIds)
		-- there might be an edge case when '-1' leaks into RecycledWaterBodyIds
		-- in that case we simply ask for the next free water body id
		-- as '-1' just got removed from the table
		if recycledWaterBodyId == -1 then
			return waterbodies.getNextFreeWaterBodyId()
		end
		return recycledWaterBodyId
	end

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
	if waterBody.valid then
		storage.ValidWaterBodies[waterBodyId] = waterBody
	end
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


function waterbodies.removeTileFromWaterGrid(waterBody, gridKey)
	-- handle dry tile removal
	local currentTile = waterBody.gridsData.waterGridWithData[gridKey]
    if utils.DryWaterTiles[currentTile.name] then
        local state = waterBody.waterBodyStateData
        if state.DriedTiles > 0 then
            state.DriedTiles = state.DriedTiles - 1
        else
            utils.profile_hits("waterbodies.removeTileFromWaterGrid", string.format("DriedTiles is %d for a water body with dry tile being removed.", state.DriedTiles))
            game.print(string.format("Warning: DriedTiles is %d for a water body with dry tile being removed.", state.DriedTiles))
        end
    end
	-- remove from grid
    waterBody.gridsData.waterGridWithData[gridKey] = nil
end

function waterbodies.InitSearchData()
	return {
		searchQueue = utils.Queue.new(),
		totalArea = 0,
		finished = false,
		-- relative amount of scanning that will be done on the waterbody in the scanning loop
		-- 1.0 is default and assummed max value - use lower values for waterbodies that should be scanned less
		["ScanWeight"] = 1.0,

	}
end

function waterbodies.initGridsData()
	return {
		waterGridWithData = {}, -- table with position, name, originalName for tiles, also used as indicator table, position key
		edgeGrid = {}, -- indicator table, position key
	}
end

function waterbodies.calculateDimensions(shape_data)
	shape_data["Hdif"] = shape_data["MaxX"] - shape_data["MinX"]
	shape_data["Vdif"] = shape_data["MaxY"] - shape_data["MinY"]
	shape_data["Hyp"] = math.sqrt((shape_data["Hdif"]^2) + (shape_data["Vdif"]^2))
end

-- changing the order of these names will break the code in
-- waterbodies.getGeometryValuesArray
-- for performance reasons it does not read the expected indices but just fills the array
waterbodies.UpdateGeometryNames = {
	[1] = "MinX",
	[2] = "MaxX",
	[3] = "MinY",
	[4] = "MaxY",
	[5] = "SumX",
	[6] = "SumY",
	[7] = "TileCount",
}

local function sumf(a, b) return a + b end

waterbodies.LimitGeometryNamesToCompareOp = {
	[1] = math.min,
	[2] = math.max,
	[3] = math.min,
	[4] = math.max,
	[5] = sumf,
	[6] = sumf,
	[7] = sumf,
}

-- it uses either other_shape_data or batch values - not both at the same time
function waterbodies.getGeometryValuesArray(
	other_shape_data,
	batchMinX, batchMaxX,
	batchMinY, batchMaxY,

	batchSumX, batchSumY, batchTileCount
	)
	if other_shape_data == nil then
		return {
			batchMinX,
			batchMaxX,
			batchMinY,
			batchMaxY,
			batchSumX,
			batchSumY,
			batchTileCount,
		}
	end
	return {
		other_shape_data["MinX"],
		other_shape_data["MaxX"],
		other_shape_data["MinY"],
		other_shape_data["MaxY"],
		other_shape_data["SumX"],
		other_shape_data["SumY"],
		other_shape_data["TileCount"],
	}
end

-- it uses either other_shape_data or batch values - not both at the same time
-- should be used for batch updates from primitives (during scanning)
-- or merging two shapes
function waterbodies.updateGeometry(
	shape_data, other_shape_data,
	batchMinX, batchMaxX,
	batchMinY, batchMaxY,
	batchSumX, batchSumY, batchTileCount
	)
	if other_shape_data == nil and batchTileCount <= 0 then
		return
	end
    local values = waterbodies.getGeometryValuesArray(
		other_shape_data,
		batchMinX, batchMaxX,
		batchMinY, batchMaxY,
		batchSumX, batchSumY, batchTileCount
	)
    for i, name in ipairs(waterbodies.UpdateGeometryNames) do
		local value = values[i]
		if value ~= nil then
			shape_data[name] = waterbodies.LimitGeometryNamesToCompareOp[i](shape_data[name], value)
		end
    end
    waterbodies.calculateDimensions(shape_data)
end

function waterbodies.updateGeometryOnRemove(shape_data, batchSumX, batchSumY, batchTileCount)
	-- we don't handle updates of MinX, MaxX, MinY, MaxY for removal
	waterbodies.updateGeometry(shape_data, nil, nil, nil, nil, nil, batchSumX, batchSumY, batchTileCount)
end

function waterbodies.getCentroid(waterBody)
    local shape = waterBody.waterBodyShapeData
	local tile_count = shape.TileCount
    if tile_count <= 0 then
		if tile_count < 0 then
			utils.profile_hits("waterbodies.getCentroid", "tile_count < 0")
			game.print("Error: Tile count is negative in getCentroid")
		end
		if tile_count == 0 then
			utils.profile_hits("waterbodies.getCentroid", "tile_count == 0")
			game.print("Error: Tile count is 0 in getCentroid")
		end
        return { x = 0, y = 0 }
    end
    return { x = shape.SumX / tile_count, y = shape.SumY / tile_count }
end

function waterbodies.getPumpCentroid(waterBody)
	local pumpCount = 0
	local totalX, totalY = 0, 0
    for _, pump_data in ipairs(waterBody.waterBodyStateData.Pumps) do
		local position = pump_data.input_position
        totalX = totalX + position.x
        totalY = totalY + position.y
        pumpCount = pumpCount + 1
    end

    if pumpCount == 0 then
        return nil
    end

    local pumpCenterX = totalX / pumpCount
    local pumpCenterY = totalY / pumpCount
	return { x = pumpCenterX, y = pumpCenterY }
end

function waterbodies.calculateDepletionFocusPoint(waterBody)
    local centroid = waterbodies.getCentroid(waterBody)
	local pumpCentroid = waterbodies.getPumpCentroid(waterBody)
	if pumpCentroid == nil then
		return centroid
	end
	local centerX, centerY = centroid.x, centroid.y
	local vectorX = centerX - pumpCentroid.x
	local vectorY = centerY - pumpCentroid.y

    -- The focus point is "opposite" the pump center relative to the water body center
    local focusPoint = { x = centerX + vectorX, y = centerY + vectorY }
    -- fix position to left-top corner - needed because average position is not fixed
    local tile = utils.GetTile(focusPoint, waterBody.surface)
    focusPoint = tile.position
    return focusPoint
end

function waterbodies.initShapeData()
    return {
		-- min/max positions are limit values ever seen on the waterbody
		-- they are not exact because removal of tiles does not check
		-- whether these values 'shrink' - they can only 'expand'
		-- they should be used for the bounding area that the waterbody fits into
        ["MinX"] = math.huge,  -- max X position ever seen on the waterbody
        ["MaxX"] = -math.huge,
        ["MinY"] = math.huge,
        ["MaxY"] = -math.huge,
		
		["SumX"] = 0,
        ["SumY"] = 0,
        ["TileCount"] = 0,
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
        ["WaterBodyType"] = 0,
        ["BonusValue"] = 0,
        ["AmountWtr"] = 0,
        ["RegenAmount"] = 0,
        ["TotalArea"] = 0,
    }
end

function waterbodies.initWaterBodyStateData()
    return {
		["Pumps"] = {}, -- array of pump_data (reference)
		["Forces"] = {}, -- force name -> PlayerForce table (reference)
		
        ["WaterUsed"] = 0,	-- the actual water used synchronized on 'big updates'
        ["WaterUsedPrev"] = 0,	-- the actual water used on the previous 'big update'

		["TempAvailableWater"] = 0,	-- the available water that can be used before the next 'big update' 
		["TempUsedWater"] = 0,	-- the water used since the last 'big update' - used for small updates - if >= TempAvailableWater - the water body is depleted and triggers instant update

		
		["WaterUsedPenalty"] = 0,	-- the water used penalty that is applied to the water body - it occurs when waterbody is created on the water tiles that had been used in previous waterbody depleted to some extent

		["WaterUsedPenaltyRestored"] = 0,	-- the restored ater (above WaterUsed) that can negate the WaterUsedPenalty (up to that amount)

		["TempInactive"] = true,	-- if true - the water body is inactive and all pumps are inactive - due to using all of the TempAvailableWater
        ["Depleted"] = false,	-- if true - the water body is depleted and all pumps are inactive
			
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
		["OrphanedSecondsCount"] = 0, -- the number of seconds since the water body was orphaned

		["ToCalculate"] = false, -- if true, the water body area data needs to be calculated
		["ToUpdate"] = false, -- if true, the water body will emit update message


        ["MapMarkers"] = {},
    }
end

-- TODO: port more params from above
-- IDEA: make them separate 'structures' such as SearchData, TileData, MapMarker, WaterBodyState (for changing values such as depleted), AlarmData, PositionData (minX, maxX, minY, maxY) etc.
function waterbodies.InitWaterBody(
    surface,
	waterAreaData,
	gridsData,

    waterBodyShapeData,
    waterBodyTileCountData,
	searchData,
	waterBodyStateData,

    waterBodyId,
    waterBodyName

)
	return {
		valid = true, -- if false, the water body is not valid and should be deleted

        surface = surface or nil,
        waterBodyId = waterBodyId or nil,
        waterBodyName = waterBodyName or nil,
        merge_priority = 0,

		waterAreaData = waterAreaData or waterbodies.initWaterAreaData(),
		gridsData = gridsData or waterbodies.initGridsData(),
		waterBodyShapeData = waterBodyShapeData or waterbodies.initShapeData(),
		waterBodyTileCountData = waterBodyTileCountData or waterbodies.initWaterBodyTileCountData(),
		searchData = searchData or waterbodies.InitSearchData(),
		waterBodyStateData = waterBodyStateData or waterbodies.initWaterBodyStateData(),

		waterBodyTileCountPercentagePenalty = waterbodies.initWaterBodyTileCountData(),
	}
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
    return #waterBody.waterBodyStateData.Pumps == 0
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

waterbodies.WaterBodyTypeRegenScaling = 0.4
waterbodies.WaterBodyTypeToRegenBonusValue = {} 

-- 1.0 regen is for Lake
for waterBodyTypeInd, _ in pairs(waterbodies.WaterBodyTypesToName) do
	waterbodies.WaterBodyTypeToRegenBonusValue[waterBodyTypeInd] = 
		waterbodies.WaterBodyTypeRegenScaling ^ (waterBodyTypeInd - 3)
end

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

function waterbodies.getAvailableNamesForWaterBodyType(waterBodyType)
	local namesCollection = waterbodies.WaterBodyTypeToNamesCollection[waterBodyType]

	local validWaterBodies = waterbodies.getValidWaterBodies()

	local usedNames = {}
	for _, waterBody in pairs(validWaterBodies) do
		if waterBody and waterBody.waterBodyName then
			usedNames[waterBody.waterBodyName] = true
		end
	end
	local availableNames = {}
	for _, name in ipairs(namesCollection) do
		if usedNames[name] == nil then
			availableNames[#availableNames + 1] = name
		end
	end
	
	return availableNames
end

function waterbodies.getFullNameForWaterBody(waterBody)
	local name = waterBody.waterBodyName
	local suffix = waterbodies.getWaterBodyNameSuffix(waterBody)
	if name then
		return name .. " " .. suffix
	end
	return suffix
end

function waterbodies.getWaterBodyNameSuffix(waterBody)
	return waterbodies.WaterBodyTypesToName[waterBody.waterAreaData.WaterBodyType]
end

function waterbodies.GenerateWaterBodyName(waterBody)
	if waterBody.waterBodyName == nil and waterbodies.WaterBodyTypeToNamesCollection[waterBody.waterAreaData.WaterBodyType] ~= nil then
		local availableNames = waterbodies.getAvailableNamesForWaterBodyType(waterBody.waterAreaData.WaterBodyType)
		local randAmount = #availableNames
		if randAmount > 0 then
			local rand = math.random(1, randAmount)
			local name = availableNames[rand]
			waterBody.waterBodyName = name
		end
	end
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
			local amountWaterPenalty = penalty_amount / 100 * waterbodies.GetAmountWaterForWaterBodyTileType(tileType) * multiplier
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

function waterbodies.GetWaterBodyRegen(totalArea, bonusValue)
	local regenRate = settings.global["FluidArea-RegenRate"].value / 10000
	return regenRate * totalArea * bonusValue
end

function waterbodies.CalculateAndUpdateWaterBodyAreaData(waterBody)
	local area_data = waterBody.waterAreaData
	
	local totalArea, totalWater, penaltyWaterUsed = waterbodies.CalculateWaterBodyTotalAreaAndWater(waterBody)
	local waterBodyType = waterbodies.GetWaterBodyType(totalArea)
	local bonusValue = waterbodies.WaterBodyTypeToRegenBonusValue[waterBodyType]
	local amountWater = totalWater

	local regenAmount = waterbodies.GetWaterBodyRegen(totalArea, bonusValue)

	area_data.TotalArea = totalArea
    area_data.BonusValue = bonusValue
	area_data.AmountWtr = amountWater
	area_data.RegenAmount = regenAmount
	area_data.WaterBodyType = waterBodyType
	
	local state_data = waterBody.waterBodyStateData
	state_data.WaterUsedPenalty = penaltyWaterUsed
	state_data.TempAvailableWater = waterbodies.calculateRemainingWater(waterBody)

	local search_data = waterBody.searchData
	-- search data totalArea is not well tracked otherwise - update to this value
	search_data.totalArea = totalArea


	state_data.ToCalculate = false

end

function waterbodies.createNewWaterBody(surface)
    local waterBody = waterbodies.InitWaterBody(surface)
    local waterBodyId = waterbodies.addNewWaterBodyAndSetId(waterBody)
    return waterBody, waterBodyId
end




function waterbodies.signalPerForce(water_body, signal_func, additional_args)
	local water_body_forces = water_body.waterBodyStateData.Forces
	for force_name, force_data in pairs(water_body_forces) do
		local force = force_data.force
		if force.valid then
			force.print(signal_func(water_body, force_name, additional_args))
		end
	end
end

-- requires waterGridWithData + gridKey to be present in scope
function waterbodies.addTileToWaterGrid(waterGridWithData, gridKey, tileName, position, originalName)
    waterGridWithData[gridKey] = {
        name = tileName,
        position = position,
        originalName = originalName
    }
end

function waterbodies.initCleanedWaterBody(water_body)
	return {
		["PercentageWaterUsed"] = waterbodies.calculatePercentageWaterUsed(water_body),
		["valid"] = false,
		["waterBodyId"] = water_body.waterBodyId,
		["surface"] = water_body.surface,
		["waterBodyName"] = water_body.waterBodyName,
	}
end

function waterbodies.destroyMapMarkers(waterBodyStateData)
	for _, marker in pairs(waterBodyStateData.MapMarkers) do
		if marker then
			utils.MapMarker.destroy(marker)
		end
	end
end

function waterbodies.getWaterBodyWaterOrDryTilesArray(waterBody, findDryTiles)
	-- if findDryTiles is true, it will return dry tiles
	-- otherwise it will return water tiles
    local candidateTiles = {}
    local gridData = waterBody.gridsData.waterGridWithData

    if findDryTiles then
        for _, tileData in pairs(gridData) do
            if utils.DryWaterTiles[tileData.name] then
                candidateTiles[#candidateTiles + 1] = tileData
            end
        end
    else
        for _, tileData in pairs(gridData) do
            if utils.IsWaterTile(tileData.name) then
                candidateTiles[#candidateTiles + 1] = tileData
            end
        end
    end
    return candidateTiles
end

function waterbodies.removeWaterBody(waterBody)
	waterBody.valid = false
	
	waterbodies.destroyMapMarkers(waterBody.waterBodyStateData)
	
	-- dry tiles become orphaned - we need to remember their original name
	if waterBody.waterBodyStateData.DriedTiles > 0 then
		local dried_tiles = waterbodies.getWaterBodyWaterOrDryTilesArray(waterBody, true)
		local surfaceName = waterBody.surface.name
		local gridKey
		for _, tileData in ipairs(dried_tiles) do
			gridKey = hot_utils.GridKey(tileData.position)
			storage.OrphanedDryTilesOriginalName[surfaceName][gridKey] = tileData.originalName
		end
	end
	
	-- Clean up tile assignments to this water body
    -- waterbodies.cleanupWaterBodyTiles(waterBody)

	 -- Remove most data from water body (garbage collection)
	 storage.WaterBodies[waterBody.waterBodyId] = waterbodies.initCleanedWaterBody(waterBody)
	 storage.ValidWaterBodies[waterBody.waterBodyId] = nil
end

function waterbodies.cleanupWaterBodyTiles(waterBody)
    local surfaceName = waterBody.surface.name
    
    -- Remove tile assignments for this water body
    for gridKey, _ in pairs(waterBody.gridsData.waterGridWithData) do
        if hot_utils.getWaterTile(gridKey, surfaceName) == waterBody.waterBodyId then
            hot_utils.addNewWaterTile(gridKey, surfaceName, -1)
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

function waterbodies.canPumpWaterNow(waterBodyStateData)
	return not waterBodyStateData.Depleted and (waterBodyStateData.TempAvailableWater > waterBodyStateData.TempUsedWater)
end
