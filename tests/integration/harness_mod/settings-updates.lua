-- Each profile has fresh, isolated settings. Set defaults rather than modifying
-- the candidate ZIP or fabricating a mod-settings.dat file.
local config = require("config")
for kind, prototypes in pairs(data.raw) do
    if kind:match("%-setting$") then
        for name, value in pairs(config.settings or {}) do
            if prototypes[name] then prototypes[name].default_value = value end
        end
    end
end
