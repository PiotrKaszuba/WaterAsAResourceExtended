local W = require("world")

-- Physical receiver/drain balance is independent of Water's active predicate.
local steps = {
    { name = "flow", ticks = 61 },
    { name = "circuit-stop", ticks = 61 },
    { name = "flow", ticks = 59 },
    { name = "deconstruction-stop", ticks = 59 },
    { name = "flow", ticks = 62 },
    -- Stay between Water's big updates: competing scripts do not own separate
    -- disable flags. Natural prolonged Water stops are covered by S.pumping.
    { name = "script-stop", ticks = 12 },
    { name = "flow", ticks = 58 },
    { name = "blocked", ticks = 90 },
    { name = "flow", ticks = 60 },
    { name = "blocked", ticks = 60 },
}

local function buffer()
    return storage.meter_pump.get_fluid_count() + storage.meter_pipe.get_fluid_count()
end

local function apply(step)
    local pump = storage.meter_pump
    local behavior = pump.get_or_create_control_behavior()
    behavior.circuit_enable_disable = step.name == "circuit-stop"
    behavior.circuit_condition = { condition = { comparator = ">",
        first_signal = { type = "virtual", name = "signal-A" }, constant = 0 } }
    if step.name == "deconstruction-stop" then
        assert(pump.order_deconstruction("player"), "Cannot mark native pump for deconstruction")
    else
        pump.cancel_deconstruction("player")
    end
    pump.disabled_by_script = step.name == "script-stop"
end

return function(H)
    if storage.phase == "setup" then
        local surface = W.prepare(H)
        W.rectangle(surface, 0, 0, 32, 16, "water")
        storage.meter_pump, storage.meter_pipe = W.pump(H, surface, 0, 0, 32, 16)
        local chest = assert(surface.create_entity({ name = "wooden-chest", force = "player",
            position = assert(surface.find_non_colliding_position("wooden-chest", storage.meter_pump.position, 5, 0.5)) }))
        H.check(storage.meter_pump.get_wire_connector(defines.wire_connector_id.circuit_red, true).connect_to(
            chest.get_wire_connector(defines.wire_connector_id.circuit_red, true)),
            "Pump is connected to a genuine empty circuit network")
        storage.trace, storage.meter_removed, storage.step = {}, 0, 0
        H.phase("settling")
        return
    end
    local view = W.snapshot(H)
    if storage.phase == "settling" then
        if H.elapsed() < 240 or not view.finished then return end
        storage.meter_initial, storage.meter_buffer = view.remaining, buffer()
        storage.step = 1
        H.phase(steps[1].name)
        apply(steps[1])
        return
    end
    local pump, step = storage.meter_pump, steps[storage.step]
    local removed = step.name ~= "blocked" and pump.clear_fluid(1) or nil
    local amount = removed and removed.amount or 0
    storage.meter_removed = storage.meter_removed + amount
    storage.trace[#storage.trace + 1] = { tick = game.tick, phase = step.name,
        active = pump.active, script_stop = pump.disabled_by_script,
        circuit_stop = pump.disabled_by_control_behavior,
        deconstruction = pump.to_be_deconstructed(), status = pump.status, sample = pump.pumped_last_tick,
        removed = amount, buffer = buffer(), remaining = view.remaining }
    if H.elapsed() < step.ticks then return end
    local row = storage.trace[#storage.trace]
    if step.name:find("stop", 1, true) then
        local old = storage.trace[#storage.trace - 4]
        H.near(row.remaining, old.remaining, 0.001, step.name .. " does not keep charging a stale sample")
        H.near(row.removed, 0, 0.001, step.name .. " stops physical extraction")
        if step.name == "circuit-stop" then
            H.check(not row.script_stop, "Water releases its script stop while the circuit still prevents extraction")
        elseif step.name == "deconstruction-stop" then
            H.check(row.deconstruction and not row.active, "Water reactivation respects deconstruction")
        else
            H.check(row.script_stop and not row.active, "Script-stop trace stays inside the noncompeting control window")
            storage.script_stop_sample = row.sample
        end
    elseif step.name == "flow" then
        H.check(amount > 0 and pump.active, "Native flow resumes in step " .. storage.step)
    else
        H.near(row.remaining, storage.trace[#storage.trace - 20].remaining, 0.001,
            "Full output stops reserve consumption")
    end
    if storage.step == #steps then
        local debit = storage.meter_initial - view.remaining
        local extracted = storage.meter_removed + buffer() - storage.meter_buffer
        H.near(debit, extracted, 0.01, "Lake debit matches independent removed-fluid and receiver balance")
        storage.trials = { debit = debit, physically_extracted = extracted,
            discrepancy = debit - extracted, samples = #storage.trace,
            script_stop_sample = storage.script_stop_sample }
        H.finish()
        return
    end
    storage.step = storage.step + 1
    H.phase(steps[storage.step].name)
    apply(steps[storage.step])
end
