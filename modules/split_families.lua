require("modules.utils")

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
--   hitCap, -- boolean
--   createdPeriodicTick,
--   successorId, -- current best successor
--   members = { [wbId]=true, ... },
--   finished = { [wbId]=true, ... },
-- }

function split_families.create_family(memberIds, name, parentArea, parentCentroid, parentDiag, hitCap)
    split_families.init_storage()
    local id = next_family_id()
    local fam = {
        id = id,
        name = name,
        parentArea = parentArea,
        parentCentroid = parentCentroid,
        parentDiag = parentDiag,
        hitCap = hitCap or false,
        createdPeriodicTick = storage.PeriodicTick,
        successorId = nil,
        members = {},
        finished = {},
    }
    for _, wbId in ipairs(memberIds) do
        fam.members[wbId] = true
        storage.WbIdToFamilyId[wbId] = id
    end
    storage.SplitFamilyById[id] = fam
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
    local w_size, w_centroid = fam.hitCap and 0.3 or 0.7, fam.hitCap and 0.7 or 0.3
    return w_size * size_score + w_centroid * centroid_score
end

local function update_successor(newId, fam)
    -- name silently
    if newId == nil then return end
    local newWb = storage.WaterBodies[newId]
    if newWb and newWb.valid then
        newWb.waterBodyName = fam.name
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
    clear_family(fam)
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
    fam.members[wbId] = nil
    fam.finished[wbId] = nil
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
            if (drop.parentArea or 0) > (keep.parentArea or 0) and drop.name then
                keep.name = drop.name
                keep.parentArea = drop.parentArea
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

function split_families.updateSplitFamilies(updateBudget, periodic_tick)
    split_families.init_storage()
    local max_landfills_per_update = get_max_landfills_per_update()
    for id, fam in pairs(storage.SplitFamilyById) do
        local periodic_ticks_elapsed = periodic_tick - (fam.createdPeriodicTick or periodic_tick)
        local seconds_elapsed = utils.periodic_ticks_to_seconds(periodic_ticks_elapsed)
        if timeout_seconds > 0 and seconds_elapsed >= timeout_seconds then
            -- timeout: recompute best once and clear family
            recompute_successor(fam)
            clear_family(fam)
        end
        if updateBudget then updateBudget.budget = updateBudget.budget - 1 end
    end
end

