-- WATER AS A RESOURCE MAIN LUA CONTROL PROGRAM -- 
--    CREATED BY TREEFROGGREAKEN 2018 - 2021    --

-- REQUIRED ADDITIONAL LUA FILES -- 

require("waterbodies") -- Loads waterbodies.lua
require("fluidentities")
require("fluidlist")

-- GLOBAL VARIABLES

function Globals()
	if not global.WaterGlobalArea then global.WaterGlobalArea = {} end
	if not global.OPLocate then global.OPLocate = {} end
	if not global.ODLocate then global.ODLocate = {} end
	if not global.LandFill then global.LandFill = {} end
	if not global.FluidProducers then global.FluidProducers = {} end
	if not global.PlayerForces then global.PlayerForces = {} end
	if not global.FluidFlow then global.FluidFlow = {} end
	if not global.ScanOffshoresQueue then global.ScanOffshoresQueue = {} end
	
	if not global.WGAID then global.WGAID = 0 end
	if not global.Type then global.Type = 0 end
	-- if not global.WaterFlow then global.WaterFlow = 0 end
	-- if not global.CrudeFlow then global.CrudeFlow = 0 end
	-- if not global.LastWaterFlow then global.LastWaterFlow = 0 end
	-- if not global.LastCrudeFlow then global.LastCrudeFlow = 0 end
	if not global.WaterBodyType then global.WaterBodyType = 0 end
	if not global.ActiveOPs then global.ActiveOPs = 0 end
	if not global.ActiveODs then global.ActiveODs = 0 end
	if not global.PercentChange then global.PercentChange = 0 end
	if not global.InstallTick then global.InstallTick = 0 end
	if not global.LoopTick then global.LoopTick = 0 end

	if not global.Added then global.Added = true end
	if not global.NewInstall then global.NewInstall = true end
	if not global.ITMessage then global.ITMessage = true end
	if not global.remotetrigger then global.remotetrigger = false end
	if not global.ODRemoved then global.ODRemoved = false end
	if not global.EnableNextOffshore then global.EnableNextOffshore = false end
end

function LinkGlobals()
	-- WaterFlow = global.WaterFlow
	-- CrudeFlow = global.CrudeFlow
	-- LastWaterFlow = global.LastWaterFlow
	-- LastCrudeFlow = global.LastCrudeFlow
	WaterBodyType = global.WaterBodyType
	ActiveOPs = global.ActiveOPs
	ActiveODs = global.ActiveODs
	PercentChange = global.PercentChange
	WGAID = global.WGAID
end

-- EVENT DEPENDANT FUNCTIONS

