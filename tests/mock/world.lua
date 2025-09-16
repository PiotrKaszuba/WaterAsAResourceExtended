local mock = require("tests.mock.factorio_runtime")

-- same implementation as hot_utils.GridKey to avoid extra dependency
local function grid_key(pos)
    return pos.x * 10000000 + pos.y
end

local function remove_chart_tag(surface, tag)
    local tags = surface.chart_tags
    if not tags then return end
    for i = #tags, 1, -1 do
        if tags[i] == tag then
            table.remove(tags, i)
            break
        end
    end
end

local World = {}
World.__index = World

local function new_surface(name, default_tile)
    local surface = {
        name = name,
        index = nil,
        tiles = {},
        entities = {},
        chart_tags = {},
        next_unit = 1,
        default_tile = default_tile or "grass-1",
    }

    function surface.get_tile(pos)
        local key = grid_key(pos)
        local tile_name = surface.tiles[key] or surface.default_tile
        return {name = tile_name, position = {x = pos.x, y = pos.y}, valid = true}
    end

    function surface.set_tiles(arg1, arg2, arg3, arg4, arg5, arg6, arg7)
        local tiles_arg
        local correct_tiles_flag
        local remove_colliding_entities_flag
        local remove_colliding_decoratives_flag
        local raise_event_flag

        if arg1 == surface then
            if type(arg2) == "table" and arg2.tiles then
                tiles_arg = arg2.tiles
                correct_tiles_flag = arg2.correct_tiles
                remove_colliding_entities_flag = arg2.remove_colliding_entities
                remove_colliding_decoratives_flag = arg2.remove_colliding_decoratives
                raise_event_flag = arg2.raise_event
            else
                tiles_arg = arg2
                correct_tiles_flag = arg3
                remove_colliding_entities_flag = arg4
                remove_colliding_decoratives_flag = arg5
                raise_event_flag = arg6
            end
        elseif type(arg1) == "table" and arg1.tiles then
            tiles_arg = arg1.tiles
            correct_tiles_flag = arg1.correct_tiles
            remove_colliding_entities_flag = arg1.remove_colliding_entities
            remove_colliding_decoratives_flag = arg1.remove_colliding_decoratives
            raise_event_flag = arg1.raise_event
        else
            tiles_arg = arg1
            correct_tiles_flag = arg2
            remove_colliding_entities_flag = arg3
            remove_colliding_decoratives_flag = arg4
            raise_event_flag = arg5
        end

        tiles_arg = tiles_arg or {}

        -- correct_tiles_flag, remove_colliding_entities_flag, and remove_colliding_decoratives_flag
        -- are accepted for signature compatibility only and are not simulated by the mock world.
        local event_tiles = raise_event_flag and {} or nil
        for _, tile in ipairs(tiles_arg) do
            local position = tile.position or {x = 0, y = 0}
            local key = grid_key(position)
            surface.tiles[key] = tile.name
            if event_tiles then
                event_tiles[#event_tiles + 1] = {
                    name = tile.name,
                    position = {x = position.x, y = position.y},
                }
            end
        end

        if event_tiles then
            mock.raise_event(defines.events.script_raised_set_tiles, {
                surface_index = surface.index,
                tiles = event_tiles,
                tick = mock.tick,
            })
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
    local force = {name = "player", valid = true, index = 1}
    force.print = mock.make_printer("force", force.name)

    local function resolve_surface(surface_ref)
        if type(surface_ref) == "table" and surface_ref.name then
            return surface_ref
        end
        return surface_ref and game.surfaces[surface_ref] or nil
    end

    force.add_chart_tag = function(surface_ref, spec)
        local surface = resolve_surface(surface_ref)
        if not surface then
            error("surface not found for add_chart_tag: " .. tostring(surface_ref))
        end
        local position = spec.position or {x = 0, y = 0}
        local tag = {
            valid = true,
            force = force,
            surface = surface,
            position = {x = position.x, y = position.y},
            text = spec.text or "",
            icon = spec.icon,
        }
        surface.chart_tags[#surface.chart_tags + 1] = tag
        function tag.destroy()
            if not tag.valid then return end
            tag.valid = false
            remove_chart_tag(surface, tag)
        end
        return tag
    end

    force.find_chart_tags = function(surface_ref)
        local surface = resolve_surface(surface_ref)
        if not surface then return {} end
        local result = {}
        for _, tag in ipairs(surface.chart_tags) do
            if tag.valid and tag.force == force then
                result[#result + 1] = tag
            end
        end
        return result
    end

    game.forces[force.name] = force
    game.forces[force.index] = force

    local player = {
        index = 1,
        name = "player",
        valid = true,
    }
    player.print = mock.make_printer("player", player.name)
    player.force = force
    player._inventory_capacity = 1000
    player._inventory_count = 0
    player._inventory_contents = {}

    local function stack_count(stack)
        if type(stack) ~= "table" then return 0 end
        return stack.count or 1
    end

    local function clone_inventory_contents()
        local copy = {}
        for item, count in pairs(player._inventory_contents) do
            copy[item] = count
        end
        return copy
    end

    function player.clear_inventory()
        player._inventory_contents = {}
        player._inventory_count = 0
    end

    -- returns a copy of the inventory contents - cannot be reused after anything that could modify the inventory
    function player.get_inventory_contents()
        return clone_inventory_contents()
    end

    function player.get_item_count(name)
        return player._inventory_contents[name] or 0
    end

    function player._can_insert(stack, at_least_amount)
        if type(stack) ~= "table" or not stack.name then return false end
        local count = stack_count(stack)
        if count <= 0 then return true end
        return player._inventory_count + at_least_amount <= player._inventory_capacity
    end

    -- true if at least a part of the given items could be inserted into this inventory.
    function player.can_insert(stack)
        return player._can_insert(stack, 1)
    end

    -- returns the number of items that were actually inserted
    function player._insert(stack, ignore_capacity)
        if type(stack) ~= "table" or not stack.name then return 0 end
        local count = stack_count(stack)
        if count <= 0 then return 0 end
        local insertable = count
        if not ignore_capacity then
            local space = player._inventory_capacity - player._inventory_count
            if space <= 0 then return 0 end
            if insertable > space then insertable = space end
        end
        player._inventory_contents[stack.name] = (player._inventory_contents[stack.name] or 0) + insertable
        player._inventory_count = player._inventory_count + insertable
        return insertable
    end

    function player.insert(stack)
        return player._insert(stack)
    end

    -- returns the number of items that were actually removed
    function player._remove_item(name, count_to_remove)
        if type(name) ~= "string" or count_to_remove <= 0 then return 0 end
        local count = player._inventory_contents[name] or 0
        if count <= 0 then return 0 end
        if count_to_remove > count then count_to_remove = count end
        player._inventory_contents[name] = count - count_to_remove
        player._inventory_count = player._inventory_count - count_to_remove
        return count_to_remove
    end

    function player.remove_item(stack)
        if type(stack) == "string" then
            return player._remove_item(stack, 1)
        end
        local count = stack_count(stack)
        return player._remove_item(stack.name, count)
    end

    local function normalize_mining_results(results)
        if not results then return {} end
        if type(results) ~= "table" or results.name or results[1] == nil then
            results = {results}
        end
        local normalized = {}
        for _, entry in ipairs(results) do
            if type(entry) == "string" then
                normalized[#normalized + 1] = {name = entry, count = 1}
            elseif type(entry) == "table" then
                local name = entry.name or entry[1]
                if name then
                    local count = stack_count(entry)
                    if count <= 0 then count = 1 end
                    normalized[#normalized + 1] = {name = name, count = count}
                end
            end
        end
        return normalized
    end

    local function get_mining_results(entity)
        if not entity then return {} end
        local proto = entity.prototype or {}
        local results = entity.mine_results or entity.minable_results or proto.mine_results or proto.minable_results
        if results then
            return normalize_mining_results(results)
        end
        local single = entity.mine_result or entity.minable_result or proto.mine_result or proto.minable_result or entity.name
        return normalize_mining_results(single)
    end

    player.mine_entity = function(entity, force)
        -- force: Forces mining the entity even if the items can't fit in the player.
        if not (entity and entity.valid) then return false end

        local results = get_mining_results(entity)
        if not force then
            for _, stack in ipairs(results) do
                if stack.name and stack.count > 0 and not player._can_insert(stack, stack.count) then
                    return false
                end
            end
        end

        for _, stack in ipairs(results) do
            if stack.name and stack.count > 0 then
                player._insert(stack, force)
            end
        end

        mock.raise_event(defines.events.on_player_mined_entity, {
            entity = entity,
            player_index = player.index,
        })
        entity.destroy({raise_destroy=false})
        return true
    end

    game.players[1] = player
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
            tiles[#tiles+1] = {old_tile = {name = old_name}, position = pos} -- array[OldTileAndPosition]
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

function World:build_entity(spec, player_index, require_item_name)
    local surface = spec.surface
    local player = game.players[player_index or 1]
    if require_item_name then
        if player.get_item_count(require_item_name) < 1 then
            return nil
        end
        player.remove_item({name = require_item_name, count = 1})
    end

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
        last_user = game.players[player_index or 1],
    }
    surface.next_unit = surface.next_unit + 1
    function entity.destroy(opts)
        if not entity.valid then return end
        entity.valid = false
        surface.entities[entity.unit_number] = nil
        if opts and opts.raise_destroy then
            mock.raise_event(defines.events.script_raised_destroy, {entity = entity})
        end
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

