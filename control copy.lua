-- WATER AS A RESOURCE MAIN LUA CONTROL PROGRAM -- 
--    CREATED BY TREEFROGGREAKEN 2018 - 2023    --

-- REQUIRED ADDITIONAL LUA FILES -- 

require("waterbodies") -- Loads waterbodies.lua
require("fluidentities")
require("fluidlist")

-- storage VARIABLES

function storages()
	if not storage.WaterGlobalArea then storage.WaterGlobalArea = {} end
	if not storage.OPLocate then storage.OPLocate = {} end
	if not storage.ODLocate then storage.ODLocate = {} end
	if not storage.LandFill then storage.LandFill = {} end
	if not storage.FluidProducers then storage.FluidProducers = {} end
	if not storage.PlayerForces then storage.PlayerForces = {} end
	if not storage.FluidFlow then storage.FluidFlow = {} end
	if not storage.ScanOffshoresQueue then storage.ScanOffshoresQueue = {} end
	
	if not storage.WGAID then storage.WGAID = 0 end
	if not storage.Type then storage.Type = 0 end
	-- if not storage.WaterFlow then storage.WaterFlow = 0 end
	-- if not storage.CrudeFlow then storage.CrudeFlow = 0 end
	-- if not storage.LastWaterFlow then storage.LastWaterFlow = 0 end
	-- if not storage.LastCrudeFlow then storage.LastCrudeFlow = 0 end
	if not storage.WaterBodyType then storage.WaterBodyType = 0 end
	if not storage.ActiveOPs then storage.ActiveOPs = 0 end
	if not storage.ActiveODs then storage.ActiveODs = 0 end
	if not storage.PercentChange then storage.PercentChange = 0 end
	if not storage.InstallTick then storage.InstallTick = 0 end
	if not storage.LoopTick then storage.LoopTick = 0 end

	if not storage.Added then storage.Added = true end
	if not storage.NewInstall then storage.NewInstall = true end
	if not storage.ITMessage then storage.ITMessage = true end
	if not storage.remotetrigger then storage.remotetrigger = false end
	if not storage.ODRemoved then storage.ODRemoved = false end
	if not storage.EnableNextOffshore then storage.EnableNextOffshore = false end
end

function Linkstorages()
	-- WaterFlow = storage.WaterFlow
	-- CrudeFlow = storage.CrudeFlow
	-- LastWaterFlow = storage.LastWaterFlow
	-- LastCrudeFlow = storage.LastCrudeFlow
	WaterBodyType = storage.WaterBodyType
	ActiveOPs = storage.ActiveOPs
	ActiveODs = storage.ActiveODs
	PercentChange = storage.PercentChange
	WGAID = storage.WGAID
end

-- EVENT DEPENDANT FUNCTIONS

