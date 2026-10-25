local W = require("world")
local S = {}

function S.prototypes(H)
    local enabled = settings.startup["Enable-Waterfill"].value
    for _, spec in ipairs({ { prototypes.recipe, "waterfill-recipe" },
        { prototypes.item, "waterfill" }, { prototypes.entity, "waterfill-placer" },
        { prototypes.technology, "waterfill-tech" } }) do
        H.check((spec[1][spec[2]] ~= nil) == enabled, "Waterfill prototype switch: " .. spec[2])
    end
    for _, name in ipairs({ "water", "water-green", "water-shallow", "water-mud", "deepwater", "deepwater-green" }) do
        H.check(prototypes.tile["lake-dry-" .. name] ~= nil, "Typed dry prototype: " .. name)
    end
    H.check(settings.startup["Yield-Boost-Max-Level"].value == 6
        and not settings.startup["Enable-Infinite-Yield-Research"].value, "Loop-safe research defaults")
    if enabled then
        local recipe = prototypes.recipe["waterfill-recipe"]
        local cost, count = 0, 0
        for _, ingredient in pairs(recipe.ingredients) do
            if ingredient.name == "water" then cost = ingredient.amount end
        end
        for _, product in pairs(recipe.products) do
            if product.name == "waterfill" then count = product.amount end
        end
        H.near(cost, 1200, 0, "Native recipe costs 1200 water")
        H.near(count, 3, 0, "Native recipe produces 3 tiles")
    end
    H.finish()
end

