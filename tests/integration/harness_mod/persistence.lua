local W = require("world")

-- Builds upon the mixed wet/dry/robot trial without pretending this 2.1-created
-- state is a second old-engine upgrade fixture.
return function(H, landfill)
    if not storage.persist_prepared then return landfill(H) end
    local surface, force = game.surfaces.nauvis, game.forces.player
    if storage.phase == "persist-prepare" then
        H.setting("Waterbody-Regen-Enabled-By-Size", "0000000")
        H.setting("Waterbody-Regen-Rate", 317)
        H.setting("Pumps-Reactivation-LevelPerThousand", 975)
        H.check(force.add_research("waar-yield-boost-1"), "Start native yield research")
        force.research_progress = 1
        W.ghost(H, surface, "landfill", { 14, 2 })
        W.rectangle(surface, 40, 20, 4, 4, "water")
        storage.persist_dry_pump = W.pump(H, surface, 40, 20, 4, 4)
        H.phase("persist-cover")
    elseif storage.phase == "persist-cover" then
        storage.persist_dry_pump.clear_fluid(1)
        local snapshot = H.snapshot()
        if surface.get_tile(14, 2).name ~= "landfill" or H.snapshot().queued > 0
            or not force.technologies["waar-yield-boost-1"].researched
            or #snapshot.bodies < 2 or not snapshot.bodies[2].depleted
            or not storage.persist_dry_pump.disabled_by_script then return end
        H.near(snapshot.forces.player, 0.85, 0.000001, "Native research completion updates Water's multiplier")
        H.check(surface.get_tile(14, 2).hidden_tile == "lake-dry-water-green",
            "Covered typed dry bed exists before saving")
        storage.persist_expected = snapshot
        H.checkpoint()
    elseif storage.phase == "resumed" then
        local snapshot, expected = H.snapshot(), storage.persist_expected
        H.check(storage.restarted, "Mixed-state trial reloads in another native process")
        H.near(snapshot.settings.regeneration, 317, 0, "Nondefault regeneration factor survives reload")
        H.check(snapshot.settings.regen_mask == "0000000", "Nondefault regeneration mask survives reload")
        H.near(snapshot.settings.reactivation, 975, 0, "Nondefault reactivation threshold survives reload")
        H.near(snapshot.forces.player, 0.85, 0.000001, "Completed yield bonus survives reload")
        H.check(force.technologies["waar-yield-boost-1"].researched, "Completed research survives reload")
        H.near(#snapshot.bodies, #expected.bodies, 0, "Mixed and depleted lakes both survive reload")
        for i, body in ipairs(snapshot.bodies) do
            H.near(body.capacity, expected.bodies[i].capacity, 0.01, "Lake capacity survives reload: " .. i)
            H.near(body.remaining - body.uncollected,
                expected.bodies[i].remaining - expected.bodies[i].uncollected, 0.01,
                "Lake reserve survives reload: " .. i)
            H.near(body.regen, 0, 0, "Saved disabled mask retains zero cached regeneration: " .. i)
        end
        H.check(snapshot.bodies[2].depleted and storage.persist_dry_pump.disabled_by_script
            and not storage.persist_dry_pump.active, "Saved depleted lake retains its Water-controlled pump stop")
        H.check(surface.get_tile(14, 2).hidden_tile == "lake-dry-water-green",
            "Native hidden dry identity survives reload")
        assert(surface.get_tile(14, 2).order_deconstruction("player"))
        H.phase("persist-uncover")
    elseif storage.phase == "persist-uncover" then
        if surface.get_tile(14, 2).name ~= "lake-dry-water-green" or H.snapshot().queued > 0
            or storage.chest.get_item_count("landfill") ~= 30 then return end
        local expected = 0
        for _, body in ipairs(storage.persist_expected.bodies) do expected = expected + body.remaining - body.uncollected end
        H.near(W.snapshot(H).remaining, expected, 0.01,
            "Post-reload robot mining restores the dry identity without adding water")
        storage.persist_complete = true
        H.finish()
    end
end