function EdgePattern(SearchPosition)
	-- Define all 8 surrounding positions efficiently
	local adjacentPositions = {
		{x = SearchPosition.x,     y = SearchPosition.y - 1}, -- north
		{x = SearchPosition.x + 1, y = SearchPosition.y - 1}, -- northeast
		{x = SearchPosition.x + 1, y = SearchPosition.y},     -- east
		{x = SearchPosition.x + 1, y = SearchPosition.y + 1}, -- southeast
		{x = SearchPosition.x,     y = SearchPosition.y + 1}, -- south
		{x = SearchPosition.x - 1, y = SearchPosition.y + 1}, -- southwest
		{x = SearchPosition.x - 1, y = SearchPosition.y},     -- west
		{x = SearchPosition.x - 1, y = SearchPosition.y - 1}  -- northwest
	}
	
	-- Water tile types lookup table for O(1) performance
	local waterTiles = {
		["water"] = true,
		["deepwater"] = true,
		["water-green"] = true,
		["water-shallow"] = true,
		["water-mud"] = true,
		["deepwater-green"] = true
	}
	
	local edgeFound = false
	
	for _, position in pairs(adjacentPositions) do
		local gridKey = PositionToString(position)
		if not WASearched[gridKey] then
			local tile = game.surfaces[surface].get_tile(position.x, position.y)
			if tile.valid then
				if waterTiles[tile.name] then
					-- Water tile: add to search queue
					WASearchQueue[#WASearchQueue + 1] = {x = tile.position.x, y = tile.position.y}
				else
					-- Non-water tile: mark as edge
					local edgePosition = {x = tile.position.x, y = tile.position.y}
					WASearched[PositionToString(edgePosition)] = true
					WaterEdgeGrid[PositionToString(edgePosition)] = true
					edgeFound = true
				end
			end
		end
	end
	
	Edge = edgeFound  -- Set global Edge variable for compatibility
	return edgeFound
end

function PositionToString (SearchPosition)
	return string.format ("%.1f , %.1f", SearchPosition.x , SearchPosition.y)	-- Print SearchPosition X, Y CoOrds as String
end

function IsWater(SearchPosition, surface)
	local tile = game.surfaces[surface].get_tile(SearchPosition.x,SearchPosition.y) 		-- Get Name of Tile by looking on the surface by using SearchPosition Variable
	if tile.valid == true then
		fluidname = tile.name
		if fluidlist.CheckNames(fluidname) == "shallow" then 								-- IF Water or Deepwater THEN
			return "shallow"																-- Return TRUE
		elseif fluidlist.CheckNames(fluidname) == "deep" then
			return "deep"
		elseif tile.name == "lake-shallow" then																	-- Otherwise
			return "lake-shallow" 															-- Return False
		elseif tile.name == "lake-deep" then
			return "lake-deep"
		elseif tile.name == "crude-oil" then
			return "crude-oil"
		elseif tile.name == "crude-oil-deep" then
			return "crude-oil-deep"
		else
			return false
		end																			-- NOT Water or Deepwater
	else
		game.print("Invalid Tile")		-- Print Not A Water Tile
		return false
	end
end

function GlobalWaterArea()
	if #storage.WaterGlobalArea == 0 then
		if storage.Type == 1 then
			CreateWaterArea()	-- Create WaterArea
			player = storage.OPLocate[1]["entity"].last_user
			storage.OPLocate[1]["WA"] = storage.WGAID			-- Assign Offshore Pump 1 to WaterArea 1 - If RemoveWAOPD Active then Assign WGAID
			storage.WaterGlobalArea[1]["OPs"][1] = {["force"] = storage.OPLocate[1]["force"], ["count"] = 1}
			storage.WaterGlobalArea[1]["OPsA"][1] = {["force"] = storage.OPLocate[1]["force"], ["count"] = 0}
			storage.WaterGlobalArea[1]["MapMarker"][1] = {["force"] = storage.OPLocate[1]["force"], ["placed"] = false,["icon"] = nil}
			storage.WaterGlobalArea[1]["Surface"] = storage.OPLocate[1]["entity"].surface
			AssignFluid()
			if storage.WaterGlobalArea[1]["ToSearch"] == nil then
				game.forces[player.force.name].print(string.format("%s created, with %sL of %s.", storage.WaterGlobalArea[1]["WtrName"], comma_value(storage.WaterGlobalArea[1]["AmountWtr"]), storage.WaterGlobalArea[1]["FluidType"]))
				a = 1
				MapMarker(a)
				return "GWA-Complete"
			else
				game.players[player.name].print("FluidArea being scanned, please wait for assignment.")
				return "GWA-ToSearch"
			end
		elseif storage.Type == 2 then
			local x = storage.ODLocate[1]["position"]["x"]
			local y = storage.ODLocate[1]["position"]["y"]
			surface = storage.ODLocate[1]["surface"].name
			local dir = storage.ODLocate[1]["direction"]
			player = storage.ODLocate[1]["entity"].last_user
			if dir == 0 then -- North
				SearchPosition = {x = storage.ODLocate[1]["position"]["x"], y = storage.ODLocate[1]["position"]["y"]+1}
			elseif dir == 2 then -- East
				SearchPosition = {x = storage.ODLocate[1]["position"]["x"]-1, y = storage.ODLocate[1]["position"]["y"]}
			elseif dir == 4 then -- South
				SearchPosition = {x = storage.ODLocate[1]["position"]["x"], y = storage.ODLocate[1]["position"]["y"]-1}
			elseif dir == 6 then -- West
				SearchPosition = {x = storage.ODLocate[1]["position"]["x"]+1, y = storage.ODLocate[1]["position"]["y"]}
			end
			local WaterCheck = storage.ODLocate[1]["surface"].get_tile(x,y).name
			if IsWater(SearchPosition,surface) == false then
				if WaterCheck == "water" or WaterCheck == "deepwater" then
					CreateWaterArea()
					storage.ODLocate[1]["WA"] = 1
					storage.WaterGlobalArea[1]["ODs"][1] = {["force"] = storage.ODLocate[1]["force"], ["count"] = 1}
					storage.WaterGlobalArea[1]["ODsA"][1] = {["force"] = storage.ODLocate[1]["force"], ["count"] = 0}
					storage.WaterGlobalArea[1]["WtrAdd"][1] = {["force"] = storage.ODLocate[1]["force"], ["count"] = 0}
					storage.WaterGlobalArea[1]["MapMarker"][1] = {["force"] = storage.ODLocate[1]["force"], ["placed"] = false,["icon"] = nil}
					storage.WaterGlobalArea[1]["Surface"] = storage.ODLocate[1]["entity"].surface
					AssignFluid()
					if storage.WaterGlobalArea[1]["ToSearch"] == nil then
						game.forces[player.force.name].print(string.format("%s created, with %sL of %s.", storage.WaterGlobalArea[1]["WtrName"], comma_value(storage.WaterGlobalArea[1]["AmountWtr"]), "water"))
						a = 1
						MapMarker(a)
						return "GWA-Complete"
					else
						game.print("FluidArea being scanned, please wait for assignment.")
						return "GWA-ToSearch"
					end
				else
					game.players[player.name].print("Area not suitable for Offshore Drain.")
					storage.ODLocate[1]["entity"].destroy()
					table.remove(storage.ODLocate)
					game.players[player.name].insert{name="offshore-drain",count=1}
					storage.ODRemoved = true
					return "GWA-NotSuitable"
				end
			else
				game.players[player.name].print("Not On Edge Of Lake.")
				storage.ODLocate[1]["entity"].destroy()
				table.remove(storage.ODLocate)
				game.players[player.name].insert{name="offshore-drain",count=1}
				storage.ODRemoved = true
				return "GWA-NotEdge"
			end
		end
	else
		CompareAssign()
	end
end

function CompareAssign()
	OffShoreCompareArea()
	if FoundExt == true then 						-- IF No Offshores Found then New Area
		if storage.Type == 1 then
			CreateWaterArea()
			player = storage.OPLocate[#storage.OPLocate]["entity"].last_user
			force = storage.OPLocate[#storage.OPLocate]["entity"].force.name
			storage.OPLocate[#storage.OPLocate]["WA"] = storage.WaterGlobalArea[#storage.WaterGlobalArea]["WGAID"]
			storage.WaterGlobalArea[#storage.WaterGlobalArea]["OPs"][1] = {["force"] = storage.OPLocate[#storage.OPLocate]["force"], ["count"] = 1}
			storage.WaterGlobalArea[#storage.WaterGlobalArea]["OPsA"][1] = {["force"] = storage.OPLocate[#storage.OPLocate]["force"], ["count"] = 0}
			storage.WaterGlobalArea[#storage.WaterGlobalArea]["MapMarker"][1] = {["force"] = storage.OPLocate[#storage.OPLocate]["force"], ["placed"] = false,["icon"] = nil}
			storage.WaterGlobalArea[#storage.WaterGlobalArea]["Surface"] = storage.OPLocate[#storage.OPLocate]["entity"].surface
			AssignFluid()
			if storage.WaterGlobalArea[#storage.WaterGlobalArea]["ToSearch"] == nil then
				game.forces[force].print(string.format("%s created, with %sL of %s.", storage.WaterGlobalArea[#storage.WaterGlobalArea]["WtrName"], comma_value(storage.WaterGlobalArea[#storage.WaterGlobalArea]["AmountWtr"]), storage.WaterGlobalArea[#storage.WaterGlobalArea]["FluidType"]))
				a = #storage.WaterGlobalArea
				MapMarker(#storage.WaterGlobalArea)
				return "CA-Complete"
			else
				game.players[player.name].print("FluidArea being scanned, please wait for assignment.")
				return "CA-ToSearch"
			end
			FoundExt = false
		elseif storage.Type == 2 then
			local x = storage.ODLocate[#storage.ODLocate]["position"]["x"]
			local y = storage.ODLocate[#storage.ODLocate]["position"]["y"]
			surface = storage.ODLocate[#storage.ODLocate]["surface"].name
			local dir = storage.ODLocate[#storage.ODLocate]["direction"]
			player = storage.ODLocate[#storage.ODLocate]["entity"].last_user
			if dir == 0 then -- North
				SearchPosition = {x = storage.ODLocate[#storage.ODLocate]["position"]["x"], y = storage.ODLocate[#storage.ODLocate]["position"]["y"]+1}
			elseif dir == 2 then -- East
				SearchPosition = {x = storage.ODLocate[#storage.ODLocate]["position"]["x"]-1, y = storage.ODLocate[#storage.ODLocate]["position"]["y"]}
			elseif dir == 4 then -- South
				SearchPosition = {x = storage.ODLocate[#storage.ODLocate]["position"]["x"], y = storage.ODLocate[#storage.ODLocate]["position"]["y"]-1}
			elseif dir == 6 then -- West
				SearchPosition = {x = storage.ODLocate[#storage.ODLocate]["position"]["x"]+1, y = storage.ODLocate[#storage.ODLocate]["position"]["y"]+1}
			end
			local WaterCheck = storage.ODLocate[#storage.ODLocate]["surface"].get_tile(x,y).name
			if IsWater(SearchPosition,surface) == false then
				if WaterCheck == "water" or WaterCheck == "deepwater" then
					CreateWaterArea()
					storage.ODLocate[#storage.ODLocate]["WA"] = storage.WaterGlobalArea[#storage.WaterGlobalArea]["WGAID"]
					storage.WaterGlobalArea[#storage.WaterGlobalArea]["ODs"][1] = {["force"] = storage.ODLocate[#storage.ODLocate]["force"], ["count"] = 1}
					storage.WaterGlobalArea[#storage.WaterGlobalArea]["ODsA"][1] = {["force"] = storage.ODLocate[#storage.ODLocate]["force"], ["count"] = 0}
					storage.WaterGlobalArea[#storage.WaterGlobalArea]["WtrAdd"][1] = {["force"] = storage.ODLocate[#storage.ODLocate]["force"], ["count"] = 0}
					storage.WaterGlobalArea[#storage.WaterGlobalArea]["MapMarker"][1] = {["force"] = storage.ODLocate[#storage.ODLocate]["force"], ["placed"] = false,["icon"] = nil}
					-- storage.WaterGlobalArea[#storage.WaterGlobalArea]["ODs"] = 1
					storage.WaterGlobalArea[#storage.WaterGlobalArea]["Surface"] = storage.ODLocate[#storage.ODLocate]["entity"].surface
					AssignFluid()
					if storage.WaterGlobalArea[#storage.WaterGlobalArea]["ToSearch"] == nil then
						game.forces[player.force.name].print(string.format("%s created, with %sL of %s.", storage.WaterGlobalArea[#storage.WaterGlobalArea]["WtrName"], comma_value(storage.WaterGlobalArea[#storage.WaterGlobalArea]["AmountWtr"]), "water"))
						a = #storage.WaterGlobalArea
						MapMarker(a)
						return "CA-Complete"
					else
						game.players[player.name].print("FluidArea being scanned, please wait for assignment.")
						return "CA-ToSearch"
					end
				else
					game.players[player.name].print("Area not suitable for Offshore Drain.")
					storage.ODLocate[#storage.ODLocate]["entity"].destroy()
					table.remove(storage.ODLocate,#storage.ODLocate)
					game.players[player.name].insert{name="offshore-drain",count=1}
					storage.ODRemoved = true
					return "CA-NotSuitable"
				end
				FoundExt = false
			else
				game.players[player.name].print("Not On Edge of Lake.")
				storage.ODLocate[#storage.ODLocate]["entity"].destroy()
				table.remove(storage.ODLocate,#storage.ODLocate)
				game.players[player.name].insert{name="offshore-drain",count=1}
				storage.ODRemoved = true
				return "CA-NotEdge"
			end
			FoundExt = false
		end
	end
end

function CreateWaterArea()
	storage.WaterGlobalArea[#storage.WaterGlobalArea+1] = {["WGAID"] = 0, ["WtrName"] = "None",["Surface"] = nil, ["ToSearch"] = nil, ["HasSearched"] = nil,["LoopCount"] = 0, ["AmountWtr"] = 0,["AmountBonusValue"] = 0,["RegenAmount"] = 0,["Depleted"] = 0,["ShallowWater"] = 0, ["DeepWater"] = 0,["ShallowWater-Shallow"] = 0,["ShallowWater-Mud"] = 0,["Percent"] = 0,["PercentPrev"] = 0,["Fired50"] = false, ["Fired75"] = false, ["Fired90"] = false, ["Fired95"] = false, ["Fired97"] = false,["Fired98"] = false,["Fired99"] = false,["RandPercent"] = 79, ["BTF"] = 0,["BTFE"] = 0,["Below80"] = 0, ["WaterRepArea"] = {},["WaterEdgeArea"] = {},["WaterEdgeGrid"] = {},["WaterEdgeAreaY"] = {},["WaterEdgeAreaX"] = {},["MinX"] = 0, ["MaxX"] = 0, ["MinY"] = 0, ["MaxY"] = 0, ["Hdif"] = 0, ["Vdif"] = 0, ["Hyp"] = 0, ["TilesSet"] = "N",["OPs"] = {},["OPsA"] = {},["ODs"] = {}, ["ODsA"] = {}, ["WtrUsed"] = 0,["WtrAdd"] = {}, ["WaterBodyType"] = 0, ["FluidType"] = nil, ["MapMarker"] = {}, ["MapMarkerPlaced"] = false, ["TechYRBoost"] = 1}
	a = #storage.WaterGlobalArea
	storage.WGAID = storage.WGAID + 1
	storage.WaterGlobalArea[a]["WGAID"] = storage.WGAID
	GetWaterArea(a)
	CalculatedWaterTotal(a)
	if storage.WaterGlobalArea[a]["ToSearch"] == nil then
		if storage.WaterGlobalArea[a]["WtrName"] == "None" or storage.WaterGlobalArea[a]["WtrName"] == "Puddle" or storage.WaterGlobalArea[a]["WtrName"] == "Well" or storage.WaterGlobalArea[a]["WtrName"] == "Pond"  then
			waterbodies.WtrName(a)
		end
		game.print(string.format("%s created, with %sL of %s with regen %sL.", storage.WaterGlobalArea[a]["WtrName"], comma_value(storage.WaterGlobalArea[a]["AmountWtr"]), storage.WaterGlobalArea[a]["FluidType"], storage.WaterGlobalArea[a]["RegenAmount"]))
	end
	MapMarkerPlace(a)
	a = 0
end

function AssignFluid()	-- Assign Fluid On New WaterArea Creation
	for a = 1, #storage.WaterGlobalArea, 1 do
		if storage.WaterGlobalArea[a]["FluidType"] == nil then
			if storage.Type == 1 then
				for b = 1, #storage.OPLocate, 1 do
					if storage.OPLocate[b]["WA"] == storage.WaterGlobalArea[a]["WGAID"] then
						storage.WaterGlobalArea[a]["FluidType"] = storage.OPLocate[b]["tile"]
					end
				end
			elseif storage.Type == 2 then
				for b = 1, #storage.ODLocate, 1 do
					if storage.ODLocate[b]["WA"] == storage.WaterGlobalArea[a]["WGAID"] then
						storage.WaterGlobalArea[a]["FluidType"] = storage.ODLocate[b]["tile"]
					end
				end
			end
		end
	end
end

function OffShoreCompareArea()
	if storage.Type == 1 then
		NuOPs = #storage.OPLocate
		OPS = storage.OPLocate
		NewOPPosX = OPS[NuOPs]["position"]["x"] - 0.5
		NewOPPosY = OPS[NuOPs]["position"]["y"] - 0.5
		player = OPS[NuOPs]["entity"].last_user
	elseif storage.Type == 2 then
		NuOPs = #storage.ODLocate
		OPS = storage.ODLocate
		NewOPPosX = OPS[NuOPs]["position"]["x"] - 0.5
		NewOPPosY = OPS[NuOPs]["position"]["y"] - 0.5
		player = OPS[NuOPs]["entity"].last_user
	end
	local NuWAs = #storage.WaterGlobalArea
	local WA = storage.WaterGlobalArea
	FoundInt = false
	FoundExt = true
	for a = NuWAs, 1, -1 do 	-- FOR Each WATERAREA
		if #WA[a]["WaterRepArea"] > 0 then
			FluidArea = WA[a]["WaterRepArea"]
			NewOPPosX = NewOPPosX + 0.5
			NewOPPosY = NewOPPosY + 0.5
		else
			FluidArea = WA[a]["WaterEdgeArea"]
		end
		for b = 1, #FluidArea, 1 do -- FOR EACH TILE in WATERAREA
			if FluidArea[b] ~= nil then
				local WATilePosX = FluidArea[b]["position"]["x"]
				local WATilePosY = FluidArea[b]["position"]["y"]
				if NewOPPosX == WATilePosX or NewOPPosX - 0.5 == WATilePosX then		-- IF NEW OFFSHORE IS IN WATER AREAS X POSITION
					if NewOPPosY == WATilePosY or NewOPPosY - 0.5 == WATilePosY then	-- IF NEW OFFSHORE IS IN WATER AREAS Y POSITION
						FoundExt = false
						FoundInt = true
					end
				end
			end
		end
		if FoundInt == true then -- FOUND IN THIS WATERAREA
			if storage.Type == 1 then
				OPS[NuOPs]["WA"] = WA[a]["WGAID"]
				OPForce = OPS[NuOPs]["force"]
				PumpForceNotFound = true
				for b = 1, #WA[a]["OPs"], 1 do
					if WA[a]["OPs"][b]["force"] == OPS[NuOPs]["force"] then
						WA[a]["OPs"][b]["count"] = WA[a]["OPs"][b]["count"] + 1
						PumpForceNotFound = false
					end
				end
				if PumpForceNotFound == true then
					WA[a]["OPs"][#WA[a]["OPs"]+1] = {["force"] = OPS[NuOPs]["force"],["count"] = 1}
					WA[a]["OPsA"][#WA[a]["OPsA"]+1] = {["force"] = OPS[NuOPs]["force"],["count"] = 0}
					WA[a]["MapMarker"][#WA[a]["MapMarker"]+1] = {["force"] = OPS[NuOPs]["force"], ["placed"] = false, ["icon"] = nil}
				end
				-- WA[a]["OPs"] = WA[a]["OPs"] + 1
				WA[a]["FluidType"] = OPS[NuOPs]["tile"]
				if WA[a]["Percent"] < 0 then
					for z = 1, #WA[a]["OPs"], 1 do
						if WA[a]["OPs"][z]["force"] == OPS[NuOPs]["force"] then
							game.forces[OPForce].print(string.format("%s has %s Offshore Pumps, with %.0f %% of %s volume depleted.", WA[a]["WtrName"], WA[a]["OPs"][z]["count"], 0, WA[a]["FluidType"]))
							--game.players[player.name].print(string.format("%s has %s Offshore Pumps, with %.0f %% of %s volume depleted.", WA[a]["WtrName"], WA[a]["OPs"][z]["count"], 0, WA[a]["FluidType"]))
						end
					end
				else
					for z = 1, #WA[a]["OPs"], 1 do
						if WA[a]["OPs"][z]["force"] == OPS[NuOPs]["force"] then
							game.forces[OPForce].print(string.format("%s has %s Offshore Pumps, with %.0f %% of %s volume depleted.", WA[a]["WtrName"], WA[a]["OPs"][z]["count"], WA[a]["Percent"], WA[a]["FluidType"]))
							--game.players[player.name].print(string.format("%s has %s Offshore Pumps, with %.0f %% of %s volume depleted.", WA[a]["WtrName"], WA[a]["OPs"][z]["count"], WA[a]["Percent"], WA[a]["FluidType"]))
						end
					end
				end
				FoundInt = false
			elseif storage.Type == 2 then
				OPS[NuOPs]["WA"] = WA[a]["WGAID"]
				OPForce = OPS[NuOPs]["force"]
				DrainForceNotFound = true
				for b = 1, #WA[a]["ODs"], 1 do
					if WA[a]["ODs"][b]["force"] == OPS[NuOPs]["force"] then
						WA[a]["ODs"][b]["count"] = WA[a]["ODs"][b]["count"] + 1
						DrainForceNotFound = false
					end
				end
				if DrainForceNotFound == true then
					WA[a]["ODs"][#WA[a]["ODs"]+1] = {["force"] = OPS[NuOPs]["force"],["count"] = 1}
					WA[a]["ODsA"][#WA[a]["ODsA"]+1] = {["force"] = OPS[NuOPs]["force"],["count"] = 0}
					WA[a]["WtrAdd"][#WA[a]["WtrAdd"]+1] = {["force"] = OPS[NuOPs]["force"],["count"] = 0}
					WA[a]["MapMarker"][#WA[a]["MapMarker"]+1] = {["force"] = OPS[NuOPs]["force"], ["placed"] = false, ["icon"] = nil}
				end
				-- WA[a]["ODs"] = WA[a]["ODs"] + 1
				if WA[a]["Percent"] >= 0 and WA[a]["Percent"] < 100 then
					for z = 1, #WA[a]["ODs"], 1 do
						if WA[a]["ODs"][z]["force"] == OPS[NuOPs]["force"] then
							game.players[player.name].print(string.format("%s has %s Offshore Drains, with %.0f %% of %s volume depleted.", WA[a]["WtrName"], WA[a]["ODs"][z]["count"], WA[a]["Percent"], WA[a]["FluidType"]))
						end
					end
				else
					for z = 1, #WA[a]["ODs"], 1 do
						if WA[a]["ODs"][z]["force"] == OPS[NuOPs]["force"] then
							if WA[a]["Percent"] >= 100 then
								game.forces[OPForce].print(string.format("%s has %s Offshore Drains, with %.0f %% depleted.", WA[a]["WtrName"], WA[a]["ODs"][z]["count"], WA[a]["Percent"], WA[a]["FluidType"]))
								--game.players[player.name].print(string.format("%s has %s Offshore Drains, with %.0f %% depleted.", WA[a]["WtrName"], WA[a]["ODs"][z]["count"], WA[a]["Percent"], WA[a]["FluidType"]))
							else
								game.forces[OPForce].print(string.format("%s has %s Offshore Drains, with %.0f %% depleted.", WA[a]["WtrName"], WA[a]["ODs"][z]["count"], 0, WA[a]["FluidType"]))
								--game.players[player.name].print(string.format("%s has %s Offshore Drains, with %.0f %% depleted.", WA[a]["WtrName"], WA[a]["ODs"][z]["count"], 0, WA[a]["FluidType"]))
							end
						end
					end
				end
				FoundInt = false
			end
		end
	end
return FoundExt
end

function GetWaterArea(a) 										-- Get Water Area Function
	SearchAmount = settings.global["FluidArea-Start-Area"].value
	if storage.Type == 1 then
		position = storage.OPLocate[#storage.OPLocate]["position"]
		surface = storage.OPLocate[#storage.OPLocate]["surface"].name
		direction = storage.OPLocate[#storage.OPLocate]["direction"]
		WASearchQueue = {position}
		WASearched = {}
	elseif storage.Type == 2 then
		position = storage.ODLocate[#storage.ODLocate]["position"]
		surface = storage.ODLocate[#storage.ODLocate]["surface"].name
		direction = storage.ODLocate[#storage.ODLocate]["direction"]
		WASearchQueue = {position}
		WASearched = {}
	elseif storage.WaterGlobalArea[a]["ToSearch"] ~= nil then
		WASearchQueue = storage.WaterGlobalArea[a]["ToSearch"]
		WASearched = storage.WaterGlobalArea[a]["HasSearched"]
		surface = storage.WaterGlobalArea[a]["Surface"].name
		SearchAmount = settings.global["FluidArea-Additional-Tiles-Per-Second"].value
	end
	WaterGArea = storage.WaterGlobalArea[a]
	WaterRepArea = storage.WaterGlobalArea[a]["WaterRepArea"]
	WaterEdgeArea = storage.WaterGlobalArea[a]["WaterEdgeArea"]
	WaterEdgeGrid = storage.WaterGlobalArea[a]["WaterEdgeGrid"]

	FA = storage.WaterGlobalArea[a]
	PlayerMaxArea = settings.global["FluidArea-MaxFluidAreaSize"].value
	TotalArea = storage.WaterGlobalArea[a]["ShallowWater"] + storage.WaterGlobalArea[a]["DeepWater"]
	if script.active_mods["SeaBlock"] or script.active_mods["ctg"] then
		if TotalArea > 60000 then
			table.remove (WASearchQueue,1)
			goto NOSEARCH								
		end
	end
	while #WASearchQueue > 0 and SearchAmount > 0 do
		local SearchPosition = WASearchQueue[1]													-- Convert Offshore Pump Position into SearchPosition
		if WASearched[PositionToString(SearchPosition)] ~= true and TotalArea <= PlayerMaxArea then 		-- IF GridRef has not been searched
			if IsWater(SearchPosition, surface) == false or IsWater(SearchPosition, surface) == "lake-shallow" or IsWater(SearchPosition, surface) == "lake-deep" then						-- IF IsWater is FALSE then
				WASearched[PositionToString(SearchPosition)] = true							-- GridRef has been Searched
			else																	-- ELSE IsWater is TRUE then
				if fluidname == "water" or fluidname == "water-green" or fluidname == "water-shallow" or fluidname == "water-mud" then					-- IF Water Type is "water"
					--WaterRepArea[#WaterRepArea+1] = {["name"] = "sand-3" , ["position"] = {["x"] = SearchPosition.x, ["y"] = SearchPosition.y},["OriginalName"] = fluidname}
					if fluidname == "water" or fluidname == "water-green" then
						FA["ShallowWater"] = FA["ShallowWater"] + 1
					elseif fluidname == "water-shallow" then
						FA["ShallowWater-Shallow"] = FA["ShallowWater-Shallow"] + 1
					elseif fluidname == "water-mud" then
						FA["ShallowWater-Mud"] = FA["ShallowWater-Mud"] + 1
					end
					if EdgePattern(SearchPosition) == true then
						WaterEdgeArea[#WaterEdgeArea+1] = {["name"] = "lake-shallow" , ["position"] = {["x"] = SearchPosition.x, ["y"] = SearchPosition.y},["OriginalName"] = fluidname}
						
					end
				elseif fluidname == "deepwater" or fluidname == "deepwater-green" then
					FA["DeepWater"] = FA["DeepWater"] + 1
					if EdgePattern(SearchPosition) == true then
						WaterEdgeArea[#WaterEdgeArea+1] = {["name"] = "lake-deep" , ["position"] = {["x"] = SearchPosition.x, ["y"] = SearchPosition.y},["OriginalName"] = fluidname}
						
					end
				end
				if WaterGArea["MinX"] > SearchPosition.x then
					WaterGArea["MinX"] = SearchPosition.x
				end
				if WaterGArea["MaxX"] < SearchPosition.x then
					WaterGArea["MaxX"] = SearchPosition.x
				end
				if WaterGArea["MinY"] > SearchPosition.y then
					WaterGArea["MinY"] = SearchPosition.y
				end
				if WaterGArea["MaxY"] < SearchPosition.y then
					WaterGArea["MaxY"] = SearchPosition.y
				end
				WASearched[PositionToString(SearchPosition)] = true									-- Make SearchPosition TRUE in WASerached
			end	
			table.remove (WASearchQueue,1)																		-- IF IsWater isn't TRUE or False 
		else
			table.remove (WASearchQueue,1)				-- Remove from WASearchQueue
		end
		SearchAmount = SearchAmount - 1
	end
	::NOSEARCH::
	FA["ToSearch"] = WASearchQueue
	FA["HasSearched"] = WASearched
	local DebugQueue = settings.global["FluidArea-DebugQueueLength"].value
	if DebugQueue == true then
		game.print(#WASearchQueue)
	end
	if #WASearchQueue == 0 then
		storage.WaterGlobalArea[a]["ToSearch"] = nil
		-- storage.WaterGlobalArea[a]["HasSearched"] = nil
		-- local wateredgeposition = {}
		-- local wateredgepositionxtemp = {}
		-- local wateredgepositionx = storage.WaterGlobalArea[a]["WaterEdgeAreaX"]
		-- local wateredgepositionytemp = {}
		-- local wateredgepositiony = storage.WaterGlobalArea[a]["WaterEdgeAreaY"]
		-- local maxx = 0
		-- local minx = 0
		-- local maxy = 0
		-- local miny = 0
		-- for c = 1, #WaterEdgeArea, 1 do
			-- wateredgeposition[#wateredgeposition+1] = WaterEdgeArea[c]["position"]
		-- end
		-- for c = 1, #wateredgeposition, 1 do		-- Extract Position for X
			-- wateredgepositionxtemp[#wateredgepositionxtemp+1] = wateredgeposition[c]["x"]
			-- wateredgepositionytemp[#wateredgepositionytemp+1] = wateredgeposition[c]["y"]
		-- end
		-- local hashx = {}
		-- for _,v in ipairs(wateredgepositionxtemp) do
			-- if (not hashx[v]) then
				-- wateredgepositionx[#wateredgepositionx+1] = v 
				-- hashx[v] = true
			-- end
		-- end
		-- table.sort(wateredgepositionx)					-- Sort for Position X
		-- local hashy = {}
		-- for _,v in ipairs(wateredgepositionytemp) do
			-- if (not hashy[v]) then
				-- wateredgepositiony[#wateredgepositiony+1] = v 
				-- hashy[v] = true
			-- end
		-- end
		-- table.sort(wateredgepositiony)					-- Sort for Position Y
		-- minx = wateredgepositionx[1]					-- Save Min X (Left)
		-- maxx = wateredgepositionx[#wateredgepositionx]	-- Save Max X (Right)
		-- miny = wateredgepositiony[1]
		-- maxy = wateredgepositiony[#wateredgepositiony]
		local minx = WaterGArea["MinX"]
		local maxx = WaterGArea["MaxX"]
		local miny = WaterGArea["MinY"]
		local maxy = WaterGArea["MaxY"]
		WaterGArea["Hdif"] = maxx - minx
		WaterGArea["Vdif"] = maxy - miny
		WaterGArea["Hyp"] = math.sqrt(((maxx - minx)^2) + ((maxy - miny)^2))
	end
end

function FluidAreaContinue(a)
	GetWaterArea(a)
	CalculatedWaterTotal(a)
	storage.WaterGlobalArea[a]["LoopCount"] = storage.WaterGlobalArea[a]["LoopCount"] + 1
	local AlarmEnabled = settings.get_player_settings(game.players[1])["Alarms-Continuing-Search"].value
	if storage.WaterGlobalArea[a]["LoopCount"] == 20 and AlarmEnabled == true then
		storage.WaterGlobalArea[a]["LoopCount"] = 0
		game.print(string.format("Still Scanning FluidArea %s", a))
	end
	if storage.WaterGlobalArea[a]["ToSearch"] == nil then
		storage.WaterGlobalArea[a]["LoopCount"] = 0
		if storage.WaterGlobalArea[a]["WtrName"] == "None" or storage.WaterGlobalArea[a]["WtrName"] == "Puddle" or storage.WaterGlobalArea[a]["WtrName"] == "Well" or storage.WaterGlobalArea[a]["WtrName"] == "Pond"  then
				waterbodies.WtrName(a)
		end
		game.print(string.format("%s created, with %sL of %s with regen %sL.", storage.WaterGlobalArea[a]["WtrName"], comma_value(storage.WaterGlobalArea[a]["AmountWtr"]), storage.WaterGlobalArea[a]["FluidType"], storage.WaterGlobalArea[a]["RegenAmount"]))

		MapMarker(a)
	end
end

function CalculatedWaterTotal(a)
	local Shallow = storage.WaterGlobalArea[a]["ShallowWater"]
	local ShallowS = storage.WaterGlobalArea[a]["ShallowWater-Shallow"]
	local ShallowM = storage.WaterGlobalArea[a]["ShallowWater-Mud"]
	local Deep = storage.WaterGlobalArea[a]["DeepWater"]
	local TechYRBoost = storage.WaterGlobalArea[a]["TechYRBoost"]
	local TotalArea = (Shallow + ShallowS + ShallowM + Deep)
	storage.WaterGlobalArea[a]["BTF"] = TotalArea
	local WATER = settings.global["TileFluidAmount-Shallow"].value
	local DEEPWATER = settings.global["TileFluidAmount-Deep"].value
	local PBonus = 0.01 
	local WBonus = 0.5 
	local PDBonus = 1 
	local LBonus = 1.5 
	local GLBonus = 2 
	local SBonus = 2.5 
    local OBonus = 3 
	local WaterTotal = (Shallow * WATER) + (Deep * DEEPWATER) + (ShallowS * (WATER/2)) + (ShallowM * (WATER/4))
	local WaterBodyType = 0
	
	if TotalArea < 4 then
		--game.print("PUDDLE")
		storage.WaterGlobalArea[a]["AmountWtr"] = WaterTotal * PBonus * TechYRBoost
		storage.WaterGlobalArea[a]["AmountBonusValue"] = PBonus
		storage.WaterGlobalArea[a]["WtrName"] = "Puddle"
		storage.WaterGlobalArea[a]["WaterBodyType"] = 0
	elseif TotalArea == 4 then
		--game.print("WELL")
		storage.WaterGlobalArea[a]["AmountWtr"] = WaterTotal * WBonus * TechYRBoost
		storage.WaterGlobalArea[a]["AmountBonusValue"] = WBonus
		storage.WaterGlobalArea[a]["WtrName"] = "Well"
		storage.WaterGlobalArea[a]["WaterBodyType"] = 1
	elseif TotalArea > 4 and TotalArea <= 200 then
		--game.print("POND")
		storage.WaterGlobalArea[a]["AmountWtr"] = WaterTotal * PDBonus * TechYRBoost
		storage.WaterGlobalArea[a]["AmountBonusValue"] = PDBonus
		storage.WaterGlobalArea[a]["WtrName"] = "Pond"
		storage.WaterGlobalArea[a]["WaterBodyType"] = 2
	elseif TotalArea > 200 and TotalArea <= 6000 then
		--game.print("LAKE")
		storage.WaterGlobalArea[a]["AmountWtr"] = WaterTotal * LBonus * TechYRBoost
		storage.WaterGlobalArea[a]["AmountBonusValue"] = LBonus
		storage.WaterGlobalArea[a]["WaterBodyType"] = 3
	elseif TotalArea > 6000 and TotalArea <= 60000 then
		--game.print("GREAT LAKE")
		storage.WaterGlobalArea[a]["AmountWtr"] = WaterTotal * GLBonus * TechYRBoost
		storage.WaterGlobalArea[a]["AmountBonusValue"] = GLBonus
		storage.WaterGlobalArea[a]["WaterBodyType"] = 4
	elseif TotalArea > 60000 and TotalArea <= 600000 then
		--game.print("SEA")
		storage.WaterGlobalArea[a]["AmountWtr"] = WaterTotal * SBonus * TechYRBoost
		storage.WaterGlobalArea[a]["AmountBonusValue"] = SBonus
		storage.WaterGlobalArea[a]["WaterBodyType"] = 5
	else
		--game.print("OCEAN")
		storage.WaterGlobalArea[a]["AmountWtr"] = WaterTotal * OBonus
		storage.WaterGlobalArea[a]["AmountBonusValue"] = OBonus
		storage.WaterGlobalArea[a]["WaterBodyType"] = 6
	end
	local RegenOff = settings.global["Disable-FluidArea-RegenRate"].value
	if RegenOff == false then
		local RegenRate = settings.global["FluidArea-RegenRate"].value / 10000
		RegenAmount = (RegenRate * TotalArea) * TechYRBoost
	else
		RegenAmount = 0
	end
	storage.WaterGlobalArea[a]["RegenAmount"] = RegenAmount
end

function comma_value(n) -- credit http://richard.warburton.it
	local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
	return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end

function MapMarker(a)
	if settings.global["Map-EnableMarkers"].value == true then
		local MapMarker = storage.WaterGlobalArea[a]["MapMarker"]
		local LMapMarker = #storage.WaterGlobalArea[a]["MapMarker"]
		local WGA = storage.WaterGlobalArea[a]
		--for b = 1, #storage.PlayerForces, 1 do
			for c = 1, LMapMarker, 1 do
				--if MapMarker[c]["force"] == storage.PlayerForces[b]["name"] then
					if MapMarker[c]["icon"] == nil or MapMarker[c]["icon"].valid == false or MapMarker[c]["placed"] == false then
						storage.WaterGlobalArea[a]["MapMarker"][c]["placed"] = false
						MapMarkerPlace(a)
					elseif MapMarker[c]["icon"].valid == true and WGA["ToSearch"] == nil and WGA["Depleted"] ~= 1 then
						local maptext = string.format("%s - %s - %.2f %%",storage.WaterGlobalArea[a]["WtrName"],comma_value(math.ceil(storage.WaterGlobalArea[a]["AmountWtr"]*((100-storage.WaterGlobalArea[a]["Percent"])/100))),100-storage.WaterGlobalArea[a]["Percent"])
						storage.WaterGlobalArea[a]["MapMarker"][c]["icon"].icon = {type="fluid",name=storage.WaterGlobalArea[a]["FluidType"]}
						storage.WaterGlobalArea[a]["MapMarker"][c]["icon"].text = maptext
					elseif MapMarker[c]["icon"].valid == true and WGA["ToSearch"] == nil and WGA["Depleted"] == 1 then
						local maptext = string.format("%s - %s",storage.WaterGlobalArea[a]["WtrName"],"Depleted")
						storage.WaterGlobalArea[a]["MapMarker"][c]["icon"].text = maptext
					end
				--end
			end
		--end
	else
		for b = 1, #storage.PlayerForces, 1 do
			local MapMarker = storage.WaterGlobalArea[a]["MapMarker"]
			local LMapMarker = #storage.WaterGlobalArea[a]["MapMarker"]
			for c = 1, LMapMarker, 1 do
				if MapMarker[c]["placed"] == true then
					storage.WaterGlobalArea[a]["MapMarker"][c]["placed"] = false
				end
			end
		end
	end
end

function MapMarkerPlace(a)
	if settings.global["Map-EnableMarkers"].value == true then
		local MapMarker = storage.WaterGlobalArea[a]["MapMarker"]
		local LMapMarker = #storage.WaterGlobalArea[a]["MapMarker"]
		local maptext = "Pending..."
		for b = 1, #storage.PlayerForces, 1 do
			for c = 1, LMapMarker, 1 do
				if MapMarker[c]["force"] == storage.PlayerForces[b]["name"] then
					if MapMarker[c]["placed"] == false then
						storage.WaterGlobalArea[a]["MapMarker"][c]["placed"] = true
						if #storage.WaterGlobalArea[a]["WaterRepArea"] > 0 then
							storage.WaterGlobalArea[a]["MapMarker"][c]["icon"] = game.forces[storage.PlayerForces[b]["name"]].add_chart_tag(storage.WaterGlobalArea[a]["Surface"],{["position"]= storage.WaterGlobalArea[a]["WaterRepArea"][1]["position"],["text"] = maptext})
						else
							storage.WaterGlobalArea[a]["MapMarker"][c]["icon"] = game.forces[storage.PlayerForces[b]["name"]].add_chart_tag(storage.WaterGlobalArea[a]["Surface"],{["position"]= storage.WaterGlobalArea[a]["WaterEdgeArea"][1]["position"],["text"] = maptext})
						end         
					end
				end
			end
		end
	end
end

function CorrectPump()
	if storage.OPLocate[#storage.OPLocate]["entity"].valid then
		if storage.OPLocate[#storage.OPLocate]["entity"]["name"] == "offshore-pump" or storage.OPLocate[#storage.OPLocate]["entity"]["name"] == "kr-electric-offshore-pump"then
			if storage.OPLocate[#storage.OPLocate]["tile"] == "crude-oil" then
				local OPE = storage.OPLocate[#storage.OPLocate]["entity"]
				local OPD = OPE.direction
				local OPP = OPE.position
				local OPSp = storage.OPLocate[#storage.OPLocate]["spritepos"]
				local OPS = OPE.surface
				local OPF = OPE.force
				local OPPl = OPE.last_user
				OPE.destroy()
				local OPN = game.surfaces[OPS.name].create_entity{name="offshore-crude-oil-pump",position = OPSp,direction = OPD,force = OPF,player=OPPl}
				if OPN ~= nil then
					storage.OPLocate[#storage.OPLocate]["entity"] = OPN
				else
					game.players[OPN.last_user.name].print("Offshore Pump - Crude Oil cannot be placed here. Returned Pump")
					game.players[OPN.last_user.name].insert{name="offshore-pump",count=1}
					return false
				end
			end
		end
	else
		game.player.print("Invalid Pump")
	end
end

function CorrectedFluid(tile)
	if tile == "crude-oil-deep" or tile == "crude-oil" then
		correctedtile = "crude-oil"
	else
		correctedtile = "water"
	end
	return correctedtile
end

function OffshoreForce(OPforce,ODforce)
	InitalForce = false
	NotFound = false
	if storage.Type == 1 then
		Offpump = storage.OPLocate
		LOffpump = #storage.OPLocate
		Force = OPforce
	elseif storage.Type == 2 then
		Offpump = storage.ODLocate
		LOffpump = #storage.ODLocate
		Force = ODforce
	end
	if storage.PlayerForces == nil or #storage.PlayerForces == 0 then
		storage.PlayerForces[#storage.PlayerForces+1] = {["name"] = Force, ["OPcount"] = 0, ["ODcount"] = 0, ["WaterFlow"] = 0, ["LastWaterFlow"] = 0, ["CrudeFlow"] = 0, ["LastCrudeFlow"] = 0, ["TechYRBoost"] = 0}
		if storage.Type == 1 then
			storage.PlayerForces[1]["OPcount"] = 1
		elseif storage.Type == 2 then
			storage.PlayerForces[1]["ODcount"] = 1
		end
		InitalForce = true
	elseif #storage.PlayerForces > 0 then
		for a = 1, #storage.PlayerForces, 1 do
			if storage.PlayerForces[a]["name"] == Force then
				if storage.Type == 1 then
					storage.PlayerForces[a]["OPcount"] = storage.PlayerForces[a]["OPcount"] + 1
				elseif storage.Type == 2 then
					storage.PlayerForces[a]["ODcount"] = storage.PlayerForces[a]["ODcount"] + 1
				end
				goto Found
			end
		end
		NotFound = true
		::Found::
	end
	if InitalForce == false and NotFound == true then
		storage.PlayerForces[#storage.PlayerForces+1] = {["name"] = OPforce, ["OPcount"] = 0, ["ODcount"] = 0, ["WaterFlow"] = 0, ["LastWaterFlow"] = 0, ["CrudeFlow"] = 0, ["LastCrudeFlow"] = 0, ["TechYRBoost"] = 0}
		if storage.Type == 1 then
			storage.PlayerForces[#storage.PlayerForces]["OPcount"] = storage.PlayerForces[#storage.PlayerForces]["OPcount"] + 1
		elseif storage.Type == 2 then
			storage.PlayerForces[#storage.PlayerForces]["ODcount"] = storage.PlayerForces[#storage.PlayerForces]["ODcount"] + 1
		end
	end
end

-- ON TICK DEPENDANT FUNCTIONS -- 

function RegenWater(a)
	local DisableRegen = settings.global["Disable-FluidArea-RegenRate"].value
	local WGA = storage.WaterGlobalArea
	if DisableRegen == false and WGA[a]["FluidType"] == "water" and WGA[a]["Percent"] > 0 and WGA[a]["Percent"] <= 99 and WGA[a]["Depleted"] ~= 1 then
		local WGA = storage.WaterGlobalArea
		if WGA[a]["WtrUsed"] - WGA[a]["RegenAmount"] <= 0 then
			WGA[a]["WtrUsed"] = 0
		else
			WGA[a]["WtrUsed"] = WGA[a]["WtrUsed"] - (WGA[a]["RegenAmount"] * 6)
		end
		WGA[a]["PercentPrev"] = WGA[a]["Percent"]
		WGA[a]["Percent"] = (WGA[a]["WtrUsed"] / WGA[a]["AmountWtr"]) * 100
		PercentChange = WGA[a]["PercentPrev"] - WGA[a]["Percent"]
		-- game.print(WGA[a]["Percent"])
	end	
end

function EverySec()
	for a = 1, #storage.WaterGlobalArea, 1 do
		if storage.WaterGlobalArea[a]["ToSearch"] ~= nil then
			FluidAreaContinue(a)
		end
		if #storage.LandFill > 0 then
			LandFill(a)
		end
		RegenWater(a)
		MapMarker(a)
	end
end

function EmptyDrainPipes(a)
	local ODL = storage.ODLocate
	for b = 1, #ODL, 1 do
		local WGA = storage.WaterGlobalArea
		if WGA[a]["WGAID"] == ODL[b]["WA"] and WGA[a]["Depleted"] ~= 1 and ODL[b]["Active"] == 1 and ODL[b]["entity"].neighbours[1][1] and ODL[b]["entity"].neighbours[1][1].fluidbox[1] ~= nil and WGA[a]["FluidType"] == ODL[b]["PipeFluid"] and ODL[b]["entity"].neighbours[1][1].get_fluid_count() > 0.005 then
			if ODL[b]["entity"].neighbours[1][1]["name"] == "storage-tank" then
				fluid = ODL[b]["entity"].neighbours[1][1].fluidbox[1]
				if fluid.amount >= 20 then
					fluid.amount = (20 * 6)
				elseif fluid.amount < 20 and fluid.amount > 0 then
					fluid.amount = (fluid.amount * 6)
				elseif fluid.amount == 0 then
					fluid.amount = 0
				end
				ODL[b]["entity"].neighbours[1][1].remove_fluid{name=fluid.name,amount=fluid.amount}
			else
				fluid = ODL[b]["entity"].neighbours[1][1].fluidbox[1]
				if fluid.amount >= 20 then
					fluid.amount = (20 * 6)
				elseif fluid.amount < 20 and fluid.amount > 0 then
					fluid.amount = (fluid.amount * 6)
				elseif fluid.amount == 0 then
					fluid.amount = 0
				end
				ODL[b]["entity"].neighbours[1][1].remove_fluid{name=fluid.name,amount=fluid.amount}
			end
		end
		for d = 1, #storage.WaterGlobalArea[a]["WtrAdd"], 1 do
			if storage.WaterGlobalArea[a]["WtrAdd"][d]["force"] == storage.ODLocate[b]["force"] then
				WGA[a]["WtrAdd"][d]["count"] = 0
			end
		end
	end
 end
 
function AssignTiles(a)
	local WGA = storage.WaterGlobalArea
	local WGAA = WGA[a]["ShallowWater"] + WGA[a]["DeepWater"]
	local WGAT = WGA[a]["WaterRepArea"]
	local WGAFT = WGA[a]["FluidType"]
	if PercentChange < 0 and WGA[a]["TilesSet"] ~= "P" then -- IF WATERAREA IS BEING DEPLETED (PUMPS IN CHARGE)
		for b = 1, WGAA, 1 do
			if WGAT[b] ~= nil then
				if WGAT[b]["OriginalName"] == "water" or WGAT[b]["OriginalName"] == "crude-oil" or WGAT[b]["OriginalName"] == "water-green" or WGAT[b]["OriginalName"] == "water-shallow" or WGAT[b]["OriginalName"] == "water-mud" then
					WGA[a]["WaterRepArea"][b]["name"] = "lake-shallow"
				elseif WGAT[b]["OriginalName"] == "deepwater" or WGAT[b]["OriginalName"] == "crude-oil-deep" or WGAT[b]["OriginalName"] == "deepwater-green" then
					WGA[a]["WaterRepArea"][b]["name"] = "lake-deep"
				end
			end
		end
		WGA[a]["TilesSet"] = "P"
	elseif PercentChange > 0 and WGA[a]["TilesSet"] ~= "D" then -- ELSE WATERAREA IS BEING FILLED (DRAINS IN CHARGE)
		for b = 1, WGAA, 1 do
			if WGAT[b] ~= nil then
				if WGAT[b]["name"] == "lake-shallow" or WGAT[b]["name"] == "sand-3" then
					if WGAFT == "water" then
						if WGAT[b]["OriginalName"] == "water" then
							WGA[a]["WaterRepArea"][b]["name"] = "water"
						elseif WGAT[b]["OriginalName"] == "water-green" then
							WGA[a]["WaterRepArea"][b]["name"] = "water-green"
						elseif WGAT[b]["OriginalName"] == "water-shallow" then
							WGA[a]["WaterRepArea"][b]["name"] = "water-shallow"
						elseif WGAT[b]["OriginalName"] == "water-mud" then
							WGA[a]["WaterRepArea"][b]["name"] = "water-mud"
						end
					else
						WGA[a]["WaterRepArea"][b]["name"] = "crude-oil"
					end
				elseif WGAT[b]["name"] == "lake-deep" or WGAT[b]["name"] == "dry-dirt" then
					if WGAFT == "water" then
						if WGAT[b]["OriginalName"] == "deepwater" then
							WGA[a]["WaterRepArea"][b]["name"] = "deepwater"
						elseif WGAT[b]["OriginalName"] == "deepwater-green" then
							WGA[a]["WaterRepArea"][b]["name"] = "deepwater-green"
						end
					else
						WGA[a]["WaterRepArea"][b]["name"] = "crude-oil-deep"
					end
				end
			end
		end
		WGA[a]["TilesSet"] = "D"
	end
end

function WaterRandom(a)
	local WGA = storage.WaterGlobalArea
	local WaterTiles = (WGA[a]["ShallowWater"] + WGA[a]["DeepWater"])
	local Surface = WGA[a]["Surface"]
	local finalper = 20
	local TilePerPercent = math.floor((WaterTiles / finalper) * 0.8)
	if TilePerPercent < 1 then
		TilePerPercent = 1
	end
	local randnotiles = math.random(1,TilePerPercent)
	for z = 1, randnotiles, 1 do
		local rand = math.random(1,WaterTiles)
		game.surfaces[Surface.name].set_tiles({WGA[a]["WaterRepArea"][rand]})
	end
	if PercentChange < 0 then
		WGA[a]["BTFE"] = WGA[a]["BTFE"] + 1
	elseif PercentChange > 1 then
		WGA[a]["BTFE"] = WGA[a]["BTFE"] - 1
	end
end

function BackToFront(a)
	local WGA = storage.WaterGlobalArea
	local WaterTiles = (WGA[a]["ShallowWater"] + WGA[a]["DeepWater"])
	local Surface = WGA[a]["Surface"]
	local TileCount = WGA[a]["BTF"]
	local WAArea = WGA[a]["WaterRepArea"]
	local finalper = 20
	local TilePerPercent = math.floor(WaterTiles / finalper)
	if TilePerPercent < 1 then
		TilePerPercent = 1
	end
	if PercentChange < 0 and TileCount ~= 0 then	-- PUMPS
		if TilePerPercent > TileCount then
			TilePerPercent = TileCount - 1
		end
		for b=TilePerPercent, 0, -1 do
			if WAArea[TileCount] ~= nil then
				--if WAArea[TileCount]["name"] == "sand-3" or WAArea[TileCount]["name"] == "dry-dirt" then
					game.surfaces[Surface.name].set_tiles({WAArea[TileCount]})
					WGA[a]["BTF"] = WGA[a]["BTF"] - 1
					TileCount = WGA[a]["BTF"]
				--end
			else
				WGA[a]["BTF"] = WGA[a]["BTF"] - 1
				TileCount = WGA[a]["BTF"]
			end
		end
		WGA[a]["BTFE"] = WGA[a]["BTFE"] + 1
	elseif PercentChange > 0 and TileCount <= WaterTiles then -- DRAINS
		if TileCount == 0 then
			TileCount = 1
		end
		for b=TilePerPercent, 0, -1 do
			if WAArea[TileCount] ~= nil then
				--if WAArea[TileCount]["name"] == "water" or WAArea[TileCount]["name"] == "deepwater" or WAArea[TileCount]["name"] == "crude-oil" or WAArea[TileCount]["name"] == "crude-oil-deep" then
					game.surfaces[Surface.name].set_tiles({WAArea[TileCount]})
					game.print("Setting Area to Fill With Water")
					WGA[a]["BTF"] = WGA[a]["BTF"] + 1
					TileCount = WGA[a]["BTF"]
				--end
				if TileCount > WaterTiles then
					TileCount = WaterTiles
				end
			else
				WGA[a]["BTF"] = WGA[a]["BTF"] + 1
				TileCount = WGA[a]["BTF"]
			end
		end
		WGA[a]["BTFE"] = WGA[a]["BTFE"] - 1
	end
end

function RegenWaterEdge(a)
	local WGA = storage.WaterGlobalArea
	local surface = WGA[a]["Surface"]
	local WAArea = WGA[a]["WaterEdgeArea"]
	local TilesToReplace = {}
	local TpP = (WGA[a]["Hyp"]) / 20
	if TpP < 1 then
		TpP = 1
	end
	CirR = (((WGA[a]["Hyp"]-(WGA[a]["BTFE"]*TpP))+1)^2)
	if CirR < 0 or WGA[a]["Percent"] == 100 then
		CirR = 0
	end
	CirA = WGA[a]["WaterEdgeArea"][1]["position"]["x"]
	CirB = WGA[a]["WaterEdgeArea"][1]["position"]["y"]
	Fluid = WGA[a]["FluidType"]
	for c = 1, #WAArea, 1 do
		CirY = WAArea[c]["position"]["y"]
		for d = WAArea[c]["position"]["x"], WGA[a]["MaxX"], 1 do
			CirX = d
			local SearchPosition = {x = CirX ,y = CirY}
			local Cir = ((CirX - CirA)^2) + ((CirY - CirB)^2)
			if Cir <= CirR then -- Inside/On the Boundary
				--game.print("InSide Boundary")
				if IsWater(SearchPosition, surface.name) == "lake-shallow" then
					if Fluid == "water" then
						table.insert(TilesToReplace,{name = "water" , position = {x = CirX ,y = CirY}})
					elseif Fluid == "crude-oil" then
						table.insert(TilesToReplace,{name = "crude-oil" , position = {x = CirX ,y = CirY}})
					else
						table.insert(TilesToReplace,{name = "water" , position = {x = CirX ,y = CirY}})
					end
					--game.print("Water")
				elseif IsWater(SearchPosition, surface.name) == "lake-deep" then
					if Fluid == "water" then
						table.insert(TilesToReplace,{name = "deepwater" , position = {x = CirX ,y = CirY}})
					elseif Fluid == "crude-oil" then
						table.insert(TilesToReplace,{name = "crude-oil-deep" , position = {x = CirX ,y = CirY}})
					else
						table.insert(TilesToReplace,{name = "deepwater" , position = {x = CirX ,y = CirY}})
					end
					--game.print("Deepwater")
				elseif IsWater(SearchPosition, surface.name) == false then
					--game.print("Land")
					goto ItsLand2
				end
			end
		end
		::ItsLand2::
	end
	game.surfaces[surface.name].set_tiles(TilesToReplace, true)
end

function BackToFrontEdge(a)
	local WGA = storage.WaterGlobalArea
	local PGT = storage.OPLocate
	local DGT = storage.ODLocate
	local surface = WGA[a]["Surface"]
	local WAArea = WGA[a]["WaterEdgeArea"]
	local TilesToReplace = {}
	-- ((x-a)^2 + (y-b)^2) = r^2
	local CirA = 0
	local CirB = 0
	local TpP = (WGA[a]["Hyp"]) / 20
	if TpP < 1 then
		TpP = 1
	end
	CirR = (((WGA[a]["Hyp"]-(WGA[a]["BTFE"]*TpP))+1)^2)
	if CirR < 0 or WGA[a]["Percent"] == 100 then
		CirR = 0
	end
	if PercentChange < 0 then	-- PUMPS
		for b = 1, #PGT, 1 do
			if PGT[b]["WA"] == WGA[a]["WGAID"] then
				CirA = PGT[b]["position"]["x"]
				CirB = PGT[b]["position"]["y"]
				for c = 1, #WAArea, 1 do
					CirY = WAArea[c]["position"]["y"]
					for d = WAArea[c]["position"]["x"], WGA[a]["MaxX"], 1 do
						CirX = d
						local SearchPosition = {x = CirX ,y = CirY}
						local Cir = ((CirX - CirA)^2) + ((CirY - CirB)^2)
						if Cir >= CirR then -- Outside/On the Boundary
							--game.print("OutSide Boundary")
							if IsWater(SearchPosition, surface.name) == "shallow" or IsWater(SearchPosition, surface.name) == "crude-oil" then
								table.insert(TilesToReplace,{name = "lake-shallow" , position = {x = CirX ,y = CirY}})
								--game.print("Shallow")
							elseif IsWater(SearchPosition, surface.name) == "deep" or IsWater(SearchPosition, surface.name) == "crude-oil-deep" then
								table.insert(TilesToReplace,{name = "lake-deep" , position = {x = CirX ,y = CirY}})
								--game.print("Deep")
							elseif IsWater(SearchPosition, surface.name) == false then
								--game.print("Land")
								goto ItsLand
							end
						end
					end
					::ItsLand::
				end
				goto FoundCircCos
			end
		end
		::FoundCircCos::
		game.surfaces[surface.name].set_tiles(TilesToReplace, true)
		WGA[a]["BTFE"] = WGA[a]["BTFE"] + 1
	elseif PercentChange > 0 then -- DRAINS
		for b = 1, #DGT, 1 do
			if DGT[b]["WA"] == WGA[a]["WGAID"] then
				CirA = DGT[b]["position"]["x"]
				CirB = DGT[b]["position"]["y"]
				Fluid = DGT[b]["PipeFluid"]
				for c = 1, #WAArea, 1 do
					CirY = WAArea[c]["position"]["y"]
					for d = WAArea[c]["position"]["x"], WGA[a]["MaxX"], 1 do
						CirX = d
						local SearchPosition = {x = CirX ,y = CirY}
						local Cir = ((CirX - CirA)^2) + ((CirY - CirB)^2)
						if Cir <= CirR then -- Inside/On the Boundary
							--game.print("InSide Boundary")
							if IsWater(SearchPosition, surface.name) == "lake-shallow" then
								if Fluid == "water" then
									table.insert(TilesToReplace,{name = "water" , position = {x = CirX ,y = CirY}})
								elseif Fluid == "crude-oil" then
									table.insert(TilesToReplace,{name = "crude-oil" , position = {x = CirX ,y = CirY}})
								else
									table.insert(TilesToReplace,{name = "water" , position = {x = CirX ,y = CirY}})
								end
								--game.print("Water")
							elseif IsWater(SearchPosition, surface.name) == "lake-deep" then
								if Fluid == "water" then
									table.insert(TilesToReplace,{name = "deepwater" , position = {x = CirX ,y = CirY}})
								elseif Fluid == "crude-oil" then
									table.insert(TilesToReplace,{name = "crude-oil-deep" , position = {x = CirX ,y = CirY}})
								else
									table.insert(TilesToReplace,{name = "deepwater" , position = {x = CirX ,y = CirY}})
								end
								--game.print("Deepwater")
							elseif IsWater(SearchPosition, surface.name) == false then
								--game.print("Land")
								goto ItsLand2
							end
						end
					end
					::ItsLand2::
				end
				goto FoundCircCos2
			end
		end
		::FoundCircCos2::
		game.surfaces[surface.name].set_tiles(TilesToReplace, true)
		WGA[a]["BTFE"] = WGA[a]["BTFE"] - 1
	end
end

function AddedWaterArea(a)
	local WGA = storage.WaterGlobalArea
	if WGA[a]["AmountWtr"] ~= WGA[a]["WtrUsed"] and WGA[a]["Percent"] > 0 then
		local Percent = WGA[a]["Percent"]
		local WA = WGA[a]
		local LowAlarmEnabled = settings.global["Alarms-Low-Level"].value
		local HighAlarmEnabled = settings.global["Alarms-High-Level"].value
		if Percent < 100 and Percent >= 80 then
			WGA[a]["Depleted"] = 0
			local RP = WA["RandPercent"]
			if Percent <= 80 + WGA[a]["BTFE"] then
				local Method = settings.global["FluidArea-Replace-Method"].value
				if #WGA[a]["WaterRepArea"] > 0 then
					if Method == "Random" then
						WaterRandom(a)
					elseif Method == "From/To Pump" then
						BackToFront(a)
					end
				else
					BackToFrontEdge(a)
					RegenWaterEdge(a)
				end
				WA["RandPercent"] = Percent
			end
			if Percent < 99 and WA["Fired99"] == true and HighAlarmEnabled == true then
				WA["Fired99"] = false
			elseif Percent < 98 and WA["Fired98"] == true and HighAlarmEnabled == true then
				WA["Fired98"] = false
			elseif Percent < 97 and WA["Fired97"] == true and HighAlarmEnabled == true then
				WA["Fired97"] = false
			elseif Percent < 95 and WA["Fired95"] == true and HighAlarmEnabled == true then
				WA["Fired95"] = false
			elseif Percent < 90 and WA["Fired90"] == true and HighAlarmEnabled == true then
				WA["Fired90"] = false
			end
		elseif Percent < 80 and Percent > 0 then
			WA["RandPercent"] = 79
			if Percent < 75 and WA["Fired75"] == true and LowAlarmEnabled == true then
				WA["Fired75"] = false
			elseif Percent < 50 and WA["Fired50"] == true and LowAlarmEnabled == true then
				WA["Fired50"] = false
			end
			if WA["Below80"] == 0 then
				if Method == "Random" then
					if #WGA[a]["WaterRepArea"] > 0 then
						game.surfaces[WA["Surface"].name].set_tiles(WA["WaterRepArea"])
					else
						--game.surfaces[WA["Surface"]].set_tiles(WA["WaterEdgeArea"])
						BackToFrontEdge(a)
						RegenWaterEdge(a)
					end
				elseif Method == "From/To Pump" then
					-- Should Be Filled
				end
				WA["Below80"] = 1
				WGA[a]["BTF"] = WGA[a]["ShallowWater"] + WGA[a]["DeepWater"]
				WGA[a]["BTFE"] = 0
			end
		elseif Percent <= 0 then
			-- DO NOTHING
		end
	end
end

function DepleatedWaterArea(a)
	local WGA = storage.WaterGlobalArea
	if WGA[a]["ToSearch"] == nil then
		if WGA[a]["Depleted"] ~= 1 then
			local Percent = WGA[a]["Percent"]
			local LowAlarmEnabled = settings.global["Alarms-Low-Level"].value
			local HighAlarmEnabled = settings.global["Alarms-High-Level"].value
			local WA = WGA[a]
			if Percent <= 49 then
				
			elseif Percent >= 50 and WA["Fired50"] == false and LowAlarmEnabled == true then
				for b = 1, #storage.PlayerForces, 1 do
					for c = 1, #WGA[a]["OPsA"], 1 do
						if storage.PlayerForces[b]["name"] == WGA[a]["OPsA"][c]["force"] then
							game.forces[storage.PlayerForces[b]["name"]].print(string.format("%s has used %.0f %% of available %s.",WA["WtrName"], WA["Percent"], WA["FluidType"]))
						end
					end
				end
				WA["Fired50"] = true
			elseif Percent >= 75 and WA["Fired75"] == false and LowAlarmEnabled == true then
				for b = 1, #storage.PlayerForces, 1 do
					for c = 1, #WGA[a]["OPsA"], 1 do
						if storage.PlayerForces[b]["name"] == WGA[a]["OPsA"][c]["force"] then
							game.forces[storage.PlayerForces[b]["name"]].print(string.format("%s has used %.0f %% of available %s.",WA["WtrName"], WA["Percent"], WA["FluidType"]))
						end
					end
				end
				WA["Fired75"] = true
			elseif Percent >= 80 and Percent < 100 then
				WA["Below80"] = 0
				local RP = WA["RandPercent"]
				if Percent >= 80 + WGA[a]["BTFE"] then
					Method = settings.global["FluidArea-Replace-Method"].value
					if #WGA[a]["WaterRepArea"] > 0 then
						if Method == "Random" then
							WaterRandom(a)
						elseif Method == "From/To Pump" then
							BackToFront(a)
						end
					else
						BackToFrontEdge(a)
					end
					WA["RandPercent"] = Percent
				end
				if Percent >= 90 and WA["Fired90"] == false and LowAlarmEnabled == true then
					for b = 1, #storage.PlayerForces, 1 do
						for c = 1, #WGA[a]["OPsA"], 1 do
							if storage.PlayerForces[b]["name"] == WGA[a]["OPsA"][c]["force"] then
								game.forces[storage.PlayerForces[b]["name"]].print(string.format("%s has used %.0f %% of available %s.",WA["WtrName"], WA["Percent"], WA["FluidType"]))
							end
						end
					end
					WA["Fired90"] = true
				elseif Percent >= 95 and WA["Fired95"] == false and HighAlarmEnabled == true then
					for b = 1, #storage.PlayerForces, 1 do
						for c = 1, #WGA[a]["OPsA"], 1 do
							if storage.PlayerForces[b]["name"] == WGA[a]["OPsA"][c]["force"] then
								game.forces[storage.PlayerForces[b]["name"]].print(string.format("%s has used %.0f %% of available %s.",WA["WtrName"], WA["Percent"], WA["FluidType"]))
							end
						end
					end
					WA["Fired95"] = true
				elseif Percent >= 97 and WA["Fired97"] == false and HighAlarmEnabled == true then
					for b = 1, #storage.PlayerForces, 1 do
						for c = 1, #WGA[a]["OPsA"], 1 do
							if storage.PlayerForces[b]["name"] == WGA[a]["OPsA"][c]["force"] then
								game.forces[storage.PlayerForces[b]["name"]].print(string.format("%s has used %.0f %% of available %s.",WA["WtrName"], WA["Percent"], WA["FluidType"]))
							end
						end
					end
					WA["Fired97"] = true
				elseif Percent >= 98 and WA["Fired98"] == false and HighAlarmEnabled == true then
					for b = 1, #storage.PlayerForces, 1 do
						for c = 1, #WGA[a]["OPsA"], 1 do
							if storage.PlayerForces[b]["name"] == WGA[a]["OPsA"][c]["force"] then
								game.forces[storage.PlayerForces[b]["name"]].print(string.format("%s has used %.0f %% of available %s.",WA["WtrName"], WA["Percent"], WA["FluidType"]))
							end
						end
					end
					WA["Fired98"] = true
				elseif Percent >= 99 and WA["Fired99"] == false and HighAlarmEnabled == true then
					for b = 1, #storage.PlayerForces, 1 do
						for c = 1, #WGA[a]["OPsA"], 1 do
							if storage.PlayerForces[b]["name"] == WGA[a]["OPsA"][c]["force"] then
								game.forces[storage.PlayerForces[b]["name"]].print(string.format("%s has used %.0f %% of available %s.",WA["WtrName"], WA["Percent"], WA["FluidType"]))
							end
						end
					end
					WA["Fired99"] = true
				end		
			elseif Percent >= 100 then 
				if storage.NewInstall == false then
					for z = 1, #storage.OPLocate, 1 do
						local OP = storage.OPLocate[z]
						if OP["WA"] == WGA[a]["WGAID"] and OP["name"] ~= "offshore-pump-nofluid" then
							local OPD = OP["direction"]
							local OPE = OP["entity"]
							local OPP = OP["position"]
							local OPSp = OP["spritepos"]
							local OPS = OP["surface"]
							local OPF = OPE.force
							local OPPl = OPE.last_user
							if OP["Active"] == 1 then
								OP["Active"] = 0
								ActiveOPs = ActiveOPs - 1
								for y =1, #storage.WaterGlobalArea[a]["OPsA"], 1 do
									if storage.WaterGlobalArea[a]["OPsA"][y]["force"] == OP["force"] then
										WA["OPsA"][y]["count"] = WA["OPsA"][y]["count"] - 1
									end
								end								
							end
							if script.active_mods["aai-industry"] then
								local x = OPP.x
								local y = OPP.y
								if OPD == 0 then
									AS = game.surfaces[OPS.name].find_entities_filtered{position=OPSp,radius=1, name = "offshore-pump-output"}
								elseif OPD == 4 then
									AS = game.surfaces[OPS.name].find_entities_filtered{position=OPSp,radius=1, name = "offshore-pump-output"}
								elseif OPD == 2 then
									AS = game.surfaces[OPS.name].find_entities_filtered{position=OPSp,radius=1, name = "offshore-pump-output"}
								elseif OPD == 6 then
									AS = game.surfaces[OPS.name].find_entities_filtered{position=OPSp,radius=1, name = "offshore-pump-output"}
								end
								local Entity = AS[1]
								if Entity ~= nil then
									Entity.destroy()
								end
							end
							OPE.destroy()
							local OPNF = game.surfaces[OPS.name].create_entity{name="offshore-pump-nofluid",position = OPSp,direction = OPD,player = OPPl, force = "neutral"}
							storage.OPLocate[z]["entity"] = OPNF
						end
					end
					WGA[a]["Depleted"] = 1
					WGA[a]["Percent"] = 100
					WGA[a]["PercentPrev"] = 100
					WGA[a]["RandPercent"] = 100
					if #WGA[a]["WaterRepArea"] > 0 then
						game.surfaces[WA["Surface"].name].set_tiles(WGA[a]["WaterRepArea"])													
					else
						BackToFrontEdge(a)
					end
					WGA[a]["BTFE"] = 20
					WGA[a]["WtrUsed"] = WGA[a]["AmountWtr"]
					for b = 1, #storage.PlayerForces, 1 do
						for c = 1, #WGA[a]["OPsA"], 1 do
							if storage.PlayerForces[b]["name"] == WGA[a]["OPsA"][c]["force"] then
								game.forces[storage.PlayerForces[b]["name"]].print(string.format("%s has been depleted of %s.",WA["WtrName"], WA["FluidType"]))
							end
						end
					end
					WGA[a]["FluidType"] = "None"
					WGA[a]["BTF"] = 0
				else
					local CurrentTick = game.tick
					if CurrentTick < (storage.InstallTick + 18000) and storage.ITMessage == true then
						for b = 1, #storage.PlayerForces, 1 do
							for c = 1, #WGA[a]["OPsA"], 1 do
								if storage.PlayerForces[b]["name"] == WGA[a]["OPsA"][c]["force"] then
									game.forces[storage.PlayerForces[b]["name"]].print(string.format("Fluid Area Depletion Stopped on New/Mid Game Install. 5 Minutes from install till depletion."))
								end
							end
						end
						storage.ITMessage = false
					end
					if CurrentTick >= (storage.InstallTick + 18000) then
						for b = 1, #storage.PlayerForces, 1 do
							for c = 1, #WGA[a]["OPsA"], 1 do
								if storage.PlayerForces[b]["name"] == WGA[a]["OPsA"][c]["force"] then
									game.forces[storage.PlayerForces[b]["name"]].print(string.format("Fluid Area 5 Mins Over. Depleting Fluid Area."))
								end
							end
						end
						WGA[a]["Percent"] = 99
						storage.NewInstall = false
						storage.ITMessage = false
					end
				end
			end
		else
			local RemoveFromTable = settings.global["FluidArea-RemoveFromTable"].value
			if RemoveFromTable == true and storage.NewInstall == false then
				RemoveWAOPOD(a)
			end
		end
	end
end

function CalcWaterUse(a)
	local WGA = storage.WaterGlobalArea
	local GPF = storage.PlayerForces
	local LGPF = #storage.PlayerForces
	local WaterAreaUsed = WGA[a]["WtrUsed"]
	local WaterAreaAmount = WGA[a]["AmountWtr"]
	local WaterAreaPercent = WGA[a]["Percent"]
	TotalWaterFlowRate = 0
	TotalCrudeFlowRate = 0
	ForceCrudeAdjust = 0
	TotalWaterAreaDrained = 0
	TotalWaterAreaActivePumps = 0
	TotalWaterAreaActiveDrains = 0
	for b = 1, LGPF, 1 do
		TotalWaterFlowRate = TotalWaterFlowRate + GPF[b]["WaterFlow"] -- GPF[b]["LastWaterFlow"]
		for c = 1, #storage.FluidProducers, 1 do
			if storage.FluidProducers[c]["force"] == GPF[b]["name"] then
				ForceCrudeAdjust = ForceCrudeAdjust + storage.FluidProducers[c]["LastAmount"]
			end
		end
		TotalCrudeFlowRate = TotalCrudeFlowRate + GPF[b]["CrudeFlow"] - GPF[b]["LastCrudeFlow"] - ForceCrudeAdjust
		if WGA[a]["OPsA"][b] ~= nil then
			TotalWaterAreaActivePumps = TotalWaterAreaActivePumps + WGA[a]["OPsA"][b]["count"]
		end
		if WGA[a]["ODsA"][b] ~= nil then
			TotalWaterAreaActiveDrains = TotalWaterAreaActiveDrains + WGA[a]["ODsA"][b]["count"]
		end
		if WGA[a]["WtrAdd"][b] ~= nil then
			TotalWaterAreaDrained = TotalWaterAreaDrained + WGA[a]["WtrAdd"][b]["count"]
		end
	end
	if ActiveOPs == 0 then
		ActiveOPs = 1
	end
	local PumpRatio = TotalWaterAreaActivePumps / ActiveOPs
	if WGA[a]["FluidType"] == "water" then
		FluidFlowRate = TotalWaterFlowRate
	elseif WGA[a]["FluidType"] == "crude-oil" then
		FluidFlowRate = TotalCrudeFlowRate
	elseif WGA[a]["FluidType"] == nil or WGA[a]["FluidType"] == "None" then
		FluidFlowRate = 0
	end
	if FluidFlowRate < 0 then
		FluidFlowRate = 0
	end
	if not script.active_mods["Krastorio2"] then
		local check = TotalWaterAreaActivePumps * 20 * 6 -- 20 per Tick X 6 Tick Update Speed
		if FluidFlowRate > check then
			FluidFlowRate = TotalWaterAreaActivePumps * 20 * 6 
		end
	end
	local FluidRatePerPump = FluidFlowRate * PumpRatio
	if WaterAreaUsed == 0 then 
		--game.print("START UP")
		WGA[a]["WtrUsed"] = WaterAreaUsed + FluidRatePerPump
		WGA[a]["Depleted"] = 0
	elseif WaterAreaUsed < 0 then
		--game.print("WA < 0")
		WGA[a]["WtrUsed"] = 0
		WGA[a]["Depleted"] = 0
	elseif WaterAreaUsed == WaterAreaAmount then
		--game.print("WA = AMOUNT")
		WGA[a]["WtrUsed"] = (WaterAreaUsed - TotalWaterAreaDrained)
	elseif TotalWaterAreaDrained == 0 and TotalWaterAreaActiveDrains > 0 and WaterAreaPercent < 0.3 then
		--game.print("WD = 0")
		WGA[a]["WtrUsed"] = 0
	elseif WaterAreaUsed - TotalWaterAreaDrained > 0 then
		--game.print("WU - WD > 0")
		if TotalWaterAreaActivePumps > 0 and TotalWaterAreaActiveDrains > 0 then
			--game.print("WU AND WA ACTIVE")
			WGA[a]["WtrUsed"] = WaterAreaUsed + (FluidRatePerPump - TotalWaterAreaDrained)
		elseif TotalWaterAreaActivePumps == 0 and TotalWaterAreaActiveDrains > 0 then
			--game.print("WD ACTIVE")
			WGA[a]["WtrUsed"] = WaterAreaUsed - TotalWaterAreaDrained
		elseif TotalWaterAreaActivePumps > 0 and TotalWaterAreaActiveDrains == 0 then
			--game.print("WA ACTIVE")
			WGA[a]["WtrUsed"] = WaterAreaUsed + FluidRatePerPump
		end
	elseif WaterAreaUsed - TotalWaterAreaDrained < 0 then
		--game.print("WU - WD < 0")
		WGA[a]["WtrUsed"] = 0
		WGA[a]["Depleted"] = 0
	else
		--game.print("WU = WU")
		WGA[a]["WtrUsed"] = WaterAreaUsed
	end	
	WGA[a]["PercentPrev"] = WGA[a]["Percent"]
	WGA[a]["Percent"] = (WGA[a]["WtrUsed"] / WGA[a]["AmountWtr"]) * 100
	PercentChange = WGA[a]["PercentPrev"] - WGA[a]["Percent"]
end

function CheckDrainAssignedFluidUse(a) -- Assign Fluid to Empty WaterArea
	for c = 1, #storage.ODLocate,1 do
		local ODL = storage.ODLocate
		local WGA = storage.WaterGlobalArea
		if ODL[c]["WA"] == WGA[a]["WGAID"] and ODL[c]["entity"].neighbours[1][1] and ODL[c]["entity"].neighbours[1][1].fluidbox[1] ~= nil and ODL[c]["PipeFluid"] == WGA[a]["FluidType"] then
			if ODL[c]["entity"].neighbours[1][1].get_fluid_count() > 0.005 then
				fluid = ODL[c]["entity"].neighbours[1][1].fluidbox[1]
				for d = 1, #storage.WaterGlobalArea[a]["WtrAdd"], 1 do
					if storage.WaterGlobalArea[a]["WtrAdd"][d]["force"] == storage.ODLocate[c]["force"] then
						if ODL[c]["entity"].neighbours[1][1]["name"] == "storage-tank" then
							if fluid.amount >= 20 then
								WGA[a]["WtrAdd"][d]["count"] = WGA[a]["WtrAdd"][d]["count"] + (20 * 6)
							elseif fluid.amount < 20 and fluid.amount > 0 then
								WGA[a]["WtrAdd"][d]["count"] = WGA[a]["WtrAdd"][d]["count"] + (1 * 6)
							elseif fluid.amount == 0 then
								WGA[a]["WtrAdd"][d]["count"] = WGA[a]["WtrAdd"][d]["count"]
							end
						else
							if fluid.amount >= 20 then
								WGA[a]["WtrAdd"][d]["count"] = WGA[a]["WtrAdd"][d]["count"] + (20 * 6)
							elseif fluid.amount < 20 and fluid.amount > 0 then
								WGA[a]["WtrAdd"][d]["count"] = WGA[a]["WtrAdd"][d]["count"] + (fluid.amount * 6)
							elseif fluid.amount == 0 then
								WGA[a]["WtrAdd"][d]["count"] = WGA[a]["WtrAdd"][d]["count"]
							end
						end
					end
				end
			end
		end
	end
end

function CheckDrainAssignedFluid(a)
	if ActiveODs ~= 0 then
	local WGA = storage.WaterGlobalArea
	local ODL = storage.ODLocate
		for c = 1, #WGA, 1 do
			if WGA[c]["FluidType"] == "None" then
				if ODL[a]["WA"] == WGA[c]["WGAID"] and ODL[a]["entity"].neighbours[1][1] and ODL[a]["entity"].neighbours[1][1].fluidbox[1] ~= nil then
					WGA[c]["FluidType"] = ODL[a]["PipeFluid"]
				end
			end
		end
	end
end

function CheckOPActive(a)
	local GOPL = storage.OPLocate[a]
	local WGA = storage.WaterGlobalArea
	local GPF = storage.PlayerForces
	for b = 1, #WGA, 1 do
		if GOPL["Active"] == 0 and WGA[b]["WGAID"] == GOPL["WA"] and WGA[b]["Depleted"] ~= 1 then
			if GOPL["entity"].valid and GOPL["entity"].neighbours[1][1] then
				GOPL["Active"] = 1
				for c = 1, #WGA[b]["OPsA"], 1 do
					if WGA[b]["OPsA"][c]["force"] == GOPL["force"] then
						if WGA[b]["OPsA"][c]["count"] <= 0 then
							WGA[b]["OPsA"][c]["count"] = 1
						else
							WGA[b]["OPsA"][c]["count"] = WGA[b]["OPsA"][c]["count"] + 1
						end
					end
				end
				ActiveOPs = ActiveOPs + 1
			end
		elseif GOPL["Active"] == 1 and WGA[b]["WGAID"] == GOPL["WA"] and WGA[b]["Depleted"] ~= 1 then
			if GOPL["entity"].valid and GOPL["entity"].neighbours[1][1] then
				GOPL["Active"] = 1
				ActiveOPs = ActiveOPs + 1
			elseif GOPL["entity"].valid and not GOPL["entity"].neighbours[1][1] then
				GOPL["Active"] = 0
				for c = 1, #WGA[b]["OPsA"], 1 do
					if WGA[b]["OPsA"][c]["force"] == GOPL["force"] then
						if WGA[b]["OPsA"][c]["count"] <= 0 then
							WGA[b]["OPsA"][c]["count"] = 0
						else
							WGA[b]["OPsA"][c]["count"] = WGA[b]["OPsA"][c]["count"] - 1
						end
					end
				end
				ActiveOPs = ActiveOPs - 1
			end
		end
	end
end

function CheckODActive(a)
	local GOPL = storage.ODLocate[a]
	local WGA = storage.WaterGlobalArea
	local ODL = storage.ODLocate
	local ODA = settings.global["FluidArea-ReactivateDrains"].value
	for b = 1, #WGA, 1 do
		if GOPL["Active"] == 0 and WGA[b]["WGAID"] == GOPL["WA"] then
			if GOPL["entity"].neighbours[1][1] then
				if GOPL["entity"].valid and GOPL["entity"].neighbours[1][1].fluidbox[1] ~= nil and WGA[b]["WtrUsed"] > 0.005 then
					GOPL["Active"] = 1
					for c = 1, #WGA[b]["ODsA"], 1 do
						if WGA[b]["ODsA"][c]["force"] == GOPL["force"] then
							if WGA[b]["ODsA"][c]["count"] <= 0 then
								WGA[b]["ODsA"][c]["count"] = 1
							else
								WGA[b]["ODsA"][c]["count"] = WGA[b]["ODsA"][c]["count"] + 1
							end
						end
					end
					ActiveODs = ActiveODs + 1
					GOPL["PipeFluid"] = GOPL["entity"].neighbours[1][1].fluidbox[1].name
				end
			else
				GOPL["entity"].clear_fluid_inside()
			end
		elseif GOPL["Active"] == 1 and WGA[b]["WGAID"] == GOPL["WA"] then
			if GOPL["entity"].valid and GOPL["entity"].neighbours[1][1] and GOPL["entity"].neighbours[1][1].fluidbox[1] ~= nil and WGA[b]["WtrUsed"] > 0.005 then
				GOPL["Active"] = 1
				ActiveODs = ActiveODs + 1
				GOPL["PipeFluid"] = GOPL["entity"].neighbours[1][1].fluidbox[1].name
			elseif GOPL["entity"].valid or not GOPL["entity"].neighbours[1][1] or GOPL["entity"].neighbours[1][1].fluidbox[1] == nil or WGA[b]["Percent"] <= 0 then
				GOPL["Active"] = 0
				for c = 1, #WGA[b]["ODsA"], 1 do
					if WGA[b]["ODsA"][c]["force"] == GOPL["force"] then
						if WGA[b]["ODsA"][c]["count"] <= 0 then
							WGA[b]["ODsA"][c]["count"] = 0
						else
							WGA[b]["ODsA"][c]["count"] = WGA[b]["ODsA"][c]["count"] - 1
						end
					end
				end
				ActiveODs = ActiveODs - 1
				GOPL["PipeFluid"] = "None"
			end
		end
	end
end

function LandFill(a)
	local WGA = storage.WaterGlobalArea
	local Check = #WGA[a]["WaterRepArea"]
	if Check > 0 then
		WASize = #WGA[a]["WaterRepArea"]
		WAra = WGA[a]["WaterRepArea"]
	else
		WASize = #WGA[a]["WaterEdgeArea"]
		WAra = WGA[a]["WaterEdgeArea"]
	end
	for b = #storage.LandFill, 1, -1 do
		for c = 1, WASize, 1 do
			if WAra[c]["name"] ~= "landfill" then
				if Check > 0 then
					storage.WaterGlobalArea[a]["WaterRepArea"][c]["name"] = "landfill" 
					LFPosX = storage.LandFill[b]["position"]["x"] + 0.5
					LFPosY = storage.LandFill[b]["position"]["y"] + 0.5
				else
					LFPosX = storage.LandFill[b]["position"]["x"]
                    LFPosY = storage.LandFill[b]["position"]["y"]
				end
				WAPosX = WAra[c]["position"]["x"]
				WAPosY = WAra[c]["position"]["y"]
				if LFPosX == WAPosX then -- IF LandFill position x is equal to FluidArea position x
					if LFPosY == WAPosY then -- IF LandFill position y is equal to FluidArea position y
						Found = true
						if Check > 0 then
							storage.WaterGlobalArea[a]["WaterRepArea"][c]["name"] = "landfill" 
						end
						local FluidName = storage.LandFill[b]["name"]
						if FluidName == "water" or FluidName == "crude-oil" or FluidName == "water-green" or FluidName == "water-shallow" or FluidName == "water-mud" then
							local ShallowAmount = settings.global["TileFluidAmount-Shallow"].value
							storage.WaterGlobalArea[a]["AmountWtr"] = WGA[a]["AmountWtr"] - (ShallowAmount * WGA[a]["AmountBonusValue"])
							if FluidName == "water" or FluidName == "water-green" then
								WGA[a]["ShallowWater"] =  WGA[a]["ShallowWater"] - 1
							elseif FluidName == "water-shallow" then
								WGA[a]["ShallowWater-Shallow"] = WGA[a]["ShallowWater-Shallow"] - 1
							elseif FluidName == "water-mud" then
								WGA[a]["ShallowWater-Mud"] = WGA[a]["ShallowWater-Mud"] - 1
							end
							
						
						elseif FluidName == "deepwater" or FluidName == "crude-oil-deep" or FluidName == "deepwater-green" then
							local DeepAmount = settings.global["TileFluidAmount-Deep"].value
							storage.WaterGlobalArea[a]["AmountWtr"] = WGA[a]["AmountWtr"] - (DeepAmount * WGA[a]["AmountBonusValue"])
							if FluidName == "deepwater" or FluidName == "deepwater-green" then
								WGA[a]["DeepWater"] = WGA[a]["DeepWater"] - 1
							end
						end
						table.remove(storage.LandFill,#storage.LandFill)
						goto EscapeLFSearch
					end
				end
			end
			if a == #storage.WaterGlobalArea and c == WASize then -- Remove from Landfill table if not found.
				table.remove(storage.LandFill,#storage.LandFill)
				goto EscapeLFSearch
			end
		end
	::EscapeLFSearch::
	end
	local LandfillEnabled = settings.get_player_settings(game.players[1])["Alarms-Landfill-Message"].value
	if #storage.LandFill == 0 and Found == true and LandfillEnabled == true then
		CalculatedWaterTotal(a)
		game.print(string.format("Landfill has reduced FluidArea %s, to %sL of %s with regen %sL.", WGA[a]["WtrName"], WGA[a]["AmountWtr"], WGA[a]["FluidType"], WGA[a]["RegenAmount"]))
	end
	::EscapeLFSearchNF::
end

function CheckActive()
	ActiveOPs = 0
	ActiveODs = 0
	WGA = storage.WaterGlobalArea
	if #storage.OPLocate ~= 0 then
		for a = 1, #storage.OPLocate, 1 do
			CheckOPActive(a)
		end
	end
	if #storage.ODLocate ~= 0 then
		for a = 1, #storage.ODLocate, 1 do
			CheckODActive(a)
			CheckDrainAssignedFluid(a)
		end
	end
end

function ScanOffshores()
	for a = 1, #game.surfaces, -1 do
		if game.surfaces[a].valid == true then
			Jacks = game.surfaces[a].find_entities_filtered{name= "pumpjack"}
			if #Jacks > 0 then
				for b = 1, #Jacks, 1 do
					for c = #storage.FluidProducers, 1, -1 do
						if Jacks[b]["position"] == storage.FluidProducers[c]["position"] then
							table.remove(Jacks,#Jacks)
						end
					end
				end
				for d = 1, #Jacks, 1 do
					Jackentity = Jacks[d]
					Jackposition = Jackentity.position	
					Jacksurface = Jackentity.surface
					Jackforce = Jackentity.force.name
					storage.FluidProducers[#storage.FluidProducers+1] = {["entity"] = Jackentity, ["position"] = {["x"] = Jackposition.x , ["y"] = Jackposition.y}, ["surface"] = Jacksurface, ["FluidType"] = nil, ["LastAmount"] = 0, ["force"] = Jackforce}
				end
			end
			Pumps = 0
			if script.active_mods["Krastorio2"] then
				Pumps = game.surfaces[a].find_entities_filtered{name= "kr-electric-offshore-pump"}
			else
				Pumps = game.surfaces[a].find_entities_filtered{name= "offshore-pump"}
			end
			if script.active_mods["IndustrialRevolution"] then
				Pumps = game.surfaces[a].find_entities_filtered{name= "copper-pump"}
				IROPS = game.surfaces[a].find_entities_filtered{name= "offshore-pump"}
				if #IROPS > 0 then
					for b = 1, #IROPS, 1 do
						table.insert(Pumps,IROPS[b])
					end
				end
			end		
			if #Pumps > 0 then
				for b = 1, #Pumps, 1 do
					if Pumps[b].force.name ~= "neutral" then -- Ignore AbandondedRuins OffshorePumps which are neutral force
						storage.ScanOffshoresQueue[#storage.ScanOffshoresQueue+1] = Pumps[b]
					end
				end
				created_entity = storage.ScanOffshoresQueue[1]
				a = {["created_entity"] = created_entity}
				BuiltOffShore(a)
				table.remove(storage.ScanOffshoresQueue,1)
			end
		end
	end
	storage.Added = false
end

function PumpRereplace(a)
	local PRPV = settings.global["FluidArea-RereplacePumps"].value
	local PRP = 100 - PRPV
	local WGA = storage.WaterGlobalArea
	if PRPV == 0 then
		--Do Nothing as Off
	else
		local FAP = WGA[a]["Percent"]
		if PRP >= FAP then
			for b = #storage.OPLocate, 1, -1 do
				if storage.OPLocate[b]["WA"] == WGA[a]["WGAID"] and storage.OPLocate[b]["entity"].name == "offshore-pump-nofluid"then
					local OP = storage.OPLocate[b]
					local OPD = OP["direction"]
					local OPE = OP["entity"]
					local OPP = OP["position"]
					local OPSp = OP["spritepos"]
					local OPS = OP["surface"]
					local OPF = OP.force.name
					local OPP = OP.last_user
					OPE.destroy()
					if WGA[a]["FluidType"] == "water" then
						OPN = game.surfaces[OPS.name].create_entity{name="offshore-pump",position = OPSp,direction = OPD,player = OPP, force = OPF}
					elseif WGA[a]["FluidType"] == "crude-oil" then
						OPN = game.surfaces[OPS.name].create_entity{name="offshore-crude-oil-pump",position = OPSp,direction = OPD,player = OPP, force = OPF}
					end	
					storage.OPLocate[b]["entity"] = OPN
					if storage.OPLocate[b]["entity"] == nil then
						if storage.WaterGlobalArea[a]["OPs"] <= 0 then
							storage.WaterGlobalArea[a]["OPs"] = 0
						else
							storage.WaterGlobalArea[a]["OPs"] = storage.WaterGlobalArea[storage.OPLocate[b]["WA"]]["OPs"] - 1
						end
						game.players[storage.OPLocate[b]["entity"].last_user.name].print(string.format("Water As A Resource: Offshore Pump Removed from %s, as Pipes have another fluid type.", storage.WaterGlobalArea[storage.OPLocate[b]["WA"]]["WtrName"]))
						game.players[storage.OPLocate[b]["entity"].last_user.name].insert{name="offshore-pump",count=1}
						table.remove(storage.OPLocate,b)
					end
				end
			end
		end
	end
end

function RemoveWAOPOD(a)
	local WGA = storage.WaterGlobalArea
	if WGA[a]["Depleted"] == 1 then
		if #WGA[a]["OPs"] > 0 then
			for c = #storage.OPLocate, 1, - 1 do
				if WGA[a]["WGAID"] == storage.OPLocate[c]["WA"] then
					table.remove(storage.OPLocate,c)
				end
			end
		end
		if #WGA[a]["ODs"] > 0 then
			for c = #storage.ODLocate, 1, - 1 do
				if WGA[a]["WGAID"] == storage.ODLocate[c]["WA"] then
					table.remove(storage.ODLocate,c)
				end
			end
		end
		for d = #WGA[a]["MapMarker"], 1, -1 do
			if WGA[a]["MapMarker"][d]["icon"] ~= nil and WGA[a]["MapMarker"][d]["icon"].valid == true then
				WGA[a]["MapMarker"][d]["icon"].destroy()
			end
		end
		table.remove(WGA,a)
	end
end

function FluidFlow()
	GPF = storage.PlayerForces
	LGPF = #storage.PlayerForces
	-- if Skip ~= true or Skip == nil then
		-- for a = 1, LGPF, 1 do							
			-- GPF[a]["WaterFlow"] = math.ceil(game.forces[GPF[a]["name"]].fluid_production_statistics.get_input_count("water"))
			-- GPF[a]["CrudeFlow"] = math.ceil(game.forces[GPF[a]["name"]].fluid_production_statistics.get_input_count("crude-oil"))
		-- end
		-- Skip = true
	-- else
		-- for a = 1, LGPF, 1 do
			-- GPF[a]["LastWaterFlow"] = GPF[a]["WaterFlow"]
			-- GPF[a]["LastCrudeFlow"] = GPF[a]["CrudeFlow"]
		-- end
		-- Skip = false
	-- end
	local surface = nil
	for a = 1, LGPF, 1 do
		for _, b in pairs(game.surfaces) do
			-- TODO include surfaces correctly?
			GPF[a]["WaterFlow"] = math.ceil(game.forces[GPF[a]["name"]].get_fluid_production_statistics(b).get_flow_count{name="water",input=1,precision_index=0,count=true, category="input"})/50
			GPF[a]["CrudeFlow"] = math.ceil(game.forces[GPF[a]["name"]].get_fluid_production_statistics(b).get_flow_count{name="crude-oil",input=1,precision_index=0,count=true, category="input"})/50
			--game.print(string.format("Water Flow Rate: %s",GPF[a]["WaterFlow"]))
		end
	end
	
end

function CheckWater()
	local WGA = storage.WaterGlobalArea
	-- fluidentities.CheckFluidProducers()
	if storage.Added == true then
		ScanOffshores()
	end
	if #storage.ScanOffshoresQueue >= 1 then
		for a = 1, #storage.WaterGlobalArea, 1 do
			if storage.WaterGlobalArea[a]["ToSearch"] == nil then
				storage.EnableNextOffshore = true
				goto ENO
			else
				storage.EnableNextOffshore = false
			end
		end
		::ENO::
		if storage.EnableNextOffshore == true then
			created_entity = storage.ScanOffshoresQueue[1]
			a = {["created_entity"] = created_entity}
			BuiltOffShore(a)
			table.remove(storage.ScanOffshoresQueue,1)
		end				
	end
	if #WGA ~= nil and storage.Added ~= true then
		FluidFlow()
		CheckActive()
		for a = #WGA, 1, -1 do
			if ActiveOPs > 0 or ActiveODs > 0 then
				CheckDrainAssignedFluidUse(a)
				CalcWaterUse(a)
				if #WGA[a]["WaterRepArea"] > 0 then
					AssignTiles(a)
				end
			end
			if PercentChange <= 0 then
				DepleatedWaterArea(a)
			elseif PercentChange > 0 then
				AddedWaterArea(a)
				if not script.active_mods["Krastorio2"] then
					PumpRereplace(a)
				end
			end
			if ActiveODs > 0 then
				EmptyDrainPipes(a)
			end
		end
		--FluidFlow()
		if storage.LoopTick < 10 then
			storage.LoopTick = storage.LoopTick + 1
		elseif storage.LoopTick == 10 then
			storage.LoopTick = 0
			EverySec()
		end
	end
end

-- SCRIPT EVENT FUNCTIONS --
function RaisedSetTiles(event)
	local tilenames = {}
	local use_tile = nil
	for _, tile in pairs(event.tiles) do
		tilenames[tile.name] = 0
		if use_tile == nil then
			use_tile = tile
			use_tile.valid = true
		end
	end
	if use_tile == nil then
		return
	end
	if #tilenames > 1 then
		game.print("Warning: cannot properly call LandFillCheck due to script set_tiles having multiple tilenames (WAARE mod)")
	end
	if use_tile.name == "landfill" then
		game.print("Warning: cannot properly call LandFillCheck due to script set_tiles using Landfill - it shouldn't be done (WAARE mod)")
	end
	local data = {["tile"]=use_tile, ["tiles"]=event.tiles}
	LandFillCheck(data)

end



function LandFillCheck(event)
    if event.mod_name ~= "creative-mod" and event.tile.valid == true then
		if event.tile.name == "landfill" then
			local tiles = event.tiles
			local surface = event.surface_index
			for a = 1, #tiles, 1 do
				storage.LandFill[#storage.LandFill+1] = {["name"] = tiles[a].old_tile.name, ["position"] = {["x"] = tiles[a]["position"].x, ["y"] = tiles[a]["position"].y},["surface"] = surface}
			end
		end
		if event.tile.name == "water" or event.tile.name == "water-shallow" or event.tile.name == "water-green" or event.tile.name == "water-mud" then
			for a = 1, #storage.WaterGlobalArea, 1 do
				if storage.WaterGlobalArea[a]["HasSearched"] == nil or storage.WaterGlobalArea[a]["HasSearched"] == 0 then
					storage.WaterGlobalArea[a]["HasSearched"] = {}
				end
				
				local tiles = event.tiles
				local surface = storage.WaterGlobalArea[a]["Surface"].name
				local reset_edge = false
				for t = 1, #tiles, 1 do
					local position = {x=tiles[t]["position"].x, y=tiles[t]["position"].y}
					-- game.print(string.format("Tile put: %s", GridRef(position)))
					if storage.WaterGlobalArea[a]["WaterEdgeGrid"][PositionToString(position)] == true then
						-- game.print(string.format("EdgeGrid hit: %s", GridRef(position)))
						storage.WaterGlobalArea[a]["WaterEdgeGrid"][PositionToString(position)] = nil
						if reset_edge == false then
							if storage.WaterGlobalArea[a]["ToSearch"] == nil or storage.WaterGlobalArea[a]["ToSearch"] == 0 then
								storage.WaterGlobalArea[a]["ToSearch"] = {}
							end
							storage.WaterGlobalArea[a]["ToSearch"][#storage.WaterGlobalArea[a]["ToSearch"]+1] = position
							reset_edge = true
						end
					end
					
					storage.WaterGlobalArea[a]["HasSearched"][PositionToString(position)] = false


					
				end
				
				

				if reset_edge == true then
					-- game.print("Reset Edge")
					local new_water_edge_area = {}
					for e = 1, #storage.WaterGlobalArea[a]["WaterEdgeArea"], 1 do
						local position = {x=storage.WaterGlobalArea[a]["WaterEdgeArea"][e]["position"]["x"], y=storage.WaterGlobalArea[a]["WaterEdgeArea"][e]["position"]["y"]}
						
						if storage.WaterGlobalArea[a]["HasSearched"][PositionToString(position)] ~= true then
							-- game.print(GridRef(position))
						
							local tile = game.surfaces[surface].get_tile(position.x, position.y)
							local fluidname = tile.name
						
																						
							if fluidname == "water" or fluidname == "water-green" or fluidname == "water-shallow" or fluidname == "water-mud" then
								if fluidname == "water" or fluidname == "water-green" then
									storage.WaterGlobalArea[a]["ShallowWater"] = storage.WaterGlobalArea[a]["ShallowWater"] - 1
								elseif fluidname == "water-shallow" then
									storage.WaterGlobalArea[a]["ShallowWater-Shallow"] = storage.WaterGlobalArea[a]["ShallowWater-Shallow"] - 1
								elseif fluidname == "water-mud" then
									storage.WaterGlobalArea[a]["ShallowWater-Mud"] = storage.WaterGlobalArea[a]["ShallowWater-Mud"] - 1
								end
							elseif fluidname == "deepwater" or fluidname == "deepwater-green" then
								storage.WaterGlobalArea[a]["DeepWater"] = storage.WaterGlobalArea[a]["DeepWater"] - 1
							end
						else
							new_water_edge_area[#new_water_edge_area+1] = storage.WaterGlobalArea[a]["WaterEdgeArea"][e]
						end
						


					end
					storage.WaterGlobalArea[a]["WaterEdgeArea"] = new_water_edge_area
				end
				
			end
		end
	end
end

function ScriptConvert(event)
	-- game.print("Script Raise Event")
	if script.active_mods["Krastorio2"] and not script.active_mods["aai-industary"] then
		-- DO NOTHING - Fixes lots of problems with K2 OP Detection (04/11/21)
		OPentity = {["created_entity"] = event}  
		BuiltOffShore(OPentity)
	else
		if event.entity.valid == true then
			-- game.print("VALID")
			-- game.print(event.entity.name)
			OPentity = {["created_entity"] = event.entity}  
			BuiltOffShore(OPentity)
		end
	end
end

local function placerWater(placed)

    local replacement = "water-shallow"

    local dir     = placed.direction
    local pos     = placed.position
    local surface = placed.surface

    placed.destroy()
    local tileArray = {}
    local i = 1
	tileArray[i] = {
		name = replacement,
		position = {pos.x, pos.y}
	}
   
    surface.set_tiles(tileArray, true, true, true, true)
end

function BuiltOffShore(event) 					-- Script Event On Built
	if event.entity.name == "waterfill-placer" then
		placerWater(event.entity) 
		goto NOTVALID
	end
	if event.entity.name == "offshore-pump" and event.entity.force.name ~= "neutral" or event.entity.name == "offshore-drain" or event.entity.name =="pumpjack" or event.entity.name == "kr-electric-offshore-pump" or event.entity.name == "copper-pump"then
		OPentity = event.entity
		storage.Player = OPentity.last_user
		if script.active_mods["Krastorio2"] then
			if event.entity.name == "offshore-pump" then 
				-- IGNORE FIRST OFFSHORE TRIGGER UNLESS AAI IS ACTIVE
				if script.active_mods["aai-industry"] then
					
				else
					goto NOTVALID
				end
			elseif event.entity.name == "kr-electric-offshore-pump" then
				
			end
		else
			
		end
	else
		goto NOTVALID
	end
	if OPentity.name == "offshore-pump" or OPentity.name == "kr-electric-offshore-pump" or event.entity.name == "copper-pump" and OPentity.force.name ~= "neutral" then
		OPposition = OPentity.position													-- Variable for e.Position
		OPsurface = OPentity.surface													-- Variable for e.Surface
		OPdirection = OPentity.direction												-- Variable for OPentity.direction
		OPforce = OPentity.force.name
		storage.OPLocate[#storage.OPLocate+1] = {["entity"] = OPentity,["position"] = {["x"] = OPposition.x, ["y"] = OPposition.y},["spritepos"] = {["x"] = OPposition.x, ["y"] = OPposition.y},["surface"] = OPsurface,["direction"] = OPdirection,["tile"] = nil, ["Active"] = 0, ["WA"] = 0, ["force"] = OPforce}
		if OPdirection == 0 then -- North
			storage.OPLocate[#storage.OPLocate]["position"]["y"] = OPposition.y - 1
		elseif OPdirection == 4 then -- East
			storage.OPLocate[#storage.OPLocate]["position"]["x"] = OPposition.x + 1
		elseif OPdirection == 8 then -- South
			storage.OPLocate[#storage.OPLocate]["position"]["y"] = OPposition.y + 1
		elseif OPdirection == 12 then -- West
			storage.OPLocate[#storage.OPLocate]["position"]["x"] = OPposition.x - 1
		end
		tile = OPsurface.get_tile(storage.OPLocate[#storage.OPLocate]["position"]["x"],storage.OPLocate[#storage.OPLocate]["position"]["y"]).name
		CorrectedFluid(tile)
		storage.OPLocate[#storage.OPLocate]["tile"] = correctedtile
		storage.Type = 1
		if CorrectPump() ~= false then
			OffshoreForce(OPforce,false)
			GlobalWaterArea()
		else
			table.remove(storage.OPLocate,#storage.OPLocate)
		end
		storage.Type = 0
	elseif OPentity.name == "offshore-drain" then
		ODentity = event.entity
		ODposition = ODentity.position
		ODsurface = ODentity.surface
		ODdirection = ODentity.direction
		ODforce = ODentity.force.name
		tile = ODsurface.get_tile(ODposition.x,ODposition.y).name
		CorrectedFluid(tile)
		storage.ODLocate[#storage.ODLocate+1] = {["entity"] = ODentity,["position"] = {["x"] = ODposition.x, ["y"] = ODposition.y},["surface"] = ODsurface,["direction"] = ODdirection, ["tile"] = correctedtile, ["PipeFluid"] = nil, ["Active"] = 0, ["WA"] = 0, ["force"] = ODforce}
		storage.Type = 2
		GlobalWaterArea()
		if storage.ODRemoved == false then
			OffshoreForce(false,ODforce)
		else
			storage.ODRemoved = false
		end
		storage.Type = 0
	elseif OPentity.name =="pumpjack" or event.entity ~= nil and OPentity.name =="pumpjack" then
		if event.entity.valid == true then
			FPentity = event.entity
		else
			FPentity = event.entity
		end
		FPposition = FPentity.position	
		FPsurface = FPentity.surface
		FPforce = FPentity.force.name
		storage.FluidProducers[#storage.FluidProducers+1] = {["entity"] = FPentity, ["position"] = {["x"] = FPposition.x , ["y"] = FPposition.y}, ["surface"] = FPsurface, ["FluidType"] = nil, ["LastAmount"] = 0, ["force"] = FPforce}
	else
		--game.print("Not Built A Offshore Pump")									-- If Not Offshore Pump then print Bad Times
	end
	storage.Type = 0
	::NOTVALID::
end 

function DestroyedOffShore(event) 			-- Script Event On Player Mined
	if event.entity.name == "offshore-pump" or event.entity.name == "offshore-pump-nofluid" or event.entity.name == "offshore-crude-oil-pump" or event.entity.name == "kr-electric-offshore-pump" or event.entity.name == "copper-pump" then								-- If Offshore Pump No Fluid Mined
		--game.print("PICKED UP MY OFFSHORE PUMP")									-- Print My Offshore Pump
		DOentity = event.entity
		DOposition = DOentity.position
		DOforce = DOentity.force.name
		storage.Type = 1
		DestroyOffshore()
		storage.Type = 0
	elseif event.entity.name == "offshore-drain" then
		DOentity = event.entity
		-- if DOentity.neighbours[1][1] and DOentity.neighbours[1][1].get_fluid_count() ~= 0 then
			-- DOentity.neighbours[1][1].fluidbox[1] = nil
		-- end
		DOposition = DOentity.position
		DOforce = DOentity.force.name
		storage.Type = 2
		DestroyOffshore()
		storage.Type = 0
	elseif event.entity.name == "pumpjack" then
		DOentity = event.entity
		DOposition = DOentity.position
		DOforce = DOentity.force.name
		storage.Type = 3
		DestroyOffshore()
		storage.Type = 0
	end
end

function DestroyOffshore()
	if storage.Type == 1 then
		PTYPE = storage.OPLocate
		PTYPEL = #storage.OPLocate
		PFORCE = DOforce
	elseif storage.Type == 2 then
		PTYPE = storage.ODLocate
		PTYPEL = #storage.ODLocate
		PFORCE = DOforce
	elseif storage.Type == 3 then
		PTYPE = storage.FluidProducers
		PTYPEL = #storage.FluidProducers
		PFORCE = DOforce
	end	
	local DOPosX = DOposition.x
	local DOPosY = DOposition.y
	local WGA = storage.WaterGlobalArea
	local OPF = storage.PlayerForces
	for a = PTYPEL, 1, -1 do
		if storage.Type == 1 then
			OPosX = PTYPE[a]["spritepos"]["x"]
			OPosY = PTYPE[a]["spritepos"]["y"]
		elseif storage.Type == 2 then
			OPosX = PTYPE[a]["position"]["x"]			
			OPosY = PTYPE[a]["position"]["y"]
		end
		if DOPosX == OPosX then
			if DOPosY == OPosY then
				if storage.Type == 1 then
					local OWA = PTYPE[a]["WA"]
					for b = 1, #WGA, 1 do	
						if #storage.WaterGlobalArea ~= 0 and WGA ~= 0 and WGA[b]["WGAID"] == OWA then
							for c = 1, #storage.WaterGlobalArea[b]["OPs"], 1 do
								if storage.WaterGlobalArea[b]["OPs"][c]["force"] == PFORCE then
									storage.WaterGlobalArea[b]["OPs"][c]["count"] = storage.WaterGlobalArea[b]["OPs"][c]["count"] - 1
								end
							end
						end					
						if PTYPE[a]["Active"] == 1 and WGA ~= 0 and WGA[b]["WGAID"] == OWA then
							for c = 1, #storage.WaterGlobalArea[b]["OPs"], 1 do
								if storage.WaterGlobalArea[b]["OPsA"][c]["force"] == PFORCE then
									storage.WaterGlobalArea[b]["OPsA"][c]["count"] = storage.WaterGlobalArea[b]["OPsA"][c]["count"] - 1
									ActiveOPs = ActiveOPs - 1
								end
							end
						end
					end
					for c = 1, #OPF, 1 do
						if OPF[c]["name"] == PFORCE then
							OPF[c]["OPcount"] = OPF[c]["OPcount"] - 1
						end
					end
				elseif storage.Type == 2 then
					local OWA = PTYPE[a]["WA"]
					for b = 1, #WGA, 1 do
						if #storage.WaterGlobalArea ~= 0 and WGA ~= 0 and WGA[b]["WGAID"] == OWA then
							for c = 1, #storage.WaterGlobalArea[b]["ODs"], 1 do
								if storage.WaterGlobalArea[b]["ODs"][c]["force"] == PFORCE then
									storage.WaterGlobalArea[b]["ODs"][c]["count"] = storage.WaterGlobalArea[b]["ODs"][c]["count"] - 1
								end
							end
						end					
						if PTYPE[a]["Active"] == 1 and WGA ~= 0 and WGA[b]["WGAID"] == OWA then
							for c = 1, #storage.WaterGlobalArea[b]["ODs"], 1 do
								if storage.WaterGlobalArea[b]["ODsA"][c]["force"] == PFORCE then
									storage.WaterGlobalArea[b]["ODsA"][c]["count"] = storage.WaterGlobalArea[b]["ODsA"][c]["count"] - 1
									ActiveODs = ActiveODs - 1
								end
							end
						end
					end
					for c = 1, #OPF, 1 do
						if OPF[c]["name"] == PFORCE then
							OPF[c]["ODcount"] = OPF[c]["ODcount"] - 1
						end
					end
				end
				table.remove(PTYPE,a)
			end
		end
	end	
end

function UpdateMod(data)
	if data.mod_changes.WaterAsAResourceExtended then
		-- oldVer = data.mod_changes.WaterAsAResourceExtended.old_version
		local oldVer = "some"
		if oldVer == nil then
			do end
		-- 	-- storage.LastWaterFlow = math.ceil(game.players[1].force.fluid_production_statistics.get_input_count("water"))
		-- 	-- storage.LastCrudeFlow = math.ceil(game.players[1].force.fluid_production_statistics.get_input_count("crude-oil"))
		-- 	Players = #game.players
		-- 	if Players <= 1 then
		-- 		if storage.PlayerForces == nil then
		-- 			Force = game.players[1].force.name
		-- 			storage.PlayerForces[#storage.PlayerForces+1] = {["name"] = Force, ["OPcount"] = 0, ["ODcount"] = 0, ["WaterFlow"] = 0, ["LastWaterFlow"] = 0, ["CrudeFlow"] = 0, ["LastCrudeFlow"] = 0}
		-- 			storage.PlayerForces[#storage.PlayerForces]["LastWaterFlow"] = math.ceil(game.forces[storage.PlayerForces[#storage.PlayerForces]["name"]].fluid_production_statistics.get_input_count("water"))
		-- 			storage.PlayerForces[#storage.PlayerForces]["LastCrudeFlow"] = math.ceil(game.forces[storage.PlayerForces[#storage.PlayerForces]["name"]].fluid_production_statistics.get_input_count("crude-oil"))
		-- 		end
		-- 	else
		-- 		for a = 1, Players, 1 do
		-- 			Force = game.players[a].force.name
		-- 			if storage.PlayerForces == nil then
		-- 				storage.PlayerForces[#storage.PlayerForces+1] = {["name"] = Force, ["OPcount"] = 0, ["ODcount"] = 0, ["WaterFlow"] = 0, ["LastWaterFlow"] = 0, ["CrudeFlow"] = 0, ["LastCrudeFlow"] = 0}
		-- 				storage.PlayerForces[#storage.PlayerForces]["LastWaterFlow"] = math.ceil(game.forces[storage.PlayerForces[#storage.PlayerForces]["name"]].fluid_production_statistics.get_input_count("water"))
		-- 				storage.PlayerForces[#storage.PlayerForces]["LastCrudeFlow"] = math.ceil(game.forces[storage.PlayerForces[#storage.PlayerForces]["name"]].fluid_production_statistics.get_input_count("crude-oil"))
		-- 			else
		-- 				NewForce = true
		-- 				for c = 1, #storage.PlayerForces, 1 do
		-- 					if storage.PlayerForces[c]["force"] == Force then
		-- 						NewForce = false
		-- 					end
		-- 				end
		-- 				if NewForce == true then
		-- 					storage.PlayerForces[#storage.PlayerForces+1] = {["name"] = Force, ["OPcount"] = 0, ["ODcount"] = 0, ["WaterFlow"] = 0, ["LastWaterFlow"] = 0, ["CrudeFlow"] = 0, ["LastCrudeFlow"] = 0}
		-- 					storage.PlayerForces[#storage.PlayerForces]["LastWaterFlow"] = math.ceil(game.forces[storage.PlayerForces[#storage.PlayerForces]["name"]].fluid_production_statistics.get_input_count("water"))
		-- 					storage.PlayerForces[#storage.PlayerForces]["LastCrudeFlow"] = math.ceil(game.forces[storage.PlayerForces[#storage.PlayerForces]["name"]].fluid_production_statistics.get_input_count("crude-oil"))
		-- 				end
		-- 			end
		-- 		end
		-- 	end
		-- 	storage.InstallTick = game.tick
		else
			--game.print("Water As A Resource: Updating Mod Internals")
			storages()
			Linkstorages()
							
			if #storage.WaterGlobalArea > 0 then
				for a = 1, #storage.WaterGlobalArea, 1 do
					if storage.WaterGlobalArea[a]["WGAID"] == nil then
						storage.WaterGlobalArea[a]["WGAID"] = a
					end
					local Count = storage.WaterGlobalArea[a]["ShallowWater"] + storage.WaterGlobalArea[a]["DeepWater"]
					if storage.WaterGlobalArea[a]["ShallowWater-Shallow"] == nil then
						storage.WaterGlobalArea[a]["ShallowWater-Shallow"] = 0
					end
					if storage.WaterGlobalArea[a]["ShallowWater-Mud"] == nil then
						storage.WaterGlobalArea[a]["ShallowWater-Mud"] = 0
					end
					if storage.WaterGlobalArea[a]["WtrName"] == nil or storage.WaterGlobalArea[a]["WtrName"] == "None" then
						storage.WaterGlobalArea[a]["WtrName"] = a
					end
					if storage.WaterGlobalArea[a]["AmountBonusValue"] == nil or storage.WaterGlobalArea[a]["AmountBonusValue"] == 0 then
						if Count < 4 then
							storage.WaterGlobalArea[a]["AmountBonusValue"] = 0.01
						elseif Count == 4 then
							storage.WaterGlobalArea[a]["AmountBonusValue"] = 0.5
						elseif Count >4 and Count <= 200 then
							storage.WaterGlobalArea[a]["AmountBonusValue"] = 1
						elseif Count > 200 and Count <= 6000 then
							storage.WaterGlobalArea[a]["AmountBonusValue"] = 1.5
						elseif Count > 6000 and Count <= 60000 then
							storage.WaterGlobalArea[a]["AmountBonusValue"] = 2
						elseif Count > 60000 and Count <= 600000 then
							storage.WaterGlobalArea[a]["AmountBonusValue"] = 2.5
						else
							storage.WaterGlobalArea[a]["AmountBonusValue"] = 3
						end
					end
					if storage.WaterGlobalArea[a]["WtrUsed"] == nil then
						storage.WaterGlobalArea[a]["WtrUsed"] = (storage.WaterGlobalArea[a]["AmountWtr"] * storage.WaterGlobalArea[a]["Percent"]) / 100
					end
					-- if storage.WaterGlobalArea[a]["OPsA"] == nil or storage.WaterGlobalArea[a]["OPsA"] < 0 then
						-- storage.WaterGlobalArea[a]["OPsA"] = 0
					-- end
					-- if storage.WaterGlobalArea[a]["WtrAdd"] == nil then
						-- storage.WaterGlobalArea[a]["WtrAdd"] = 0
					-- end
					-- if storage.WaterGlobalArea[a]["ODsA"] == nil or storage.WaterGlobalArea[a]["ODsA"] < 0 then
						-- storage.WaterGlobalArea[a]["ODsA"] = 0
					-- end
					-- if storage.WaterGlobalArea[a]["ODs"] == nil then
						-- storage.WaterGlobalArea[a]["ODs"] = 0
					-- end
					if storage.WaterGlobalArea[a]["PercentPrev"] == nil then
						storage.WaterGlobalArea[a]["PercentPrev"] = storage.WaterGlobalArea[a]["Percent"]
					end
					if storage.WaterGlobalArea[a]["Depleted"] == 1 then
						storage.WaterGlobalArea[a]["FluidType"] = "None"
						storage.WaterGlobalArea[a]["Percent"] = 100
						storage.WaterGlobalArea[a]["PercentPrev"] = 100
						storage.WaterGlobalArea[a]["WtrUsed"] = storage.WaterGlobalArea[a]["AmountWtr"]
					end
					if storage.WaterGlobalArea[a]["ToSearch"] == nil or storage.WaterGlobalArea[a]["ToSearch"] == 0 then
						storage.WaterGlobalArea[a]["ToSearch"] = nil
					end
					if storage.WaterGlobalArea[a]["HasSearched"] == nil or storage.WaterGlobalArea[a]["HasSearched"] == 0 then
						storage.WaterGlobalArea[a]["HasSearched"] = nil
					end
					if storage.WaterGlobalArea[a]["TilesSet"] == nil then
						storage.WaterGlobalArea[a]["TilesSet"] = "N"
					end
					if storage.WaterGlobalArea[a]["Percent"] < 50 then
						storage.WaterGlobalArea[a]["Fired50"] = false
						storage.WaterGlobalArea[a]["Fired75"] = false
						storage.WaterGlobalArea[a]["Fired90"] = false
						storage.WaterGlobalArea[a]["Fired95"] = false
						storage.WaterGlobalArea[a]["Fired97"] = false
						storage.WaterGlobalArea[a]["Fired98"] = false
						storage.WaterGlobalArea[a]["Fired99"] = false
					end
					if storage.WaterGlobalArea[a]["Percent"] >= 50 then
						storage.WaterGlobalArea[a]["Fired50"] = true
					end
					if storage.WaterGlobalArea[a]["Percent"] >= 75 then
						storage.WaterGlobalArea[a]["Fired75"] = false
					end
					if storage.WaterGlobalArea[a]["Percent"] >= 90 then
						storage.WaterGlobalArea[a]["Fired90"] = true
					end
					if storage.WaterGlobalArea[a]["Percent"] >= 95 then
						storage.WaterGlobalArea[a]["Fired95"] = true
					end
					if storage.WaterGlobalArea[a]["Percent"] >= 97 then
						storage.WaterGlobalArea[a]["Fired97"] = true
					end
					if storage.WaterGlobalArea[a]["Percent"] >= 98 then
						storage.WaterGlobalArea[a]["Fired98"] = true
					end
					if storage.WaterGlobalArea[a]["Percent"] >= 99 then
						storage.WaterGlobalArea[a]["Fired99"] = true
					end
					if storage.WaterGlobalArea[a]["BTFE"] == nil then
						storage.WaterGlobalArea[a]["BTFE"] = 0
					end
					storage.WaterGlobalArea[a]["BTF"] = Count
					for b = 1, Count, 1 do
						if storage.WaterGlobalArea[a]["FluidType"] == nil or storage.WaterGlobalArea[a]["FluidType"] == "None" then
							if #storage.WaterGlobalArea[a]["WaterRepArea"] > 0 then
								tile = storage.WaterGlobalArea[a]["WaterRepArea"][b]["name"]
							else
								tile = storage.WaterGlobalArea[a]["WaterEdgeArea"][1]["name"]
							end
							if tile == "water" or tile == "deepwater" or tile == "lake-shallow" then
								storage.WaterGlobalArea[a]["FluidType"] = "water"
							elseif tile == "crude-oil" or tile == "crude-oil-deep" or tile == "lake-deep" then
								storage.WaterGlobalArea[a]["FluidType"] = "crude-oil"
							elseif storage.WaterGlobalArea[a]["FluidType"] == nil then
								storage.WaterGlobalArea[a]["FluidType"] = "None"
							end
						end
					end
					if storage.WaterGlobalArea[a]["LoopCount"] == nil then
						storage.WaterGlobalArea[a]["LoopCount"] = 0
					end
					if storage.WaterGlobalArea[a]["RegenAmount"] == nil then
						storage.WaterGlobalArea[a]["RegenAmount"] = 0
					end
					if storage.WaterGlobalArea[a]["Percent"] >= 80 and storage.WaterGlobalArea[a]["Percent"] < 100 then
						local TPP = math.floor((storage.WaterGlobalArea[a]["ShallowWater"] + storage.WaterGlobalArea[a]["DeepWater"]) / 20)
						local PF = math.floor(storage.WaterGlobalArea[a]["Percent"] - 80) / 0.1
						local Tiles = TPP * (PF/100)
						storage.WaterGlobalArea[a]["BTF"] = storage.WaterGlobalArea[a]["BTF"] - Tiles
					else
						storage.WaterGlobalArea[a]["BTF"] = Count
					end
					if storage.WaterGlobalArea[a]["WaterEdgeArea"] == nil then
						storage.WaterGlobalArea[a]["WaterEdgeArea"] = {}
					end
					for b = 1, #game.surfaces, 1 do
						if #storage.WaterGlobalArea[a]["WaterRepArea"] > 0 then
							pos = storage.WaterGlobalArea[a]["WaterRepArea"][1]["position"]
						else
							pos = storage.WaterGlobalArea[a]["WaterEdgeArea"][1]["position"]
						end
						local tile = game.surfaces[b].get_tile(pos)
						if tile.valid == true then
							local tilename = tile.name
							if tilename == "water" or tilename =="deepwater" or tilename=="crude-oil" or tilename=="crude-oil-deep" or tilename=="sand-3" or tilename=="dry-dirt" or tilename=="lake-shallow" or tilename=="lake-deep" then
								if storage.WaterGlobalArea[a]["Surface"] == nil then
									storage.WaterGlobalArea[a]["Surface"] = game.surfaces[b]
								end
							end	
						end
						for c = Count, 1 , -1 do
							if #storage.WaterGlobalArea[a]["WaterRepArea"] > 0 then
								posc = storage.WaterGlobalArea[a]["WaterRepArea"][c]["position"]
								local tile = game.surfaces[b].get_tile(posc)
								if tile.valid == true then
									local tilename = tile.name
									if tilename == "water" or tilename =="deepwater" or tilename=="crude-oil" or tilename=="crude-oil-deep" then
										if storage.WaterGlobalArea[a]["WaterRepArea"][c]["OriginalName"] == nil then
											storage.WaterGlobalArea[a]["WaterRepArea"][c]["OriginalName"] = tilename
										end
									end
								end
							end
						end
					end
					if #storage.WaterGlobalArea[a]["WaterEdgeArea"] > 0 then
						for b = 1, #storage.WaterGlobalArea[a]["WaterEdgeArea"], 1 do
							if storage.WaterGlobalArea[a]["MinX"] == nil then 
								storage.WaterGlobalArea[a]["MinX"] = storage.WaterGlobalArea[a]["WaterEdgeArea"][b]["x"]
							elseif storage.WaterGlobalArea[a]["MinX"] == 0 or storage.WaterGlobalArea[a]["MinX"] > storage.WaterGlobalArea[a]["WaterEdgeArea"][b]["position"]["x"] then
								storage.WaterGlobalArea[a]["MinX"] = storage.WaterGlobalArea[a]["WaterEdgeArea"][b]["position"]["x"]
							end
							if storage.WaterGlobalArea[a]["MaxX"] == nil then
								storage.WaterGlobalArea[a]["MaxX"] = storage.WaterGlobalArea[a]["WaterEdgeArea"][b]["x"]
							elseif storage.WaterGlobalArea[a]["MaxX"] == 0 or storage.WaterGlobalArea[a]["MaxX"] < storage.WaterGlobalArea[a]["WaterEdgeArea"][b]["position"]["x"] then
								storage.WaterGlobalArea[a]["MaxX"] = storage.WaterGlobalArea[a]["WaterEdgeArea"][b]["position"]["x"]
							end
							if storage.WaterGlobalArea[a]["MinY"] == nil then
								storage.WaterGlobalArea[a]["MinY"] = storage.WaterGlobalArea[a]["WaterEdgeArea"][b]["y"]
							elseif storage.WaterGlobalArea[a]["MinY"] == 0 or storage.WaterGlobalArea[a]["MinY"] > storage.WaterGlobalArea[a]["WaterEdgeArea"][b]["position"]["y"] then
								storage.WaterGlobalArea[a]["MinY"] = storage.WaterGlobalArea[a]["WaterEdgeArea"][b]["position"]["y"]
							end
							if storage.WaterGlobalArea[a]["MaxY"] == nil then
								storage.WaterGlobalArea[a]["MaxY"] = storage.WaterGlobalArea[a]["WaterEdgeArea"][b]["y"]
							elseif storage.WaterGlobalArea[a]["MaxY"] == 0 or storage.WaterGlobalArea[a]["MaxY"] < storage.WaterGlobalArea[a]["WaterEdgeArea"][b]["position"]["y"] then
								storage.WaterGlobalArea[a]["MaxY"] = storage.WaterGlobalArea[a]["WaterEdgeArea"][b]["position"]["y"]
							end
						end
						local minx = storage.WaterGlobalArea[a]["MinX"]
						local maxx = storage.WaterGlobalArea[a]["MaxX"]
						local miny = storage.WaterGlobalArea[a]["MinY"]
						local maxy = storage.WaterGlobalArea[a]["MaxY"]
						storage.WaterGlobalArea[a]["Hdif"] = maxx - minx
						storage.WaterGlobalArea[a]["Vdif"] = maxy - miny
						storage.WaterGlobalArea[a]["Hyp"] = math.sqrt(((maxx - minx)^2) + ((maxy - miny)^2))
					end
					-- MapMarker = storage.WaterGlobalArea[a]["MapMarker"]
					-- if storage.WaterGlobalArea[a]["MapMarkerPlaced"] == false then
						-- storage.WaterGlobalArea[a]["MapMarker"][1] = {["force"] = Force, ["placed"] = false,["icon"] = nil}
					-- else
						-- storage.WaterGlobalArea[a]["MapMarker"][1] = {["force"] = Force, ["placed"] = true,["icon"] = MapMarker}
					-- end
					if storage.WaterGlobalArea[a]["MapMarker"] ~= nil and storage.WaterGlobalArea[a]["MapMarker"].valid == true then
						storage.WaterGlobalArea[a]["MapMarker"].destroy()
						storage.WaterGlobalArea[a]["MapMarkerPlaced"] = nil
					end
					if storage.WaterGlobalArea[a]["TechYRBoost"] == nil then
						storage.WaterGlobalArea[a]["TechYRBoost"] = 0 
					end
				end
			end
			if #storage.OPLocate > 0 then
				for a = #storage.OPLocate, 1, -1 do
					if storage.OPLocate[a]["OPposition"] ~= nil then
						OPTilePosX = storage.OPLocate[a]["OPposition"]["x"]
						OPTilePosY = storage.OPLocate[a]["OPposition"]["y"]
					else
						OPTilePosX = storage.OPLocate[a]["position"]["x"]
						OPTilePosY = storage.OPLocate[a]["position"]["y"]
					end
					for b = 1, #storage.WaterGlobalArea, 1 do
						if #storage.WaterGlobalArea[b]["WaterRepArea"] > 0 then
							CompTiles = storage.WaterGlobalArea[b]["ShallowWater"] + storage.WaterGlobalArea[b]["DeepWater"]
						else
							CompTiles = #storage.WaterGlobalArea[b]["WaterEdgeArea"]
						end
						if storage.OPLocate[a]["WA"] == nil or storage.OPLocate[a]["WA"] == 0 then
							for c = CompTiles, 1, -1 do -- FOR EACH TILE in WATERAREA
								if #storage.WaterGlobalArea[b]["WaterRepArea"] > 0 then
									WATilePosX = storage.WaterGlobalArea[b]["WaterRepArea"][c]["position"]["x"]
									WATilePosY = storage.WaterGlobalArea[b]["WaterRepArea"][c]["position"]["y"]
								else
									WATilePosX = storage.WaterGlobalArea[b]["WaterEdgeArea"][c]["position"]["x"]								
									WATilePosY = storage.WaterGlobalArea[b]["WaterEdgeArea"][c]["position"]["y"]
								end
								if WATilePosX == OPTilePosX then
									if WATilePosY == OPTilePosY then
										if #storage.WaterGlobalArea[b]["WaterRepArea"] > 0 then
											storage.OPLocate[a]["WA"] = b
										else
											storage.OPLocate[a]["WA"] = storage.WaterGlobalArea[b]["WGAID"]
										end
									end
								end
							end
						end
					end
					if storage.OPLocate[a]["Active"] == nil then
						storage.OPLocate[a]["Active"] = 0
					end
					if storage.OPLocate[a]["entity"] == nil then
						storage.OPLocate[a]["entity"] = storage.OPLocate[a]["OPentity"]
					end
					if storage.OPLocate[a]["position"] == nil then
						storage.OPLocate[a]["position"] = storage.OPLocate[a]["OPposition"]
					end
					if storage.OPLocate[a]["direction"] == nil then
						storage.OPLocate[a]["direction"] = storage.OPLocate[a]["OPdirection"]
					end
					if storage.OPLocate[a]["force"] == nil then
						storage.OPLocate[a]["force"] = "player"
					end
					for b = 1, #storage.WaterGlobalArea, 1 do
						if storage.OPLocate[a]["WA"] == b and storage.WaterGlobalArea[b]["Depleted"] ~= 1 then
							storage.OPLocate[a]["tile"] = storage.WaterGlobalArea[b]["FluidType"]
						elseif storage.OPLocate[a]["WA"] == b and storage.WaterGlobalArea[b]["Depleted"] == 1 then
							storage.OPLocate[a]["tile"] = "None"
						end
					end
					for b = 1, #game.surfaces, 1 do
						pos = storage.OPLocate[a]["position"]
						local tile = game.surfaces[b].get_tile(pos)
						if tile.valid == true then
							local tilename = tile.name
							if tilename == "water" or tilename =="deepwater" or tilename=="crude-oil" or tilename=="crude-oil-deep" or tilename=="sand-3" or tilename=="dry-dirt" then
								storage.OPLocate[a]["surface"] = game.surfaces[b]
							end
						end
					end
					if storage.OPLocate[a]["spritepos"] == nil then
						--storage.OPLocate[a]["spritepos"] = storage.OPLocate[a]["position"] -- POSITION IS IN WATER / SPRITEPOS IS OUTPUT PIPE
						if storage.OPLocate[a]["direction"] == 0 then -- North
							storage.OPLocate[a]["spritepos"] = {["x"] = storage.OPLocate[a]["position"]["x"], ["y"] = storage.OPLocate[a]["position"]["y"] + 1}
						elseif storage.OPLocate[a]["direction"] == 2 then -- East
							storage.OPLocate[a]["spritepos"] = {["x"] = storage.OPLocate[a]["position"]["x"] - 1, ["y"] = storage.OPLocate[a]["position"]["y"]}
						elseif storage.OPLocate[a]["direction"] == 4 then -- South
							storage.OPLocate[a]["spritepos"] = {["x"] = storage.OPLocate[a]["position"]["x"], ["y"] = storage.OPLocate[a]["position"]["y"] - 1}
						elseif storage.OPLocate[a]["direction"] == 6 then -- West
							storage.OPLocate[a]["spritepos"] = {["x"] = storage.OPLocate[a]["position"]["x"] + 1, ["y"] = storage.OPLocate[a]["position"]["y"]}
						end
					end
					if storage.OPLocate[a]["tile"] == "water" or storage.OPLocate[a]["tile"] == "deepwater" then
						local OPE = storage.OPLocate[a]["entity"]
						local OPD = storage.OPLocate[a]["direction"]
						local OPP = storage.OPLocate[a]["position"]
						local OPSp = storage.OPLocate[a]["spritepos"]
						local OPS = storage.OPLocate[a]["surface"]
						local OPPl = OPE.last_user
						if OPE.valid == true then
							OPPl = OPE.last_user
							if OPPl == nil then
								OPPl = game.players[1]
							end
							OPF = OPPl.force.name
							if OPF == nil or OPF == "player" then
								OPF = OPPl.force.name
							end
						else
							if OPPl == nil then
								OPPl = game.players[1]
							end
							if OPF == nil then
								OPF = "neutral"
							end
						end
						OPE.destroy()
						local OPN = game.surfaces[OPS.name].create_entity{name="offshore-pump",position = OPSp,direction = OPD,player = OPPl,force=OPF}
						storage.OPLocate[a]["entity"] = OPN
						-- if storage.OPLocate[a]["entity"] == nil then
							-- if storage.WaterGlobalArea[storage.OPLocate[a]["WA"]]["OPs"] <= 0 then
								-- storage.WaterGlobalArea[storage.OPLocate[a]["WA"]]["OPs"] = 0
							-- else
								-- storage.WaterGlobalArea[storage.OPLocate[a]["WA"]]["OPs"] = storage.WaterGlobalArea[storage.OPLocate[a]["WA"]]["OPs"] - 1
							-- end
							-- table.remove(storage.OPLocate,a)
							-- game.players[1].insert{name="offshore-pump",count=1}
						-- end
					elseif storage.OPLocate[a]["tile"] == "crude-oil" or storage.OPLocate[a]["tile"] == "crude-oil-deep" then
						local OPE2 = storage.OPLocate[a]["entity"]
						local OPD2 = storage.OPLocate[a]["direction"]
						local OPP2 = storage.OPLocate[a]["position"]
						local OPSp2 = storage.OPLocate[a]["spritepos"]
						local OPS2 = storage.OPLocate[a]["surface"]
						local OP2Pl = OPE2.last_user
						if OPE2.valid == true then
							OP2Pl = OPE2.last_user
							if OP2Pl == nil then
								OP2Pl = game.players[1]
							end
							OPF2 = OP2Pl.force.name
							if OPF2 == nil or OPF2 == "player" then
								OPF2 = OP2Pl.force.name
							end
						else
							if OP2Pl == nil then
								OP2Pl = game.players[1]
							end
							if OPF2 == nil then
								OPF2 = "neutral"
							end
						end
						OPE2.destroy()
						local OPN2 = game.surfaces[OPS2.name].create_entity{name="offshore-crude-oil-pump",position = OPSp2,direction = OPD2,player=OP2Pl,force=OPF2}
						storage.OPLocate[a]["entity"] = OPN2
						-- if storage.OPLocate[a]["entity"] == nil then
							-- if storage.WaterGlobalArea[storage.OPLocate[a]["WA"]]["OPs"] <= 0 then
								-- storage.WaterGlobalArea[storage.OPLocate[a]["WA"]]["OPs"] = 0
							-- else
								-- storage.WaterGlobalArea[storage.OPLocate[a]["WA"]]["OPs"] = storage.WaterGlobalArea[storage.OPLocate[a]["WA"]]["OPs"] - 1
							-- end
							-- table.remove(storage.OPLocate,a)
							-- game.players[1].insert{name="offshore-pump",count=1}
						-- end
					else
						local OPE3 = storage.OPLocate[a]["entity"]
						local OPD3 = storage.OPLocate[a]["direction"]
						local OPP3 = storage.OPLocate[a]["position"]
						local OPSp3 = storage.OPLocate[a]["spritepos"]
						local OPS3 = storage.OPLocate[a]["surface"]
						local OP3Pl = OPE3.last_user
						if OPE3.valid == true then
							OP3Pl = OPE3.last_user
							if OP3Pl == nil then
								OP3Pl = game.players[1]
							end
							OPF3 = OP3Pl.force.name
							if OPF3 == nil or OPF3 == "player" then
								OPF3 = OP3Pl.force.name
							end
						else
							if OP3Pl == nil then
								OP3Pl = game.players[1]
							end
							if OPF3 == nil then
								OPF3 = "neutral"
							end
						end
						OPE3.destroy()
						local OPN3 = game.surfaces[OPS3.name].create_entity{name="offshore-pump-nofluid",position = OPSp3,direction = OPD3,player=OP3Pl,force = OPF3}
						storage.OPLocate[a]["entity"] = OPN3
					end
				end
			end
			if #storage.ODLocate > 0 then
				for a = 1, #storage.ODLocate, 1 do
					if storage.ODLocate[a]["force"] == nil then
						storage.ODLocate[a]["force"] = storage.ODLocate[a]["entity"].last_user.force
					end
					for b = 1, #game.surfaces, 1 do
						pos = storage.ODLocate[a]["position"]
						local tile = game.surfaces[b].get_tile(pos)
						if tile.valid == true then
							local tilename = tile.name
							if tilename == "water" or tilename =="deepwater" or tilename=="crude-oil" or tilename=="crude-oil-deep" or tilename=="sand-3" or tilename=="dry-dirt" then
								storage.ODLocate[a]["surface"] = game.surfaces[b]
							end
						end
					end
					local OPE4 = storage.ODLocate[a]["entity"]
					local OPD4 = storage.ODLocate[a]["direction"]
					local OPP4 = storage.ODLocate[a]["position"]
					local OPS4 = storage.ODLocate[a]["surface"]
					local OP4Pl = OPE4.last_user
					if OPE4.valid == true then
						OP4Pl = OPE4.last_user
						if OP4Pl == nil then
							OP4Pl = game.players[1]
						end
						OPF4 = OP4Pl.force.name
						if OPF4 == nil or OPF4 == "player" then
							OPF4 = OP4Pl.force.name
						end
					else
						if OP4Pl == nil then
							OP4Pl = game.players[1]
						end
						if OPF4 == nil then
							OPF4 = "neutral"
						end
					end
					OPE4.destroy()
					local OPN4 = game.surfaces[OPS4.name].create_entity{name="offshore-drain",position = OPP4, direction = OPD4,player=OP4Pl,force=OPF4}
					storage.ODLocate[a]["entity"] = OPN4
					for b = 1, #storage.WaterGlobalArea, 1 do
						if storage.ODLocate[a]["WA"] == b and storage.WaterGlobalArea[b]["Depleted"] ~= 1 then
							storage.ODLocate[a]["tile"] = storage.WaterGlobalArea[b]["FluidType"]
							storage.ODLocate[a]["PipeFluid"] = storage.WaterGlobalArea[b]["FluidType"]
						elseif storage.ODLocate[a]["WA"] == b and storage.WaterGlobalArea[b]["Depleted"] == 1 then
							storage.ODLocate[a]["tile"] = "None"
							storage.ODLocate[a]["PipeFluid"] = "None"
						end
					end
				end
			end
			Players = #game.players
			if Players <= 1 then
				if storage.PlayerForces == nil or #storage.PlayerForces < 1 then
					Force = game.players[1].force.name
					storage.PlayerForces[#storage.PlayerForces+1] = {["name"] = Force, ["OPcount"] = 0, ["ODcount"] = 0, ["WaterFlow"] = 0, ["LastWaterFlow"] = 0, ["CrudeFlow"] = 0, ["LastCrudeFlow"] = 0, ["TechYRBoost"] = 0}
					for a = 1, #storage.WaterGlobalArea, 1 do
						OPs = 0
						ODs = 0
						for b = 1, #storage.OPLocate, 1 do
							if storage.WaterGlobalArea[a]["WGAID"] == storage.OPLocate[b]["WA"] then
								OPs = OPs + 1
							end
						end
						for c = 1, #storage.ODLocate, 1 do
							if storage.WaterGlobalArea[a]["WGAID"] == storage.ODLocate[c]["WA"] then
								ODs = ODs + 1
							end
						end
						-- OPs = storage.WaterGlobalArea[a]["OPs"]
						storage.WaterGlobalArea[a]["OPs"] = {}
						-- OPsA = storage.WaterGlobalArea[a]["OPsA"]
						storage.WaterGlobalArea[a]["OPsA"] = {}
						-- ODs = storage.WaterGlobalArea[a]["ODs"]
						storage.WaterGlobalArea[a]["ODs"] = {}
						-- ODsA = storage.WaterGlobalArea[a]["ODsA"]
						storage.WaterGlobalArea[a]["ODsA"] = {}
						WtrAdd = storage.WaterGlobalArea[a]["WtrAdd"]
						storage.WaterGlobalArea[a]["WtrAdd"] = {}
						storage.WaterGlobalArea[a]["MapMarker"] = {}
						storage.WaterGlobalArea[a]["MapMarkerPlaced"] = false
						storage.WaterGlobalArea[a]["OPs"][1] = {["force"] = Force, ["count"] = OPs}
						storage.PlayerForces[#storage.PlayerForces]["OPcount"] = storage.PlayerForces[#storage.PlayerForces]["OPcount"] + OPs
						storage.WaterGlobalArea[a]["OPsA"][1] = {["force"] = Force, ["count"] = 0}
						storage.WaterGlobalArea[a]["ODs"][1] = {["force"] = Force, ["count"] = ODs}
						storage.PlayerForces[#storage.PlayerForces]["ODcount"] = storage.PlayerForces[#storage.PlayerForces]["ODcount"] + ODs
						storage.WaterGlobalArea[a]["ODsA"][1] = {["force"] = Force, ["count"] = 0}
						storage.WaterGlobalArea[a]["WtrAdd"][1] = {["force"] = Force, ["count"] = WtrAdd}
						local maptext = string.format("%s - %s - %.2f %%",storage.WaterGlobalArea[a]["WtrName"],comma_value(math.ceil(storage.WaterGlobalArea[a]["AmountWtr"]*((100-storage.WaterGlobalArea[a]["Percent"])/100))),100-storage.WaterGlobalArea[a]["Percent"])
						if #storage.WaterGlobalArea[a]["WaterRepArea"] > 0 then
							storage.WaterGlobalArea[a]["MapMarker"][1] = {["placed"] = true, ["force"] = Force, ["icon"] = game.forces[Force].add_chart_tag(1,{["position"]= storage.WaterGlobalArea[a]["WaterRepArea"][1]["position"],["text"] = maptext})}
						else
							storage.WaterGlobalArea[a]["MapMarker"][1] = {["placed"] = true, ["force"] = Force, ["icon"] = game.forces[Force].add_chart_tag(1,{["position"]= storage.WaterGlobalArea[a]["WaterEdgeArea"][1]["position"],["text"] = maptext})}
						end
					end
				end
			else
				for a = 1, Players, 1 do
					Force = game.players[a].force.name
					if storage.PlayerForces == nil or #storage.PlayerForces < 1 then
						storage.PlayerForces[#storage.PlayerForces+1] = {["name"] = Force, ["OPcount"] = 0, ["ODcount"] = 0, ["WaterFlow"] = 0, ["LastWaterFlow"] = 0, ["CrudeFlow"] = 0, ["LastCrudeFlow"] = 0, ["TechYRBoost"] = 0}
						for b = 1, #storage.WaterGlobalArea, 1 do
							OPs = 0
							ODs = 0
							for c = 1, #storage.OPLocate, 1 do
								if storage.WaterGlobalArea[b]["WGAID"] == storage.OPLocate[c]["WA"] then
									if Force == storage.OPLocate[c]["force"] then
										OPs = OPs + 1
									end
								end
							end
							for d = 1, #storage.ODLocate, 1 do
								if storage.WaterGlobalArea[b]["WGAID"] == storage.ODLocate[d]["WA"] then
									if Force == storage.ODLocate[d]["force"] then
										ODs = ODs + 1
									end
								end
							end
							if OPs > 0 then
								-- OPs = storage.WaterGlobalArea[a]["OPs"]
								storage.WaterGlobalArea[b]["OPs"] = {}
								-- OPsA = storage.WaterGlobalArea[a]["OPsA"]
								storage.WaterGlobalArea[b]["OPsA"] = {}
								storage.WaterGlobalArea[b]["OPs"][1] = {["force"] = Force, ["count"] = OPs}
								storage.WaterGlobalArea[b]["OPsA"][1] = {["force"] = Force, ["count"] = 0}
								storage.PlayerForces[#storage.PlayerForces]["OPcount"] = storage.PlayerForces[#storage.PlayerForces]["OPcount"] + OPs
								local maptext = string.format("%s - %s - %.2f %%",storage.WaterGlobalArea[b]["WtrName"],comma_value(math.ceil(storage.WaterGlobalArea[b]["AmountWtr"]*((100-storage.WaterGlobalArea[b]["Percent"])/100))),100-storage.WaterGlobalArea[b]["Percent"])
								if #storage.WaterGlobalArea[b]["WaterRepArea"] > 0 then
									storage.WaterGlobalArea[b]["MapMarker"][1] = {["force"] = Force, ["placed"] = true,["icon"] = game.forces[Force].add_chart_tag(1,{["position"]= storage.WaterGlobalArea[b]["WaterRepArea"][1]["position"],["text"] = maptext})}
								else
									storage.WaterGlobalArea[b]["MapMarker"][1] = {["force"] = Force, ["placed"] = true,["icon"] = game.forces[Force].add_chart_tag(1,{["position"]= storage.WaterGlobalArea[b]["WaterEdgeArea"][1]["position"],["text"] = maptext})}
								end
								storage.WaterGlobalArea[b]["MapMarkerPlaced"] = false
							end
							if ODs > 0 then
								storage.WaterGlobalArea[b]["ODsA"] = {}
								-- ODs = storage.WaterGlobalArea[a]["ODs"]
								storage.WaterGlobalArea[b]["ODs"] = {}
								-- ODsA = storage.WaterGlobalArea[a]["ODsA"]
								storage.WaterGlobalArea[b]["WtrAdd"] = {}
								storage.WaterGlobalArea[b]["ODs"][1] = {["force"] = Force, ["count"] = ODs}
								storage.WaterGlobalArea[b]["ODsA"][1] = {["force"] = Force, ["count"] = 0}
								storage.WaterGlobalArea[b]["WtrAdd"][1] = {["force"] = Force, ["count"] = WtrAdd}
								storage.PlayerForces[#storage.PlayerForces]["ODcount"] = storage.PlayerForces[#storage.PlayerForces]["ODcount"] + ODs
							end
						end
					else
						NewForce = true
						for e = 1, #storage.PlayerForces, 1 do
							if storage.PlayerForces[e]["name"] == Force then
								NewForce = false
							end
						end
						if NewForce == true then
							storage.PlayerForces[#storage.PlayerForces+1] = {["name"] = Force, ["OPcount"] = 0, ["ODcount"] = 0, ["WaterFlow"] = 0, ["LastWaterFlow"] = 0, ["CrudeFlow"] = 0, ["LastCrudeFlow"] = 0, ["TechYRBoost"] = 0}
							--for f = 1, #storage.PlayerForces, 1 do
								for g = 1, #storage.WaterGlobalArea, 1 do
									OPs = 0
									ODs = 0
									for h = 1, #storage.OPLocate, 1 do
										if storage.WaterGlobalArea[g]["WGAID"] == storage.OPLocate[h]["WA"] then
											-- REBUILD OFFSHORE WITH CORRECT FORCE ASSIGNMENT
											if storage.OPLocate[h]["force"] == storage.PlayerForces[#storage.PlayerForces]["name"] then
												OPs = OPs + 1
											end
										end
									end
									for i = 1, #storage.ODLocate, 1 do
										if storage.WaterGlobalArea[g]["WGAID"] == storage.ODLocate[i]["WA"] then
											-- REBUILD OFFSHORE WITH CORRECT FORCE ASSIGNMENT
											if storage.ODLocate[i]["force"] == storage.PlayerForces[#storage.PlayerForces]["name"] then
												ODs = ODs + 1
											end
										end
									end
									if OPs > 0 then
										storage.WaterGlobalArea[g]["OPs"][#storage.WaterGlobalArea[g]["OPs"]+1] = {["force"] = Force, ["count"] = OPs}
										storage.WaterGlobalArea[g]["OPsA"][#storage.WaterGlobalArea[g]["OPsA"]+1] = {["force"] = Force, ["count"] = 0}
										storage.PlayerForces[#storage.PlayerForces]["OPcount"] = storage.PlayerForces[#storage.PlayerForces]["OPcount"] + OPs
										local maptext = string.format("%s - %s - %.2f %%",storage.WaterGlobalArea[g]["WtrName"],comma_value(math.ceil(storage.WaterGlobalArea[g]["AmountWtr"]*((100-storage.WaterGlobalArea[g]["Percent"])/100))),100-storage.WaterGlobalArea[g]["Percent"])
										if #storage.WaterGlobalArea[g]["WaterRepArea"] > 0 then
											storage.WaterGlobalArea[g]["MapMarker"][#storage.WaterGlobalArea[g]["MapMarker"]+1] = {["force"] = Force, ["placed"] = true,["icon"] = game.forces[Force].add_chart_tag(1,{["position"]= storage.WaterGlobalArea[g]["WaterRepArea"][1]["position"],["text"] = maptext})}
										else
											storage.WaterGlobalArea[g]["MapMarker"][#storage.WaterGlobalArea[g]["MapMarker"]+1] = {["force"] = Force, ["placed"] = true,["icon"] = game.forces[Force].add_chart_tag(1,{["position"]= storage.WaterGlobalArea[g]["WaterEdgeArea"][1]["position"],["text"] = maptext})}
										end
									end
									if ODs > 0 then
										storage.WaterGlobalArea[g]["ODs"][#storage.WaterGlobalArea[g]["ODs"]+1] = {["force"] = Force, ["count"] = ODs}
										storage.WaterGlobalArea[g]["ODsA"][#storage.WaterGlobalArea[g]["ODsA"]+1] = {["force"] = Force, ["count"] = 0}
										storage.WaterGlobalArea[g]["WtrAdd"][#storage.WaterGlobalArea[g]["WtrAdd"]+1] = {["force"] = Force, ["count"] = 0}
										storage.PlayerForces[#storage.PlayerForces]["ODcount"] = storage.PlayerForces[#storage.PlayerForces]["ODcount"] + ODs
									end
								end
							--end
						else
							do end
						end
					end
				end
			end
			for f = 1, #storage.PlayerForces, 1 do
				if storage.PlayerForces[f]["TechYRBoost"] == nil then
					storage.PlayerForces[f]["TechYRBoost"] = 1
				end
				local force = game.forces[storage.PlayerForces[f]["name"]]
				for v = 7, 1, -1 do
					local tech_name = "waar-yield-regen-boost-" .. v
					if force.technologies[tech_name] ~= nil and force.technologies[tech_name].researched then
						TechTrackUpdate(tech_name, force.name, v)
						break
					end
				end
			end
					
			
			-- for a = 1, #storage.OPLocate, 1 do
				-- for b = 1, #storage.WaterGlobalArea, 1 do
					-- for c = 1, #storage.PlayerForces, 1 do
						-- if storage.OPLocate[a]["force"] == storage.WaterGlobalArea[b]["OPs"][c]["force"] then
							-- storage.WaterGlobalArea[b]["OPs"][c]["count"] = storage.WaterGlobalArea[b]["OPs"][c]["count"] + 1
						-- end
					-- end
				-- end
			-- end
			-- for a = 1, #storage.ODLocate, 1 do
				-- for b = 1, #storage.WaterGlobalArea, 1 do
					-- for c = 1, #storage.PlayerForces, 1 do
						-- if storage.ODLocate[a]["force"] == storage.WaterGlobalArea[b]["ODs"][c]["force"] then
							-- storage.WaterGlobalArea[b]["ODs"][c]["count"] = storage.WaterGlobalArea[b]["ODs"][c]["count"] + 1
						-- end
					-- end
				-- end
			-- end
		storage.Added = false
		end
		storage.NewInstall = false
	end
end

-- COMMAND FUNCTIONS -- 
function WAARClearData()
	if storage.WaterGlobalArea then
		for a = #storage.WaterGlobalArea, 1, -1 do
			table.remove(storage.WaterGlobalArea,a)
		end
	end
	if storage.OPLocate then	
		for a = #storage.OPLocate, 1, -1 do
			table.remove(storage.OPLocate,a)
		end
	end
	if storage.ODLocate then
		for a = #storage.ODLocate,1, -1 do
			table.remove(storage.ODLocate,a)
		end
	end
	if storage.FluidProducers then
		for a = #storage.FluidProducers,1, -1 do
			table.remove(storage.ODLocate,a)
		end
	end
	storage.PercentChange = 0
	storage.WaterFlow = 0
	storage.CrudeFlow = 0
	storage.LastWaterFlow = 0
	storage.LastCrudeFlow = 0
	storage.WGAID = 0
	storage.Type = 0
	storage.ActiveOPs = 0
	storage.ActiveODs = 0
	game.print("WAAR Data Cleared!")
end

function RestoreWater()
	local RWDisabled = settings.global["Disable-RestoreWater-Command"].value
	if RWDisabled == true then
		game.player.print("RestoreWater Command has been disabled in map settings.")
	else
		if storage.WaterGlobalArea then
			for a = #storage.WaterGlobalArea, 1, -1 do
				if storage.WaterGlobalArea[a]["Percent"] >= 80 or storage.WaterGlobalArea[a]["FluidType"] == "crude-oil" then
					if #storage.WaterGlobalArea[a]["WaterRepArea"] > 0 then
						local NoTiles = storage.WaterGlobalArea[a]["ShallowWater"] + storage.WaterGlobalArea[a]["DeepWater"]
						for b = 1, NoTiles, 1 do
								TileName = storage.WaterGlobalArea[a]["WaterRepArea"][b]["name"]
								if TileName == "sand-3" or TileName == "crude-oil" or TileName == "lake-shallow" then
									storage.WaterGlobalArea[a]["WaterRepArea"][b]["name"] = "water"
								elseif TileName == "dry-dirt" or TileName == "crude-oil-deep" or "lake-deep" then
									storage.WaterGlobalArea[a]["WaterRepArea"][b]["name"] = "deepwater"
								else
									game.print("Not A Replaceable Tile")
								end
							game.surfaces[storage.WaterGlobalArea[a]["Surface"].name].set_tiles(storage.WaterGlobalArea[a]["WaterRepArea"], true)
						end
					else
						local WGA = storage.WaterGlobalArea
						local surface = WGA[a]["Surface"]
						local WAArea = WGA[a]["WaterEdgeArea"]
						local TilesToReplace = {}
						-- ((x-a)^2 + (y-b)^2) = r^2
						local CirA = WGA[a]["WaterEdgeArea"][1]["position"]["x"]
						local CirB = WGA[a]["WaterEdgeArea"][1]["position"]["y"]
						local CirR = (WGA[a]["Hyp"]^2)
						for c = 1, #WAArea, 1 do
							local CirY = WAArea[c]["position"]["y"]
							for d = WAArea[c]["position"]["x"], WGA[a]["MaxX"], 1 do
								local CirX = d
								local SearchPosition = {x = CirX ,y = CirY}
								local Cir = ((CirX - CirA)^2) + ((CirY - CirB)^2)
								if Cir <= CirR then -- Inside/On the Boundary
									--game.print("InSide Boundary")
									if IsWater(SearchPosition, surface.name) == "lake-shallow" or IsWater(SearchPosition, surface.name) == "crude-oil" or IsWater(SearchPosition, surface.name) == "sand-3" then
										table.insert(TilesToReplace,{name = "water" , position = {x = CirX ,y = CirY}})
										--game.print("Water")
									elseif IsWater(SearchPosition, surface.name) == "lake-deep" or IsWater(SearchPosition, surface.name) == "crude-oil-deep" or IsWater(SearchPosition, surface.name) == "dry-dirt"then
										table.insert(TilesToReplace,{name = "deepwater" , position = {x = CirX ,y = CirY}})
										--game.print("Deepwater")
									elseif IsWater(SearchPosition, surface.name) == false then
										--game.print("Land")
										goto ItsLand3
									end
								end
							end
							::ItsLand3::
						end
						game.surfaces[surface.name].set_tiles(TilesToReplace, true)
					end
				end
				table.remove(storage.WaterGlobalArea,a)
			end
			local RemoveFromTable = settings.global["FluidArea-RemoveFromTable"].value
			if RemoveFromTable == true then
				game.print("As Remove From Table is active, old depleted fluid areas cannot be restored.")
			end
		end
		--storage.WaterGlobalArea = nil
		if storage.OPLocate then	
			for a = #storage.OPLocate, 1, -1 do
				RepOP = storage.OPLocate[a]["position"]
				RepOPSp = storage.OPLocate[a]["spritepos"]
				RepOPD = storage.OPLocate[a]["direction"]
				RepOPE = storage.OPLocate[a]["entity"]
				RepOPS = storage.OPLocate[a]["surface"]
				RepOPPl = storage.OPLocate[a]["entity"].last_user
				if RepOPPl == nil then
					RepOPPl = game.players[1]["name"]
				end
				RepOPF = RepOPE.force
				RepOPE.destroy()
				game.surfaces[RepOPS.name].create_entity{name="offshore-pump",position = RepOPSp,direction = RepOPD,player=RepOPPl,force = RepOPF}
				table.remove(storage.OPLocate,a)
			end
		--storage.OPLocate = nil
		end
		if storage.ODLocate then
			for a = #storage.ODLocate,1, -1 do
				RepODE = storage.ODLocate[a]["entity"]
				RepODE.destroy()
				table.remove(storage.ODLocate,a)
			end
		--storage.ODLocate = nil
		end
		if storage.FluidProducers then
			for a = #storage.FluidProducers,1, -1 do
				table.remove(storage.ODLocate,a)
			end
		--storage.ODLocate = nil
		end
		--storage.FluidProducers = nil
		storage.PercentChange = 0
		storage.WaterFlow = 0
		storage.CrudeFlow = 0
		storage.LastWaterFlow = 0
		storage.LastCrudeFlow = 0
		storage.WGAID = 0
		storage.Type = 0
		storage.ActiveOPs = 0
		storage.ActiveODs = 0
		game.print("FluidAreas Restored!")
	end
end

function StopScanning()
	game.player.print("Stopping All Active Scans")
	for a = 1, #storage.WaterGlobalArea, 1 do
		if storage.WaterGlobalArea[a]["ToSearch"] ~= nil then
			storage.WaterGlobalArea[a]["ToSearch"] = nil
		
			if storage.WaterGlobalArea[a]["WtrName"] == "None" or storage.WaterGlobalArea[a]["WtrName"] == "Puddle" or storage.WaterGlobalArea[a]["WtrName"] == "Well" or storage.WaterGlobalArea[a]["WtrName"] == "Pond"  then
				waterbodies.WtrName(a)
			end
			game.print(string.format("%s created, with %sL of %s with regen %sL.", storage.WaterGlobalArea[a]["WtrName"], comma_value(storage.WaterGlobalArea[a]["AmountWtr"]), storage.WaterGlobalArea[a]["FluidType"], storage.WaterGlobalArea[a]["RegenAmount"]))

			MapMarker(a)
		end
	end
end

function PlayerForces()
	game.player.print("PlayerForces Info")
	if #storage.PlayerForces == 0 then
		game.player.print("No PlayerForces Data to show.")
	else
		local PF = storage.PlayerForces
		for a = 1, #storage.PlayerForces, 1 do
			game.player.print(string.format("PlayerForce: %s, Offshore: Pumps: %s | Drains: %s, Flow: Water: %s | Crude: %s",storage.PlayerForces[a]["name"],storage.PlayerForces[a]["OPcount"],storage.PlayerForces[a]["ODcount"],comma_value(storage.PlayerForces[a]["WaterFlow"]),comma_value(storage.PlayerForces[a]["CrudeFlow"])))
		end
	end
end

function Offshores()
	game.player.print("Offshore Pump(s) Info")
	if #storage.OPLocate == 0 then
		game.player.print("No Offshore Pump(s) on map.")
	else
		local PlayerForce = game.player.force.name
		local Found = false
		for a = 1, #storage.OPLocate, 1 do
			if storage.OPLocate[a]["force"] == PlayerForce then
				Found = true
				local FluidName = string.sub(storage.OPLocate[a]["tile"],1,1):upper()..string.sub(storage.OPLocate[a]["tile"],2)
				local SurfaceName = string.sub(storage.OPLocate[a]["surface"].name,1,1):upper()..string.sub(storage.OPLocate[a]["surface"].name,2)
				game.player.print(string.format("Offshore Pump Position: {%s, %s}, Pump Surface: %s, Fluid Type: %s, FluidArea: %s, Active: %s, Force: %s",storage.OPLocate[a]["position"]["x"],storage.OPLocate[a]["position"]["y"],SurfaceName, FluidName,storage.OPLocate[a]["WA"], storage.OPLocate[a]["Active"], storage.OPLocate[a]["force"]))
			end
		end
		if Found == false then
			game.player.print("No Offshore Pump(s) for your Team.")
		end
	end
end

function OffshoreDrains()
	game.player.print("Offshore Drain(s) Info")
	if #storage.ODLocate == 0 then
		game.player.print("No Offshore Drain(s) on map.")
	else
		local PlayerForce = game.player.force.name
		local Found = false
		for a = 1, #storage.ODLocate, 1 do
			if storage.ODLocate[a]["force"] == PlayerForce then
				if storage.ODLocate[a]["PipeFluid"] == nil then
					FluidName = "None"
				else
					FluidName = string.sub(storage.ODLocate[a]["PipeFluid"],1,1):upper()..string.sub(storage.ODLocate[a]["PipeFluid"],2)
				end
				Found = true
				local SurfaceName = string.sub(storage.ODLocate[a]["surface"].name,1,1):upper()..string.sub(storage.ODLocate[a]["surface"].name,2)
				game.player.print(string.format("Offshore Drain Position: {%s, %s}, Pipe Surface: %s , Pipe Fluid: %s, Fluid Area: %s, Active: %s",storage.ODLocate[a]["position"]["x"],storage.ODLocate[a]["position"]["y"],SurfaceName, FluidName, storage.ODLocate[a]["WA"], storage.ODLocate[a]["Active"]))
			end
		end
		if Found == false then
			game.player.print("No Offshore Drain(s) for your Team.")
		end
	end
end

function WaterAreas()
	game.player.print("FluidArea(s) Info")
	if #storage.WaterGlobalArea == 0 then
		game.player.print("No FluidArea(s) on map.")
	else
		PForce = game.player.force.name
		Found = false
		for a = 1, #storage.WaterGlobalArea, 1 do
			OPs = 0
			OPsA = 0
			ODs = 0
			ODsA = 0
			Shallow = 0
			for b = 1, #storage.WaterGlobalArea[a]["OPs"], 1 do
				if storage.WaterGlobalArea[a]["OPs"][b]["force"] == PForce then
					Found = true
					FluidName = string.sub(storage.WaterGlobalArea[a]["FluidType"],1,1):upper()..string.sub(storage.WaterGlobalArea[a]["FluidType"],2)
					FluidName2 = FluidName
					if FluidName2 == "None" then
						FluidName2 = "Fluid"
					end
					SurfaceName = string.sub(storage.WaterGlobalArea[a]["Surface"].name,1,1):upper()..string.sub(storage.WaterGlobalArea[a]["Surface"].name,2)
					if storage.WaterGlobalArea[a]["OPs"][b] == nil then
						OPs = 0
						OPsA = 0
					else
						OPs = storage.WaterGlobalArea[a]["OPs"][b]["count"]
						OPsA = storage.WaterGlobalArea[a]["OPsA"][b]["count"]
					end
					Shallow = storage.WaterGlobalArea[a]["ShallowWater"] + storage.WaterGlobalArea[a]["ShallowWater-Shallow"] + storage.WaterGlobalArea[a]["ShallowWater-Mud"]
				end
			end
			for d = 1, #storage.WaterGlobalArea[a]["ODs"], 1 do
				if storage.WaterGlobalArea[a]["ODs"][d]["force"] == PForce then
					Found = true
					FluidName = string.sub(storage.WaterGlobalArea[a]["FluidType"],1,1):upper()..string.sub(storage.WaterGlobalArea[a]["FluidType"],2)
					FluidName2 = FluidName
					if FluidName2 == "None" then
						FluidName2 = "Fluid"
					end
					SurfaceName = string.sub(storage.WaterGlobalArea[a]["Surface"].name,1,1):upper()..string.sub(storage.WaterGlobalArea[a]["Surface"].name,2)
					if storage.WaterGlobalArea[a]["ODs"][d] == nil then
						ODs = 0
						ODsA = 0
					else
						ODs = storage.WaterGlobalArea[a]["ODs"][d]["count"]
						ODsA = storage.WaterGlobalArea[a]["ODsA"][d]["count"]
					end
					Shallow = storage.WaterGlobalArea[a]["ShallowWater"] + storage.WaterGlobalArea[a]["ShallowWater-Shallow"] + storage.WaterGlobalArea[a]["ShallowWater-Mud"]
				end
			end
			if Found == true then
				game.player.print(string.format("ID: %s | %s | Surface: %s | Fluid Type: %s | %s Amount: %s L | Regen %.2f | Percent Depleted: %.4f %% | \n Tiles (RepArea:(%.f) / EdgeArea:(%.f)) | Shallow: %.f / Deep: %.f | Active: Pumps: %.f / Drains: %.f | Total : Pumps: %.f / Drains: %.f |", storage.WaterGlobalArea[a]["WGAID"],storage.WaterGlobalArea[a]["WtrName"],SurfaceName,FluidName,FluidName2, comma_value(storage.WaterGlobalArea[a]["AmountWtr"]),storage.WaterGlobalArea[a]["RegenAmount"], storage.WaterGlobalArea[a]["Percent"],#storage.WaterGlobalArea[a]["WaterRepArea"],#storage.WaterGlobalArea[a]["WaterEdgeArea"],Shallow,storage.WaterGlobalArea[a]["DeepWater"], OPsA, ODsA, OPs,ODs))
			end
		end
		if Found == false then
			game.player.print("No FluidArea(s) for your Team.")
		end
	end
end

function PumpJacks()
	game.player.print("Pumpjack(s) Location Info")
	if #storage.FluidProducers == 0 then
		game.player.print("No Pumpjack(s) to show.")
	else
		local PlayerForce = game.player.force.name
		for a = 1, #storage.FluidProducers, 1 do
			if storage.FluidProducers[a]["force"] == PlayerForce then
				local SurfaceName = string.sub(storage.FluidProducers[a]["surface"].name,1,1):upper()..string.sub(storage.FluidProducers[a]["surface"].name,2)
				game.player.print(string.format("Pumpjack Position: {%s, %s}, Pumpjack Surface: %s",storage.FluidProducers[a]["position"]["x"],storage.FluidProducers[a]["position"]["y"],SurfaceName))
			end
		end
	end
end

function TechTrackUpdate(research_name, force_name, research_level)
	for a = 1, #storage.PlayerForces, 1 do
		if force_name == storage.PlayerForces[a].name then
			if research_name == "waar-yield-regen-boost-1" then
				storage.PlayerForces[a]["TechYRBoost"] = 1.2
			elseif research_name == "waar-yield-regen-boost-2" then
				storage.PlayerForces[a]["TechYRBoost"] = 1.4
			elseif research_name == "waar-yield-regen-boost-3" then
				storage.PlayerForces[a]["TechYRBoost"] = 1.6
			elseif research_name == "waar-yield-regen-boost-4" then
				storage.PlayerForces[a]["TechYRBoost"] = 1.8
			elseif research_name == "waar-yield-regen-boost-5" then
				storage.PlayerForces[a]["TechYRBoost"] = 2.0
			else
				BoostLevel=research_level
				storage.PlayerForces[a]["TechYRBoost"] = 2.0 + (0.2 * (BoostLevel-6))
			end
		end
		for b = 1, #storage.WaterGlobalArea, 1 do
			for c = 1, #storage.OPLocate, 1 do
				if storage.WaterGlobalArea[b]["WGAID"] == storage.OPLocate[c]["WA"] and storage.OPLocate[c]["force"] == storage.PlayerForces[a].name then
					if storage.WaterGlobalArea[b]["TechYRBoost"] < storage.PlayerForces[a]["TechYRBoost"] then
						storage.WaterGlobalArea[b]["TechYRBoost"] = storage.PlayerForces[a]["TechYRBoost"]
					end
				end
			end
			if BoostLevel == 1 then
				storage.WaterGlobalArea[b]["AmountWtr"] = storage.WaterGlobalArea[b]["AmountWtr"] * storage.WaterGlobalArea[b]["TechYRBoost"]
				storage.WaterGlobalArea[b]["RegenAmount"] = storage.WaterGlobalArea[b]["RegenAmount"] * storage.WaterGlobalArea[b]["TechYRBoost"]
				if storage.WaterGlobalArea[b]["WtrUsed"] > 0 then
					storage.WaterGlobalArea[b]["WtrUsed"] = storage.WaterGlobalArea[b]["WtrUsed"] * storage.WaterGlobalArea[b]["TechYRBoost"]
				end
			else
				storage.WaterGlobalArea[b]["AmountWtr"] = (storage.WaterGlobalArea[b]["AmountWtr"] / (storage.WaterGlobalArea[b]["TechYRBoost"] - 0.2)) * storage.WaterGlobalArea[b]["TechYRBoost"]
				storage.WaterGlobalArea[b]["RegenAmount"] = (storage.WaterGlobalArea[b]["RegenAmount"] / (storage.WaterGlobalArea[b]["TechYRBoost"] - 0.2)) * storage.WaterGlobalArea[b]["TechYRBoost"]
				if storage.WaterGlobalArea[b]["WtrUsed"] > 0 then
					storage.WaterGlobalArea[b]["WtrUsed"] = (storage.WaterGlobalArea[b]["WtrUsed"] / (storage.WaterGlobalArea[b]["TechYRBoost"] - 0.2)) * storage.WaterGlobalArea[b]["TechYRBoost"]
				end
			end
		end
	end	
end

function TechTrack(event)
	if event.research.name == "waar-yield-regen-boost-1" or event.research.name == "waar-yield-regen-boost-2" or event.research.name == "waar-yield-regen-boost-3" or event.research.name == "waar-yield-regen-boost-4" or event.research.name == "waar-yield-regen-boost-5" or event.research.name == "waar-yield-regen-boost-6" or event.research.name == "waar-yield-regen-boost-7" then
		TechTrackUpdate(event.research.name, event.research.force.name, event.research.level)
	end
end

function ScenFunc()
	storage.LandFill = {}
	storage.PlayerForces = {}
	storage.ScanOffshoresQueue = {}
	storage.InstallTick = 0
	storage.WGAID = 0
	storage.LoopTick = 0
end

function WaaRSetup()
	storages()
	Linkstorages()
	for _, force in pairs(game.forces) do	-- Enable Offshore Drain Recipe if Fluid Handling has already been Researched
		if force.technologies["fluid-handling"].researched then
			force.recipes["offshore-drain"].enabled = true
		end
	end
end

-- SCRIPT EVENTS -- 

script.on_init(WaaRSetup)
script.on_load(Linkstorages)
--script.on_nth_tick(60,EverySec)
script.on_nth_tick(6, CheckWater)
-- script.set_event_filter(defines.events.on_built_entity,{{filter="type", type = "offshore-pump"},{filter="type", type = "pipe"}})
-- script.set_event_filter(defines.events.on_robot_built_entity,{{filter="type", type = "offshore-pump"},{filter="type", type = "pipe"}})
-- script.set_event_filter(defines.events.script_raised_built,{{filter="type", type = "offshore-pump"},{filter="type", type = "pipe"}})
script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity}, BuiltOffShore )
script.on_event({defines.events.script_raised_built}, ScriptConvert)
script.on_event({defines.events.on_player_mined_entity,defines.events.script_raised_destroy,defines.events.on_robot_mined_entity,defines.events.on_entity_died}, DestroyedOffShore)
script.on_event({defines.events.on_player_built_tile,defines.events.on_robot_built_tile}, LandFillCheck)
script.on_event({defines.events.script_raised_set_tiles}, RaisedSetTiles)
script.on_event({defines.events.on_game_created_from_scenario},ScenFunc)
script.on_event({defines.events.on_research_finished},TechTrack)

script.on_configuration_changed(UpdateMod)
remote.add_interface("WaaR", {	build = function(a,b)	event = a	storage.remotetrigger = b	if event ~= nil then		ScriptConvert(event)	end end})
commands.add_command("RestoreWater", "Restores Water Areas & Clears storageTable",RestoreWater)
commands.add_command("Offshores", "Displays All The Offshore Pumps Built", Offshores)
commands.add_command("OffshoreDrains", "Displays All The Offshore Drains Built", OffshoreDrains)
commands.add_command("WaterAreas", "Displays All The WaterAreas Built", WaterAreas)
commands.add_command("Pumpjacks", "Displays All The Pumpjacks Built", PumpJacks)
commands.add_command("PlayerForces", "Displays All PlayerForces",PlayerForces)
commands.add_command("StopScan", "Stops actively scanning any area that is",StopScanning)
commands.add_command("WAARClearData", "Stops actively scanning any area that is",WAARClearData)