function EdgePattern(SearchPosition, WASearchQueue)
	local EDPA = {}
	local north = {x = SearchPosition.x, y = SearchPosition.y-1}				-- Create Local North Table make it equal to SearchPostion -1 y
	local northeast = {x = SearchPosition.x+1, y = SearchPosition.y-1}
	local east  = {x = SearchPosition.x+1, y = SearchPosition.y}				-- Create Local East Table make it equal to SearchPostion +1 x
	local southeast = {x = SearchPosition.x+1, y = SearchPosition.y+1}
	local south = {x = SearchPosition.x, y = SearchPosition.y+1}				-- Create Local South Table make it equal to SearchPostion +1 y
	local southwest = {x = SearchPosition.x-1, y = SearchPosition.y+1}
	local west  = {x = SearchPosition.x-1, y = SearchPosition.y}				-- Create Local West Table make it equal to SearchPostion -1 x
	local northwest = {x = SearchPosition.x-1, y = SearchPosition.y-1}
	EDPA[#EDPA+1] = north
	EDPA[#EDPA+1] = northeast
	EDPA[#EDPA+1] = east
	EDPA[#EDPA+1] = southeast
	EDPA[#EDPA+1] = south
	EDPA[#EDPA+1] = southwest
	EDPA[#EDPA+1] = west
	EDPA[#EDPA+1] = northwest
	for a = 1, #EDPA, 1 do
		if WASearched[GridRef(EDPA[a])] ~= true then
			local tile = game.surfaces[surface].get_tile{x=EDPA[a]["x"],y=EDPA[a]["y"]}
			if tile.valid == true then
				if tile.name == "water" or tile.name == "deepwater" or tile.name == "water-green" or tile.name == "water-shallow" or tile.name == "water-mud" or tile.name == "deepwater-green" then
					-- NOT Edge, Add To Queue
					if TotalArea <= PlayerMaxArea then
						WASearchQueue[#WASearchQueue+1] = {x=tile.position.x,y=tile.position.y}
					end
				else
					-- Edge, Exclude from Queue
					SearchPosition = {x = tile.position.x, y = tile.position.y}
					WASearched[GridRef(SearchPosition)] = true
					Edge = true
				end
			end
		end
	end
	if Edge == true then
		return true, WASearchQueue
	else
		return false, WASearchQueue
	end
end

function CheckEdge(SearchPosition)
	local CheckEdgeTable = {}
	local north = game.surfaces[surface].get_tile{x = SearchPosition.x, y = SearchPosition.y-1}				-- Create Local North Table make it equal to SearchPostion -1 y
	local northeast = game.surfaces[surface].get_tile{x = SearchPosition.x+1, y = SearchPosition.y-1}
	local east  = game.surfaces[surface].get_tile{x = SearchPosition.x+1, y = SearchPosition.y}				-- Create Local East Table make it equal to SearchPostion +1 x
	local southeast = game.surfaces[surface].get_tile{x = SearchPosition.x+1, y = SearchPosition.y+1}
	local south = game.surfaces[surface].get_tile{x = SearchPosition.x, y = SearchPosition.y+1}				-- Create Local South Table make it equal to SearchPostion +1 y
	local southwest = game.surfaces[surface].get_tile{x = SearchPosition.x-1, y = SearchPosition.y+1}
	local west  = game.surfaces[surface].get_tile{x = SearchPosition.x-1, y = SearchPosition.y}				-- Create Local West Table make it equal to SearchPostion -1 x
	local northwest = game.surfaces[surface].get_tile{x = SearchPosition.x-1, y = SearchPosition.y-1}
	CheckEdgeTable[#CheckEdgeTable+1] = north
	CheckEdgeTable[#CheckEdgeTable+1] = northeast
	CheckEdgeTable[#CheckEdgeTable+1] = east
	CheckEdgeTable[#CheckEdgeTable+1] = southeast
	CheckEdgeTable[#CheckEdgeTable+1] = south
	CheckEdgeTable[#CheckEdgeTable+1] = southwest
	CheckEdgeTable[#CheckEdgeTable+1] = west
	CheckEdgeTable[#CheckEdgeTable+1] = northwest
	for a = 1, #CheckEdgeTable, 1 do
		if CheckEdgeTable[a].valid == true then
			if CheckEdgeTable[a].name == "water" or CheckEdgeTable[a].name == "water-green" or CheckEdgeTable[a].name == "water-shallow" or CheckEdgeTable[a].name == "water-mud" or CheckEdgeTable[a].name == "deepwater" or CheckEdgeTable[a].name == "deepwater-green" then
				--game.print("Not Edge")
			else
				--game.print("Edge")
				WASearched[GridRef(SearchPosition)] = true
				return true
			end
		end
	end
	return false
end

function SearchPattern (SearchPosition, WASearchQueue)							-- Function to Setup SearchPattern
	local SPD = {}
	local north = {x = SearchPosition.x, y = SearchPosition.y-1}				-- Create Local North Table make it equal to SearchPostion -1 y
	local northeast = {x = SearchPosition.x+1, y = SearchPosition.y-1}
	local east  = {x = SearchPosition.x+1, y = SearchPosition.y}				-- Create Local East Table make it equal to SearchPostion +1 x
	local southeast = {x = SearchPosition.x+1, y = SearchPosition.y+1}
	local south = {x = SearchPosition.x, y = SearchPosition.y+1}				-- Create Local South Table make it equal to SearchPostion +1 y
	local southwest = {x = SearchPosition.x-1, y = SearchPosition.y+1}
	local west  = {x = SearchPosition.x-1, y = SearchPosition.y}				-- Create Local West Table make it equal to SearchPostion -1 x
	local northwest = {x = SearchPosition.x-1, y = SearchPosition.y-1}
	SPD[#SPD+1] = north
	SPD[#SPD+1] = northeast
	SPD[#SPD+1] = east
	SPD[#SPD+1] = southeast
	SPD[#SPD+1] = south
	SPD[#SPD+1] = southwest
	SPD[#SPD+1] = west
	SPD[#SPD+1] = northwest
	for a = 1, #SPD, 1 do
		local tile = game.surfaces[surface].get_tile{x=SPD[a]["x"],y=SPD[a]["y"]}
		if tile.valid == true then
			if WASearched[GridRef(SPD[a])] ~= true then
				if tile.name == "water" or tile.name == "deepwater" or tile.name == "water-green" or tile.name == "water-shallow" or tile.name == "water-mud" or tile.name == "deepwater-green" then
					WASearchQueue[#WASearchQueue+1] = {x=tile.position.x,y=tile.position.y}
				else
					SearchPosition = {x = tile.position.x, y = tile.position.y}
					WASearched[GridRef(SearchPosition)] = true
				end
			end
		end
	end
	return WASearchQueue														-- Return WASearchQueue Table as Result
end

function GridRef (SearchPosition)
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
	if #global.WaterGlobalArea == 0 then
		if global.Type == 1 then
			CreateWaterArea()	-- Create WaterArea
			player = global.OPLocate[1]["entity"].last_user
			global.OPLocate[1]["WA"] = global.WGAID			-- Assign Offshore Pump 1 to WaterArea 1 - If RemoveWAOPD Active then Assign WGAID
			global.WaterGlobalArea[1]["OPs"][1] = {["force"] = global.OPLocate[1]["force"], ["count"] = 1}
			global.WaterGlobalArea[1]["OPsA"][1] = {["force"] = global.OPLocate[1]["force"], ["count"] = 0}
			global.WaterGlobalArea[1]["MapMarker"][1] = {["force"] = global.OPLocate[1]["force"], ["placed"] = false,["icon"] = nil}
			global.WaterGlobalArea[1]["Surface"] = global.OPLocate[1]["entity"].surface
			AssignFluid()
			if global.WaterGlobalArea[1]["ToSearch"] == nil then
				game.forces[player.force.name].print(string.format("%s created, with %sL of %s.", global.WaterGlobalArea[1]["WtrName"], comma_value(global.WaterGlobalArea[1]["AmountWtr"]), global.WaterGlobalArea[1]["FluidType"]))
				a = 1
				MapMarker(a)
				return "GWA-Complete"
			else
				game.players[player.name].print("FluidArea being scanned, please wait for assignment.")
				return "GWA-ToSearch"
			end
		elseif global.Type == 2 then
			local x = global.ODLocate[1]["position"]["x"]
			local y = global.ODLocate[1]["position"]["y"]
			surface = global.ODLocate[1]["surface"].name
			local dir = global.ODLocate[1]["direction"]
			player = global.ODLocate[1]["entity"].last_user
			if dir == 0 then -- North
				SearchPosition = {x = global.ODLocate[1]["position"]["x"], y = global.ODLocate[1]["position"]["y"]+1}
			elseif dir == 2 then -- East
				SearchPosition = {x = global.ODLocate[1]["position"]["x"]-1, y = global.ODLocate[1]["position"]["y"]}
			elseif dir == 4 then -- South
				SearchPosition = {x = global.ODLocate[1]["position"]["x"], y = global.ODLocate[1]["position"]["y"]-1}
			elseif dir == 6 then -- West
				SearchPosition = {x = global.ODLocate[1]["position"]["x"]+1, y = global.ODLocate[1]["position"]["y"]}
			end
			local WaterCheck = global.ODLocate[1]["surface"].get_tile(x,y).name
			if IsWater(SearchPosition,surface) == false then
				if WaterCheck == "water" or WaterCheck == "deepwater" then
					CreateWaterArea()
					global.ODLocate[1]["WA"] = 1
					global.WaterGlobalArea[1]["ODs"][1] = {["force"] = global.ODLocate[1]["force"], ["count"] = 1}
					global.WaterGlobalArea[1]["ODsA"][1] = {["force"] = global.ODLocate[1]["force"], ["count"] = 0}
					global.WaterGlobalArea[1]["WtrAdd"][1] = {["force"] = global.ODLocate[1]["force"], ["count"] = 0}
					global.WaterGlobalArea[1]["MapMarker"][1] = {["force"] = global.ODLocate[1]["force"], ["placed"] = false,["icon"] = nil}
					global.WaterGlobalArea[1]["Surface"] = global.ODLocate[1]["entity"].surface
					AssignFluid()
					if global.WaterGlobalArea[1]["ToSearch"] == nil then
						game.forces[player.force.name].print(string.format("%s created, with %sL of %s.", global.WaterGlobalArea[1]["WtrName"], comma_value(global.WaterGlobalArea[1]["AmountWtr"]), "water"))
						a = 1
						MapMarker(a)
						return "GWA-Complete"
					else
						game.print("FluidArea being scanned, please wait for assignment.")
						return "GWA-ToSearch"
					end
				else
					game.players[player.name].print("Area not suitable for Offshore Drain.")
					global.ODLocate[1]["entity"].destroy()
					table.remove(global.ODLocate)
					game.players[player.name].insert{name="offshore-drain",count=1}
					global.ODRemoved = true
					return "GWA-NotSuitable"
				end
			else
				game.players[player.name].print("Not On Edge Of Lake.")
				global.ODLocate[1]["entity"].destroy()
				table.remove(global.ODLocate)
				game.players[player.name].insert{name="offshore-drain",count=1}
				global.ODRemoved = true
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
		if global.Type == 1 then
			CreateWaterArea()
			player = global.OPLocate[#global.OPLocate]["entity"].last_user
			force = global.OPLocate[#global.OPLocate]["entity"].force.name
			global.OPLocate[#global.OPLocate]["WA"] = global.WaterGlobalArea[#global.WaterGlobalArea]["WGAID"]
			global.WaterGlobalArea[#global.WaterGlobalArea]["OPs"][1] = {["force"] = global.OPLocate[#global.OPLocate]["force"], ["count"] = 1}
			global.WaterGlobalArea[#global.WaterGlobalArea]["OPsA"][1] = {["force"] = global.OPLocate[#global.OPLocate]["force"], ["count"] = 0}
			global.WaterGlobalArea[#global.WaterGlobalArea]["MapMarker"][1] = {["force"] = global.OPLocate[#global.OPLocate]["force"], ["placed"] = false,["icon"] = nil}
			global.WaterGlobalArea[#global.WaterGlobalArea]["Surface"] = global.OPLocate[#global.OPLocate]["entity"].surface
			AssignFluid()
			if global.WaterGlobalArea[#global.WaterGlobalArea]["ToSearch"] == nil then
				game.forces[force].print(string.format("%s created, with %sL of %s.", global.WaterGlobalArea[#global.WaterGlobalArea]["WtrName"], comma_value(global.WaterGlobalArea[#global.WaterGlobalArea]["AmountWtr"]), global.WaterGlobalArea[#global.WaterGlobalArea]["FluidType"]))
				a = #global.WaterGlobalArea
				MapMarker(#global.WaterGlobalArea)
				return "CA-Complete"
			else
				game.players[player.name].print("FluidArea being scanned, please wait for assignment.")
				return "CA-ToSearch"
			end
			FoundExt = false
		elseif global.Type == 2 then
			local x = global.ODLocate[#global.ODLocate]["position"]["x"]
			local y = global.ODLocate[#global.ODLocate]["position"]["y"]
			surface = global.ODLocate[#global.ODLocate]["surface"].name
			local dir = global.ODLocate[#global.ODLocate]["direction"]
			player = global.ODLocate[#global.ODLocate]["entity"].last_user
			if dir == 0 then -- North
				SearchPosition = {x = global.ODLocate[#global.ODLocate]["position"]["x"], y = global.ODLocate[#global.ODLocate]["position"]["y"]+1}
			elseif dir == 2 then -- East
				SearchPosition = {x = global.ODLocate[#global.ODLocate]["position"]["x"]-1, y = global.ODLocate[#global.ODLocate]["position"]["y"]}
			elseif dir == 4 then -- South
				SearchPosition = {x = global.ODLocate[#global.ODLocate]["position"]["x"], y = global.ODLocate[#global.ODLocate]["position"]["y"]-1}
			elseif dir == 6 then -- West
				SearchPosition = {x = global.ODLocate[#global.ODLocate]["position"]["x"]+1, y = global.ODLocate[#global.ODLocate]["position"]["y"]+1}
			end
			local WaterCheck = global.ODLocate[#global.ODLocate]["surface"].get_tile(x,y).name
			if IsWater(SearchPosition,surface) == false then
				if WaterCheck == "water" or WaterCheck == "deepwater" then
					CreateWaterArea()
					global.ODLocate[#global.ODLocate]["WA"] = global.WaterGlobalArea[#global.WaterGlobalArea]["WGAID"]
					global.WaterGlobalArea[#global.WaterGlobalArea]["ODs"][1] = {["force"] = global.ODLocate[#global.ODLocate]["force"], ["count"] = 1}
					global.WaterGlobalArea[#global.WaterGlobalArea]["ODsA"][1] = {["force"] = global.ODLocate[#global.ODLocate]["force"], ["count"] = 0}
					global.WaterGlobalArea[#global.WaterGlobalArea]["WtrAdd"][1] = {["force"] = global.ODLocate[#global.ODLocate]["force"], ["count"] = 0}
					global.WaterGlobalArea[#global.WaterGlobalArea]["MapMarker"][1] = {["force"] = global.ODLocate[#global.ODLocate]["force"], ["placed"] = false,["icon"] = nil}
					-- global.WaterGlobalArea[#global.WaterGlobalArea]["ODs"] = 1
					global.WaterGlobalArea[#global.WaterGlobalArea]["Surface"] = global.ODLocate[#global.ODLocate]["entity"].surface
					AssignFluid()
					if global.WaterGlobalArea[#global.WaterGlobalArea]["ToSearch"] == nil then
						game.forces[player.force.name].print(string.format("%s created, with %sL of %s.", global.WaterGlobalArea[#global.WaterGlobalArea]["WtrName"], comma_value(global.WaterGlobalArea[#global.WaterGlobalArea]["AmountWtr"]), "water"))
						a = #global.WaterGlobalArea
						MapMarker(a)
						return "CA-Complete"
					else
						game.players[player.name].print("FluidArea being scanned, please wait for assignment.")
						return "CA-ToSearch"
					end
				else
					game.players[player.name].print("Area not suitable for Offshore Drain.")
					global.ODLocate[#global.ODLocate]["entity"].destroy()
					table.remove(global.ODLocate,#global.ODLocate)
					game.players[player.name].insert{name="offshore-drain",count=1}
					global.ODRemoved = true
					return "CA-NotSuitable"
				end
				FoundExt = false
			else
				game.players[player.name].print("Not On Edge of Lake.")
				global.ODLocate[#global.ODLocate]["entity"].destroy()
				table.remove(global.ODLocate,#global.ODLocate)
				game.players[player.name].insert{name="offshore-drain",count=1}
				global.ODRemoved = true
				return "CA-NotEdge"
			end
			FoundExt = false
		end
	end
end

function CreateWaterArea()
	global.WaterGlobalArea[#global.WaterGlobalArea+1] = {["WGAID"] = 0, ["WtrName"] = "None",["Surface"] = nil, ["ToSearch"] = nil, ["HasSearched"] = nil,["LoopCount"] = 0, ["AmountWtr"] = 0,["AmountBonusValue"] = 0,["RegenAmount"] = 0,["Depleted"] = 0,["ShallowWater"] = 0, ["DeepWater"] = 0,["ShallowWater-Shallow"] = 0,["ShallowWater-Mud"] = 0,["Percent"] = 0,["PercentPrev"] = 0,["Fired50"] = false, ["Fired75"] = false, ["Fired90"] = false, ["Fired95"] = false, ["Fired97"] = false,["Fired98"] = false,["Fired99"] = false,["RandPercent"] = 79, ["BTF"] = 0,["BTFE"] = 0,["Below80"] = 0, ["WaterRepArea"] = {},["WaterEdgeArea"] = {},["WaterEdgeAreaY"] = {},["WaterEdgeAreaX"] = {},["MinX"] = 0, ["MaxX"] = 0, ["MinY"] = 0, ["MaxY"] = 0, ["Hdif"] = 0, ["Vdif"] = 0, ["Hyp"] = 0, ["TilesSet"] = "N",["OPs"] = {},["OPsA"] = {},["ODs"] = {}, ["ODsA"] = {}, ["WtrUsed"] = 0,["WtrAdd"] = {}, ["WaterBodyType"] = 0, ["FluidType"] = nil, ["MapMarker"] = {}, ["MapMarkerPlaced"] = false}
	a = #global.WaterGlobalArea
	global.WGAID = global.WGAID + 1
	global.WaterGlobalArea[a]["WGAID"] = global.WGAID
	GetWaterArea(a)
	CalculatedWaterTotal(a)
	waterbodies.WtrName(a)
	MapMarkerPlace(a)
	a = 0
end

function AssignFluid()	-- Assign Fluid On New WaterArea Creation
	for a = 1, #global.WaterGlobalArea, 1 do
		if global.WaterGlobalArea[a]["FluidType"] == nil then
			if global.Type == 1 then
				for b = 1, #global.OPLocate, 1 do
					if global.OPLocate[b]["WA"] == global.WaterGlobalArea[a]["WGAID"] then
						global.WaterGlobalArea[a]["FluidType"] = global.OPLocate[b]["tile"]
					end
				end
			elseif global.Type == 2 then
				for b = 1, #global.ODLocate, 1 do
					if global.ODLocate[b]["WA"] == global.WaterGlobalArea[a]["WGAID"] then
						global.WaterGlobalArea[a]["FluidType"] = global.ODLocate[b]["tile"]
					end
				end
			end
		end
	end
end

function OffShoreCompareArea()
	if global.Type == 1 then
		NuOPs = #global.OPLocate
		OPS = global.OPLocate
		NewOPPosX = OPS[NuOPs]["position"]["x"] - 0.5
		NewOPPosY = OPS[NuOPs]["position"]["y"] - 0.5
		player = OPS[NuOPs]["entity"].last_user
	elseif global.Type == 2 then
		NuOPs = #global.ODLocate
		OPS = global.ODLocate
		NewOPPosX = OPS[NuOPs]["position"]["x"] - 0.5
		NewOPPosY = OPS[NuOPs]["position"]["y"] - 0.5
		player = OPS[NuOPs]["entity"].last_user
	end
	local NuWAs = #global.WaterGlobalArea
	local WA = global.WaterGlobalArea
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
			if global.Type == 1 then
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
			elseif global.Type == 2 then
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
	if global.Type == 1 then
		position = global.OPLocate[#global.OPLocate]["position"]
		surface = global.OPLocate[#global.OPLocate]["surface"].name
		direction = global.OPLocate[#global.OPLocate]["direction"]
		WaterGArea = global.WaterGlobalArea[#global.WaterGlobalArea]
		WaterRepArea = global.WaterGlobalArea[#global.WaterGlobalArea]["WaterRepArea"]
		WaterEdgeArea = global.WaterGlobalArea[#global.WaterGlobalArea]["WaterEdgeArea"]
		WASearchQueue = {position}
		WASearched = {}
		SearchAmount = settings.global["FluidArea-Start-Area"].value
		FA = global.WaterGlobalArea[a]
		PlayerMaxArea = settings.global["FluidArea-MaxFluidAreaSize"].value
		TotalArea = global.WaterGlobalArea[a]["ShallowWater"] + global.WaterGlobalArea[a]["DeepWater"]
	elseif global.Type == 2 then
		position = global.ODLocate[#global.ODLocate]["position"]
		surface = global.ODLocate[#global.ODLocate]["surface"].name
		direction = global.ODLocate[#global.ODLocate]["direction"]
		WaterGArea = global.WaterGlobalArea[#global.WaterGlobalArea]
		WaterRepArea = global.WaterGlobalArea[#global.WaterGlobalArea]["WaterRepArea"]
		WaterEdgeArea = global.WaterGlobalArea[#global.WaterGlobalArea]["WaterEdgeArea"]
		WASearchQueue = {position}
		WASearched = {}
		SearchAmount = settings.global["FluidArea-Start-Area"].value
		FA = global.WaterGlobalArea[a]
		PlayerMaxArea = settings.global["FluidArea-MaxFluidAreaSize"].value
		TotalArea = global.WaterGlobalArea[a]["ShallowWater"] + global.WaterGlobalArea[a]["DeepWater"]
	elseif global.WaterGlobalArea[a]["ToSearch"] ~= nil then
		WaterGArea = global.WaterGlobalArea[a]
		WaterRepArea = global.WaterGlobalArea[a]["WaterRepArea"]
		WaterEdgeArea = global.WaterGlobalArea[a]["WaterEdgeArea"]
		WASearchQueue = global.WaterGlobalArea[a]["ToSearch"]
		WASearched = global.WaterGlobalArea[a]["HasSearched"]
		surface = global.WaterGlobalArea[a]["Surface"].name
		SearchAmount = settings.global["FluidArea-Additional-Tiles-Per-Second"].value
		PlayerMaxArea = settings.global["FluidArea-MaxFluidAreaSize"].value
		FA = global.WaterGlobalArea[a]
		TotalArea = global.WaterGlobalArea[a]["ShallowWater"] + global.WaterGlobalArea[a]["DeepWater"]
	end
	while #WASearchQueue > 0 and SearchAmount > 0 do
		local SearchPosition = WASearchQueue[1]										-- Convert Offshore Pump Position into SearchPosition
		if WASearched[GridRef(SearchPosition)] ~= true and TotalArea <= PlayerMaxArea or TotalArea <= 60000 and game.active_mods["SeaBlock"] or game.active_mods["ctg"] then							-- IF GridRef has not been searched
			if IsWater(SearchPosition, surface) == false or IsWater(SearchPosition, surface) == "lake-shallow" or IsWater(SearchPosition, surface) == "lake-deep" then						-- IF IsWater is FALSE then
				WASearched[GridRef(SearchPosition)] = true							-- GridRef has been Searched
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
					if EdgePattern(SearchPosition,WASearchQueue) == true then
						WaterEdgeArea[#WaterEdgeArea+1] = {["name"] = "lake-shallow" , ["position"] = {["x"] = SearchPosition.x, ["y"] = SearchPosition.y},["OriginalName"] = fluidname}
					end
				elseif fluidname == "deepwater" or fluidname == "deepwater-green" then
					FA["DeepWater"] = FA["DeepWater"] + 1
					if EdgePattern(SearchPosition,WASearchQueue) == true then
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
				WASearched[GridRef(SearchPosition)] = true									-- Make SearchPosition TRUE in WASerached
				-- if game.active_mods["SeaBlock"] or game.active_mods["ctg"] then
					-- if TotalArea <= 60000 then
						-- SearchPattern(SearchPosition, WASearchQueue)								-- Run SearchPattern Function Passing SearchPosition and WASearchQueue
					-- end
				-- end
				-- if TotalArea <= PlayerMaxArea then
					-- SearchPattern(SearchPosition, WASearchQueue)								-- Run SearchPattern Function Passing SearchPosition and WASearchQueue
				-- end	
				table.remove (WASearchQueue,1)												-- Remove from WASearchQueue
			end																				-- IF IsWater isn't TRUE or False 
		else
			table.remove (WASearchQueue,1)				-- Remove from WASearchQueue
		end
		SearchAmount = SearchAmount - 1
	end
	FA["ToSearch"] = WASearchQueue
	FA["HasSearched"] = WASearched
	local DebugQueue = settings.global["FluidArea-DebugQueueLength"].value
	if DebugQueue == true then
		game.print(#WASearchQueue)
	end
	if #WASearchQueue == 0 then
		global.WaterGlobalArea[a]["ToSearch"] = nil
		global.WaterGlobalArea[a]["HasSearched"] = nil
		-- local wateredgeposition = {}
		-- local wateredgepositionxtemp = {}
		-- local wateredgepositionx = global.WaterGlobalArea[a]["WaterEdgeAreaX"]
		-- local wateredgepositionytemp = {}
		-- local wateredgepositiony = global.WaterGlobalArea[a]["WaterEdgeAreaY"]
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
	global.WaterGlobalArea[a]["LoopCount"] = global.WaterGlobalArea[a]["LoopCount"] + 1
	local AlarmEnabled = settings.get_player_settings(game.players[1])["Alarms-Continuing-Search"].value
	if global.WaterGlobalArea[a]["LoopCount"] == 20 and AlarmEnabled == true then
		global.WaterGlobalArea[a]["LoopCount"] = 0
		game.print(string.format("Still Scanning FluidArea %s", a))
	end
	if global.WaterGlobalArea[a]["ToSearch"] == nil then
		global.WaterGlobalArea[a]["LoopCount"] = 0
		waterbodies.WtrName(a)
		game.print(string.format("%s created, with %sL of %s.", global.WaterGlobalArea[a]["WtrName"], comma_value(global.WaterGlobalArea[a]["AmountWtr"]), global.WaterGlobalArea[a]["FluidType"]))
		MapMarker(a)
	end
end

function CalculatedWaterTotal(a)
	local Shallow = global.WaterGlobalArea[a]["ShallowWater"]
	local ShallowS = global.WaterGlobalArea[a]["ShallowWater-Shallow"]
	local ShallowM = global.WaterGlobalArea[a]["ShallowWater-Mud"]
	local Deep = global.WaterGlobalArea[a]["DeepWater"]
	local ShallowShallow = global.WaterGlobalArea[a]["ShallowWater-Shallow"]
	local ShallowMud = global.WaterGlobalArea[a]["ShallowWater-Mud"]
	local TotalArea = Shallow + ShallowS + ShallowM + Deep
	global.WaterGlobalArea[a]["BTF"] = TotalArea
	local WATER = settings.global["TileFluidAmount-Shallow"].value
	local DEEPWATER = settings.global["TileFluidAmount-Deep"].value
	local PBonus = 0.01 
	local WBonus = 0.5 
	local PDBonus = 1 
	local LBonus = 1.5 
	local GLBonus = 2 
	local SBonus = 2.5 
    local OBonus = 3 
	local WaterTotal = (Shallow * WATER) + (Deep * DEEPWATER) + (ShallowShallow * (WATER/2)) + (ShallowMud * (WATER/4))
	local WaterBodyType = 0
	if TotalArea < 4 then
		--game.print("PUDDLE")
		global.WaterGlobalArea[a]["AmountWtr"] = WaterTotal * PBonus
		global.WaterGlobalArea[a]["AmountBonusValue"] = PBonus
		global.WaterGlobalArea[a]["WtrName"] = "Puddle"
		global.WaterGlobalArea[a]["WaterBodyType"] = 0
	elseif TotalArea == 4 then
		--game.print("WELL")
		global.WaterGlobalArea[a]["AmountWtr"] = WaterTotal * WBonus
		global.WaterGlobalArea[a]["AmountBonusValue"] = WBonus
		global.WaterGlobalArea[a]["WtrName"] = "Well"
		global.WaterGlobalArea[a]["WaterBodyType"] = 1
	elseif TotalArea > 4 and TotalArea <= 200 then
		--game.print("POND")
		global.WaterGlobalArea[a]["AmountWtr"] = WaterTotal * PDBonus
		global.WaterGlobalArea[a]["AmountBonusValue"] = PDBonus
		global.WaterGlobalArea[a]["WtrName"] = "Pond"
		global.WaterGlobalArea[a]["WaterBodyType"] = 2
	elseif TotalArea > 200 and TotalArea <= 6000 then
		--game.print("LAKE")
		global.WaterGlobalArea[a]["AmountWtr"] = WaterTotal * LBonus
		global.WaterGlobalArea[a]["AmountBonusValue"] = LBonus
		global.WaterGlobalArea[a]["WaterBodyType"] = 3
	elseif TotalArea > 6000 and TotalArea <= 60000 then
		--game.print("GREAT LAKE")
		global.WaterGlobalArea[a]["AmountWtr"] = WaterTotal * GLBonus
		global.WaterGlobalArea[a]["AmountBonusValue"] = GLBonus
		global.WaterGlobalArea[a]["WaterBodyType"] = 4
	elseif TotalArea > 60000 and TotalArea <= 600000 then
		--game.print("SEA")
		global.WaterGlobalArea[a]["AmountWtr"] = WaterTotal * SBonus
		global.WaterGlobalArea[a]["AmountBonusValue"] = SBonus
		global.WaterGlobalArea[a]["WaterBodyType"] = 5
	else
		--game.print("OCEAN")
		global.WaterGlobalArea[a]["AmountWtr"] = WaterTotal * OBonus
		global.WaterGlobalArea[a]["AmountBonusValue"] = OBonus
		global.WaterGlobalArea[a]["WaterBodyType"] = 6
	end
	local RegenOff = settings.global["Disable-FluidArea-RegenRate"].value
	if RegenOff == false then
		local RegenRate = settings.global["FluidArea-RegenRate"].value / 10000
		RegenAmount = (RegenRate * TotalArea)
	else
		RegenAmount = 0
	end
	global.WaterGlobalArea[a]["RegenAmount"] = RegenAmount
end

function comma_value(n) -- credit http://richard.warburton.it
	local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
	return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end

function MapMarker(a)
	if settings.global["Map-EnableMarkers"].value == true then
		local MapMarker = global.WaterGlobalArea[a]["MapMarker"]
		local LMapMarker = #global.WaterGlobalArea[a]["MapMarker"]
		local WGA = global.WaterGlobalArea[a]
		--for b = 1, #global.PlayerForces, 1 do
			for c = 1, LMapMarker, 1 do
				--if MapMarker[c]["force"] == global.PlayerForces[b]["name"] then
					if MapMarker[c]["icon"] == nil or MapMarker[c]["icon"].valid == false or MapMarker[c]["placed"] == false then
						global.WaterGlobalArea[a]["MapMarker"][c]["placed"] = false
						MapMarkerPlace(a)
					elseif MapMarker[c]["icon"].valid == true and WGA["ToSearch"] == nil and WGA["Depleted"] ~= 1 then
						local maptext = string.format("%s - %s - %.2f %%",global.WaterGlobalArea[a]["WtrName"],comma_value(math.ceil(global.WaterGlobalArea[a]["AmountWtr"]*((100-global.WaterGlobalArea[a]["Percent"])/100))),100-global.WaterGlobalArea[a]["Percent"])
						global.WaterGlobalArea[a]["MapMarker"][c]["icon"].icon = {type="fluid",name=global.WaterGlobalArea[a]["FluidType"]}
						global.WaterGlobalArea[a]["MapMarker"][c]["icon"].text = maptext
					elseif MapMarker[c]["icon"].valid == true and WGA["ToSearch"] == nil and WGA["Depleted"] == 1 then
						local maptext = string.format("%s - %s",global.WaterGlobalArea[a]["WtrName"],"Depleted")
						global.WaterGlobalArea[a]["MapMarker"][c]["icon"].text = maptext
					end
				--end
			end
		--end
	else
		for b = 1, #global.PlayerForces, 1 do
			local MapMarker = global.WaterGlobalArea[a]["MapMarker"]
			local LMapMarker = #global.WaterGlobalArea[a]["MapMarker"]
			for c = 1, LMapMarker, 1 do
				if MapMarker[c]["placed"] == true then
					global.WaterGlobalArea[a]["MapMarker"][c]["placed"] = false
				end
			end
		end
	end
end

function MapMarkerPlace(a)
	if settings.global["Map-EnableMarkers"].value == true then
		local MapMarker = global.WaterGlobalArea[a]["MapMarker"]
		local LMapMarker = #global.WaterGlobalArea[a]["MapMarker"]
		local maptext = "Pending..."
		for b = 1, #global.PlayerForces, 1 do
			for c = 1, LMapMarker, 1 do
				if MapMarker[c]["force"] == global.PlayerForces[b]["name"] then
					if MapMarker[c]["placed"] == false then
						global.WaterGlobalArea[a]["MapMarker"][c]["placed"] = true
						if #global.WaterGlobalArea[a]["WaterRepArea"] > 0 then
							global.WaterGlobalArea[a]["MapMarker"][c]["icon"] = game.forces[global.PlayerForces[b]["name"]].add_chart_tag(global.WaterGlobalArea[a]["Surface"],{["position"]= global.WaterGlobalArea[a]["WaterRepArea"][1]["position"],["text"] = maptext})
						else
							global.WaterGlobalArea[a]["MapMarker"][c]["icon"] = game.forces[global.PlayerForces[b]["name"]].add_chart_tag(global.WaterGlobalArea[a]["Surface"],{["position"]= global.WaterGlobalArea[a]["WaterEdgeArea"][1]["position"],["text"] = maptext})
						end         
					end
				end
			end
		end
	end
end

function CorrectPump()
	if global.OPLocate[#global.OPLocate]["entity"].valid then
		if global.OPLocate[#global.OPLocate]["entity"]["name"] == "offshore-pump" or global.OPLocate[#global.OPLocate]["entity"]["name"] == "kr-electric-offshore-pump"then
			if global.OPLocate[#global.OPLocate]["tile"] == "crude-oil" then
				local OPE = global.OPLocate[#global.OPLocate]["entity"]
				local OPD = OPE.direction
				local OPP = OPE.position
				local OPSp = global.OPLocate[#global.OPLocate]["spritepos"]
				local OPS = OPE.surface
				local OPF = OPE.force
				local OPPl = OPE.last_user
				OPE.destroy()
				local OPN = game.surfaces[OPS.name].create_entity{name="offshore-crude-oil-pump",position = OPSp,direction = OPD,force = OPF,player=OPPl}
				if OPN ~= nil then
					global.OPLocate[#global.OPLocate]["entity"] = OPN
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
	if global.Type == 1 then
		Offpump = global.OPLocate
		LOffpump = #global.OPLocate
		Force = OPforce
	elseif global.Type == 2 then
		Offpump = global.ODLocate
		LOffpump = #global.ODLocate
		Force = ODforce
	end
	if global.PlayerForces == nil or #global.PlayerForces == 0 then
		global.PlayerForces[#global.PlayerForces+1] = {["name"] = Force, ["OPcount"] = 0, ["ODcount"] = 0, ["WaterFlow"] = 0, ["LastWaterFlow"] = 0, ["CrudeFlow"] = 0, ["LastCrudeFlow"] = 0}
		if global.Type == 1 then
			global.PlayerForces[1]["OPcount"] = 1
		elseif global.Type == 2 then
			global.PlayerForces[1]["ODcount"] = 1
		end
		InitalForce = true
	elseif #global.PlayerForces > 0 then
		for a = 1, #global.PlayerForces, 1 do
			if global.PlayerForces[a]["name"] == Force then
				if global.Type == 1 then
					global.PlayerForces[a]["OPcount"] = global.PlayerForces[a]["OPcount"] + 1
				elseif global.Type == 2 then
					global.PlayerForces[a]["ODcount"] = global.PlayerForces[a]["ODcount"] + 1
				end
				goto Found
			end
		end
		NotFound = true
		::Found::
	end
	if InitalForce == false and NotFound == true then
		global.PlayerForces[#global.PlayerForces+1] = {["name"] = OPforce, ["OPcount"] = 0, ["ODcount"] = 0, ["WaterFlow"] = 0, ["LastWaterFlow"] = 0, ["CrudeFlow"] = 0, ["LastCrudeFlow"] = 0}
		if global.Type == 1 then
			global.PlayerForces[#global.PlayerForces]["OPcount"] = global.PlayerForces[#global.PlayerForces]["OPcount"] + 1
		elseif global.Type == 2 then
			global.PlayerForces[#global.PlayerForces]["ODcount"] = global.PlayerForces[#global.PlayerForces]["ODcount"] + 1
		end
	end
end

-- ON TICK DEPENDANT FUNCTIONS -- 

function RegenWater(a)
	local DisableRegen = settings.global["Disable-FluidArea-RegenRate"].value
	local WGA = global.WaterGlobalArea
	if DisableRegen == false and WGA[a]["FluidType"] == "water" and WGA[a]["Percent"] > 0 and WGA[a]["Percent"] <= 99 and WGA[a]["Depleted"] ~= 1 then
		local WGA = global.WaterGlobalArea
		if WGA[a]["WtrUsed"] - WGA[a]["RegenAmount"] <= 0 then
			WGA[a]["WtrUsed"] = 0
		else
			WGA[a]["WtrUsed"] = WGA[a]["WtrUsed"] - (WGA[a]["RegenAmount"] * 6)
		end
		WGA[a]["PercentPrev"] = WGA[a]["Percent"]
		WGA[a]["Percent"] = (WGA[a]["WtrUsed"] / WGA[a]["AmountWtr"]) * 100
		PercentChange = WGA[a]["PercentPrev"] - WGA[a]["Percent"]
	end	
end

function EverySec()
	for a = 1, #global.WaterGlobalArea, 1 do
		if global.WaterGlobalArea[a]["ToSearch"] ~= nil then
			FluidAreaContinue(a)
		end
		if #global.LandFill > 0 then
			LandFill(a)
		end
		RegenWater(a)
		MapMarker(a)
	end
end

function EmptyDrainPipes(a)
	local ODL = global.ODLocate
	for b = 1, #ODL, 1 do
		local WGA = global.WaterGlobalArea
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
		for d = 1, #global.WaterGlobalArea[a]["WtrAdd"], 1 do
			if global.WaterGlobalArea[a]["WtrAdd"][d]["force"] == global.ODLocate[b]["force"] then
				WGA[a]["WtrAdd"][d]["count"] = 0
			end
		end
	end
 end
 
function AssignTiles(a)
	local WGA = global.WaterGlobalArea
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
	local WGA = global.WaterGlobalArea
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
	local WGA = global.WaterGlobalArea
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
	local WGA = global.WaterGlobalArea
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
	local WGA = global.WaterGlobalArea
	local PGT = global.OPLocate
	local DGT = global.ODLocate
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
	local WGA = global.WaterGlobalArea
	if WGA[a]["AmountWtr"] ~= WGA[a]["WtrUsed"] and WGA[a]["Percent"] > 0 then
		local Percent = WGA[a]["Percent"]
		local WA = WGA[a]
		local LowAlarmEnabled = settings.global["Alarms-Low-Level (50/75/90%)"].value
		local HighAlarmEnabled = settings.global["Alarms-High-Level (95/97/98/99%)"].value
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
	local WGA = global.WaterGlobalArea
	if WGA[a]["Depleted"] ~= 1 and WGA[a]["ToSearch"] == nil then
		local Percent = WGA[a]["Percent"]
		local LowAlarmEnabled = settings.global["Alarms-Low-Level (50/75/90%)"].value
		local HighAlarmEnabled = settings.global["Alarms-High-Level (95/97/98/99%)"].value
		local WA = WGA[a]
		if Percent <= 49 then
			--game.print("IN NORMAL BOUNDS")
		elseif Percent >= 50 and WA["Fired50"] == false and LowAlarmEnabled == true then
			for b = 1, #global.PlayerForces, 1 do
				for c = 1, #WGA[a]["OPsA"], 1 do
					if global.PlayerForces[b]["name"] == WGA[a]["OPsA"][c]["force"] then
						game.forces[global.PlayerForces[b]["name"]].print(string.format("%s has used %.0f %% of available %s.",WA["WtrName"], WA["Percent"], WA["FluidType"]))
					end
				end
			end
			WA["Fired50"] = true
		elseif Percent >= 75 and WA["Fired75"] == false and LowAlarmEnabled == true then
			for b = 1, #global.PlayerForces, 1 do
				for c = 1, #WGA[a]["OPsA"], 1 do
					if global.PlayerForces[b]["name"] == WGA[a]["OPsA"][c]["force"] then
						game.forces[global.PlayerForces[b]["name"]].print(string.format("%s has used %.0f %% of available %s.",WA["WtrName"], WA["Percent"], WA["FluidType"]))
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
				for b = 1, #global.PlayerForces, 1 do
					for c = 1, #WGA[a]["OPsA"], 1 do
						if global.PlayerForces[b]["name"] == WGA[a]["OPsA"][c]["force"] then
							game.forces[global.PlayerForces[b]["name"]].print(string.format("%s has used %.0f %% of available %s.",WA["WtrName"], WA["Percent"], WA["FluidType"]))
						end
					end
				end
				WA["Fired90"] = true
			elseif Percent >= 95 and WA["Fired95"] == false and HighAlarmEnabled == true then
				for b = 1, #global.PlayerForces, 1 do
					for c = 1, #WGA[a]["OPsA"], 1 do
						if global.PlayerForces[b]["name"] == WGA[a]["OPsA"][c]["force"] then
							game.forces[global.PlayerForces[b]["name"]].print(string.format("%s has used %.0f %% of available %s.",WA["WtrName"], WA["Percent"], WA["FluidType"]))
						end
					end
				end
				WA["Fired95"] = true
			elseif Percent >= 97 and WA["Fired97"] == false and HighAlarmEnabled == true then
				for b = 1, #global.PlayerForces, 1 do
					for c = 1, #WGA[a]["OPsA"], 1 do
						if global.PlayerForces[b]["name"] == WGA[a]["OPsA"][c]["force"] then
							game.forces[global.PlayerForces[b]["name"]].print(string.format("%s has used %.0f %% of available %s.",WA["WtrName"], WA["Percent"], WA["FluidType"]))
						end
					end
				end
				WA["Fired97"] = true
			elseif Percent >= 98 and WA["Fired98"] == false and HighAlarmEnabled == true then
				for b = 1, #global.PlayerForces, 1 do
					for c = 1, #WGA[a]["OPsA"], 1 do
						if global.PlayerForces[b]["name"] == WGA[a]["OPsA"][c]["force"] then
							game.forces[global.PlayerForces[b]["name"]].print(string.format("%s has used %.0f %% of available %s.",WA["WtrName"], WA["Percent"], WA["FluidType"]))
						end
					end
				end
				WA["Fired98"] = true
			elseif Percent >= 99 and WA["Fired99"] == false and HighAlarmEnabled == true then
				for b = 1, #global.PlayerForces, 1 do
					for c = 1, #WGA[a]["OPsA"], 1 do
						if global.PlayerForces[b]["name"] == WGA[a]["OPsA"][c]["force"] then
							game.forces[global.PlayerForces[b]["name"]].print(string.format("%s has used %.0f %% of available %s.",WA["WtrName"], WA["Percent"], WA["FluidType"]))
						end
					end
				end
				WA["Fired99"] = true
			end		
		elseif Percent >= 100 then 
			if global.NewInstall == false then
				for z = 1, #global.OPLocate, 1 do
					local OP = global.OPLocate[z]
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
							for y =1, #global.WaterGlobalArea[a]["OPsA"], 1 do
								if global.WaterGlobalArea[a]["OPsA"][y]["force"] == OP["force"] then
									WA["OPsA"][y]["count"] = WA["OPsA"][y]["count"] - 1
								end
							end								
						end
						if game.active_mods["aai-industry"] then -- MOD Compat with AAI, remove the additional sprites
							local x = OPP.x
							local y = OPP.y
							if OPD == 0 then
								--AS = game.surfaces[OPS.name].find_entities_filtered{area={{x-1, 0},{x+1,y+1}}, name = "offshore-pump-output"}
								AS = game.surfaces[OPS.name].find_entities_filtered{position=OPSp,radius=1, name = "offshore-pump-output"}
							elseif OPD == 4 then
								--AS = game.surfaces[OPS.name].find_entities_filtered{area={{x-1, y-1},{x+1,0}}, name = "offshore-pump-output"}
								AS = game.surfaces[OPS.name].find_entities_filtered{position=OPSp,radius=1, name = "offshore-pump-output"}
							elseif OPD == 2 then
								--AS = game.surfaces[OPS.name].find_entities_filtered{area={{0, y-1},{x+1,y+1}}, name = "offshore-pump-output"}
								AS = game.surfaces[OPS.name].find_entities_filtered{position=OPSp,radius=1, name = "offshore-pump-output"}
							elseif OPD == 6 then
								--AS = game.surfaces[OPS.name].find_entities_filtered{area={{0, y-1},{x+1,y+1}}, name = "offshore-pump-output"}
								AS = game.surfaces[OPS.name].find_entities_filtered{position=OPSp,radius=1, name = "offshore-pump-output"}
							end
							local Entity = AS[1]
							if Entity ~= nil then
								Entity.destroy()
							end
						end
						OPE.destroy()
						local OPNF = game.surfaces[OPS.name].create_entity{name="offshore-pump-nofluid",position = OPSp,direction = OPD,player = OPPl, force = "neutral"}
						global.OPLocate[z]["entity"] = OPNF
					end
				end
				WGA[a]["Depleted"] = 1
				WGA[a]["Percent"] = 100
				WGA[a]["PercentPrev"] = 100
				WGA[a]["RandPercent"] = 100
				if #WGA[a]["WaterRepArea"] > 0 then
					game.surfaces[WA["Surface"].name].set_tiles(WGA[a]["WaterRepArea"])													-- Set Tiles to those in WaterArea Table
				else
					--game.surfaces[WA["Surface"].name].set_tiles(WGA[a]["WaterEdgeArea"])
					BackToFrontEdge(a)
				end
				WGA[a]["BTFE"] = 20
				WGA[a]["WtrUsed"] = WGA[a]["AmountWtr"]
				for b = 1, #global.PlayerForces, 1 do
					for c = 1, #WGA[a]["OPsA"], 1 do
						if global.PlayerForces[b]["name"] == WGA[a]["OPsA"][c]["force"] then
							game.forces[global.PlayerForces[b]["name"]].print(string.format("%s has been depleted of %s.",WA["WtrName"], WA["FluidType"]))
						end
					end
				end
				WGA[a]["FluidType"] = "None"
				WGA[a]["BTF"] = 0
			else
				local CurrentTick = game.tick
				if CurrentTick < (global.InstallTick + 18000) and global.ITMessage == true then
					for b = 1, #global.PlayerForces, 1 do
						for c = 1, #WGA[a]["OPsA"], 1 do
							if global.PlayerForces[b]["name"] == WGA[a]["OPsA"][c]["force"] then
								game.forces[global.PlayerForces[b]["name"]].print(string.format("Fluid Area Depletion Stopped on New/Mid Game Install. 5 Minutes from install till depletion."))
							end
						end
					end
					global.ITMessage = false
				end
				if CurrentTick >= (global.InstallTick + 18000) then
					for b = 1, #global.PlayerForces, 1 do
						for c = 1, #WGA[a]["OPsA"], 1 do
							if global.PlayerForces[b]["name"] == WGA[a]["OPsA"][c]["force"] then
								game.forces[global.PlayerForces[b]["name"]].print(string.format("Fluid Area 5 Mins Over. Depleting Fluid Area."))
							end
						end
					end
					WGA[a]["Percent"] = 99
					global.NewInstall = false
					global.ITMessage = false
				end
			end
		end
	else
		-- AREA DEPLETED
		local RemoveFromTable = settings.global["FluidArea-RemoveFromTable"].value
		if RemoveFromTable == true and global.NewInstall == false then
			RemoveWAOPOD(a)
		end
	end
end

function CalcWaterUse(a)
	local WGA = global.WaterGlobalArea
	local GPF = global.PlayerForces
	local LGPF = #global.PlayerForces
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
		TotalWaterFlowRate = TotalWaterFlowRate + GPF[b]["WaterFlow"] - GPF[b]["LastWaterFlow"]
		for c = 1, #global.FluidProducers, 1 do
			if global.FluidProducers[c]["force"] == GPF[b]["name"] then
				ForceCrudeAdjust = ForceCrudeAdjust + global.FluidProducers[c]["LastAmount"]
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
	if not game.active_mods["Krastorio2"] then
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
	for c = 1, #global.ODLocate,1 do
		local ODL = global.ODLocate
		local WGA = global.WaterGlobalArea
		if ODL[c]["WA"] == WGA[a]["WGAID"] and ODL[c]["entity"].neighbours[1][1] and ODL[c]["entity"].neighbours[1][1].fluidbox[1] ~= nil and ODL[c]["PipeFluid"] == WGA[a]["FluidType"] then
			if ODL[c]["entity"].neighbours[1][1].get_fluid_count() > 0.005 then
				fluid = ODL[c]["entity"].neighbours[1][1].fluidbox[1]
				for d = 1, #global.WaterGlobalArea[a]["WtrAdd"], 1 do
					if global.WaterGlobalArea[a]["WtrAdd"][d]["force"] == global.ODLocate[c]["force"] then
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
	local WGA = global.WaterGlobalArea
	local ODL = global.ODLocate
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
	local GOPL = global.OPLocate[a]
	local WGA = global.WaterGlobalArea
	local GPF = global.PlayerForces
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
	local GOPL = global.ODLocate[a]
	local WGA = global.WaterGlobalArea
	local ODL = global.ODLocate
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
	local WGA = global.WaterGlobalArea
	local Check = #WGA[a]["WaterRepArea"]
	if Check > 0 then
		WASize = #WGA[a]["WaterRepArea"]
		WAra = WGA[a]["WaterRepArea"]
	else
		WASize = #WGA[a]["WaterEdgeArea"]
		WAra = WGA[a]["WaterEdgeArea"]
	end
	for b = #global.LandFill, 1, -1 do
		for c = 1, WASize, 1 do
			if WAra[c]["name"] ~= "landfill" then
				if Check > 0 then
					global.WaterGlobalArea[a]["WaterRepArea"][c]["name"] = "landfill" 
					LFPosX = global.LandFill[b]["position"]["x"] + 0.5
					LFPosY = global.LandFill[b]["position"]["y"] + 0.5
				else
					LFPosX = global.LandFill[b]["position"]["x"]
                    LFPosY = global.LandFill[b]["position"]["y"]
				end
				WAPosX = WAra[c]["position"]["x"]
				WAPosY = WAra[c]["position"]["y"]
				if LFPosX == WAPosX then -- IF LandFill position x is equal to FluidArea position x
					if LFPosY == WAPosY then -- IF LandFill position y is equal to FluidArea position y
					Found = true
					if Check > 0 then
						global.WaterGlobalArea[a]["WaterRepArea"][c]["name"] = "landfill" 
					end
					local FluidName = global.LandFill[b]["name"]
					if FluidName == "water" or FluidName == "crude-oil" or FluidName == "water-green" or FluidName == "water-shallow" or FluidName == "water-mud" then
						local ShallowAmount = settings.global["TileFluidAmount-Shallow"].value
						global.WaterGlobalArea[a]["AmountWtr"] = WGA[a]["AmountWtr"] - (ShallowAmount * WGA[a]["AmountBonusValue"])
					elseif FluidName == "deepwater" or FluidName == "crude-oil-deep" or FluidName == "deepwater-green" then
						local DeepAmount = settings.global["TileFluidAmount-Deep"].value
						global.WaterGlobalArea[a]["AmountWtr"] = WGA[a]["AmountWtr"] - (DeepAmount * WGA[a]["AmountBonusValue"])
					end
					table.remove(global.LandFill,#global.LandFill)
					goto EscapeLFSearch
					end
				end
			end
			if a == #global.WaterGlobalArea and c == WASize then -- Remove from Landfill table if not found.
				table.remove(global.LandFill,#global.LandFill)
				goto EscapeLFSearch
			end
		end
	::EscapeLFSearch::
	end
	local LandfillEnabled = settings.get_player_settings(game.players[1])["Alarms-Landfill Message"].value
	if #global.LandFill == 0 and Found == true and LandfillEnabled == true then
		game.print(string.format("Landfill has reduced FluidArea %s, to %sL of %s.", WGA[a]["WtrName"], WGA[a]["AmountWtr"], WGA[a]["FluidType"]))
	end
	::EscapeLFSearchNF::
end

function CheckActive()
	ActiveOPs = 0
	ActiveODs = 0
	WGA = global.WaterGlobalArea
	if #global.OPLocate ~= 0 then
		for a = 1, #global.OPLocate, 1 do
			CheckOPActive(a)
		end
	end
	if #global.ODLocate ~= 0 then
		for a = 1, #global.ODLocate, 1 do
			CheckODActive(a)
			CheckDrainAssignedFluid(a)
		end
	end
end

function ScanOffshores()
	for a = #game.surfaces, 1, -1 do
		local Jacks = game.surfaces[a].find_entities_filtered{name= "pumpjack"}
		if #Jacks > 0 then
			for b = 1, #Jacks, 1 do
				for c = #global.FluidProducers, 1, -1 do
					if Jacks[a]["position"] == global.FluidProducers[c]["position"] then
						table.remove(Jacks,#Jacks)
					end
				end
			end
			for b = 1, #Jacks, 1 do
				Jackentity = Jacks[b]
				Jackposition = Jackentity.position	
				Jacksurface = Jackentity.surface
				Jackforce = Jackentity.force.name
				global.FluidProducers[#global.FluidProducers+1] = {["entity"] = Jackentity, ["position"] = {["x"] = Jackposition.x , ["y"] = Jackposition.y}, ["surface"] = Jacksurface, ["FluidType"] = nil, ["LastAmount"] = 0, ["force"] = Jackforce}
			end
		end
		Pumps = 0
		if game.active_mods["Krastorio2"] then
			Pumps = game.surfaces[a].find_entities_filtered{name= "kr-electric-offshore-pump"}
		else
			Pumps = game.surfaces[a].find_entities_filtered{name= "offshore-pump"}
		end
		if game.active_mods["IndustrialRevolution"] then
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
					global.ScanOffshoresQueue[#global.ScanOffshoresQueue+1] = Pumps[b]
				end
			end
			created_entity = global.ScanOffshoresQueue[1]
			a = {["created_entity"] = created_entity}
			BuiltOffShore(a)
			table.remove(global.ScanOffshoresQueue,1)
		end
	end
	global.Added = false
end

function PumpRereplace(a)
	local PRPV = settings.global["FluidArea-RereplacePumps"].value
	local PRP = 100 - PRPV
	local WGA = global.WaterGlobalArea
	if PRPV == 0 then
		--Do Nothing as Off
	else
		local FAP = WGA[a]["Percent"]
		if PRP >= FAP then
			for b = #global.OPLocate, 1, -1 do
				if global.OPLocate[b]["WA"] == WGA[a]["WGAID"] and global.OPLocate[b]["entity"].name == "offshore-pump-nofluid"then
					local OP = global.OPLocate[b]
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
					global.OPLocate[b]["entity"] = OPN
					if global.OPLocate[b]["entity"] == nil then
						if global.WaterGlobalArea[a]["OPs"] <= 0 then
							global.WaterGlobalArea[a]["OPs"] = 0
						else
							global.WaterGlobalArea[a]["OPs"] = global.WaterGlobalArea[global.OPLocate[b]["WA"]]["OPs"] - 1
						end
						game.players[global.OPLocate[b]["entity"].last_user.name].print(string.format("Water As A Resource: Offshore Pump Removed from %s, as Pipes have another fluid type.", global.WaterGlobalArea[global.OPLocate[b]["WA"]]["WtrName"]))
						game.players[global.OPLocate[b]["entity"].last_user.name].insert{name="offshore-pump",count=1}
						table.remove(global.OPLocate,b)
					end
				end
			end
		end
	end
end

function RemoveWAOPOD(a)
	local WGA = global.WaterGlobalArea
	if WGA[a]["Depleted"] == 1 then
		if #WGA[a]["OPs"] > 0 then
			for c = #global.OPLocate, 1, - 1 do
				if WGA[a]["WGAID"] == global.OPLocate[c]["WA"] then
					table.remove(global.OPLocate,c)
				end
			end
		end
		if #WGA[a]["ODs"] > 0 then
			for c = #global.ODLocate, 1, - 1 do
				if WGA[a]["WGAID"] == global.ODLocate[c]["WA"] then
					table.remove(global.ODLocate,c)
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
	GPF = global.PlayerForces
	LGPF = #global.PlayerForces
	if Skip ~= true or Skip == nil then
		for a = 1, LGPF, 1 do							
			GPF[a]["WaterFlow"] = math.ceil(game.forces[GPF[a]["name"]].fluid_production_statistics.get_input_count("water"))
			GPF[a]["CrudeFlow"] = math.ceil(game.forces[GPF[a]["name"]].fluid_production_statistics.get_input_count("crude-oil"))
		end
		Skip = true
	else
		for a = 1, LGPF, 1 do
			GPF[a]["LastWaterFlow"] = GPF[a]["WaterFlow"]
			GPF[a]["LastCrudeFlow"] = GPF[a]["CrudeFlow"]
		end
		Skip = false
	end
end

function CheckWater()
	local WGA = global.WaterGlobalArea
	fluidentities.CheckFluidProducers()
	if global.Added == true then
		ScanOffshores()
	end
	if #global.ScanOffshoresQueue >= 1 then
		for a = 1, #global.WaterGlobalArea, 1 do
			if global.WaterGlobalArea[a]["ToSearch"] == nil then
				global.EnableNextOffshore = true
				goto ENO
			else
				global.EnableNextOffshore = false
			end
		end
		::ENO::
		if global.EnableNextOffshore == true then
			created_entity = global.ScanOffshoresQueue[1]
			a = {["created_entity"] = created_entity}
			BuiltOffShore(a)
			table.remove(global.ScanOffshoresQueue,1)
		end				
	end
	if #WGA ~= nil and global.Added ~= true then
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
				if not game.active_mods["Krastorio2"] then
					PumpRereplace(a)
				end
			end
			if ActiveODs > 0 then
				EmptyDrainPipes(a)
			end
		end
		FluidFlow()
		if global.LoopTick < 10 then
			global.LoopTick = global.LoopTick + 1
		elseif global.LoopTick == 10 then
			global.LoopTick = 0
			EverySec()
		end
	end
end

-- SCRIPT EVENT FUNCTIONS --

function LandFillCheck(event)
    if event.mod_name ~= "creative-mod" and event.tile.valid == true then
		if event.tile.name == "landfill" then
			local tiles = event.tiles
			local surface = event.surface_index
			for a = 1, #tiles, 1 do
				global.LandFill[#global.LandFill+1] = {["name"] = tiles[a].old_tile.name, ["position"] = {["x"] = tiles[a]["position"].x, ["y"] = tiles[a]["position"].y},["surface"] = surface}
			end
		end
	end
end

function ScriptConvert(event)
	if game.active_mods["Krastorio2"] and not game.active_mods["aai-industary"] then
		-- DO NOTHING - Fixes lots of problems with K2 OP Detection (04/11/21)
		OPentity = {["created_entity"] = event}  
		BuiltOffShore(OPentity)
	else
		if event.entity.valid == true then
			OPentity = {["created_entity"] = event.entity}  
			BuiltOffShore(OPentity)
		end
	end
end

function BuiltOffShore(event) 					-- Script Event On Built
	if event.created_entity.name == "offshore-pump" or event.created_entity.name == "offshore-drain" or event.created_entity.name =="pumpjack" or event.created_entity.name == "kr-electric-offshore-pump" or event.created_entity.name == "copper-pump"then
		if game.active_mods["Krastorio2"] then
			if event.created_entity.name == "offshore-pump" then 
				-- IGNORE FIRST OFFSHORE TRIGGER UNLESS AAI IS ACTIVE
				if game.active_mods["aai-industry"] then
					OPentity = event.created_entity
					global.Player = OPentity.last_user
				else
					goto NOTVALID
				end
			elseif event.created_entity.name == "kr-electric-offshore-pump" then
				OPentity = event.created_entity
				global.Player = OPentity.last_user
			end
		else
			OPentity = event.created_entity
			global.Player = OPentity.last_user
		end
	else
		goto NOTVALID
	end
	if OPentity.name == "offshore-pump" or OPentity.name == "kr-electric-offshore-pump" or event.created_entity.name == "copper-pump" and OPentity.force.name ~= "neutral" then
		OPposition = OPentity.position													-- Variable for e.Position
		OPsurface = OPentity.surface													-- Variable for e.Surface
		OPdirection = OPentity.direction												-- Variable for OPentity.direction
		OPforce = OPentity.force.name
		global.OPLocate[#global.OPLocate+1] = {["entity"] = OPentity,["position"] = {["x"] = OPposition.x, ["y"] = OPposition.y},["spritepos"] = {["x"] = OPposition.x, ["y"] = OPposition.y},["surface"] = OPsurface,["direction"] = OPdirection,["tile"] = nil, ["Active"] = 0, ["WA"] = 0, ["force"] = OPforce}
		if OPdirection == 0 then -- North
			global.OPLocate[#global.OPLocate]["position"]["y"] = OPposition.y - 1
		elseif OPdirection == 2 then -- East
			global.OPLocate[#global.OPLocate]["position"]["x"] = OPposition.x + 1
		elseif OPdirection == 4 then -- South
			global.OPLocate[#global.OPLocate]["position"]["y"] = OPposition.y + 1
		elseif OPdirection == 6 then -- West
			global.OPLocate[#global.OPLocate]["position"]["x"] = OPposition.x - 1
		end
		tile = OPsurface.get_tile(global.OPLocate[#global.OPLocate]["position"]["x"],global.OPLocate[#global.OPLocate]["position"]["y"]).name
		CorrectedFluid(tile)
		global.OPLocate[#global.OPLocate]["tile"] = correctedtile
		global.Type = 1
		if CorrectPump() ~= false then
			OffshoreForce(OPforce,false)
			GlobalWaterArea()
		else
			table.remove(global.OPLocate,#global.OPLocate)
		end
		global.Type = 0
	elseif OPentity.name == "offshore-drain" then
		ODentity = event.created_entity
		ODposition = ODentity.position
		ODsurface = ODentity.surface
		ODdirection = ODentity.direction
		ODforce = ODentity.force.name
		tile = ODsurface.get_tile(ODposition.x,ODposition.y).name
		CorrectedFluid(tile)
		global.ODLocate[#global.ODLocate+1] = {["entity"] = ODentity,["position"] = {["x"] = ODposition.x, ["y"] = ODposition.y},["surface"] = ODsurface,["direction"] = ODdirection, ["tile"] = correctedtile, ["PipeFluid"] = nil, ["Active"] = 0, ["WA"] = 0, ["force"] = ODforce}
		global.Type = 2
		GlobalWaterArea()
		if global.ODRemoved == false then
			OffshoreForce(false,ODforce)
		else
			global.ODRemoved = false
		end
		global.Type = 0
	elseif OPentity.name =="pumpjack" or event.entity ~= nil and OPentity.name =="pumpjack" then
		if event.created_entity.valid == true then
			FPentity = event.created_entity
		else
			FPentity = event.entity
		end
		FPposition = FPentity.position	
		FPsurface = FPentity.surface
		FPforce = FPentity.force.name
		global.FluidProducers[#global.FluidProducers+1] = {["entity"] = FPentity, ["position"] = {["x"] = FPposition.x , ["y"] = FPposition.y}, ["surface"] = FPsurface, ["FluidType"] = nil, ["LastAmount"] = 0, ["force"] = FPforce}
	else
		--game.print("Not Built A Offshore Pump")									-- If Not Offshore Pump then print Bad Times
	end
	global.Type = 0
	::NOTVALID::
end 

function DestroyedOffShore(event) 			-- Script Event On Player Mined
	if event.entity.name == "offshore-pump" or event.entity.name == "offshore-pump-nofluid" or event.entity.name == "offshore-crude-oil-pump" or event.entity.name == "kr-electric-offshore-pump" or event.entity.name == "copper-pump" then								-- If Offshore Pump No Fluid Mined
		--game.print("PICKED UP MY OFFSHORE PUMP")									-- Print My Offshore Pump
		DOentity = event.entity
		DOposition = DOentity.position
		DOforce = DOentity.force.name
		global.Type = 1
		DestroyOffshore()
		global.Type = 0
	elseif event.entity.name == "offshore-drain" then
		DOentity = event.entity
		-- if DOentity.neighbours[1][1] and DOentity.neighbours[1][1].get_fluid_count() ~= 0 then
			-- DOentity.neighbours[1][1].fluidbox[1] = nil
		-- end
		DOposition = DOentity.position
		DOforce = DOentity.force.name
		global.Type = 2
		DestroyOffshore()
		global.Type = 0
	elseif event.entity.name == "pumpjack" then
		DOentity = event.entity
		DOposition = DOentity.position
		DOforce = DOentity.force.name
		global.Type = 3
		DestroyOffshore()
		global.Type = 0
	end
end

function DestroyOffshore()
	if global.Type == 1 then
		PTYPE = global.OPLocate
		PTYPEL = #global.OPLocate
		PFORCE = DOforce
	elseif global.Type == 2 then
		PTYPE = global.ODLocate
		PTYPEL = #global.ODLocate
		PFORCE = DOforce
	elseif global.Type == 3 then
		PTYPE = global.FluidProducers
		PTYPEL = #global.FluidProducers
		PFORCE = DOforce
	end	
	local DOPosX = DOposition.x
	local DOPosY = DOposition.y
	local WGA = global.WaterGlobalArea
	local OPF = global.PlayerForces
	for a = PTYPEL, 1, -1 do
		if global.Type == 1 then
			OPosX = PTYPE[a]["spritepos"]["x"]
			OPosY = PTYPE[a]["spritepos"]["y"]
		elseif global.Type == 2 then
			OPosX = PTYPE[a]["position"]["x"]			
			OPosY = PTYPE[a]["position"]["y"]
		end
		if DOPosX == OPosX then
			if DOPosY == OPosY then
				if global.Type == 1 then
					local OWA = PTYPE[a]["WA"]
					for b = 1, #WGA, 1 do	
						if #global.WaterGlobalArea ~= 0 and WGA ~= 0 and WGA[b]["WGAID"] == OWA then
							for c = 1, #global.WaterGlobalArea[b]["OPs"], 1 do
								if global.WaterGlobalArea[b]["OPs"][c]["force"] == PFORCE then
									global.WaterGlobalArea[b]["OPs"][c]["count"] = global.WaterGlobalArea[b]["OPs"][c]["count"] - 1
								end
							end
						end					
						if PTYPE[a]["Active"] == 1 and WGA ~= 0 and WGA[b]["WGAID"] == OWA then
							for c = 1, #global.WaterGlobalArea[b]["OPs"], 1 do
								if global.WaterGlobalArea[b]["OPsA"][c]["force"] == PFORCE then
									global.WaterGlobalArea[b]["OPsA"][c]["count"] = global.WaterGlobalArea[b]["OPsA"][c]["count"] - 1
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
				elseif global.Type == 2 then
					local OWA = PTYPE[a]["WA"]
					for b = 1, #WGA, 1 do
						if #global.WaterGlobalArea ~= 0 and WGA ~= 0 and WGA[b]["WGAID"] == OWA then
							for c = 1, #global.WaterGlobalArea[b]["ODs"], 1 do
								if global.WaterGlobalArea[b]["ODs"][c]["force"] == PFORCE then
									global.WaterGlobalArea[b]["ODs"][c]["count"] = global.WaterGlobalArea[b]["ODs"][c]["count"] - 1
								end
							end
						end					
						if PTYPE[a]["Active"] == 1 and WGA ~= 0 and WGA[b]["WGAID"] == OWA then
							for c = 1, #global.WaterGlobalArea[b]["ODs"], 1 do
								if global.WaterGlobalArea[b]["ODsA"][c]["force"] == PFORCE then
									global.WaterGlobalArea[b]["ODsA"][c]["count"] = global.WaterGlobalArea[b]["ODsA"][c]["count"] - 1
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
	if data.mod_changes.WaterAsAResource then
		oldVer = data.mod_changes.WaterAsAResource.old_version
		if oldVer == nil then
			-- global.LastWaterFlow = math.ceil(game.players[1].force.fluid_production_statistics.get_input_count("water"))
			-- global.LastCrudeFlow = math.ceil(game.players[1].force.fluid_production_statistics.get_input_count("crude-oil"))
			Players = #game.players
			if Players <= 1 then
				if global.PlayerForces == nil then
					Force = game.players[1].force.name
					global.PlayerForces[#global.PlayerForces+1] = {["name"] = Force, ["OPcount"] = 0, ["ODcount"] = 0, ["WaterFlow"] = 0, ["LastWaterFlow"] = 0, ["CrudeFlow"] = 0, ["LastCrudeFlow"] = 0}
					global.PlayerForces[#global.PlayerForces]["LastWaterFlow"] = math.ceil(game.forces[global.PlayerForces[#global.PlayerForces]["name"]].fluid_production_statistics.get_input_count("water"))
					global.PlayerForces[#global.PlayerForces]["LastCrudeFlow"] = math.ceil(game.forces[global.PlayerForces[#global.PlayerForces]["name"]].fluid_production_statistics.get_input_count("crude-oil"))
				end
			else
				for a = 1, Players, 1 do
					Force = game.players[a].force.name
					if global.PlayerForces == nil then
						global.PlayerForces[#global.PlayerForces+1] = {["name"] = Force, ["OPcount"] = 0, ["ODcount"] = 0, ["WaterFlow"] = 0, ["LastWaterFlow"] = 0, ["CrudeFlow"] = 0, ["LastCrudeFlow"] = 0}
						global.PlayerForces[#global.PlayerForces]["LastWaterFlow"] = math.ceil(game.forces[global.PlayerForces[#global.PlayerForces]["name"]].fluid_production_statistics.get_input_count("water"))
						global.PlayerForces[#global.PlayerForces]["LastCrudeFlow"] = math.ceil(game.forces[global.PlayerForces[#global.PlayerForces]["name"]].fluid_production_statistics.get_input_count("crude-oil"))
					else
						NewForce = true
						for c = 1, #global.PlayerForces, 1 do
							if global.PlayerForces[c]["force"] == Force then
								NewForce = false
							end
						end
						if NewForce == true then
							global.PlayerForces[#global.PlayerForces+1] = {["name"] = Force, ["OPcount"] = 0, ["ODcount"] = 0, ["WaterFlow"] = 0, ["LastWaterFlow"] = 0, ["CrudeFlow"] = 0, ["LastCrudeFlow"] = 0}
							global.PlayerForces[#global.PlayerForces]["LastWaterFlow"] = math.ceil(game.forces[global.PlayerForces[#global.PlayerForces]["name"]].fluid_production_statistics.get_input_count("water"))
							global.PlayerForces[#global.PlayerForces]["LastCrudeFlow"] = math.ceil(game.forces[global.PlayerForces[#global.PlayerForces]["name"]].fluid_production_statistics.get_input_count("crude-oil"))
						end
					end
				end
			end
			global.InstallTick = game.tick
		else
			--game.print("Water As A Resource: Updating Mod Internals")
			Globals()
			LinkGlobals()
							
			if #global.WaterGlobalArea > 0 then
				for a = 1, #global.WaterGlobalArea, 1 do
					if global.WaterGlobalArea[a]["WGAID"] == nil then
						global.WaterGlobalArea[a]["WGAID"] = a
					end
					local Count = global.WaterGlobalArea[a]["ShallowWater"] + global.WaterGlobalArea[a]["DeepWater"]
					if global.WaterGlobalArea[a]["ShallowWater-Shallow"] == nil then
						global.WaterGlobalArea[a]["ShallowWater-Shallow"] = 0
					end
					if global.WaterGlobalArea[a]["ShallowWater-Mud"] == nil then
						global.WaterGlobalArea[a]["ShallowWater-Mud"] = 0
					end
					if global.WaterGlobalArea[a]["WtrName"] == nil or global.WaterGlobalArea[a]["WtrName"] == "None" then
						global.WaterGlobalArea[a]["WtrName"] = a
					end
					if global.WaterGlobalArea[a]["AmountBonusValue"] == nil or global.WaterGlobalArea[a]["AmountBonusValue"] == 0 then
						if Count < 4 then
							global.WaterGlobalArea[a]["AmountBonusValue"] = 0.01
						elseif Count == 4 then
							global.WaterGlobalArea[a]["AmountBonusValue"] = 0.5
						elseif Count >4 and Count <= 200 then
							global.WaterGlobalArea[a]["AmountBonusValue"] = 1
						elseif Count > 200 and Count <= 6000 then
							global.WaterGlobalArea[a]["AmountBonusValue"] = 1.5
						elseif Count > 6000 and Count <= 60000 then
							global.WaterGlobalArea[a]["AmountBonusValue"] = 2
						elseif Count > 60000 and Count <= 600000 then
							global.WaterGlobalArea[a]["AmountBonusValue"] = 2.5
						else
							global.WaterGlobalArea[a]["AmountBonusValue"] = 3
						end
					end
					if global.WaterGlobalArea[a]["WtrUsed"] == nil then
						global.WaterGlobalArea[a]["WtrUsed"] = (global.WaterGlobalArea[a]["AmountWtr"] * global.WaterGlobalArea[a]["Percent"]) / 100
					end
					-- if global.WaterGlobalArea[a]["OPsA"] == nil or global.WaterGlobalArea[a]["OPsA"] < 0 then
						-- global.WaterGlobalArea[a]["OPsA"] = 0
					-- end
					-- if global.WaterGlobalArea[a]["WtrAdd"] == nil then
						-- global.WaterGlobalArea[a]["WtrAdd"] = 0
					-- end
					-- if global.WaterGlobalArea[a]["ODsA"] == nil or global.WaterGlobalArea[a]["ODsA"] < 0 then
						-- global.WaterGlobalArea[a]["ODsA"] = 0
					-- end
					-- if global.WaterGlobalArea[a]["ODs"] == nil then
						-- global.WaterGlobalArea[a]["ODs"] = 0
					-- end
					if global.WaterGlobalArea[a]["PercentPrev"] == nil then
						global.WaterGlobalArea[a]["PercentPrev"] = global.WaterGlobalArea[a]["Percent"]
					end
					if global.WaterGlobalArea[a]["Depleted"] == 1 then
						global.WaterGlobalArea[a]["FluidType"] = "None"
						global.WaterGlobalArea[a]["Percent"] = 100
						global.WaterGlobalArea[a]["PercentPrev"] = 100
						global.WaterGlobalArea[a]["WtrUsed"] = global.WaterGlobalArea[a]["AmountWtr"]
					end
					if global.WaterGlobalArea[a]["ToSearch"] == nil or global.WaterGlobalArea[a]["ToSearch"] == 0 then
						global.WaterGlobalArea[a]["ToSearch"] = nil
					end
					if global.WaterGlobalArea[a]["HasSearched"] == nil or global.WaterGlobalArea[a]["HasSearched"] == 0 then
						global.WaterGlobalArea[a]["HasSearched"] = nil
					end
					if global.WaterGlobalArea[a]["TilesSet"] == nil then
						global.WaterGlobalArea[a]["TilesSet"] = "N"
					end
					if global.WaterGlobalArea[a]["Percent"] < 50 then
						global.WaterGlobalArea[a]["Fired50"] = false
						global.WaterGlobalArea[a]["Fired75"] = false
						global.WaterGlobalArea[a]["Fired90"] = false
						global.WaterGlobalArea[a]["Fired95"] = false
						global.WaterGlobalArea[a]["Fired97"] = false
						global.WaterGlobalArea[a]["Fired98"] = false
						global.WaterGlobalArea[a]["Fired99"] = false
					end
					if global.WaterGlobalArea[a]["Percent"] >= 50 then
						global.WaterGlobalArea[a]["Fired50"] = true
					end
					if global.WaterGlobalArea[a]["Percent"] >= 75 then
						global.WaterGlobalArea[a]["Fired75"] = false
					end
					if global.WaterGlobalArea[a]["Percent"] >= 90 then
						global.WaterGlobalArea[a]["Fired90"] = true
					end
					if global.WaterGlobalArea[a]["Percent"] >= 95 then
						global.WaterGlobalArea[a]["Fired95"] = true
					end
					if global.WaterGlobalArea[a]["Percent"] >= 97 then
						global.WaterGlobalArea[a]["Fired97"] = true
					end
					if global.WaterGlobalArea[a]["Percent"] >= 98 then
						global.WaterGlobalArea[a]["Fired98"] = true
					end
					if global.WaterGlobalArea[a]["Percent"] >= 99 then
						global.WaterGlobalArea[a]["Fired99"] = true
					end
					if global.WaterGlobalArea[a]["BTFE"] == nil then
						global.WaterGlobalArea[a]["BTFE"] = 0
					end
					global.WaterGlobalArea[a]["BTF"] = Count
					for b = 1, Count, 1 do
						if global.WaterGlobalArea[a]["FluidType"] == nil or global.WaterGlobalArea[a]["FluidType"] == "None" then
							if #global.WaterGlobalArea[a]["WaterRepArea"] > 0 then
								tile = global.WaterGlobalArea[a]["WaterRepArea"][b]["name"]
							else
								tile = global.WaterGlobalArea[a]["WaterEdgeArea"][1]["name"]
							end
							if tile == "water" or tile == "deepwater" or tile == "lake-shallow" then
								global.WaterGlobalArea[a]["FluidType"] = "water"
							elseif tile == "crude-oil" or tile == "crude-oil-deep" or tile == "lake-deep" then
								global.WaterGlobalArea[a]["FluidType"] = "crude-oil"
							elseif global.WaterGlobalArea[a]["FluidType"] == nil then
								global.WaterGlobalArea[a]["FluidType"] = "None"
							end
						end
					end
					if global.WaterGlobalArea[a]["LoopCount"] == nil then
						global.WaterGlobalArea[a]["LoopCount"] = 0
					end
					if global.WaterGlobalArea[a]["RegenAmount"] == nil then
						global.WaterGlobalArea[a]["RegenAmount"] = 0
					end
					if global.WaterGlobalArea[a]["Percent"] >= 80 and global.WaterGlobalArea[a]["Percent"] < 100 then
						local TPP = math.floor((global.WaterGlobalArea[a]["ShallowWater"] + global.WaterGlobalArea[a]["DeepWater"]) / 20)
						local PF = math.floor(global.WaterGlobalArea[a]["Percent"] - 80) / 0.1
						local Tiles = TPP * (PF/100)
						global.WaterGlobalArea[a]["BTF"] = global.WaterGlobalArea[a]["BTF"] - Tiles
					else
						global.WaterGlobalArea[a]["BTF"] = Count
					end
					if global.WaterGlobalArea[a]["WaterEdgeArea"] == nil then
						global.WaterGlobalArea[a]["WaterEdgeArea"] = {}
					end
					for b = 1, #game.surfaces, 1 do
						if #global.WaterGlobalArea[a]["WaterRepArea"] > 0 then
							pos = global.WaterGlobalArea[a]["WaterRepArea"][1]["position"]
						else
							pos = global.WaterGlobalArea[a]["WaterEdgeArea"][1]["position"]
						end
						local tile = game.surfaces[b].get_tile(pos)
						if tile.valid == true then
							local tilename = tile.name
							if tilename == "water" or tilename =="deepwater" or tilename=="crude-oil" or tilename=="crude-oil-deep" or tilename=="sand-3" or tilename=="dry-dirt" or tilename=="lake-shallow" or tilename=="lake-deep" then
								if global.WaterGlobalArea[a]["Surface"] == nil then
									global.WaterGlobalArea[a]["Surface"] = game.surfaces[b]
								end
							end	
						end
						for c = Count, 1 , -1 do
							if #global.WaterGlobalArea[a]["WaterRepArea"] > 0 then
								posc = global.WaterGlobalArea[a]["WaterRepArea"][c]["position"]
								local tile = game.surfaces[b].get_tile(posc)
								if tile.valid == true then
									local tilename = tile.name
									if tilename == "water" or tilename =="deepwater" or tilename=="crude-oil" or tilename=="crude-oil-deep" then
										if global.WaterGlobalArea[a]["WaterRepArea"][c]["OriginalName"] == nil then
											global.WaterGlobalArea[a]["WaterRepArea"][c]["OriginalName"] = tilename
										end
									end
								end
							end
						end
					end
					if #global.WaterGlobalArea[a]["WaterEdgeArea"] > 0 then
						for b = 1, #global.WaterGlobalArea[a]["WaterEdgeArea"], 1 do
							if global.WaterGlobalArea[a]["MinX"] == nil then 
								global.WaterGlobalArea[a]["MinX"] = global.WaterGlobalArea[a]["WaterEdgeArea"][b]["x"]
							elseif global.WaterGlobalArea[a]["MinX"] == 0 or global.WaterGlobalArea[a]["MinX"] > global.WaterGlobalArea[a]["WaterEdgeArea"][b]["position"]["x"] then
								global.WaterGlobalArea[a]["MinX"] = global.WaterGlobalArea[a]["WaterEdgeArea"][b]["position"]["x"]
							end
							if global.WaterGlobalArea[a]["MaxX"] == nil then
								global.WaterGlobalArea[a]["MaxX"] = global.WaterGlobalArea[a]["WaterEdgeArea"][b]["x"]
							elseif global.WaterGlobalArea[a]["MaxX"] == 0 or global.WaterGlobalArea[a]["MaxX"] < global.WaterGlobalArea[a]["WaterEdgeArea"][b]["position"]["x"] then
								global.WaterGlobalArea[a]["MaxX"] = global.WaterGlobalArea[a]["WaterEdgeArea"][b]["position"]["x"]
							end
							if global.WaterGlobalArea[a]["MinY"] == nil then
								global.WaterGlobalArea[a]["MinY"] = global.WaterGlobalArea[a]["WaterEdgeArea"][b]["y"]
							elseif global.WaterGlobalArea[a]["MinY"] == 0 or global.WaterGlobalArea[a]["MinY"] > global.WaterGlobalArea[a]["WaterEdgeArea"][b]["position"]["y"] then
								global.WaterGlobalArea[a]["MinY"] = global.WaterGlobalArea[a]["WaterEdgeArea"][b]["position"]["y"]
							end
							if global.WaterGlobalArea[a]["MaxY"] == nil then
								global.WaterGlobalArea[a]["MaxY"] = global.WaterGlobalArea[a]["WaterEdgeArea"][b]["y"]
							elseif global.WaterGlobalArea[a]["MaxY"] == 0 or global.WaterGlobalArea[a]["MaxY"] < global.WaterGlobalArea[a]["WaterEdgeArea"][b]["position"]["y"] then
								global.WaterGlobalArea[a]["MaxY"] = global.WaterGlobalArea[a]["WaterEdgeArea"][b]["position"]["y"]
							end
						end
						local minx = global.WaterGlobalArea[a]["MinX"]
						local maxx = global.WaterGlobalArea[a]["MaxX"]
						local miny = global.WaterGlobalArea[a]["MinY"]
						local maxy = global.WaterGlobalArea[a]["MaxY"]
						global.WaterGlobalArea[a]["Hdif"] = maxx - minx
						global.WaterGlobalArea[a]["Vdif"] = maxy - miny
						global.WaterGlobalArea[a]["Hyp"] = math.sqrt(((maxx - minx)^2) + ((maxy - miny)^2))
					end
					-- MapMarker = global.WaterGlobalArea[a]["MapMarker"]
					-- if global.WaterGlobalArea[a]["MapMarkerPlaced"] == false then
						-- global.WaterGlobalArea[a]["MapMarker"][1] = {["force"] = Force, ["placed"] = false,["icon"] = nil}
					-- else
						-- global.WaterGlobalArea[a]["MapMarker"][1] = {["force"] = Force, ["placed"] = true,["icon"] = MapMarker}
					-- end
					if global.WaterGlobalArea[a]["MapMarker"] ~= nil and global.WaterGlobalArea[a]["MapMarker"].valid == true then
						global.WaterGlobalArea[a]["MapMarker"].destroy()
						global.WaterGlobalArea[a]["MapMarkerPlaced"] = nil
					end
				end
			end
			if #global.OPLocate > 0 then
				for a = #global.OPLocate, 1, -1 do
					if global.OPLocate[a]["OPposition"] ~= nil then
						OPTilePosX = global.OPLocate[a]["OPposition"]["x"]
						OPTilePosY = global.OPLocate[a]["OPposition"]["y"]
					else
						OPTilePosX = global.OPLocate[a]["position"]["x"]
						OPTilePosY = global.OPLocate[a]["position"]["y"]
					end
					for b = 1, #global.WaterGlobalArea, 1 do
						if #global.WaterGlobalArea[b]["WaterRepArea"] > 0 then
							CompTiles = global.WaterGlobalArea[b]["ShallowWater"] + global.WaterGlobalArea[b]["DeepWater"]
						else
							CompTiles = #global.WaterGlobalArea[b]["WaterEdgeArea"]
						end
						if global.OPLocate[a]["WA"] == nil or global.OPLocate[a]["WA"] == 0 then
							for c = CompTiles, 1, -1 do -- FOR EACH TILE in WATERAREA
								if #global.WaterGlobalArea[b]["WaterRepArea"] > 0 then
									WATilePosX = global.WaterGlobalArea[b]["WaterRepArea"][c]["position"]["x"]
									WATilePosY = global.WaterGlobalArea[b]["WaterRepArea"][c]["position"]["y"]
								else
									WATilePosX = global.WaterGlobalArea[b]["WaterEdgeArea"][c]["position"]["x"]								
									WATilePosY = global.WaterGlobalArea[b]["WaterEdgeArea"][c]["position"]["y"]
								end
								if WATilePosX == OPTilePosX then
									if WATilePosY == OPTilePosY then
										if #global.WaterGlobalArea[b]["WaterRepArea"] > 0 then
											global.OPLocate[a]["WA"] = b
										else
											global.OPLocate[a]["WA"] = global.WaterGlobalArea[b]["WGAID"]
										end
									end
								end
							end
						end
					end
					if global.OPLocate[a]["Active"] == nil then
						global.OPLocate[a]["Active"] = 0
					end
					if global.OPLocate[a]["entity"] == nil then
						global.OPLocate[a]["entity"] = global.OPLocate[a]["OPentity"]
					end
					if global.OPLocate[a]["position"] == nil then
						global.OPLocate[a]["position"] = global.OPLocate[a]["OPposition"]
					end
					if global.OPLocate[a]["direction"] == nil then
						global.OPLocate[a]["direction"] = global.OPLocate[a]["OPdirection"]
					end
					if global.OPLocate[a]["force"] == nil then
						global.OPLocate[a]["force"] = "player"
					end
					for b = 1, #global.WaterGlobalArea, 1 do
						if global.OPLocate[a]["WA"] == b and global.WaterGlobalArea[b]["Depleted"] ~= 1 then
							global.OPLocate[a]["tile"] = global.WaterGlobalArea[b]["FluidType"]
						elseif global.OPLocate[a]["WA"] == b and global.WaterGlobalArea[b]["Depleted"] == 1 then
							global.OPLocate[a]["tile"] = "None"
						end
					end
					for b = 1, #game.surfaces, 1 do
						pos = global.OPLocate[a]["position"]
						local tile = game.surfaces[b].get_tile(pos)
						if tile.valid == true then
							local tilename = tile.name
							if tilename == "water" or tilename =="deepwater" or tilename=="crude-oil" or tilename=="crude-oil-deep" or tilename=="sand-3" or tilename=="dry-dirt" then
								global.OPLocate[a]["surface"] = game.surfaces[b]
							end
						end
					end
					if global.OPLocate[a]["spritepos"] == nil then
						--global.OPLocate[a]["spritepos"] = global.OPLocate[a]["position"] -- POSITION IS IN WATER / SPRITEPOS IS OUTPUT PIPE
						if global.OPLocate[a]["direction"] == 0 then -- North
							global.OPLocate[a]["spritepos"] = {["x"] = global.OPLocate[a]["position"]["x"], ["y"] = global.OPLocate[a]["position"]["y"] + 1}
						elseif global.OPLocate[a]["direction"] == 2 then -- East
							global.OPLocate[a]["spritepos"] = {["x"] = global.OPLocate[a]["position"]["x"] - 1, ["y"] = global.OPLocate[a]["position"]["y"]}
						elseif global.OPLocate[a]["direction"] == 4 then -- South
							global.OPLocate[a]["spritepos"] = {["x"] = global.OPLocate[a]["position"]["x"], ["y"] = global.OPLocate[a]["position"]["y"] - 1}
						elseif global.OPLocate[a]["direction"] == 6 then -- West
							global.OPLocate[a]["spritepos"] = {["x"] = global.OPLocate[a]["position"]["x"] + 1, ["y"] = global.OPLocate[a]["position"]["y"]}
						end
					end
					if global.OPLocate[a]["tile"] == "water" or global.OPLocate[a]["tile"] == "deepwater" then
						local OPE = global.OPLocate[a]["entity"]
						local OPD = global.OPLocate[a]["direction"]
						local OPP = global.OPLocate[a]["position"]
						local OPSp = global.OPLocate[a]["spritepos"]
						local OPS = global.OPLocate[a]["surface"]
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
						global.OPLocate[a]["entity"] = OPN
						-- if global.OPLocate[a]["entity"] == nil then
							-- if global.WaterGlobalArea[global.OPLocate[a]["WA"]]["OPs"] <= 0 then
								-- global.WaterGlobalArea[global.OPLocate[a]["WA"]]["OPs"] = 0
							-- else
								-- global.WaterGlobalArea[global.OPLocate[a]["WA"]]["OPs"] = global.WaterGlobalArea[global.OPLocate[a]["WA"]]["OPs"] - 1
							-- end
							-- table.remove(global.OPLocate,a)
							-- game.players[1].insert{name="offshore-pump",count=1}
						-- end
					elseif global.OPLocate[a]["tile"] == "crude-oil" or global.OPLocate[a]["tile"] == "crude-oil-deep" then
						local OPE2 = global.OPLocate[a]["entity"]
						local OPD2 = global.OPLocate[a]["direction"]
						local OPP2 = global.OPLocate[a]["position"]
						local OPSp2 = global.OPLocate[a]["spritepos"]
						local OPS2 = global.OPLocate[a]["surface"]
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
						global.OPLocate[a]["entity"] = OPN2
						-- if global.OPLocate[a]["entity"] == nil then
							-- if global.WaterGlobalArea[global.OPLocate[a]["WA"]]["OPs"] <= 0 then
								-- global.WaterGlobalArea[global.OPLocate[a]["WA"]]["OPs"] = 0
							-- else
								-- global.WaterGlobalArea[global.OPLocate[a]["WA"]]["OPs"] = global.WaterGlobalArea[global.OPLocate[a]["WA"]]["OPs"] - 1
							-- end
							-- table.remove(global.OPLocate,a)
							-- game.players[1].insert{name="offshore-pump",count=1}
						-- end
					else
						local OPE3 = global.OPLocate[a]["entity"]
						local OPD3 = global.OPLocate[a]["direction"]
						local OPP3 = global.OPLocate[a]["position"]
						local OPSp3 = global.OPLocate[a]["spritepos"]
						local OPS3 = global.OPLocate[a]["surface"]
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
						global.OPLocate[a]["entity"] = OPN3
					end
				end
			end
			if #global.ODLocate > 0 then
				for a = 1, #global.ODLocate, 1 do
					if global.ODLocate[a]["force"] == nil then
						global.ODLocate[a]["force"] = global.ODLocate[a]["entity"].last_user.force
					end
					for b = 1, #game.surfaces, 1 do
						pos = global.ODLocate[a]["position"]
						local tile = game.surfaces[b].get_tile(pos)
						if tile.valid == true then
							local tilename = tile.name
							if tilename == "water" or tilename =="deepwater" or tilename=="crude-oil" or tilename=="crude-oil-deep" or tilename=="sand-3" or tilename=="dry-dirt" then
								global.ODLocate[a]["surface"] = game.surfaces[b]
							end
						end
					end
					local OPE4 = global.ODLocate[a]["entity"]
					local OPD4 = global.ODLocate[a]["direction"]
					local OPP4 = global.ODLocate[a]["position"]
					local OPS4 = global.ODLocate[a]["surface"]
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
					global.ODLocate[a]["entity"] = OPN4
					for b = 1, #global.WaterGlobalArea, 1 do
						if global.ODLocate[a]["WA"] == b and global.WaterGlobalArea[b]["Depleted"] ~= 1 then
							global.ODLocate[a]["tile"] = global.WaterGlobalArea[b]["FluidType"]
							global.ODLocate[a]["PipeFluid"] = global.WaterGlobalArea[b]["FluidType"]
						elseif global.ODLocate[a]["WA"] == b and global.WaterGlobalArea[b]["Depleted"] == 1 then
							global.ODLocate[a]["tile"] = "None"
							global.ODLocate[a]["PipeFluid"] = "None"
						end
					end
				end
			end
			Players = #game.players
			if Players <= 1 then
				if global.PlayerForces == nil or #global.PlayerForces < 1 then
					Force = game.players[1].force.name
					global.PlayerForces[#global.PlayerForces+1] = {["name"] = Force, ["OPcount"] = 0, ["ODcount"] = 0, ["WaterFlow"] = 0, ["LastWaterFlow"] = 0, ["CrudeFlow"] = 0, ["LastCrudeFlow"] = 0}
					for a = 1, #global.WaterGlobalArea, 1 do
						OPs = 0
						ODs = 0
						for b = 1, #global.OPLocate, 1 do
							if global.WaterGlobalArea[a]["WGAID"] == global.OPLocate[b]["WA"] then
								OPs = OPs + 1
							end
						end
						for c = 1, #global.ODLocate, 1 do
							if global.WaterGlobalArea[a]["WGAID"] == global.ODLocate[c]["WA"] then
								ODs = ODs + 1
							end
						end
						-- OPs = global.WaterGlobalArea[a]["OPs"]
						global.WaterGlobalArea[a]["OPs"] = {}
						-- OPsA = global.WaterGlobalArea[a]["OPsA"]
						global.WaterGlobalArea[a]["OPsA"] = {}
						-- ODs = global.WaterGlobalArea[a]["ODs"]
						global.WaterGlobalArea[a]["ODs"] = {}
						-- ODsA = global.WaterGlobalArea[a]["ODsA"]
						global.WaterGlobalArea[a]["ODsA"] = {}
						WtrAdd = global.WaterGlobalArea[a]["WtrAdd"]
						global.WaterGlobalArea[a]["WtrAdd"] = {}
						global.WaterGlobalArea[a]["MapMarker"] = {}
						global.WaterGlobalArea[a]["MapMarkerPlaced"] = false
						global.WaterGlobalArea[a]["OPs"][1] = {["force"] = Force, ["count"] = OPs}
						global.PlayerForces[#global.PlayerForces]["OPcount"] = global.PlayerForces[#global.PlayerForces]["OPcount"] + OPs
						global.WaterGlobalArea[a]["OPsA"][1] = {["force"] = Force, ["count"] = 0}
						global.WaterGlobalArea[a]["ODs"][1] = {["force"] = Force, ["count"] = ODs}
						global.PlayerForces[#global.PlayerForces]["ODcount"] = global.PlayerForces[#global.PlayerForces]["ODcount"] + ODs
						global.WaterGlobalArea[a]["ODsA"][1] = {["force"] = Force, ["count"] = 0}
						global.WaterGlobalArea[a]["WtrAdd"][1] = {["force"] = Force, ["count"] = WtrAdd}
						local maptext = string.format("%s - %s - %.2f %%",global.WaterGlobalArea[a]["WtrName"],comma_value(math.ceil(global.WaterGlobalArea[a]["AmountWtr"]*((100-global.WaterGlobalArea[a]["Percent"])/100))),100-global.WaterGlobalArea[a]["Percent"])
						if #global.WaterGlobalArea[a]["WaterRepArea"] > 0 then
							global.WaterGlobalArea[a]["MapMarker"][1] = {["placed"] = true, ["force"] = Force, ["icon"] = game.forces[Force].add_chart_tag(1,{["position"]= global.WaterGlobalArea[a]["WaterRepArea"][1]["position"],["text"] = maptext})}
						else
							global.WaterGlobalArea[a]["MapMarker"][1] = {["placed"] = true, ["force"] = Force, ["icon"] = game.forces[Force].add_chart_tag(1,{["position"]= global.WaterGlobalArea[a]["WaterEdgeArea"][1]["position"],["text"] = maptext})}
						end
					end
				end
			else
				for a = 1, Players, 1 do
					Force = game.players[a].force.name
					if global.PlayerForces == nil or global.PlayerForces < 1 then
						global.PlayerForces[#global.PlayerForces+1] = {["name"] = Force, ["OPcount"] = 0, ["ODcount"] = 0, ["WaterFlow"] = 0, ["LastWaterFlow"] = 0, ["CrudeFlow"] = 0, ["LastCrudeFlow"] = 0}
						for b = 1, #global.WaterGlobalArea, 1 do
							OPs = 0
							ODs = 0
							for c = 1, #global.OPLocate, 1 do
								if global.WaterGlobalArea[b]["WGAID"] == global.OPLocate[c]["WA"] then
									if Force == global.OPLocate[c]["force"] then
										OPs = OPs + 1
									end
								end
							end
							for d = 1, #global.ODLocate, 1 do
								if global.WaterGlobalArea[b]["WGAID"] == global.ODLocate[d]["WA"] then
									if Force == global.ODLocate[d]["force"] then
										ODs = ODs + 1
									end
								end
							end
							if OPs > 0 then
								-- OPs = global.WaterGlobalArea[a]["OPs"]
								global.WaterGlobalArea[b]["OPs"] = {}
								-- OPsA = global.WaterGlobalArea[a]["OPsA"]
								global.WaterGlobalArea[b]["OPsA"] = {}
								global.WaterGlobalArea[b]["OPs"][1] = {["force"] = Force, ["count"] = OPs}
								global.WaterGlobalArea[b]["OPsA"][1] = {["force"] = Force, ["count"] = 0}
								global.PlayerForces[#global.PlayerForces]["OPcount"] = global.PlayerForces[#global.PlayerForces]["OPcount"] + OPs
								local maptext = string.format("%s - %s - %.2f %%",global.WaterGlobalArea[b]["WtrName"],comma_value(math.ceil(global.WaterGlobalArea[b]["AmountWtr"]*((100-global.WaterGlobalArea[b]["Percent"])/100))),100-global.WaterGlobalArea[b]["Percent"])
								if #global.WaterGlobalArea[b]["WaterRepArea"] > 0 then
									global.WaterGlobalArea[b]["MapMarker"][1] = {["force"] = Force, ["placed"] = true,["icon"] = game.forces[Force].add_chart_tag(1,{["position"]= global.WaterGlobalArea[b]["WaterRepArea"][1]["position"],["text"] = maptext})}
								else
									global.WaterGlobalArea[b]["MapMarker"][1] = {["force"] = Force, ["placed"] = true,["icon"] = game.forces[Force].add_chart_tag(1,{["position"]= global.WaterGlobalArea[b]["WaterEdgeArea"][1]["position"],["text"] = maptext})}
								end
								global.WaterGlobalArea[b]["MapMarkerPlaced"] = false
							end
							if ODs > 0 then
								global.WaterGlobalArea[b]["ODsA"] = {}
								-- ODs = global.WaterGlobalArea[a]["ODs"]
								global.WaterGlobalArea[b]["ODs"] = {}
								-- ODsA = global.WaterGlobalArea[a]["ODsA"]
								global.WaterGlobalArea[b]["WtrAdd"] = {}
								global.WaterGlobalArea[b]["ODs"][1] = {["force"] = Force, ["count"] = ODs}
								global.WaterGlobalArea[b]["ODsA"][1] = {["force"] = Force, ["count"] = 0}
								global.WaterGlobalArea[b]["WtrAdd"][1] = {["force"] = Force, ["count"] = WtrAdd}
								global.PlayerForces[#global.PlayerForces]["ODcount"] = global.PlayerForces[#global.PlayerForces]["ODcount"] + ODs
							end
						end
					else
						NewForce = true
						for e = 1, #global.PlayerForces, 1 do
							if global.PlayerForces[e]["name"] == Force then
								NewForce = false
							end
						end
						if NewForce == true then
							global.PlayerForces[#global.PlayerForces+1] = {["name"] = Force, ["OPcount"] = 0, ["ODcount"] = 0, ["WaterFlow"] = 0, ["LastWaterFlow"] = 0, ["CrudeFlow"] = 0, ["LastCrudeFlow"] = 0}
							--for f = 1, #global.PlayerForces, 1 do
								for g = 1, #global.WaterGlobalArea, 1 do
									OPs = 0
									ODs = 0
									for h = 1, #global.OPLocate, 1 do
										if global.WaterGlobalArea[g]["WGAID"] == global.OPLocate[h]["WA"] then
											-- REBUILD OFFSHORE WITH CORRECT FORCE ASSIGNMENT
											if global.OPLocate[h]["force"] == global.PlayerForces[#global.PlayerForces]["name"] then
												OPs = OPs + 1
											end
										end
									end
									for i = 1, #global.ODLocate, 1 do
										if global.WaterGlobalArea[g]["WGAID"] == global.ODLocate[i]["WA"] then
											-- REBUILD OFFSHORE WITH CORRECT FORCE ASSIGNMENT
											if global.ODLocate[i]["force"] == global.PlayerForces[#global.PlayerForces]["name"] then
												ODs = ODs + 1
											end
										end
									end
									if OPs > 0 then
										global.WaterGlobalArea[g]["OPs"][#global.WaterGlobalArea[g]["OPs"]+1] = {["force"] = Force, ["count"] = OPs}
										global.WaterGlobalArea[g]["OPsA"][#global.WaterGlobalArea[g]["OPsA"]+1] = {["force"] = Force, ["count"] = 0}
										global.PlayerForces[#global.PlayerForces]["OPcount"] = global.PlayerForces[#global.PlayerForces]["OPcount"] + OPs
										local maptext = string.format("%s - %s - %.2f %%",global.WaterGlobalArea[g]["WtrName"],comma_value(math.ceil(global.WaterGlobalArea[g]["AmountWtr"]*((100-global.WaterGlobalArea[g]["Percent"])/100))),100-global.WaterGlobalArea[g]["Percent"])
										if #global.WaterGlobalArea[g]["WaterRepArea"] > 0 then
											global.WaterGlobalArea[g]["MapMarker"][#global.WaterGlobalArea[g]["MapMarker"]+1] = {["force"] = Force, ["placed"] = true,["icon"] = game.forces[Force].add_chart_tag(1,{["position"]= global.WaterGlobalArea[g]["WaterRepArea"][1]["position"],["text"] = maptext})}
										else
											global.WaterGlobalArea[g]["MapMarker"][#global.WaterGlobalArea[g]["MapMarker"]+1] = {["force"] = Force, ["placed"] = true,["icon"] = game.forces[Force].add_chart_tag(1,{["position"]= global.WaterGlobalArea[g]["WaterEdgeArea"][1]["position"],["text"] = maptext})}
										end
									end
									if ODs > 0 then
										global.WaterGlobalArea[g]["ODs"][#global.WaterGlobalArea[g]["ODs"]+1] = {["force"] = Force, ["count"] = ODs}
										global.WaterGlobalArea[g]["ODsA"][#global.WaterGlobalArea[g]["ODsA"]+1] = {["force"] = Force, ["count"] = 0}
										global.WaterGlobalArea[g]["WtrAdd"][#global.WaterGlobalArea[g]["WtrAdd"]+1] = {["force"] = Force, ["count"] = 0}
										global.PlayerForces[#global.PlayerForces]["ODcount"] = global.PlayerForces[#global.PlayerForces]["ODcount"] + ODs
									end
								end
							--end
						end
					end
				end
			end
			-- for a = 1, #global.OPLocate, 1 do
				-- for b = 1, #global.WaterGlobalArea, 1 do
					-- for c = 1, #global.PlayerForces, 1 do
						-- if global.OPLocate[a]["force"] == global.WaterGlobalArea[b]["OPs"][c]["force"] then
							-- global.WaterGlobalArea[b]["OPs"][c]["count"] = global.WaterGlobalArea[b]["OPs"][c]["count"] + 1
						-- end
					-- end
				-- end
			-- end
			-- for a = 1, #global.ODLocate, 1 do
				-- for b = 1, #global.WaterGlobalArea, 1 do
					-- for c = 1, #global.PlayerForces, 1 do
						-- if global.ODLocate[a]["force"] == global.WaterGlobalArea[b]["ODs"][c]["force"] then
							-- global.WaterGlobalArea[b]["ODs"][c]["count"] = global.WaterGlobalArea[b]["ODs"][c]["count"] + 1
						-- end
					-- end
				-- end
			-- end
		global.Added = false
		end
		global.NewInstall = false
	end
end

-- COMMAND FUNCTIONS -- 

function RestoreWater()
	local RWDisabled = settings.global["Disable-RestoreWater-Command"].value
	if RWDisabled == true then
		game.player.print("RestoreWater Command has been disabled in map settings.")
	else
		if global.WaterGlobalArea then
			for a = #global.WaterGlobalArea, 1, -1 do
				if global.WaterGlobalArea[a]["Percent"] >= 80 or global.WaterGlobalArea[a]["FluidType"] == "crude-oil" then
					if #global.WaterGlobalArea[a]["WaterRepArea"] > 0 then
						local NoTiles = global.WaterGlobalArea[a]["ShallowWater"] + global.WaterGlobalArea[a]["DeepWater"]
						for b = 1, NoTiles, 1 do
								TileName = global.WaterGlobalArea[a]["WaterRepArea"][b]["name"]
								if TileName == "sand-3" or TileName == "crude-oil" or TileName == "lake-shallow" then
									global.WaterGlobalArea[a]["WaterRepArea"][b]["name"] = "water"
								elseif TileName == "dry-dirt" or TileName == "crude-oil-deep" or "lake-deep" then
									global.WaterGlobalArea[a]["WaterRepArea"][b]["name"] = "deepwater"
								else
									game.print("Not A Replaceable Tile")
								end
							game.surfaces[global.WaterGlobalArea[a]["Surface"].name].set_tiles(global.WaterGlobalArea[a]["WaterRepArea"], true)
						end
					else
						local WGA = global.WaterGlobalArea
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
				table.remove(global.WaterGlobalArea,a)
			end
			local RemoveFromTable = settings.global["FluidArea-RemoveFromTable"].value
			if RemoveFromTable == true then
				game.print("As Remove From Table is active, old depleted fluid areas cannot be restored.")
			end
		end
		--global.WaterGlobalArea = nil
		if global.OPLocate then	
			for a = #global.OPLocate, 1, -1 do
				RepOP = global.OPLocate[a]["position"]
				RepOPSp = global.OPLocate[a]["spritepos"]
				RepOPD = global.OPLocate[a]["direction"]
				RepOPE = global.OPLocate[a]["entity"]
				RepOPS = global.OPLocate[a]["surface"]
				RepOPPl = global.OPLocate[a]["entity"].last_user
				if RepOPPl == nil then
					RepOPPl = game.players[1]["name"]
				end
				RepOPF = RepOPE.force
				RepOPE.destroy()
				game.surfaces[RepOPS.name].create_entity{name="offshore-pump",position = RepOPSp,direction = RepOPD,player=RepOPPl,force = RepOPF}
				table.remove(global.OPLocate,a)
			end
		--global.OPLocate = nil
		end
		if global.ODLocate then
			for a = #global.ODLocate,1, -1 do
				RepODE = global.ODLocate[a]["entity"]
				RepODE.destroy()
				table.remove(global.ODLocate,a)
			end
		--global.ODLocate = nil
		end
		if global.FluidProducers then
			for a = #global.FluidProducers,1, -1 do
				table.remove(global.ODLocate,a)
			end
		--global.ODLocate = nil
		end
		--global.FluidProducers = nil
		global.PercentChange = 0
		global.WaterFlow = 0
		global.CrudeFlow = 0
		global.LastWaterFlow = 0
		global.LastCrudeFlow = 0
		global.WGAID = 0
		global.Type = 0
		global.ActiveOPs = 0
		global.ActiveODs = 0
		game.print("FluidAreas Restored!")
	end
end

function StopScanning()
	game.player.print("Stopping All Active Scans")
	for a = 1, #global.WaterGlobalArea, 1 do
		if global.WaterGlobalArea[a]["ToSearch"] ~= nil then
			global.WaterGlobalArea[a]["ToSearch"] = nil
			waterbodies.WtrName(a)
			game.player.print(string.format("%s created, with %sL of %s.", global.WaterGlobalArea[a]["WtrName"], global.WaterGlobalArea[a]["AmountWtr"], global.WaterGlobalArea[a]["FluidType"]))
			MapMarker(a)
		end
	end
end

function PlayerForces()
	game.player.print("PlayerForces Info")
	if #global.PlayerForces == 0 then
		game.player.print("No PlayerForces Data to show.")
	else
		local PF = global.PlayerForces
		for a = 1, #global.PlayerForces, 1 do
			game.player.print(string.format("PlayerForce: %s, Offshore: Pumps: %s | Drains: %s, Flow: Water: %s | Crude: %s",global.PlayerForces[a]["name"],global.PlayerForces[a]["OPcount"],global.PlayerForces[a]["ODcount"],comma_value(global.PlayerForces[a]["WaterFlow"]),comma_value(global.PlayerForces[a]["CrudeFlow"])))
		end
	end
end

function Offshores()
	game.player.print("Offshore Pump(s) Info")
	if #global.OPLocate == 0 then
		game.player.print("No Offshore Pump(s) on map.")
	else
		local PlayerForce = game.player.force.name
		local Found = false
		for a = 1, #global.OPLocate, 1 do
			if global.OPLocate[a]["force"] == PlayerForce then
				Found = true
				local FluidName = string.sub(global.OPLocate[a]["tile"],1,1):upper()..string.sub(global.OPLocate[a]["tile"],2)
				local SurfaceName = string.sub(global.OPLocate[a]["surface"].name,1,1):upper()..string.sub(global.OPLocate[a]["surface"].name,2)
				game.player.print(string.format("Offshore Pump Position: {%s, %s}, Pump Surface: %s, Fluid Type: %s, FluidArea: %s, Active: %s, Force: %s",global.OPLocate[a]["position"]["x"],global.OPLocate[a]["position"]["y"],SurfaceName, FluidName,global.OPLocate[a]["WA"], global.OPLocate[a]["Active"], global.OPLocate[a]["force"]))
			end
		end
		if Found == false then
			game.player.print("No Offshore Pump(s) for your Team.")
		end
	end
end

function OffshoreDrains()
	game.player.print("Offshore Drain(s) Info")
	if #global.ODLocate == 0 then
		game.player.print("No Offshore Drain(s) on map.")
	else
		local PlayerForce = game.player.force.name
		local Found = false
		for a = 1, #global.ODLocate, 1 do
			if global.ODLocate[a]["force"] == PlayerForce then
				if global.ODLocate[a]["PipeFluid"] == nil then
					FluidName = "None"
				else
					FluidName = string.sub(global.ODLocate[a]["PipeFluid"],1,1):upper()..string.sub(global.ODLocate[a]["PipeFluid"],2)
				end
				Found = true
				local SurfaceName = string.sub(global.ODLocate[a]["surface"].name,1,1):upper()..string.sub(global.ODLocate[a]["surface"].name,2)
				game.player.print(string.format("Offshore Drain Position: {%s, %s}, Pipe Surface: %s , Pipe Fluid: %s, Fluid Area: %s, Active: %s",global.ODLocate[a]["position"]["x"],global.ODLocate[a]["position"]["y"],SurfaceName, FluidName, global.ODLocate[a]["WA"], global.ODLocate[a]["Active"]))
			end
		end
		if Found == false then
			game.player.print("No Offshore Drain(s) for your Team.")
		end
	end
end

function WaterAreas()
	game.player.print("FluidArea(s) Info")
	if #global.WaterGlobalArea == 0 then
		game.player.print("No FluidArea(s) on map.")
	else
		PForce = game.player.force.name
		Found = false
		for a = 1, #global.WaterGlobalArea, 1 do
			OPs = 0
			OPsA = 0
			ODs = 0
			ODsA = 0
			Shallow = 0
			for b = 1, #global.WaterGlobalArea[a]["OPs"], 1 do
				if global.WaterGlobalArea[a]["OPs"][b]["force"] == PForce then
					Found = true
					FluidName = string.sub(global.WaterGlobalArea[a]["FluidType"],1,1):upper()..string.sub(global.WaterGlobalArea[a]["FluidType"],2)
					FluidName2 = FluidName
					if FluidName2 == "None" then
						FluidName2 = "Fluid"
					end
					SurfaceName = string.sub(global.WaterGlobalArea[a]["Surface"].name,1,1):upper()..string.sub(global.WaterGlobalArea[a]["Surface"].name,2)
					if global.WaterGlobalArea[a]["OPs"][b] == nil then
						OPs = 0
						OPsA = 0
					else
						OPs = global.WaterGlobalArea[a]["OPs"][b]["count"]
						OPsA = global.WaterGlobalArea[a]["OPsA"][b]["count"]
					end
					Shallow = global.WaterGlobalArea[a]["ShallowWater"] + global.WaterGlobalArea[a]["ShallowWater-Shallow"] + global.WaterGlobalArea[a]["ShallowWater-Mud"]
				end
			end
			for d = 1, #global.WaterGlobalArea[a]["ODs"], 1 do
				if global.WaterGlobalArea[a]["ODs"][d]["force"] == PForce then
					Found = true
					FluidName = string.sub(global.WaterGlobalArea[a]["FluidType"],1,1):upper()..string.sub(global.WaterGlobalArea[a]["FluidType"],2)
					FluidName2 = FluidName
					if FluidName2 == "None" then
						FluidName2 = "Fluid"
					end
					SurfaceName = string.sub(global.WaterGlobalArea[a]["Surface"].name,1,1):upper()..string.sub(global.WaterGlobalArea[a]["Surface"].name,2)
					if global.WaterGlobalArea[a]["ODs"][d] == nil then
						ODs = 0
						ODsA = 0
					else
						ODs = global.WaterGlobalArea[a]["ODs"][d]["count"]
						ODsA = global.WaterGlobalArea[a]["ODsA"][d]["count"]
					end
					Shallow = global.WaterGlobalArea[a]["ShallowWater"] + global.WaterGlobalArea[a]["ShallowWater-Shallow"] + global.WaterGlobalArea[a]["ShallowWater-Mud"]
				end
			end
			if Found == true then
				game.player.print(string.format("ID: %s | %s | Surface: %s | Fluid Type: %s | %s Amount: %s L | Regen %.2f | Percent Depleted: %.4f %% | \n Tiles (RepArea:(%.f) / EdgeArea:(%.f)) | Shallow: %.f / Deep: %.f | Active: Pumps: %.f / Drains: %.f | Total : Pumps: %.f / Drains: %.f |", global.WaterGlobalArea[a]["WGAID"],global.WaterGlobalArea[a]["WtrName"],SurfaceName,FluidName,FluidName2, comma_value(global.WaterGlobalArea[a]["AmountWtr"]),global.WaterGlobalArea[a]["RegenAmount"], global.WaterGlobalArea[a]["Percent"],#global.WaterGlobalArea[a]["WaterRepArea"],#global.WaterGlobalArea[a]["WaterEdgeArea"],Shallow,global.WaterGlobalArea[a]["DeepWater"], OPsA, ODsA, OPs,ODs))
			end
		end
		if Found == false then
			game.player.print("No FluidArea(s) for your Team.")
		end
	end
end

function PumpJacks()
	game.player.print("Pumpjack(s) Location Info")
	if #global.FluidProducers == 0 then
		game.player.print("No Pumpjack(s) to show.")
	else
		local PlayerForce = game.player.force.name
		for a = 1, #global.FluidProducers, 1 do
			if global.FluidProducers[a]["force"] == PlayerForce then
				local SurfaceName = string.sub(global.FluidProducers[a]["surface"].name,1,1):upper()..string.sub(global.FluidProducers[a]["surface"].name,2)
				game.player.print(string.format("Pumpjack Position: {%s, %s}, Pumpjack Surface: %s",global.FluidProducers[a]["position"]["x"],global.FluidProducers[a]["position"]["y"],SurfaceName))
			end
		end
	end
end

function ScenFunc()
	global.LandFill = {}
	global.PlayerForces = {}
	global.ScanOffshoresQueue = {}
	global.InstallTick = 0
	global.WGAID = 0
	global.LoopTick = 0
end

function WaaRSetup()
	Globals()
	LinkGlobals()
	for _, force in pairs(game.forces) do	-- Enable Offshore Drain Recipe if Fluid Handling has already been Researched
		if force.technologies["fluid-handling"].researched then
			force.recipes["offshore-drain"].enabled = true
		end
	end
end

-- SCRIPT EVENTS -- 

script.on_init(WaaRSetup)
script.on_load(LinkGlobals)
--script.on_nth_tick(60,EverySec)
script.on_nth_tick(6, CheckWater)
-- script.set_event_filter(defines.events.on_built_entity,{{filter="type", type = "offshore-pump"},{filter="type", type = "pipe"}})
-- script.set_event_filter(defines.events.on_robot_built_entity,{{filter="type", type = "offshore-pump"},{filter="type", type = "pipe"}})
-- script.set_event_filter(defines.events.script_raised_built,{{filter="type", type = "offshore-pump"},{filter="type", type = "pipe"}})
script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity}, BuiltOffShore )
script.on_event({defines.events.script_raised_built}, ScriptConvert)
script.on_event({defines.events.on_player_mined_entity,defines.events.script_raised_destroy,defines.events.on_robot_mined_entity,defines.events.on_entity_died}, DestroyedOffShore)
script.on_event({defines.events.on_player_built_tile,defines.events.on_robot_built_tile}, LandFillCheck)
script.on_event({defines.events.on_game_created_from_scenario},ScenFunc)
script.on_configuration_changed(UpdateMod)
remote.add_interface("WaaR", {	build = function(a,b)	event = a	global.remotetrigger = b	if event ~= nil then		ScriptConvert(event)	end end})
commands.add_command("RestoreWater", "Restores Water Areas & Clears GlobalTable",RestoreWater)
commands.add_command("Offshores", "Displays All The Offshore Pumps Built", Offshores)
commands.add_command("OffshoreDrains", "Displays All The Offshore Drains Built", OffshoreDrains)
commands.add_command("WaterAreas", "Displays All The WaterAreas Built", WaterAreas)
commands.add_command("Pumpjacks", "Displays All The Pumpjacks Built", PumpJacks)
commands.add_command("PlayerForces", "Displays All PlayerForces",PlayerForces)
commands.add_command("StopScan", "Stops actively scanning any area that is",StopScanning)