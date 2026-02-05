local settings_definitions = {
    -- Alarms
    {
        type = "string-setting",
        name = "Alarm-Depletion-Level",
        setting_type = "runtime-global",
        default_value = "all",
        allowed_values = {"none", "major", "all"},
        order = "a[alarms]-a"
    },
    {
        type = "bool-setting",
        name = "Alarms-Tile-Message",
        setting_type = "runtime-global",
        default_value = true,
        order = "a[alarms]-b"
    },
    -- Scan
    {
        type = "int-setting",
        name = "Scan-Instant-Tiles",
        setting_type = "runtime-global",
        default_value = 50,
        minimum_value = 20,
        maximum_value = 10000,
        order = "b[scan]-a"
    },
    {
        type = "int-setting",
        name = "Scan-Tiles-Per-Second",
        setting_type = "runtime-global",
        default_value = 1000,
        minimum_value = 100,
        maximum_value = 100000,
        order = "b[scan]-b"
    },
    {
        type = "int-setting",
        name = "Scan-Status-Period",
        setting_type = "runtime-global",
        default_value = 20,
        minimum_value = 5,
        maximum_value = 600,
        hidden = true,
        order = "b[scan]-c"
    },
    -- Tile Amounts (startup - affects game balance)
    {
        type = "int-setting",
        name = "TileFluidAmount-Shallow",
        setting_type = "startup",
        default_value = 50,
        minimum_value = 10,
        maximum_value = 5000,
        order = "c[amounts]-a"
    },
    {
        type = "int-setting",
        name = "TileFluidAmount-Deep",
        setting_type = "startup",
        default_value = 150,
        minimum_value = 20,
        maximum_value = 10000,
        order = "c[amounts]-b"
    },
    -- Waterbody
    {
        type = "int-setting",
        name = "Waterbody-Max-Size",
        setting_type = "runtime-global",
        default_value = 0,
        minimum_value = 0,
        maximum_value = 9999999999,
        order = "d[waterbody]-a"
    },
    {
        type = "int-setting",
        name = "Waterbody-Regen-Rate",
        setting_type = "runtime-global",
        default_value = 100,
        minimum_value = 0,
        maximum_value = 1000,
        order = "d[waterbody]-b"
    },
    {
        type = "double-setting",
        name = "WaterBody-Regen-Scaling",
        setting_type = "startup",
        default_value = 1.5,
        minimum_value = 0.5,
        maximum_value = 3.0,
        order = "d[waterbody]-c"
    },
    -- Maintenance
    {
        type = "int-setting",
        name = "Update-Budget-Per-Second",
        setting_type = "runtime-global",
        default_value = 2000,
        minimum_value = 200,
        maximum_value = 200000,
        order = "e[maintenance]-a"
    },
    {
        type = "double-setting",
        name = "WaterBody-Centroid-Shift-Threshold",
        setting_type = "runtime-global",
        default_value = 0.025,
        minimum_value = 0.0,
        maximum_value = 0.5,
        hidden = true,
        order = "e[maintenance]-b"
    },
    {
        type = "int-setting",
        name = "Visual-Depletion-Start-Percentage",
        setting_type = "runtime-global",
        default_value = 80,
        minimum_value = 50,
        maximum_value = 95,
        order = "e[maintenance]-c"
    },
    {
        type = "bool-setting",
        name = "Visual-Depletion-Furthest-First",
        setting_type = "runtime-global",
        default_value = true,
        order = "e[maintenance]-d"
    },
    -- Pumps
    {
        type = "int-setting",
        name = "Pumps-Reactivation-LevelPerThousand",
        setting_type = "runtime-global",
        default_value = 990,
        minimum_value = 1,
        maximum_value = 1000,
        order = "f[pumps]-a"
    },
    -- Cleanup
    {
        type = "bool-setting",
        name = "Cleanup-Remove-Depleted-Orphaned",
        setting_type = "runtime-global",
        default_value = true,
        order = "g[cleanup]-a"
    },
    -- Splits (all hidden - technical settings)
    {
        type = "int-setting",
        name = "Split-Max-BBox-Side",
        setting_type = "runtime-global",
        default_value = 32,
        minimum_value = 16,
        maximum_value = 1024,
        hidden = true,
        order = "h[splits]-a"
    },
    {
        type = "int-setting",
        name = "Split-Max-Adjacent-Landfill-Depth-Check",
        setting_type = "runtime-global",
        default_value = 16,
        minimum_value = 8,
        maximum_value = 128,
        hidden = true,
        order = "h[splits]-b"
    },
    {
        type = "int-setting",
        name = "Split-Finalize-Max-Landfills-Per-Update",
        setting_type = "runtime-global",
        default_value = 100,
        minimum_value = 10,
        maximum_value = 10000,
        hidden = true,
        order = "h[splits]-c"
    },
    -- Map
    {
        type = "bool-setting",
        name = "Map-EnableMarkers",
        setting_type = "runtime-global",
        default_value = true,
        order = "i[map]-a"
    }
}

data:extend(settings_definitions)
