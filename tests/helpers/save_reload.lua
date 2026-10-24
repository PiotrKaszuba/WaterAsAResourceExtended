-- Copy storage's serializable graph while retaining mock LuaObject identities.
-- This checks aliases, queued work and code reload; it is not a binary-save test.
return function()
    local api_objects = {}
    for _, surface in pairs(game.surfaces) do
        api_objects[surface] = true
        for _, entity in pairs(surface.entities) do api_objects[entity] = true end
        for _, tag in pairs(surface.chart_tags) do api_objects[tag] = true end
    end
    for _, force in pairs(game.forces) do api_objects[force] = true end
    for _, player in pairs(game.players) do api_objects[player] = true end
    local seen = {}
    local function copy(value)
        assert(type(value) ~= "function", "storage contains a nonserializable function")
        if type(value) ~= "table" or api_objects[value] then return value end
        if seen[value] then return seen[value] end
        local result = {}
        seen[value] = result
        for key, item in pairs(value) do result[copy(key)] = copy(item) end
        return result
    end
    local previous = storage
    storage = copy(storage)
    assert(storage ~= previous, "storage must be reconstructed")
    for name in pairs(package.loaded) do
        if name == "control" or string.match(name, "^modules%.") then package.loaded[name] = nil end
    end
    require("control")
    return previous
end
