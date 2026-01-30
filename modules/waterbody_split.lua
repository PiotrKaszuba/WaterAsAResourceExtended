require("modules.waterbodies")
require("modules.waterbody_scan")
require("modules.entities")
require("modules.utils")
require("modules.hot_utils")
require("modules.split_families")

waterbody_split = {}


function waterbody_split.getWaterBodyLimitedBoundingBox(shape_data, center_position, side_length)
	local minX = shape_data.MinX
	local minY = shape_data.MinY
	local maxX = shape_data.MaxX
	local maxY = shape_data.MaxY

	-- local desired_rect_area = side_length * side_length
	local max_rect_area = (maxX - minX) * (maxY - minY)

	local bbox = {
		left_top = {
			x = math.max(minX, center_position.x - side_length / 2),
			y = math.max(minY, center_position.y - side_length / 2),
		},
		right_bottom = {
			x = math.min(maxX, center_position.x + side_length / 2),
			y = math.min(maxY, center_position.y + side_length / 2),
		},
	}

	local rect_area = (bbox.right_bottom.x - bbox.left_top.x) * (bbox.right_bottom.y - bbox.left_top.y)
	local rect_area_ratio = rect_area / max_rect_area
	return bbox, rect_area_ratio
end

function waterbody_split.getWaterBodyConnectedTiles(waterBody, start_tile_pos, otherTiles_positions, surface,
													center_position, updateBudget, nth_call)
	-- Ensure initial bbox is large enough to include start_tile_pos when centered on center_position
	local dx = math.abs(start_tile_pos.x - center_position.x)
	local dy = math.abs(start_tile_pos.y - center_position.y)
	local min_side_for_start = 2 * math.max(dx, dy) + 2  -- +2 for margin
	local current_check_size = math.max(4, min_side_for_start)
	local rect_area_ratio = 0.0
	local start_tile_gridKey = hot_utils.GridKey(start_tile_pos)
	local connected_tiles = {}
	connected_tiles[#connected_tiles + 1] = start_tile_pos
	local missing_tiles = {} -- indicator table, gridKey -> true
	for _, tile_pos in pairs(otherTiles_positions) do
		missing_tiles[hot_utils.GridKey(tile_pos)] = true
	end
	missing_tiles[start_tile_gridKey] = nil
	local found_all_tiles = false -- if true all the missing/remaining tiles are connected
	local bbox = nil
	local hit_cap = false      -- whether we cannot tell if there is a split - because we hit the max side limit without checking the full bounding box
	local last_all_connected_tiles = nil
	local max_side = settings.global["Split-Max-BBox-Side"].value ---@cast max_side int
	while true do
		if updateBudget then
			updateBudget.budget = updateBudget.budget - (current_check_size * current_check_size) / 16
		end
		local limited_side = math.min(current_check_size, max_side)
		bbox, rect_area_ratio = waterbody_split.getWaterBodyLimitedBoundingBox(waterBody.waterBodyShapeData,
			center_position, limited_side)
		local all_connected_tiles = surface.get_connected_tiles(start_tile_pos,
			utils.IndicatorTableToArray(utils.WaterAndDryTiles), true, bbox)
		last_all_connected_tiles = all_connected_tiles
		for _, tile_pos in pairs(all_connected_tiles) do
			local tile_pos_gridKey = hot_utils.GridKey(tile_pos)
			if missing_tiles[tile_pos_gridKey] then
				connected_tiles[#connected_tiles + 1] = tile_pos
				missing_tiles[tile_pos_gridKey] = nil
			end
		end
		if next(missing_tiles) == nil then
			found_all_tiles = true
			break
		end
		if current_check_size >= max_side then
			hit_cap = rect_area_ratio < 1.0
			break
		end
		current_check_size = current_check_size * 2
	end

	if found_all_tiles and nth_call == 1 then
		-- no need to compute component stats - because there is no split
		return connected_tiles, missing_tiles, nil, nil, hit_cap
	else
		-- compute component stats from last_all_connected_tiles
		local comp_count, comp_sum_x, comp_sum_y = 0, 0, 0
		if last_all_connected_tiles then
			for _, pos in pairs(last_all_connected_tiles) do
				comp_count = comp_count + 1
				comp_sum_x = comp_sum_x + pos.x
				comp_sum_y = comp_sum_y + pos.y
			end
		end
		local comp_centroid = { x = 0, y = 0 }
		if comp_count > 0 then
			comp_centroid.x = comp_sum_x / comp_count
			comp_centroid.y = comp_sum_y / comp_count
		end
		return connected_tiles, missing_tiles, comp_count, comp_centroid, hit_cap
	end
end

function waterbody_split.checkIfAllTilesAreUsedAndUnique(all_tiles_positions, connected_tiles_sets_gridKeys)
	local temp_all_tiles_set = {}
	local temp_gridKey = nil
	for _, tile_pos in pairs(all_tiles_positions) do
		temp_gridKey = hot_utils.GridKey(tile_pos)
		temp_all_tiles_set[temp_gridKey] = true
	end
	for _, connected_tiles_set_gridKeys in pairs(connected_tiles_sets_gridKeys) do
		for _, position in ipairs(connected_tiles_set_gridKeys) do
			local grid_key = hot_utils.GridKey(position)
			if not temp_all_tiles_set[grid_key] then
				return "duplicate"
			end
			temp_all_tiles_set[grid_key] = nil
		end
	end
	return next(temp_all_tiles_set) == nil and "ok" or "not_all_used"
end

function waterbody_split.signalWaterBodySplitToPlayer(waterBody, force, data)
	local num_new_water_bodies = data.num_new_water_bodies
	local is_potential_split = data.is_potential_split
	local potential_split_str = is_potential_split and " potentially" or ""
	return string.format("%s%s split into %s waterbodies.", waterbodies.getFullNameForWaterBody(waterBody),
		potential_split_str, num_new_water_bodies)
end

function waterbody_split.checkIfWaterBodyGotSplit(waterBodyId, split_position, surface, updateBudget)
	-- assume split_position is left-top corner already

	-- water body got split if there is no path between any pair of boundary water tiles (around the landfilled tiles area)
	-- landfilled tiles area is a non-water (nor dry) tiles area that still belongs to the water body (according to storage.WaterTiles/getWaterTile)
	-- check all adjacent water tiles around the landfilled tiles area
	-- up to the search/expand depth of

	local max_adjacent_depth = settings.global["Split-Max-Adjacent-Landfill-Depth-Check"]
	.value ---@cast max_adjacent_depth int

	-- border land tiles should present if max_adjacent_depth is not enough
	-- in that case we need to trigger potential split and add them to newly created split_family
	local adjacent_waterbody_tiles, _, adjacent_border_land_tiles = waterbody_scan.getAdjacentWaterAndLandTiles(
	split_position, surface, waterBodyId, max_adjacent_depth)

	-- we need to check if there is a path between any of the adjacent water tiles
	-- we can use get_connected_tiles with increasing area (BoundingBox)
	local waterBody = waterbodies.getWaterBody(waterBodyId)
	if not waterBody or not waterBody.valid then
		return
	end

	local connected_tile_sets = {} -- table of tables, each table is a set of connected tiles (seeds)
	local seeds_stats = {}      -- { {seed=pos, count=int, centroid={x,y}, hit_cap=bool} }
	local missing_tiles_positions = {}
	local new_missing_tiles_positions = nil
	for _, tile_pos in pairs(adjacent_waterbody_tiles) do
		missing_tiles_positions[#missing_tiles_positions + 1] = tile_pos
	end
	local nth_call = 1
	local any_hit_cap = false
	while #missing_tiles_positions > 0 do
		if updateBudget then
			updateBudget.budget = updateBudget.budget - 1
		end
		local start_tile_pos = table.remove(missing_tiles_positions)
		local connected_tiles, missing_tiles, comp_count, comp_centroid, hit_cap = waterbody_split
		.getWaterBodyConnectedTiles(waterBody, start_tile_pos, missing_tiles_positions, surface, split_position,
			updateBudget, nth_call)
		connected_tile_sets[#connected_tile_sets + 1] = connected_tiles
		seeds_stats[#seeds_stats + 1] = { seed = start_tile_pos, count = comp_count, centroid = comp_centroid, hit_cap =
		hit_cap, chosen = false }
		if hit_cap then any_hit_cap = true end
		new_missing_tiles_positions = {}
		for _, tile_pos in pairs(missing_tiles_positions) do
			local gridKey = hot_utils.GridKey(tile_pos)
			if missing_tiles[gridKey] then
				new_missing_tiles_positions[#new_missing_tiles_positions + 1] = tile_pos
			end
		end
		missing_tiles_positions = new_missing_tiles_positions
		nth_call = nth_call + 1
	end

	local check_result = waterbody_split.checkIfAllTilesAreUsedAndUnique(adjacent_waterbody_tiles, connected_tile_sets)
	if check_result ~= "ok" then
		utils.profile_hits("waterbody_split.checkIfWaterBodyGotSplit",
			string.format("Water body got split, validation of neighboring water tiles failed: %s", check_result))
		game.print(string.format("WARNING: Water body got split, validation of neighboring water tiles failed: %s",
			check_result))
	end

	-- now we have separated water bodies represented by initial tile_sets in connected_tile_sets
	-- each tile_set represent a separate water body with a few tiles
	-- we need to actually split the water bodies now

	-- or if we have adjacent_border_land_tiles - there is also a potential split

	-- select one tile from each connected_tile_set and create new water bodies from them
	-- as well as from all the water pumps that are present in the water body
	-- handle the drained water so that none can exploit it for free water

	local got_split = #connected_tile_sets > 1 or #adjacent_border_land_tiles > 0
	local is_potential_split = any_hit_cap or #adjacent_border_land_tiles > 0

	if got_split then
		waterbodies.signalPerForce(waterBody, waterbody_split.signalWaterBodySplitToPlayer,
			{ num_new_water_bodies = #connected_tile_sets, is_potential_split = is_potential_split })
		local new_water_body_ids_and_positions = {}
		-- choose primary successor among seeds
		local parent_centroid = waterbodies.getCentroid(waterBody)
		local parent_centroid_x, parent_centroid_y = nil, nil
		if parent_centroid == nil then
			utils.profile_hits("waterbody_split.checkIfWaterBodyGotSplit", "Parent centroid is nil")
			game.print("Error: Parent centroid is nil in checkIfWaterBodyGotSplit")
		else
			parent_centroid_x, parent_centroid_y = parent_centroid.x, parent_centroid.y
		end
		local parent_diag = math.max(waterBody.waterBodyShapeData.Hyp or 1, 1)
		local best_idx, best_score = 1, -math.huge
		local parent_area = waterBody.waterAreaData.TotalArea
		local count, centroid = nil, nil
		local size_score, dx, dy, centroid_score, w_size, w_centroid, score = nil, nil, nil, nil, nil, nil, nil
		for i, seed_stats in ipairs(seeds_stats) do
			count = seed_stats.count
			centroid = seed_stats.centroid

			if count and centroid then
				size_score = math.sqrt(count / parent_area) -- to match the scaling of centroid_score
				if parent_centroid ~= nil then
					dx, dy = centroid.x - parent_centroid_x, centroid.y - parent_centroid_y
					centroid_score = 1 - math.min(1, math.sqrt(dx * dx + dy * dy) / parent_diag)
				else
					centroid_score = 0
				end
				w_size, w_centroid = is_potential_split and 0.3 or 0.7, is_potential_split and 0.7 or 0.3
				score = w_size * size_score + w_centroid * centroid_score
				if score > best_score then
					best_score = score
					best_idx = i
				end
			end
		end
		seeds_stats[best_idx].chosen = true
		local parent_data = { id = waterBody.waterBodyId, name = waterBody.waterBodyName }

		local pumps = waterBody.waterBodyStateData.Pumps
		waterBody.waterBodyStateData.Pumps = {}
		waterbodies.removeWaterBody(waterBody)
		local first_tile_pos = nil
		local new_water_body_id = nil
		local new_water_body = nil
		local created_at_positions = {} -- gridKey -> waterBodyId
		local tmp_gridKey = nil
		for i, tile_set in ipairs(connected_tile_sets) do
			first_tile_pos = tile_set[1]
			new_water_body, new_water_body_id = waterbodies.createNewWaterBody(surface)
			new_water_body_ids_and_positions[#new_water_body_ids_and_positions + 1] = { waterBodyId = new_water_body_id, position =
			first_tile_pos, waterBody = new_water_body, seed_stats = seeds_stats[i] }

			tmp_gridKey = hot_utils.GridKey(first_tile_pos)
			created_at_positions[tmp_gridKey] = new_water_body_id
		end

		for _, pump_data in ipairs(pumps) do
			if pump_data.entity.valid and pump_data.type == "pump" and not pump_data.disabled then
				local pump_input_position = pump_data.input_position
				-- check if this is still water tile
				if entities.validatePumpPlacement(pump_data) then
					-- fix position to left-top corner - because it is center based - from entity position
					local pump_input_top_left_corner = utils.fixPositionToLeftTopCorner(pump_input_position)

					-- checking whether we already created a water body at this position from any seed position
					tmp_gridKey = hot_utils.GridKey(pump_input_top_left_corner)
					new_water_body_id = created_at_positions[tmp_gridKey]
					if new_water_body_id == nil then
					-- if not - create a new water body at this position
					new_water_body, new_water_body_id = waterbodies.createNewWaterBody(surface)
					new_water_body_ids_and_positions[#new_water_body_ids_and_positions + 1] = { waterBodyId =
					new_water_body_id, position = pump_input_top_left_corner, waterBody = new_water_body, seed_stats = nil }
					created_at_positions[tmp_gridKey] = new_water_body_id
				end

					-- waterBody got removed - so we just need to add it to the new water body
					entities.addPumpToWaterBody(new_water_body_id, pump_data)
				else
					entities.disablePump(pump_data)
				end
			end
		end

		local num_new_water_bodies = #new_water_body_ids_and_positions
		local waterbody_ids_and_positions_still_valid = {}
		local memberIds = {}
		for _, new_water_body_id_and_position in ipairs(new_water_body_ids_and_positions) do
			local waterBody = new_water_body_id_and_position.waterBody
			new_water_body_id = new_water_body_id_and_position.waterBodyId
			if waterBody and waterBody.valid then
				local seed_stats = new_water_body_id_and_position.seed_stats
				if seed_stats and seed_stats.chosen then
					waterBody.waterBodyName = parent_data.name
					waterBody.merge_priority = 1
				end
			waterbody_ids_and_positions_still_valid[#waterbody_ids_and_positions_still_valid + 1] =
			new_water_body_id_and_position
			waterBody.searchData.ScanWeight = 1.0 / num_new_water_bodies
			memberIds[#memberIds + 1] = new_water_body_id
			end
		end

		-- create family if enabled (check is in the call)
		split_families.create_family(memberIds, parent_data.id, surface, parent_data.name, parent_area, parent_centroid,
			parent_diag, is_potential_split, adjacent_border_land_tiles)

		-- this one scans only 1 tile and makes sure each waterbody 'claims' its own starting tile
		local new_waterbodies_still_valid = {}
		local position = nil
		for _, waterbody_id_and_position in ipairs(waterbody_ids_and_positions_still_valid) do
			position = waterbody_id_and_position.position
			new_water_body_id = waterbody_id_and_position.waterBodyId
			new_water_body_id = waterbody_scan.beginScanWaterArea(new_water_body_id, position, 1)
			if new_water_body_id then
				new_waterbodies_still_valid[#new_waterbodies_still_valid + 1] = new_water_body_id
			end
		end

		-- further scan with merges possible
		if #new_waterbodies_still_valid > 0 then
			local scan_amount = math.ceil(waterbody_scan.getInitialScanAmount() / #new_waterbodies_still_valid)
			for _, new_water_body_id in ipairs(new_waterbodies_still_valid) do
				waterbody_scan.continueScanWaterArea(new_water_body_id, scan_amount, updateBudget)
			end
		end

		if updateBudget then
			updateBudget.budget = updateBudget.budget - num_new_water_bodies
		end
	end
end
