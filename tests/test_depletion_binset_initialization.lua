local test_env = require("tests.helpers.test_env")
local t = require("tests.helpers.test_assert")
local run_mock_test = require("tests.helpers.mock_test")

local function run_test()
    t.start()
    local world, surface = test_env.create_world()
    world:set_water_rectangle(surface, { x1 = 0, y1 = 0, x2 = 1, y2 = 0 })

    local function fixture(has_centroid)
        local body = waterbodies.InitWaterBody(surface)
        body.waterBodyShapeData.TileCount = has_centroid and 2 or 0
        body.waterBodyShapeData.SumX = 1
        body.waterBodyShapeData.SumY = 0
        local enqueue = waterbodies.getDriedStackOrPendingTilesEnqueueAndDequeue(false)
        for x = 0, 1 do
            local position = { x = x, y = 0 }
            local key = hot_utils.GridKey(position)
            waterbodies.addTileToWaterGrid(body.gridsData.waterGridWithData, key, "water", position, "water")
            enqueue(body.gridsData.pendingTiles, key)
        end
        return body
    end

    -- Pending drying can run before the normal binset-maintenance phase.
    local body = fixture(true)
    t.eq(body.gridsData.newBinset, nil, "fixture starts before binset initialization")
    local dried = waterbody_depletion.getTilesDepleting(body, true, 1)
    t.eq(dried, 1, "drying progresses before scheduled binset maintenance")
    t.ok(body.gridsData.newBinset ~= nil, "missing binset initialized from the centroid")
    t.eq(body.waterBodyStateData.DriedTiles, 1, "first dried tile counted")

    local binset = body.gridsData.newBinset
    local initializer = waterbodies.ensureAndUpdateBinset
    local initializer_calls = 0
    waterbodies.ensureAndUpdateBinset = function(...)
        initializer_calls = initializer_calls + 1
        return initializer(...)
    end
    local ok, result = pcall(waterbody_depletion.getTilesDepleting, body, true, 10)
    waterbodies.ensureAndUpdateBinset = initializer
    t.ok(ok, "subsequent drying succeeds with existing binset")
    t.eq(result, 1, "oversized request dries only remaining water tile")
    t.eq(initializer_calls, 0, "existing binset does not trigger extra geometry maintenance")
    t.eq(body.gridsData.newBinset, binset, "existing binset reused")
    t.eq(body.waterBodyStateData.DriedTiles, 2, "all water tiles counted once")
    t.eq(next(body.gridsData.waterGridWithData), nil, "water grid exhausted")
    t.eq(surface.get_tile({ x = 0, y = 0 }).name, "lake-shallow", "first surface tile dried")
    t.eq(surface.get_tile({ x = 1, y = 0 }).name, "lake-shallow", "second surface tile dried")

    -- With no usable centroid yet, the existing water-grid fallback must still
    -- make progress instead of returning early or calling dynamic_bins on nil.
    local incomplete = fixture(false)
    t.eq(waterbody_depletion.getTilesDepleting(incomplete, true, 2), 2,
        "drying progresses through grid fallback when centroid is unavailable")
    t.eq(incomplete.gridsData.newBinset, nil, "no binset fabricated without a centroid")
    t.eq(incomplete.waterBodyStateData.DriedTiles, 2, "fallback updates dried count")
    t.eq(next(incomplete.gridsData.waterGridWithData), nil, "fallback consumes source water grid")
    t.eq(waterbody_depletion.getTilesDepleting(incomplete, true, 1), 0,
        "empty grid without centroid safely reports no work")
    t.eq(incomplete.waterBodyStateData.DriedTiles, 2, "empty fallback does not double-count tiles")
    t.eq(waterbody_depletion.getTilesDepleting(incomplete, false, 2), 2,
        "restoration remains functional without a binset")
    t.eq(incomplete.waterBodyStateData.DriedTiles, 0, "restoration resets dried count")
    t.eq(surface.get_tile({ x = 0, y = 0 }).name, "water", "first tile restored")
    t.eq(surface.get_tile({ x = 1, y = 0 }).name, "water", "second tile restored")
    t.finish("Depletion binset initialization regression")
end

run_mock_test(run_test)