function S.pumping(H)
    if storage.phase == "setup" then
        local surface = W.prepare(H)
        storage.pumps, storage.extracted = {}, { 0, 0, 0 }
        for i, name in ipairs({ "offshore-pump", "water-test-burner-pump", "water-test-electric-pump" }) do
            W.rectangle(surface, (i - 1) * 24, 0, 8, 8, "water")
            storage.pumps[i] = W.pump(H, surface, (i - 1) * 24, 0, 8, 8, name)
        end
        H.phase("blocked")
        return
    end
    W.sample_pumps()
    local view = W.snapshot(H)
    if storage.phase == "blocked" then
        if H.elapsed() == 180 then storage.blocked = view.remaining end
        if H.elapsed() < 240 then return end
        H.check(view.finished and #view.raw.bodies == 3, "All three native pump lakes finish normal scans")
        local pump = storage.pumps[1]
        H.check(storage.extracted[1] > 0, "Vanilla pump actually extracts into its output buffer",
            { active = pump.active, status = pump.status, fluid = pump.get_fluid(1) })
        H.near(view.remaining, storage.blocked, 0.01, "Blocked output stops reserve consumption")
        H.near(storage.extracted[2], 0, 0, "Burner pump without fuel extracts nothing")
        H.near(storage.extracted[3], 0, 0, "Electric pump without power extracts nothing")
        storage.drain = true
        storage.pumps[2].insert({ name = "coal", count = 10 })
        local p = storage.pumps[3].position
        storage.power = W.power(game.surfaces.nauvis, { p.x + 5, p.y - 4 })
        H.phase("powered")
    elseif storage.phase == "powered" then
        if H.elapsed() < 180 then return end
        H.check(storage.extracted[2] > 0 and storage.extracted[3] > 0,
            "Fuel and native electric network start both generic pump variants")
        storage.power.destroy()
        H.phase("power-off")
    elseif storage.phase == "power-off" then
        if H.elapsed() == 120 then storage.off_total = storage.extracted[3] end
        if H.elapsed() < 240 then return end
        H.near(storage.extracted[3], storage.off_total, 0.01, "Electric outage stops actual pumping after buffer drains")
        local p = storage.pumps[3].position
        storage.power = W.power(game.surfaces.nauvis, { p.x + 5, p.y - 4 })
        H.phase("depleting")
    elseif storage.phase == "depleting" then
        if not view.depleted then return end
        H.check(view.remaining <= 0, "Actual extraction depletes the three finite lakes")
        for _, pump in ipairs(storage.pumps) do H.check(not pump.active, "Water disables depleted pump") end
        local extracted = storage.extracted[1] + storage.extracted[2] + storage.extracted[3]
        H.near(view.capacity - view.remaining, extracted, 60, "Reserve debit matches native pumped_last_tick samples")
        storage.drain = false
        H.setting("Waterbody-Regen-Enabled-By-Size", "0000000")
        H.setting("Waterbody-Regen-Rate", 1000)
        storage.empty = view.remaining
        H.phase("regen-disabled")
    elseif storage.phase == "regen-disabled" then
        if H.elapsed() < 180 then return end
        H.near(view.remaining, storage.empty, 0.01, "Disabled size classes prevent regeneration of existing lakes")
        for _, body in ipairs(view.raw.bodies) do H.near(body.regen, 0, 0, "Cached regeneration disabled") end
        H.setting("Waterbody-Regen-Enabled-By-Size", "1111111")
        H.phase("recovering")
    elseif storage.phase == "recovering" then
        if view.remaining < 300 or view.depleted then return end
        for _, pump in ipairs(storage.pumps) do if not pump.active then return end end
        for _, body in ipairs(view.raw.bodies) do H.check(body.regen > 0, "Setting change refreshes existing-lake cache") end
        for _, pump in ipairs(storage.pumps) do H.check(pump.active, "Regeneration reactivates the pump") end
        H.finish()
    end
end

function S.landfill(H)
    local surface = game.surfaces.nauvis
    if storage.phase == "setup" then
        surface = W.prepare(H)
        W.rectangle(surface, 0, 0, 8, 8, "water")
        surface.set_tiles({ { name = "lake-dry-water", position = { 3, 2 } },
            { name = "lake-dry-deepwater", position = { 4, 2 } },
            { name = "lake-dry-water-green", position = { 14, 2 } } }, false)
        storage.pumps = { W.pump(H, surface, 0, 0, 8, 8) }
        storage.extracted = { 0 }
        storage.edits = { { position = { 2, 2 } }, { position = { 3, 2 } },
            { position = { 4, 2 } }, { position = { 14, 2 } } }
        storage.chest = W.robots(surface)
        H.phase("settling")
        return
    end
    local view = W.snapshot(H)
    if storage.phase == "settling" then
        if H.elapsed() < 240 or not view.finished then return end
        storage.initial_capacity = view.capacity
        for _, edit in ipairs(storage.edits) do
            edit.original = surface.get_tile(edit.position).name
            W.ghost(H, surface, "landfill", edit.position)
        end
        H.check(storage.edits[4].original == "lake-dry-water-green", "The orphan dry-bed trial is physically dry")
        H.phase("covering")
    elseif storage.phase == "covering" then
        if not W.all_tiles(surface, storage.edits, "landfill") or view.raw.queued > 0 then return end
        H.check((storage.events[tostring(defines.events.on_robot_built_tile)] or 0) >= 4,
            "Construction robots emit real tile-built events for wet and dry beds")
        H.near(view.capacity, storage.initial_capacity - 2400, 0.01, "Landfill removes correct mixed capacity classes")
        for _, edit in ipairs(storage.edits) do
            H.check(surface.get_tile(edit.position).hidden_tile == edit.original,
                "Native hidden layers retain the actual wet/dry identity")
        end
        storage.covered = view.remaining
        storage.covered_capacity = view.capacity
        W.ghost(H, surface, "concrete", { 2, 2 })
        H.phase("paving")
    elseif storage.phase == "paving" then
        if surface.get_tile(2, 2).name ~= "concrete" then return end
        H.check(surface.get_tile(2, 2).hidden_tile == "landfill", "Pavement preserves landfill as hidden foundation")
        H.check(surface.get_tile(2, 2).order_deconstruction("player") ~= nil, "Order native pavement removal")
        H.phase("unpaving")
    elseif storage.phase == "unpaving" then
        if surface.get_tile(2, 2).name ~= "landfill" then return end
        H.near(view.capacity, storage.covered_capacity, 0.01, "Pavement removal does not restore lake capacity")
        for _, edit in ipairs(storage.edits) do
            H.check(surface.get_tile(edit.position).order_deconstruction("player") ~= nil, "Order native landfill removal")
        end
        H.phase("uncovering")
    elseif storage.phase == "uncovering" then
        for _, edit in ipairs(storage.edits) do
            if surface.get_tile(edit.position).name == "landfill" then return end
        end
        if view.raw.queued > 0 or not view.finished or H.elapsed() < 120 then return end
        if storage.chest.get_item_count("landfill") ~= 30 then return end
        H.check((storage.events[tostring(defines.events.on_robot_mined_tile)] or 0) >= 5,
            "Actual robots emit pavement and landfill mining events")
        H.near(view.capacity, storage.initial_capacity, 0.01, "Mining restores all capacity categories")
        H.near(view.remaining, storage.covered, 0.01, "Wet/dry landfill removal adds exactly zero reserve")
        H.check(true, "Robots return all four mined landfill items")
        H.check(surface.get_tile(14, 2).name == "lake-dry-water-green",
            "Mining orphan dry-bed landfill restores the exact dry tile")
        storage.trials = { original_capacity = storage.initial_capacity,
            covered_remaining = storage.covered, reopened_remaining = view.remaining,
            dry_bed_after_mining = surface.get_tile(14, 2).name }
        storage.before_paid, storage.capacity_before_paid = view.remaining, view.capacity
        surface.create_entity({ name = "waterfill-placer", position = { 8.5, 3.5 },
            force = "player", raise_built = true })
        H.check(surface.get_tile(8, 3).name == "water-shallow", "Built-in placer creates native extra-shallow water")
        H.phase("paid-waterfill")
    elseif storage.phase == "paid-waterfill" then
        if view.raw.queued > 0 or not view.finished or H.elapsed() < 120 then return end
        H.near(view.capacity, storage.capacity_before_paid + 100, 0.01, "Paid waterfill adds extra-shallow capacity")
        H.near(view.remaining, storage.before_paid + 100, 0.01, "Paid waterfill adds its documented reserve")
        H.finish()
    end
end

function S.resume(H)
    local surface = game.surfaces.nauvis
    if storage.phase == "setup" then
        surface = W.prepare(H)
        W.rectangle(surface, 0, 0, 32, 16, "water")
        storage.pumps, storage.extracted, storage.drain = {}, {}, true
        for i = 1, 3 do
            storage.pumps[i] = W.pump(H, surface, 0, 0, 32, 16)
            storage.extracted[i] = 0
        end
        H.phase("draining")
        return
    end
    W.sample_pumps()
    local view = W.snapshot(H)
    if storage.phase == "draining" then
        if not view.finished or view.remaining > view.capacity * 0.15 then return end
        H.check(view.raw.bodies[1].dried > 0, "Real extraction triggers physical drying before the brush")
        storage.drain = false
        storage.before_brush = view.remaining
        storage.edits = W.rectangle(surface, 6, 4, 16, 8, "landfill", true)
        local queued = H.snapshot()
        H.check(queued.queued >= 128 and queued.pending >= 128, "Brush creates a genuine budgeted pending backlog")
        H.checkpoint()
    elseif storage.phase == "resumed" then
        H.check(storage.restarted, "Native saved game was reloaded in a new process")
        H.check(view.raw.pending > 0 and view.raw.queued > 0, "Native serialization retains queue and derived index")
        H.phase("finishing")
    elseif storage.phase == "finishing" then
        assert(W.all_tiles(surface, storage.edits, "landfill"), "Queued brush overwritten during post-restart visual work")
        if view.raw.queued > 0 or not view.finished or H.elapsed() < 240 then return end
        H.check(true, "Queued brush survived every observed post-restart visual update")
        H.near(view.capacity, 384 * 200, 0.01, "Post-restart accounting removes the whole brush")
        H.check(view.remaining <= storage.before_brush + 0.01, "Queued brush/restart cannot create water")
        H.near(view.raw.pending, 0, 0, "Pending-position index empties after queue settlement")
        H.finish()
    end
end

return S
