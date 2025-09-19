require("modules.utils")
require("modules.hot_utils")

split_families = {}

local function get_max_landfills_per_update()
    return settings.global["Split-Finalize-Max-Landfills-Per-Update"].value
end

function split_families.init_storage()
    if storage.SplitFamilyById == nil then storage.SplitFamilyById = {} end
    if storage.WbIdToFamilyId == nil then storage.WbIdToFamilyId = {} end
    if storage.NextFamilyId == nil then storage.NextFamilyId = 1 end
end

local function next_family_id()
    local id = storage.NextFamilyId
    storage.NextFamilyId = id + 1
    return id
end

-- family schema:
-- {
--   id,
--   name, -- optional string to apply to successor
--   initialArea, -- number used when merging families
--   parentCentroid, parentDiag,
--   isPotentialSplit, -- boolean
--   createdPeriodicTick,
--   successorId, -- current best successor
--   members = { [wbId]=true, ... },
--   finished = { [wbId]=true, ... },
-- }

function split_families.create_family(
    memberIds,
    parentId,
    surface,
    waterBodyName,
    parentArea,
    parentCentroid,
    parentDiag,
    isPotentialSplit,
    initialLandfills  -- array of positions
)
    split_families.init_storage()
    local id = next_family_id()
    local fam = {
        id = id,
        -- parentId -> true; parents are always invalid waterbodies that are still referenced by some waterTiles
        -- should be removed when that parentId is fully cleared and added for id reuse
        parentIds = {},
        surface = surface,
        waterBodyName = waterBodyName,
        parentArea = parentArea,
        parentCentroid = parentCentroid,
        parentDiag = parentDiag,
        isPotentialSplit = isPotentialSplit or false,
        createdPeriodicTick = storage.PeriodicTick,
        successorId = nil,
        members = {},
        finished = {},
        all_finished = false,
        -- tiles that were landfilled on the parent waterbody
        -- that will be searched for after the family is finalized
        -- there may be additional splits created from these landfills
        -- that weren't part of the initial family 
        -- and weren't detected during scanning of members
        -- we need to search for adjacent water tiles, check whether they belong to
        -- any of the members of the family, and if not - create new waterbody from them
        -- and add such waterbodies to the family
        -- can be done one at a time - and finalize will be called again
        -- since many could have accumulated we should do it in updateSplitFamilies
        landfills = {}, -- gridKey -> position
    }
    if parentId then
        fam.parentIds[parentId] = true
        storage.WbIdToFamilyId[parentId] = id
    end
    for _, wbId in ipairs(memberIds) do
        fam.members[wbId] = true
        storage.WbIdToFamilyId[wbId] = id
    end
    storage.SplitFamilyById[id] = fam
    
    if initialLandfills then
        for _, landfill_position in pairs(initialLandfills) do
            fam.landfills[hot_utils.GridKey(landfill_position)] = landfill_position
        end
    end
    return id
end

function split_families.get_family_by_wb(wbId)
    local famId = storage.WbIdToFamilyId[wbId]
    if famId == nil then return nil end
    return storage.SplitFamilyById[famId]
end

local function clear_family(fam)
    for wbId, _ in pairs(fam.members) do
        storage.WbIdToFamilyId[wbId] = nil
    end
    for parentId, _ in pairs(fam.parentIds) do
        storage.WbIdToFamilyId[parentId] = nil
    end
    storage.SplitFamilyById[fam.id] = nil
end

-- Basic score: area and centroid proximity
local function compute_score(fam, waterBody)
    local size = waterBody.waterAreaData.TotalArea
    local centroid = waterbodies.getCentroid(waterBody)
    if centroid == nil then return -math.huge end
    local pc = fam.parentCentroid
    local diag = fam.parentDiag
    local dist = math.sqrt((centroid.x - pc.x)^2 + (centroid.y - pc.y)^2)
    local centroid_score = 1 - math.min(1, dist / math.max(diag, 1))
    local size_score = size / fam.parentArea
    local w_size, w_centroid = fam.isPotentialSplit and 0.3 or 0.7, fam.isPotentialSplit and 0.7 or 0.3
    return w_size * size_score + w_centroid * centroid_score
end

local function update_successor(newId, fam)
    -- update waterBodyName silently
    if newId == nil then return end
    local newWb = storage.WaterBodies[newId]
    if newWb and newWb.valid then
        newWb.waterBodyName = fam.waterBodyName
        newWb.merge_priority = 1
        -- clear others' names
        for otherId, _ in pairs(fam.members) do
            if otherId ~= newId then
                local owb = storage.WaterBodies[otherId]
                if owb and owb.valid then
                    owb.waterBodyName = nil
                    owb.merge_priority = 0
                end
            end
        end
    end
end

local function recompute_successor(fam, is_final)
    local threshold = is_final and 0 or 0.10
    local bestId, bestScore = fam.successorId, -math.huge
    local currentScore = nil
    for wbId, _ in pairs(fam.members) do
        local wb = storage.WaterBodies[wbId]
        if wb and wb.valid then
            local score = compute_score(fam, wb)
            if score > bestScore then
                bestScore = score
                bestId = wbId
            end
            if wbId == fam.successorId then currentScore = score end
        end
    end
    local changed = bestId ~= fam.successorId
    if changed and fam.successorId ~= nil then
        -- apply threshold only if switching from an existing successor
        -- re-evaluate: require improvement over current successor's score
        if (currentScore ~= nil and bestScore < currentScore * (1 + threshold)) then
            return false, fam.successorId
        end
    end
    fam.successorId = bestId
    update_successor(bestId, fam)
    return changed, bestId
end

