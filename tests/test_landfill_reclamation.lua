local t = require("tests.helpers.test_assert")
local env = require("tests.helpers.test_env")
local mock = require("tests.mock.factorio_runtime")
local reload_storage = require("tests.helpers.save_reload")

t.start()

local function near(actual, expected, label)
    t.ok(math.abs(actual - expected) < 1e-7, label .. " (" .. actual .. " vs " .. expected .. ")")
end

local function total_remaining()
    local total = 0
    for _, body in pairs(storage.ValidWaterBodies) do
        total = total + waterbodies.calculateRemainingWater(body)
    end
    return total
end

local function count_bodies()
    local count = 0
    for _ in pairs(storage.ValidWaterBodies) do count = count + 1 end
    return count
end

local function settle(ticks)
    env.run_ticks(ticks or 600)
end

local function setup(terrain, fraction, budget)
    local world, surface = env.create_world()
    settings.global["Waterbody-Regen-Rate"].value = 0
    settings.global["Map-EnableMarkers"].value = false
    settings.global["Alarms-Tile-Message"].value = false
    if budget then
        settings.global["Update-Budget-Per-Second"].value = budget
        storage.UpdateBudget = budget
    end
    surface.set_tiles(terrain)
    local start = terrain[1].position
    local pump = world:build_entity({
        name = "offshore-pump", type = "offshore-pump", surface = surface,
        position = { x = start.x, y = start.y - 1 }, input_position = start,
    })
    settle(600)
    for _, body in pairs(storage.ValidWaterBodies) do
        body.waterBodyStateData.WaterUsed = body.waterAreaData.AmountWtr * (fraction or 0)
        body.waterBodyStateData.TempAvailableWater = waterbodies.calculateRemainingWater(body)
    end
    return world, surface, pump
end

