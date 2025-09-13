local mock = require("tests.mock.factorio_runtime")

-- same implementation as hot_utils.GridKey to avoid extra dependency
local function grid_key(pos)
    return pos.x * 10000000 + pos.y
end

local World = {}
World.__index = World

local function new_surface(name, default_tile)
    local surface = {
        name = name,
        index = nil,
        tiles = {},
        entities = {},
        next_unit = 1,
        default_tile = default_tile or "grass-1",
    }

    function surface.get_tile(pos)
        local key = grid_key(pos)
        local tile_name = surface.tiles[key] or surface.default_tile
        return {name = tile_name, position = {x = pos.x, y = pos.y}, valid = true}
    end

    function surface.set_tiles(arg1, arg2)
        local tile_array = arg2 or arg1
        for _, t in ipairs(tile_array) do
            surface.tiles[grid_key(t.position)] = t.name
        end
    end

    function surface.is_chunk_generated(_)
        return true
    end

    function surface.request_to_generate_chunks(_) end

    return surface
end

function World.new()
    local self = setmetatable({next_surface_id = 1}, World)
    -- setup default force and player
    local force = {name = "player", valid = true}
    force.print = mock.make_printer("force", force.name)
    game.forces[force.name] = force
    game.players[1] = {
        index = 1,
        name = "player",
        print = mock.make_printer("player", "player"),
        mine_entity = function(_, entity) entity.valid = false; return true end,
    }
    self.force = force
    return self
end

function World:create_surface(name)
    local surface = new_surface(name)
    surface.index = self.next_surface_id
    self.next_surface_id = self.next_surface_id + 1
    game.surfaces[surface.index] = surface
    game.surfaces[name] = surface
    return surface
end

function World:set_water_rectangle(surface, rect)
    local tiles = {}
    for x = rect.x1, rect.x2 do
        for y = rect.y1, rect.y2 do
            tiles[#tiles + 1] = {name = "water", position = {x = x, y = y}}
        end
    end
    surface:set_tiles(tiles)
end

function World:build_entity(spec)
    local surface = spec.surface
    local entity = {
        name = spec.name,
        position = spec.position,
        direction = spec.direction or defines.direction.north,
        force = self.force,
        surface = surface,
        unit_number = surface.next_unit,
        valid = true,
        active = true,
        pumped_last_tick = 0,
        prototype = {type = spec.type or spec.name},
        last_user = game.players[1],
    }
    surface.next_unit = surface.next_unit + 1
    function entity.destroy()
        entity.valid = false
        surface.entities[entity.unit_number] = nil
    end
    entity.get_fluid_source_tile = function() return spec.input_position or spec.position end
    surface.entities[entity.unit_number] = entity
    mock.raise_event(defines.events.on_built_entity, {entity = entity})
    return entity
end

return {
    World = World,
}

