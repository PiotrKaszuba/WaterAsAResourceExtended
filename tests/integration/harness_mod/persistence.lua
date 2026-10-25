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
        H.phase("persist-cover")
    elseif storage.phase == "persist-cover" then
        if surface.get_tile(14, 2).name ~= "landfill" or H.snapshot().queued > 0
            or not force.technologies["waar-yield-boost-1"].researched then return end
        local snapshot = H.snapshot()
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
        H.near(snapshot.bodies[1].capacity, expected.bodies[1].capacity, 0.01, "Mixed lake capacity survives reload")
        H.near(snapshot.bodies[1].remaining - snapshot.bodies[1].uncollected,
            expected.bodies[1].remaining - expected.bodies[1].uncollected, 0.01,
            "Mixed lake reserve survives reload")
        H.near(snapshot.bodies[1].regen, 0, 0, "Saved disabled mask retains zero cached regeneration")
        H.check(surface.get_tile(14, 2).hidden_tile == "lake-dry-water-green",
            "Native hidden dry identity survives reload")
        assert(surface.get_tile(14, 2).order_deconstruction("player"))
        H.phase("persist-uncover")
    elseif storage.phase == "persist-uncover" then
        if surface.get_tile(14, 2).name ~= "lake-dry-water-green" or H.snapshot().queued > 0
            or storage.chest.get_item_count("landfill") ~= 30 then return end
        local expected = storage.persist_expected.bodies[1]
        H.near(W.snapshot(H).remaining, expected.remaining - expected.uncollected, 0.01,
            "Post-reload robot mining restores the dry identity without adding water")
        storage.persist_complete = true
        H.finish()
    end
end
