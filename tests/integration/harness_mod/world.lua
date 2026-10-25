local W = {}

function W.prepare(H)
    local surface = game.surfaces.nauvis
    surface.request_to_generate_chunks({ 0, 0 }, 3)
    surface.force_generate_chunk_requests()
    for _, entity in pairs(surface.find_entities_filtered({ area = { { -40, -40 }, { 90, 60 } } })) do
        entity.destroy({ raise_destroy = true })
    end
    local ground = {}
    for x = -40, 89 do
        for y = -40, 59 do ground[#ground + 1] = { name = "grass-1", position = { x, y } } end
    end
    surface.set_tiles(ground, false)
    H.setting("Waterbody-Regen-Rate", 0)
    H.setting("Alarm-Depletion-Level", "none")
    H.setting("Map-EnableMarkers", false)
    H.setting("Cleanup-Remove-Depleted-Orphaned", false)
    return surface
end

function W.rectangle(surface, x, y, width, height, name, announce)
    local edits = {}
    for dx = 0, width - 1 do
        for dy = 0, height - 1 do
            edits[#edits + 1] = { name = name, position = { x = x + dx, y = y + dy } }
        end
    end
    surface.set_tiles(edits, false, false, false, announce or false)
    return edits
end

function W.pump(H, surface, x, y, width, height, name)
    for px = x - 3, x + width + 2 do
        for py = y - 3, y + height + 2 do
            for _, direction in ipairs({ defines.direction.north, defines.direction.east,
                defines.direction.south, defines.direction.west }) do
                local spec = { name = name or "offshore-pump", position = { px + 0.5, py + 0.5 },
                    force = "player", direction = direction,
                    build_check_type = defines.build_check_type.manual }
                if surface.can_place_entity(spec) then
                    spec.build_check_type = nil
                    local pump = surface.create_entity(spec)
                    if pump then
                        local input = pump.get_fluid_source_tile()
                        local source = input and surface.get_tile(input)
                        if source and source.prototype.fluid and source.prototype.fluid.name == "water"
                            and not surface.get_tile(pump.position).prototype.fluid then
                            script.raise_script_built({ entity = pump })
                            H.check(pump.valid, "Native shoreline placement succeeds for " .. spec.name)
                            local connection = pump.fluidbox.get_pipe_connections(1)[1]
                            assert(surface.create_entity({ name = "pipe", position = connection.target_position,
                                force = "player" }), "Cannot create native output pipe")
                            return pump
                        end
                        pump.destroy()
                    end
                end
            end
        end
    end
    error("No legal shoreline placement for " .. tostring(name))
end

function W.power(surface, position)
    local source = surface.create_entity({ name = "water-test-power", position = position, force = "player" })
    assert(source, "Cannot create power fixture")
    source.energy = 100000000
    local pole_position = { position[1] - 4, position[2] }
    local pole = surface.find_entity("substation", pole_position) or
        surface.create_entity({ name = "substation", position = pole_position, force = "player" })
    assert(pole, "Cannot create substation fixture")
    return source
end

function W.snapshot(H)
    local snapshot = H.snapshot()
    local area, capacity, remaining, finished, depleted = 0, 0, 0, true, true
    for _, body in ipairs(snapshot.bodies) do
        area, capacity = area + body.area, capacity + body.capacity
        remaining = remaining + body.remaining - body.uncollected
        finished, depleted = finished and body.finished, depleted and body.depleted
    end
    return { raw = snapshot, area = area, capacity = capacity, remaining = remaining,
        finished = finished and #snapshot.bodies > 0, depleted = depleted and #snapshot.bodies > 0 }
end

function W.sample_pumps()
    for i, pump in ipairs(storage.pumps or {}) do
        -- Factorio retains the last sample while a pump is script-inactive.
        -- Only an active pump supplies a new extraction sample.
        if pump.active then storage.extracted[i] = storage.extracted[i] + pump.pumped_last_tick end
        if storage.drain then pump.fluidbox[1] = nil end
    end
end

function W.robots(surface)
    W.power(surface, { -12, -10 })
    local port = surface.create_entity({ name = "roboport", position = { -5, -10 }, force = "player" })
    assert(port, "Cannot create roboport fixture")
    port.insert({ name = "construction-robot", count = 10 })
    local chest = surface.create_entity({ name = "storage-chest", position = { -4, -5 }, force = "player" })
    chest.insert({ name = "landfill", count = 30 })
    chest.insert({ name = "concrete", count = 10 })
    return chest
end

function W.ghost(H, surface, name, position)
    H.check(surface.create_entity({ name = "tile-ghost", inner_name = name,
        position = position, force = "player" }) ~= nil, "Tile ghost created: " .. name)
end

function W.all_tiles(surface, edits, name)
    for _, edit in ipairs(edits) do
        if surface.get_tile(edit.position).name ~= name then return false end
    end
    return true
end

return W