local function finalize_if_done(fam)
    for wbId, _ in pairs(fam.members) do
        if not fam.finished[wbId] then
            return false
        end
    end
    -- don't clear family yet - we need to search for landfills in the updateSplitFamilies
    fam.all_finished = true
    return true
end



function split_families.on_scan_finished(wbId)
    local fam = split_families.get_family_by_wb(wbId)
    if fam == nil then return end
    
    fam.finished[wbId] = true
    recompute_successor(fam)
    finalize_if_done(fam)
end

function split_families.on_removed(wbId, isParent)
    local fam = split_families.get_family_by_wb(wbId)
    if fam == nil then return end
    if not isParent and fam.parentIds[wbId] then return end
    if isParent then
        fam.parentIds[wbId] = nil
    else
        fam.members[wbId] = nil
        fam.finished[wbId] = nil
    end
    storage.WbIdToFamilyId[wbId] = nil
    finalize_if_done(fam)
end

function split_families.on_merged(parentOneId, parentTwoId, survivorId)
    local waterbody_id_to_family_id = storage.WbIdToFamilyId
    local family_by_id = storage.SplitFamilyById
    local familyOneId, familyTwoId = waterbody_id_to_family_id[parentOneId], waterbody_id_to_family_id[parentTwoId]
    
    if familyOneId == nil and familyTwoId == nil then return end
    if familyOneId ~= nil and familyTwoId ~= nil and familyOneId ~= familyTwoId then
        -- merge families: keep the one with larger parentArea
        local familyOne, familyTwo = family_by_id[familyOneId], family_by_id[familyTwoId]
        if familyOne and familyTwo then
            local keep, drop = familyOne, familyTwo
            if (drop.parentArea or 0) > (keep.parentArea or 0) then keep, drop = drop, keep end
            -- union members
            for waterBodyId, _ in pairs(drop.members) do
                keep.members[waterBodyId] = true
                waterbody_id_to_family_id[waterBodyId] = keep.id
            end
            for parentId, _ in pairs(drop.parentIds) do
                keep.parentIds[parentId] = true
                waterbody_id_to_family_id[parentId] = keep.id
            end
            if keep.waterBodyName == nil and drop.waterBodyName then
                keep.waterBodyName = drop.waterBodyName
            end
            family_by_id[drop.id] = nil
        end
    end
    -- normalize mapping to survivor
    local familyId = waterbody_id_to_family_id[parentOneId] or waterbody_id_to_family_id[parentTwoId]
    if familyId then
        local family = family_by_id[familyId]
        if family then
            family.members[parentOneId] = nil
            family.members[parentTwoId] = nil
            family.members[survivorId] = true
            waterbody_id_to_family_id[parentOneId] = nil
            waterbody_id_to_family_id[parentTwoId] = nil
            waterbody_id_to_family_id[survivorId] = familyId
            recompute_successor(family)
        end
    end
end

function split_families.attempt_assign_landfill(waterBodyId, position, gridKey)
    local fam = split_families.get_family_by_wb(waterBodyId)
    if fam == nil then return end
    if fam.parentIds[waterBodyId] then
        fam.landfills[gridKey] = position
    end
end

local function seed_from_landfills(fam, max_landfills, updateBudget)
    local budget_per_landfill = 1
    local budget = updateBudget.budget
    local max_landfills = math.min(max_landfills, budget / budget_per_landfill)
    local surface = fam.surface
    local landfills_done = 0
    local landfills_to_remove = {}

    for gridKey, landfill_position in pairs(fam.landfills) do
        if landfills_done >= max_landfills then break end
        landfills_done = landfills_done + 1
        -- if a landfill is neighboring to a water tile that belongs to one of the parents
        local adjacent_waterbody_parent_tiles, _, _ = waterbody_scan.getAdjacentWaterAndLandTiles(landfill_position, surface, fam.parentIds)
        if #adjacent_waterbody_parent_tiles > 0 then
            for _, adjacent_waterbody_parent_tile in pairs(adjacent_waterbody_parent_tiles) do
                -- take first one and seed new waterbody from it
                local new_water_body, new_water_body_id = waterbodies.createNewWaterBody(surface)
                if new_water_body and new_water_body.valid then
                    fam.members[new_water_body_id] = true
                    storage.WbIdToFamilyId[new_water_body_id] = fam.id
                    fam.all_finished = false  -- reset to false since we have new member
                    new_water_body_id = waterbody_scan.beginScanWaterArea(new_water_body_id, adjacent_waterbody_parent_tile, 1)

                    if new_water_body_id then
                        local scan_amount = waterbody_scan.getInitialScanAmount()
                        waterbody_scan.continueScanWaterArea(new_water_body_id, scan_amount, updateBudget)
                        budget = budget - scan_amount
                    end
                    break -- just first one is enough
                end
            end
        else
            -- if this landfill doesn't produce new seeds - remove it
            landfills_to_remove[gridKey] = true
        end
    end

    for gridKey, _ in pairs(landfills_to_remove) do
        fam.landfills[gridKey] = nil
    end

    budget = budget - landfills_done * budget_per_landfill
    updateBudget.budget = budget

    return landfills_done
end

function split_families.updateSplitFamilies(updateBudget, periodic_tick)
    split_families.init_storage()
    local max_landfills_per_update = get_max_landfills_per_update()
    for id, fam in pairs(storage.SplitFamilyById) do
        if fam.all_finished then
            local is_landfill_empty = next(fam.landfills) == nil
            local is_parent_cleared = next(fam.parentIds) == nil
            if is_landfill_empty or is_parent_cleared then
                recompute_successor(fam, true)  -- final recompute
                clear_family(fam)
            else
                seed_from_landfills(fam, max_landfills_per_update, updateBudget)
            end
        end
        if updateBudget then updateBudget.budget = updateBudget.budget - 1 end
    end
end