local function line(names, y)
    local result = {}
    for i, name in ipairs(names) do result[#result + 1] = { name = name, position = { x = i - 1, y = y or 0 } } end
    return result
end

local function assert_absent(position, surface, label)
    local key = hot_utils.GridKey(position)
    for _, body in pairs(storage.ValidWaterBodies) do
        local grids = body.gridsData
        t.ok(not hot_utils.isTileInGrid(grids.waterGridWithData, grids.lazyWaterGridWithData,
            grids.driedTilesGridWithData, grids.lazyDriedTilesGridWithData, key), label)
    end
end

-- Each original wet type must survive covering, save/reload and mining, while
-- neither the type's full capacity nor its already used share is recreated.
for _, wet_name in ipairs({ "water", "water-green", "water-shallow", "water-mud", "deepwater", "deepwater-green" }) do
    local terrain = line({ wet_name, wet_name, wet_name, wet_name, wet_name })
    local world, surface = setup(terrain, 0.4)
    local position = { x = 4, y = 0 }
    local before = total_remaining()
    world:build_tiles(surface, { position }, "landfill")
    settle()
    local after_cover = total_remaining()
    t.ok(after_cover < before, wet_name .. ": covering wet terrain discards its remaining water")
    assert_absent(position, surface, wet_name .. ": covered tile removed from wet/dry membership")
    t.eq(surface.get_hidden_tile(position), wet_name, wet_name .. ": engine retains original wet underlay")
    reload_storage()
    t.eq(world:mine_tiles(surface, { position }, wet_name == "water-green"), 1, wet_name .. ": successful player/robot mining")
    t.eq(surface.get_tile(position).name, utils.WetToDryTileMap[wet_name], wet_name .. ": removal immediately exposes empty typed ground")
    settle()
    near(total_remaining(), after_cover, wet_name .. ": mining adds exactly zero water")
    t.eq(count_bodies(), 1, wet_name .. ": reopening rejoins the existing lake")
end

-- Active dry membership uses the existing removal path, including DriedTiles;
-- after returning, normal regeneration must still restore the original color.
do
    local world, surface = setup(line({ "deepwater-green", "deepwater-green", "deepwater-green" }), 1)
    settle()
    local position = { x = 2, y = 0 }
    world:build_tiles(surface, { position }, "landfill")
    settle()
    assert_absent(position, surface, "active dried tile is removed from all dry membership")
    t.eq(surface.get_hidden_tile(position), utils.WetToDryTileMap["deepwater-green"], "active dry reclamation retains exact deep-green underlay")
    world:mine_tiles(surface, { position })
    settle()
    near(total_remaining(), 0, "active depleted lake gains no water from reclaimed dry tile removal")
    for _, body in pairs(storage.ValidWaterBodies) do
        waterbody_update.updateWaterLevel(body, 0, body.waterAreaData.AmountWtr)
        waterbody_update.handleDepletion(body)
    end
    settle()
    t.eq(surface.get_tile(position).name, "deepwater-green", "later regeneration restores the exact original deep-green tile")
end

-- Entire lakes can disappear from storage; later waterfill and a pump must not
-- resurrect old water from their revealed empty terrain.
do
    local terrain = line({ "water", "water-shallow", "water-mud", "deepwater", "water-green", "deepwater-green" })
    local world, surface = setup(terrain, 0.4)
    local positions = {}
    for _, tile in ipairs(terrain) do positions[#positions + 1] = tile.position end
    world:build_tiles(surface, positions, "landfill", true)
    settle()
    t.eq(count_bodies(), 0, "fully reclaimed lake may be deleted")
    near(total_remaining(), 0, "deleted lake has no remaining reserve")
    reload_storage()
    world:mine_tiles(surface, positions, true)
    settle()
    near(total_remaining(), 0, "mining an entire deleted lake adds no water even with no adjacent body")
    for _, tile in ipairs(terrain) do
        t.eq(surface.get_tile(tile.position).name, utils.WetToDryTileMap[tile.name], "deleted mixed lake stays dry: " .. tile.name)
    end
    world:waterfill(surface, { x = 6, y = 0 })
    world:build_entity({ name = "offshore-pump", type = "offshore-pump", surface = surface,
        position = { x = 6, y = -1 }, input_position = { x = 6, y = 0 } })
    settle()
    near(total_remaining(), 25, "later waterfill plus pump counts only the new waterfill's actual capacity")
end

-- A dry tile's exact original subtype must remain recoverable after its owning
-- body is orphaned. Cover legacy terrain with both historical metadata shapes.
for _, metadata_shape in ipairs({ "tile-data", "string" }) do
    local world, surface, pump = setup(line({ "water-shallow", "water-shallow", "water-shallow" }), 1)
    settle()
    local position = { x = 2, y = 0 }
    local key = hot_utils.GridKey(position)
    local body = storage.WaterBodies[1]
    local grids = body.gridsData
    local dry_data = utils.LazyTables.get(key, grids.driedTilesGridWithData, grids.lazyDriedTilesGridWithData)
    t.ok(dry_data ~= nil, metadata_shape .. ": full depletion creates tracked dry terrain")
    surface.set_tiles({ { name = "lake-shallow", position = position } })
    if dry_data then dry_data.name = "lake-shallow" end
    world:mine_entity(pump)
    settle()
    if metadata_shape == "string" then
        utils.LazyTables.remove(key, storage.OrphanedDryTilesOriginalName[surface.name],
            storage.lazyOrphanedDryTilesOriginalName[surface.name])
        storage.OrphanedDryTilesOriginalName[surface.name][key] = "water-shallow"
    end
    world:build_tiles(surface, { position }, "landfill")
    t.eq(surface.get_hidden_tile(position), utils.WetToDryTileMap["water-shallow"],
        metadata_shape .. ": legacy dry underlay is upgraded to its exact typed variant")
    settle()
    reload_storage()
    world:mine_tiles(surface, { position })
    settle()
    t.eq(surface.get_tile(position).name, utils.WetToDryTileMap["water-shallow"], metadata_shape .. ": orphan reclamation reveals the correct dry subtype")
    near(total_remaining(), 0, metadata_shape .. ": orphaned dry landfill removal does not create water")
end

local function neck_terrain()
    local terrain = {}
    for _, offset in ipairs({ 0, 6, 12 }) do
        for x = offset, offset + 3 do
            for y = 0, 2 do terrain[#terrain + 1] = { name = "water", position = { x = x, y = y } } end
        end
    end
    for _, x in ipairs({ 4, 5, 10, 11 }) do terrain[#terrain + 1] = { name = "water", position = { x = x, y = 1 } } end
    return terrain
end

-- Two necks produce sibling bodies and invalid parent references; reopening a
-- neck must conserve reserves while merging the right siblings and families.
do
    local world, surface = setup(neck_terrain(), 0.4)
    for _, x in ipairs({ 6, 12 }) do
        world:build_entity({ name = "offshore-pump", type = "offshore-pump", surface = surface,
            position = { x = x, y = -1 }, input_position = { x = x, y = 0 } })
    end
    local cuts = { { x = 4, y = 1 }, { x = 10, y = 1 } }
    world:build_tiles(surface, cuts, "landfill")
    settle(1200)
    t.eq(count_bodies(), 3, "two reclaimed necks create three sibling waterbodies")
    local after_cover = total_remaining()
    world:mine_tiles(surface, { cuts[1] })
    settle(1200)
    near(total_remaining(), after_cover, "reopening first neck conserves reserves across sibling merge")
    t.eq(count_bodies(), 2, "first neck merges only adjacent siblings")
    world:mine_tiles(surface, { cuts[2] }, true)
    settle(1200)
    near(total_remaining(), after_cover, "reopening second neck conserves reserves through final merge")
    t.eq(count_bodies(), 1, "both reopened necks reconnect the whole lake")
end

-- Compare an immediate mine/replacement branch against covering alone. This
-- catches stale queued owner refs, pending drying, family seeds and save aliases.
local function queued_brush(reopen)
    local terrain = {}
    for x = -4, 15 do
        for y = -3, 6 do terrain[#terrain + 1] = { name = "water", position = { x = x, y = y } } end
    end
    local world, surface = setup(terrain, 0.95, 200)
    local initial_remaining = total_remaining()
    for _, body in pairs(storage.ValidWaterBodies) do waterbody_update.handleDepletion(body) end
    local brush = { { x = 14, y = 0 }, { x = 15, y = 0 }, { x = 14, y = 1 }, { x = 15, y = 1 } }
    world:build_tiles(surface, brush, "landfill")
    local cover_only = { brush[1], brush[2] }
    if reopen then world:mine_tiles(surface, { brush[3], brush[4] }, true) end
    local queue_size = tiles.getTileEventQueue().size
    t.ok(queue_size >= 4, "terrain operations are pending before save/reload")
    reload_storage()
    t.eq(tiles.getTileEventQueue().size, queue_size, "queued terrain work survives storage graph/code reload")
    settle(2400)
    for _, position in ipairs(cover_only) do
        t.eq(surface.get_tile(position).name, "landfill", "pending visual work never resurrects covered terrain")
        assert_absent(position, surface, "covered coordinates remain absent from all body grids")
    end
    local remaining = total_remaining()
    t.ok(remaining <= initial_remaining + 1e-7, "landfill and queued topology work cannot create reserves")
    for _, body in pairs(storage.ValidWaterBodies) do
        waterbody_update.updateWaterLevel(body, 0, body.waterAreaData.AmountWtr)
        waterbody_update.handleDepletion(body)
    end
    settle(1200)
    for _, position in ipairs(cover_only) do
        t.eq(surface.get_tile(position).name, "landfill", "pending restoration cannot resurrect permanently covered terrain")
    end
    return remaining
end
local covered_remaining = queued_brush(false)
local reopened_remaining = queued_brush(true)
near(reopened_remaining, covered_remaining, "same-tick partial mining adds no water with a queued brush, tiny work budget and reload")

-- A later announced fresh waterfill at the same coordinate must
-- remain paid/full water rather than being overwritten by an older restore job.
do
    local world, surface = setup(line({ "water", "water", "water" }), 0.4)
    local position = { x = 2, y = 0 }
    world:build_tiles(surface, { position }, "landfill")
    settle()
    local covered_remaining = total_remaining()
    world:mine_tiles(surface, { position })
    local dry_name = surface.get_tile(position).name
    surface.set_tiles({ { name = "water-shallow", position = position } }, false, false, false, false)
    mock.raise_event(defines.events.script_raised_set_tiles, {
        surface_index = surface.index,
        tiles = { { name = "water-shallow", position = position, old_tile = { name = dry_name } } },
    })
    settle()
    near(total_remaining(), covered_remaining + 25, "newer announced waterfill wins over an older queued zero-water restoration")
end

-- Repetition must never refill a lake. Paving is an independent removable layer
-- and failed/partial removals must not cause duplicate topology events or charges.
do
    local world, surface = setup(line({ "water", "water", "water", "water", "water" }), 0.6)
    local position = { x = 4, y = 0 }
    for cycle = 1, 3 do
        world:build_tiles(surface, { position }, "landfill")
        settle()
        local covered = total_remaining()
        world:build_tiles(surface, { position }, "concrete")
        local before_pavement_removal = tiles.getTileEventQueue().size
        world:mine_tiles(surface, { position })
        t.eq(surface.get_tile(position).name, "landfill", "pavement removal reveals landfill, cycle " .. cycle)
        t.eq(tiles.getTileEventQueue().size, before_pavement_removal, "pavement removal does not queue water restoration")
        world:mine_tiles(surface, { position })
        settle()
        near(total_remaining(), covered, "repeated cover/uncover does not refill reserves, cycle " .. cycle)
        local old_size = tiles.getTileEventQueue().size
        t.eq(world:mine_tiles(surface, { position, { x = 20, y = 20 } }), 0, "nonmineable revealed ground and ordinary land cannot be mined")
        t.eq(tiles.getTileEventQueue().size, old_size, "failed mining raises no work")
    end
end

-- Robot tile proxies can emit mined-entity events even when an obstruction
-- prevents the tile removal. Only the later successful mined-tile event counts.
do
    local world, surface = setup(line({ "water", "water", "water" }), 0.4)
    local position = { x = 2, y = 0 }
    world:build_tiles(surface, { position }, "landfill")
    settle()
    local remaining = total_remaining()
    local queue_size = tiles.getTileEventQueue().size
    local proxy = world:add_existing_entity({
        name = "tile-ghost", type = "tile-ghost", position = position, surface = surface,
    })
    for _ = 1, 3 do
        mock.raise_event(defines.events.on_robot_mined_entity, { entity = proxy,
            robot = { valid = true, surface = surface, force = world.force } })
    end
    t.eq(tiles.getTileEventQueue().size, queue_size, "repeated blocked tile-proxy events do not queue terrain work")
    near(total_remaining(), remaining, "blocked tile-proxy events do not change water accounting")
    t.eq(surface.get_tile(position).name, "landfill", "failed tile removal leaves actual terrain covered")
    world:mine_tiles(surface, { position }, true)
    t.eq(tiles.getTileEventQueue().size, queue_size + 1, "one successful robot mined-tile event queues exactly one restoration")
    settle()
    near(total_remaining(), remaining, "successful removal following blocked attempts still adds zero water")
end

-- Surface gating must also apply to mined terrain, without replacing vanilla
-- water on surfaces the mod has opted out of managing.
do
    local world, nauvis = setup(line({ "water", "water" }), 0)
    local other = world:create_surface("gleba")
    local position = { x = 0, y = 0 }
    other.set_tiles({ { name = "water", position = position } })
    world:build_tiles(other, { position }, "landfill")
    local queue_size = tiles.getTileEventQueue().size
    world:mine_tiles(other, { position }, true)
    t.eq(other.get_tile(position).name, "water", "ignored-surface landfill removal retains vanilla wet terrain")
    t.eq(tiles.getTileEventQueue().size, queue_size, "ignored-surface removal does not queue accounting work")
end

t.finish("Landfill reclamation, mining, topology and queued-work regressions")
assert(not t.has_failures(), "landfill reclamation regressions failed")
