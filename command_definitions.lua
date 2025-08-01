local utils = require("modules.utils")

command_definitions = {}

function command_definitions.RestoreWater()
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

function command_definitions.Offshores()
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


function command_definitions.WaterAreas()
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

function command_definitions.PlayerForces()
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

function command_definitions.StopScanning()
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

function command_definitions.WAARClearData()
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

function command_definitions.UpdateMod(data)
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
