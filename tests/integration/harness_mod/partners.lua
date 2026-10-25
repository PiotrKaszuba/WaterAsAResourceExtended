local W = require("world")

return function(H)
    if storage.phase == "setup" then
        local surface = W.prepare(H)
        local names = {}
        if script.active_mods["aai-industry"] then names[#names + 1] = "offshore-pump" end
        if script.active_mods["offshore-burner"] then
            names[#names + 1] = "burner-offshore-pump"
            names[#names + 1] = "electric-offshore-pump"
        end
        if #names == 0 then names[1] = "offshore-pump" end
        storage.partner_pumps, storage.partner_removed = {}, {}
        for i, name in ipairs(names) do
            W.rectangle(surface, (i - 1) * 24, 0, 8, 8, "water")
            storage.partner_pumps[i] = W.pump(H, surface, (i - 1) * 24, 0, 8, 8, name)
            storage.partner_removed[i] = 0
        end
        H.phase("unpowered")
        return
    end
    local view = W.snapshot(H)
    if storage.phase == "unpowered" then
        if H.elapsed() < 240 or not view.finished then return end
        H.near(#view.raw.bodies, #storage.partner_pumps, 0, "Actual partner pumps are tracked on separate lakes")
        for _, pump in ipairs(storage.partner_pumps) do
            if script.active_mods["aai-industry"] or script.active_mods["offshore-burner"] then
                H.near(pump.get_fluid_count(), 0, 0.01, "Unfuelled/unpowered partner pump cannot extract")
            end
            if pump.burner then pump.insert({ name = "coal", count = 20 }) end
            W.power(game.surfaces.nauvis, { pump.position.x + 5, pump.position.y - 4 })
        end
        local force = game.forces.player
        local tech = force.technologies["waterfill-tech"]
        H.check(tech and tech.prerequisites.landfill and tech.prerequisites.explosives,
            "Waterfill technology retains its intended prerequisite graph")
        tech.researched = true
        H.check(force.recipes["waterfill-recipe"].enabled, "Research unlocks Water's recipe with actual partners")
        local surface = game.surfaces.nauvis
        storage.assembler = assert(surface.create_entity({ name = "assembling-machine-2", position = { -20, 20 }, force = "player" }))
        storage.assembler.set_recipe("waterfill-recipe")
        H.check(storage.assembler.get_recipe().name == "waterfill-recipe", "Fluid-crafting machine accepts the migrated recipe")
        assert(storage.assembler.insert({ name = "explosives", count = 1 }) == 1)
        H.near(storage.assembler.insert_fluid({ name = "water", amount = 1200 }), 1200, 0,
            "Native recipe input accepts its default water cost")
        W.power(surface, { -16, 20 })
        H.phase("draining")
    elseif storage.phase == "draining" then
        for i, pump in ipairs(storage.partner_pumps) do
            local removed = pump.clear_fluid(1)
            storage.partner_removed[i] = storage.partner_removed[i] + (removed and removed.amount or 0)
        end
        if not view.depleted then return end
        for i, pump in ipairs(storage.partner_pumps) do
            H.check(storage.partner_removed[i] > 0, "Actual partner pump extracts native fluid: " .. pump.name)
            H.check(pump.disabled_by_script and not pump.active, "Finite depletion stops actual partner pump: " .. pump.name)
        end
        H.near(storage.assembler.get_output_inventory().get_item_count("waterfill"), 3, 0,
            "Native machine crafts exactly three waterfill items")
        storage.partner_empty = view.remaining
        H.setting("Waterbody-Regen-Enabled-By-Size", "0000000")
        H.setting("Waterbody-Regen-Rate", 1000)
        H.phase("no-regeneration")
    elseif storage.phase == "no-regeneration" then
        if H.elapsed() < 180 then return end
        H.near(view.remaining, storage.partner_empty, 0.01, "Partner lakes obey the disabled regeneration mask")
        H.setting("Waterbody-Regen-Enabled-By-Size", "1111111")
        H.phase("recovering")
    elseif storage.phase == "recovering" then
        if view.depleted then return end
        for _, pump in ipairs(storage.partner_pumps) do
            if pump.disabled_by_script then return end
        end
        H.check(true, "Regeneration releases all actual partner pumps")
        storage.trials = { actual_removed = storage.partner_removed, active_mods = script.active_mods }
        H.finish()
    end
end
