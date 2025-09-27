local test_env = require("tests.helpers.test_env")
local t = require("tests.helpers.test_assert")
local run_mock_test = require("tests.helpers.mock_test")

local function enqueue(queue, position)
    queue[#queue + 1] = { x = position.x, y = position.y }
end

local function chunk_position_from_tile(tile_position)
    return { x = math.floor(tile_position.x / 32), y = math.floor(tile_position.y / 32) }
end

local function run_test()
    t.start()

    local _, surface = test_env.create_world({ simulate_chunks = true, chunk_generation_per_tick = 0.5 })

    require("modules.utils")
    require("modules.waterbody_scan")

    local waterbody_scan = _G.waterbody_scan
    local tileInvalidOrOutOfMap = waterbody_scan.tileInvalidOrOutOfMap

    local origin_tile = { x = 0.5, y = 0.5 }
    local far_tile = { x = 256, y = 0 }
    local first_chunk_tile = { x = 64.5, y = -0.5 }
    local second_chunk_tile = { x = 128.5, y = 0.5 }
    local reset_test_tile = { x = -64.5, y = -32.5 }
    local radius_center_tile = { x = 192, y = 0 }
    local radius_neighbor_tile = { x = 224, y = 32 }

    local chunk_origin = chunk_position_from_tile(origin_tile)
    local chunk_far = chunk_position_from_tile(far_tile)
    local chunk_first = chunk_position_from_tile(first_chunk_tile)
    local chunk_second = chunk_position_from_tile(second_chunk_tile)
    local chunk_reset = chunk_position_from_tile(reset_test_tile)
    local chunk_radius_center = chunk_position_from_tile(radius_center_tile)

    t.eq(chunk_first.x, 2, "chunk helper converts 64.5 tile x to chunk coordinate")
    t.eq(chunk_first.y, -1, "chunk helper floors negative tile y coordinate")
    t.eq(chunk_second.x, 4, "chunk helper converts 128.5 tile x to chunk coordinate")

    t.eq(surface.is_chunk_generated(chunk_origin), false, "chunks start as not generated")

    local initial_tile = surface.get_tile(origin_tile)
    t.eq(initial_tile.valid, false, "tile from an ungenerated chunk is invalid")
    t.eq(initial_tile.name, nil, "invalid tiles do not expose a name")

    local search_queue = {}
    local result = tileInvalidOrOutOfMap(surface, origin_tile, true, search_queue, enqueue, "chunk_test.initial")
    t.eq(result, false, "tileInvalidOrOutOfMap reports pending work when chunk is not generated")
    t.eq(#search_queue, 1, "missing chunk position is re-enqueued")
    t.eq(search_queue[1].x, origin_tile.x, "re-enqueued tile preserves X position")
    t.eq(search_queue[1].y, origin_tile.y, "re-enqueued tile preserves Y position")

    local requested_tile = surface.get_tile(origin_tile)
    t.eq(requested_tile.valid, true, "requested chunk returns a valid tile")
    t.eq(requested_tile.name, "out-of-map", "requested chunk yields out-of-map tile")

    surface.force_generate_chunk_requests()
    t.eq(surface.is_chunk_generated(chunk_origin), true, "chunk generated after forcing chunk requests")

    local generated_tile = surface.get_tile(origin_tile)
    t.eq(generated_tile.valid, true, "generated chunk returns valid tile")
    t.eq(generated_tile.name, surface.default_tile, "generated chunk resolves to default tile name")

    local out_queue = {}
    -- invalid=false signals a pure out-of-map check so no generation request is issued here
    local out_result = tileInvalidOrOutOfMap(surface, far_tile, false, out_queue, enqueue, "chunk_test.out_of_map")
    t.eq(out_result, false, "out-of-map tiles requeue when chunk is missing")
    t.eq(#out_queue, 1, "out-of-map path re-enqueues the position")
    t.eq(surface.is_chunk_generated(chunk_far), false, "out-of-map checks do not request chunk generation")
    local untouched_tile = surface.get_tile(far_tile)
    t.eq(untouched_tile.valid, false, "chunk remains invalid when no generation was requested")
    t.eq(untouched_tile.name, nil, "unrequested chunk still lacks tile name")

    surface.request_to_generate_chunks(first_chunk_tile)
    surface.request_to_generate_chunks(second_chunk_tile)
    t.eq(surface.is_chunk_generated(chunk_first), false, "first requested chunk pending")
    t.eq(surface.is_chunk_generated(chunk_second), false, "second requested chunk pending")

    test_env.run_ticks(1)
    t.eq(surface.is_chunk_generated(chunk_first), false, "accumulation prevents immediate chunk generation")

    test_env.run_ticks(1)
    t.eq(surface.is_chunk_generated(chunk_first), true, "first chunk generated after two ticks")
    local first_chunk_tile_data = surface.get_tile(first_chunk_tile)
    t.eq(first_chunk_tile_data.name, surface.default_tile, "first chunk tile resolves to default")
    t.eq(surface.is_chunk_generated(chunk_second), false, "second chunk still queued")
    local waiting_tile = surface.get_tile(second_chunk_tile)
    t.eq(waiting_tile.name, "out-of-map", "pending chunk stays out-of-map while queued")

    test_env.run_ticks(2)
    t.eq(surface.is_chunk_generated(chunk_second), true, "second chunk generated after additional delay")
    local completed_tile = surface.get_tile(second_chunk_tile)
    t.eq(completed_tile.name, surface.default_tile, "completed chunk tile resolves to default")

    surface.request_to_generate_chunks(reset_test_tile)
    test_env.run_ticks(1)
    t.eq(surface.is_chunk_generated(chunk_reset), false, "single tick leaves reset test chunk pending")
    surface.force_generate_chunk_requests()
    t.eq(surface.is_chunk_generated(chunk_reset), true, "force generation produces pending chunk immediately")

    surface.request_to_generate_chunks(radius_center_tile)
    test_env.run_ticks(1)
    t.eq(surface.is_chunk_generated(chunk_radius_center), false,
        "progress resets after queue empties before new requests")

    surface.request_to_generate_chunks(radius_center_tile, 1)

    surface.force_generate_chunk_requests()

    local radius_chunks = {}
    for dx = -1, 1 do
        for dy = -1, 1 do
            radius_chunks[#radius_chunks + 1] = { x = chunk_radius_center.x + dx, y = chunk_radius_center.y + dy }
        end
    end
    for _, chunk_pos in ipairs(radius_chunks) do
        t.eq(surface.is_chunk_generated(chunk_pos), true, "force generation produces every requested chunk")
    end

    local radius_tile = surface.get_tile(radius_center_tile)
    t.eq(radius_tile.name, surface.default_tile, "forced chunk resolves to default tile")
    local neighbor_tile = surface.get_tile(radius_neighbor_tile)
    t.eq(neighbor_tile.name, surface.default_tile, "neighboring chunk from radius request is generated")

    t.eq(origin_tile.x, 0.5, "origin tile position remains unchanged")
    t.eq(origin_tile.y, 0.5, "origin tile position remains unchanged")
    t.eq(far_tile.x, 256, "far tile position remains unchanged")
    t.eq(far_tile.y, 0, "far tile position remains unchanged")

    t.finish("Mock chunk generation")
end

run_mock_test(run_test)
