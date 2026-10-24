-- Test-only bypass. Production has no user-facing feature switch.
-- Off mode removes index maintenance and leaves its map empty, but deliberately
-- retains branch call sites, visual lookup instructions and candidate bounds.
local pending = require("modules.pending_tile_events")
local enabled = {}
for key, fn in pairs(pending) do enabled[key] = fn end
local M = {}
function M.set(on)
    for key, fn in pairs(enabled) do pending[key] = fn end
    if not on then
        pending.add = function() end
        pending.finish = function() end
        pending.ensure = function() storage.PendingTileChanges = storage.PendingTileChanges or {} end
        pending.rebuild = function() storage.PendingTileChanges = {} end
    end
end
return M
