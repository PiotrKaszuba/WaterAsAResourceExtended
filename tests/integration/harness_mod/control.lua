local config = require("config")
local scenarios = require("scenarios")
local loaded = false
local H = {}

function H.check(condition, message, details)
    assert(condition, message .. (details and (": " .. serpent.line(details)) or ""))
    storage.checks[#storage.checks + 1] = { tick = game.tick, message = message }
end

function H.near(actual, expected, tolerance, message)
    H.check(math.abs(actual - expected) <= (tolerance or 0.001), message,
        { actual = actual, expected = expected })
end

function H.snapshot() return remote.call("water_acceptance", "snapshot") end
function H.setting(name, value) remote.call("water_acceptance", "set_setting", name, value) end

function H.result(status, extra)
    helpers.write_file("water-result.json", helpers.table_to_json({
        status = status, scenario = config.scenario, tick = game.tick,
        checks = storage.checks, events = storage.events, extra = extra,
        mined_samples = storage.mined_samples, trials = storage.trials,
        snapshot = H.snapshot(),
    }), false)
end

function H.finish()
    storage.done = true
    H.result("passed")
end

function H.checkpoint()
    storage.awaiting_restart = true
    loaded = false
    assert(game.is_multiplayer(), "Checkpoint scenario requires a local server")
    game.server_save("water-acceptance-checkpoint")
    storage.checkpoint_result_tick = game.tick + 2
end

function H.phase(name)
    storage.phase = name
    storage.phase_tick = game.tick
end

function H.elapsed() return game.tick - storage.phase_tick end

script.on_init(function()
    storage.checks, storage.events = {}, {}
    storage.phase, storage.phase_tick = "setup", 0
    if config.scenario == "resume" then game.speed = 8 end
end)
script.on_load(function() loaded = true end)

for _, event in ipairs({ defines.events.on_robot_built_tile, defines.events.on_robot_mined_tile,
    defines.events.on_player_mined_tile, defines.events.script_raised_set_tiles }) do
    script.on_event(event, function(e)
        local key = tostring(e.name)
        storage.events[key] = (storage.events[key] or 0) + #e.tiles
        if e.name == defines.events.on_robot_mined_tile or e.name == defines.events.on_player_mined_tile then
            storage.mined_samples = storage.mined_samples or {}
            for _, tile in ipairs(e.tiles) do
                if #storage.mined_samples < 8 then
                    storage.mined_samples[#storage.mined_samples + 1] = { old = tile.old_tile.name,
                        observed_after_handlers = game.surfaces[e.surface_index].get_tile(tile.position).name,
                        position = tile.position }
                end
            end
        end
    end)
end

script.on_event(defines.events.on_tick, function()
    if storage.done then return end
    local ok, err = pcall(function()
        if storage.awaiting_restart then
            if loaded then
                storage.awaiting_restart = false
                storage.restarted = true
                H.phase("resumed")
            else
                if storage.checkpoint_result_tick and game.tick >= storage.checkpoint_result_tick then
                    H.result("checkpoint")
                    storage.checkpoint_result_tick = nil
                end
                return
            end
        end
        assert(game.tick - storage.phase_tick < 10000, "Timed out in phase " .. storage.phase)
        scenarios[config.scenario](H)
    end)
    if not ok then
        storage.done = true
        H.result("failed", { error = err, phase = storage.phase })
        log("Water acceptance FAILED: " .. tostring(err))
    end
end)
