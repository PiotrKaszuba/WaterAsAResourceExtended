local settings_definitions = {
    {
        type = "bool-setting",
        name = "Alarms-Low-Level",
        setting_type = "runtime-global",
        default_value = true,
        order = "a[alarms]-a"
    },
    {
        type = "bool-setting",
        name = "Alarms-High-Level",
        setting_type = "runtime-global",
        default_value = true,
        order = "a[alarms]-b"
    },
    {
        type = "bool-setting",
        name = "Alarms-Tile-Message",
        setting_type = "runtime-global",
        default_value = true,
        order = "a[alarms]-c"
    },
    {
        type = "int-setting",
        name = "FluidArea-Start-Area",
        setting_type = "runtime-global",
        default_value = 50,
        minimum_value = 20,
        maximum_value = 10000,
        order = "b[scan]-a"
    },
    {
        type = "int-setting",
        name = "FluidArea-Additional-Tiles-Per-Second",
        setting_type = "runtime-global",
        default_value = 1000,
        minimum_value = 100,
        maximum_value = 100000,
        order = "b[scan]-b"
    },
    {
        type = "int-setting",
        name = "FluidArea-MaxFluidAreaSize",
        setting_type = "runtime-global",
        default_value = 0,
        minimum_value = 0,
        maximum_value = 9999999999,
        order = "b[scan]-c"
    },
    {
        type = "int-setting",
        name = "FluidArea-Scanning-Loop-Period",
        setting_type = "runtime-global",
        default_value = 20,
        minimum_value = 5,
        maximum_value = 600,
        order = "b[scan]-d"
    },
    {
        type = "int-setting",
        name = "Update-Budget-Per-Second",
        setting_type = "runtime-global",
        default_value = 2000,
        minimum_value = 200,
        maximum_value = 200000,
        order = "b[scan]-e"
    },
    {
        type = "int-setting",
        name = "TileFluidAmount-Shallow",
        setting_type = "runtime-global",
        default_value = 50,
        minimum_value = 10,
        maximum_value = 5000,
        order = "c[amount]-a"
    },
    {
        type = "int-setting",
        name = "TileFluidAmount-Deep",
        setting_type = "runtime-global",
        default_value = 150,
        minimum_value = 20,
        maximum_value = 10000,
        order = "c[amount]-b"
    },
    {
        type = "int-setting",
        name = "FluidArea-RegenRate",
        setting_type = "runtime-global",
        default_value = 100,
        minimum_value = 0,
        maximum_value = 1000,
        order = "c[amount]-c"
    },
    {
        type = "double-setting",
        name = "WaterBody-Centroid-Shift-Threshold",
        setting_type = "runtime-global",
        default_value = 0.025,
        minimum_value = 0.0,
        maximum_value = 0.5,
        order = "d[maintenance]-a"
    },
    {
        type = "int-setting",
        name = "Visual-Depletion-Start-Percentage",
        setting_type = "runtime-global",
        default_value = 80,
        minimum_value = 50,
        maximum_value = 95,
        order = "d[maintenance]-b"
    },
    {
        type = "bool-setting",
        name = "Visual-Depletion-Furthest-First",
        setting_type = "runtime-global",
        default_value = false,
        order = "d[maintenance]-c"
    },
    {
        type = "int-setting",
        name = "Pumps-Reactivation-LevelPerThousand",
        setting_type = "runtime-global",
        default_value = 990,
        minimum_value = 1,
        maximum_value = 1000,
        order = "e[pumps]-a"
    },
    {
        type = "bool-setting",
        name = "FluidArea-RemoveDepletedOrphaned",
        setting_type = "runtime-global",
        default_value = true,
        order = "f[cleanup]-a"
    },
    {
        type = "bool-setting",
        name = "Map-EnableMarkers",
        setting_type = "runtime-global",
        default_value = true,
        order = "g[map]-a"
    },
    {
        type = "int-setting",
        name = "Split-Max-BBox-Side",
        setting_type = "runtime-global",
        default_value = 32,
        minimum_value = 16,
        maximum_value = 1024,
        order = "h[splits]-d"
    },
    {
        type = "int-setting",
        name = "Split-Max-Adjacent-Landfill-Depth-Check",
        setting_type = "runtime-global",
        default_value = 16,
        minimum_value = 8,
        maximum_value = 128,
        order = "h[splits]-e"
    },
    {
        type = "int-setting",
        name = "Split-Finalize-Max-Landfills-Per-Update",
        setting_type = "runtime-global",
        default_value = 100,
        minimum_value = 10,
        maximum_value = 10000,
        order = "h[splits]-f"
    },
    {
        type = "double-setting",
        name = "WaterBody-Regen-Scaling",
        setting_type = "startup",
        default_value = 1.5,
        minimum_value = 0.5,
        maximum_value = 3.0,
        order = "z[startup]-a"
    }
}

data:extend(settings_definitions)
