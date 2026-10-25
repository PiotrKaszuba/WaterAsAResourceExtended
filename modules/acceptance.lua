-- Loaded only with the acceptance companion installed. No update-loop hooks,
-- reserve setters or direct access to mutable production tables are exposed.
local M = {}

function M.snapshot()
    local result = { bodies = {}, pumps = {}, queued = storage.TileEventQueue.size,
        pending = 0, tick = game.tick }
    for _, positions in pairs(storage.PendingTileChanges or {}) do
        for _, count in pairs(positions) do result.pending = result.pending + count end
    end
    for id, body in pairs(storage.ValidWaterBodies) do
        local state, area = body.waterBodyStateData, body.waterAreaData
        result.bodies[#result.bodies + 1] = {
            id = id, surface = body.surface.name, finished = body.searchData.finished,
            capacity = area.AmountWtr, area = area.TotalArea, regen = area.RegenAmount,
            remaining = waterbodies.calculateRemainingWater(body),
            uncollected = state.TempUsedWater, depleted = state.Depleted,
            dried = state.DriedTiles, to_dry = state.ToDryTiles, pumps = #state.Pumps,
        }
    end
    table.sort(result.bodies, function(a, b) return a.id < b.id end)
    for id, pump in pairs(storage.TrackedEntities) do
        result.pumps[tostring(id)] = { body = pump.waterBodyId,
            valid = pump.entity.valid, disabled = pump.disabled }
    end
    return result
end

function M.set_setting(name, value)
    -- Engine settings API enforces value types/ranges and dispatches the actual
    -- setting-change event. The caller cannot set another mod's settings.
    assert(settings.global[name], "Unknown Water runtime setting: " .. name)
    settings.global[name] = { value = value }
end

remote.add_interface("water_acceptance", {
    snapshot = M.snapshot,
    set_setting = M.set_setting,
})
return M
