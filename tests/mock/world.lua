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
        local tile_array
        if type(arg1) == "table" and arg1[1] and arg1[1].position then
            tile_array = arg1
        else
            tile_array = arg2
        end
        for _, t in ipairs(tile_array) do
            surface.tiles[grid_key(t.position)] = t.name
        end
    end

    function surface.is_chunk_generated(_)
        return true
    end

    function surface.request_to_generate_chunks(_) end

    function surface.get_connected_tiles(start_pos, tiles, include_diagonal, bbox)
        local allowed = {}
        for _, name in pairs(tiles or {}) do
            allowed[name] = true
        end
        local start_name = surface.get_tile(start_pos).name
        if not allowed[start_name] then return {} end

        local result = {}
        local queue = {start_pos}
        local visited = {[grid_key(start_pos)] = true}
        local function inside_bbox(pos)
            if not bbox then return true end
            return pos.x >= bbox.left_top.x and pos.x < bbox.right_bottom.x and
                   pos.y >= bbox.left_top.y and pos.y < bbox.right_bottom.y
        end
        local dirs = {{1,0}, {-1,0}, {0,1}, {0,-1}}
        if include_diagonal then
            dirs[#dirs+1] = {1,1}
            dirs[#dirs+1] = {1,-1}
            dirs[#dirs+1] = {-1,1}
            dirs[#dirs+1] = {-1,-1}
        end
        local qi = 1
        while queue[qi] do
            local pos = queue[qi]
            qi = qi + 1
            result[#result+1] = {x = pos.x, y = pos.y}
            for _, d in ipairs(dirs) do
                local np = {x = pos.x + d[1], y = pos.y + d[2]}
                local key = grid_key(np)
                if not visited[key] and inside_bbox(np) and allowed[surface.get_tile(np).name] then
                    visited[key] = true
                    queue[#queue+1] = np
                end
            end
        end
        return result
    end

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

function World:waterfill(surface, position, variant)
    local name = "waterfill-placer"
    if variant == "deep" then name = "waterfill-placer-deep" end
    self:build_entity({
        name = name,
        position = position,
        surface = surface,
    })
end

function World:landfill_rectangle(surface, top_left, width, height)
    local tiles = {}
    for dx = 0, width - 1 do
        for dy = 0, height - 1 do
            local pos = {x = top_left.x + dx, y = top_left.y + dy}
            local old_name = surface.get_tile(pos).name
            tiles[#tiles+1] = {name = "grass-1", position = pos, old_tile = {name = old_name}}
        end
    end
    surface:set_tiles(tiles)
    mock.raise_event(defines.events.on_player_built_tile, {
        player_index = 1,
        surface_index = surface.index,
        tile = {name = "landfill"},
        tiles = tiles,
    })
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

function World:mine_entity(entity)
    if not entity.valid then return end
    mock.raise_event(defines.events.on_player_mined_entity, {entity = entity, player_index = 1})
    entity.destroy()
end

return {
    World = World,
}

