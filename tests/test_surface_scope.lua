local env = require("tests.helpers.test_env")
local mock = require("tests.mock.factorio_runtime")
local t = require("tests.helpers.test_assert")
t.start()
local world, nauvis = env.create_world()
local other = world:create_surface("another-water-world")
local function place(surface, x)
    world:set_water_rectangle(surface, { x1 = x, y1 = 0, x2 = x + 2, y2 = 0 })
    return world:build_entity({ name = "offshore-pump", type = "offshore-pump", surface = surface,
        position = { x = x, y = -1 }, input_position = { x = x, y = 0 } })
end
local ignored = place(other, 0)
t.eq(entities.getTrackedEntity(ignored.unit_number), nil, "new other-surface pump is unmanaged by default")
t.eq(ignored.active, true, "new other-surface pump stays active")
mock.raise_event(defines.events.script_raised_set_tiles, {
    surface_index = other.index,
    tiles = { { name = "water", position = { x = 5, y = 0 }, old_tile = { name = "landfill" } } },
})
t.eq(tiles.getTileEventQueue().size, 0, "other-surface tile accounting is gated centrally")

settings.startup["Waterbody-Nauvis-Only"].value = false
control.VersionChanged({ mod_changes = {} })
local tracked = entities.getTrackedEntity(ignored.unit_number)
t.ok(tracked ~= nil, "disabling restriction discovers existing other-surface pump")
local body_id = tracked.waterBodyId
env.run_ticks(120)
ignored.active = false
tracked.disabled = true
mock.raise_event(defines.events.script_raised_set_tiles, {
    surface_index = other.index,
    tiles = { { name = "water", position = { x = 5, y = 0 }, old_tile = { name = "landfill" } } },
})
t.eq(tiles.getTileEventQueue().size, 1, "unrestricted surface accepts tile events")
settings.startup["Waterbody-Nauvis-Only"].value = true
control.VersionChanged({ mod_changes = {} })
t.eq(entities.getTrackedEntity(ignored.unit_number), nil, "scope change detaches previously tracked pump")
t.eq(ignored.active, true, "scope change releases this mod's previous disable")
t.eq(storage.ValidWaterBodies[body_id], nil, "excluded waterbody leaves update set")
t.eq(tiles.getTileEventQueue().size, 0, "excluded queued tile work discarded")
ignored.active = false
env.run_ticks(120)
t.eq(ignored.active, false, "ignored pump is not repeatedly activated by later updates")

local normal = place(nauvis, 10)
t.ok(entities.getTrackedEntity(normal.unit_number) ~= nil, "Nauvis remains managed")
settings.startup["Waterbody-Nauvis-Only"].value = false
other.set_tiles({ { name = "lava", position = { x = 20, y = 0 } } })
local lava = world:build_entity({ name = "lava-pump", type = "offshore-pump", source_fluid = "lava", surface = other,
    position = { x = 20, y = -1 }, input_position = { x = 20, y = 0 } })
t.eq(entities.getTrackedEntity(lava.unit_number), nil, "lifting surface gate does not enable finite non-water fluids")
t.eq(lava.active, true, "non-water extractor remains untouched")
t.finish("Nauvis scope admission and reconciliation")
