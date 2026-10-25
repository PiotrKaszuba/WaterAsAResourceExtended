-- Derived bookkeeping for queued edits only, not history of covered terrain.
local pending = {}

function pending.has(surfaceName, gridKey)
    local positions = storage.PendingTileChanges and storage.PendingTileChanges[surfaceName]
    return positions ~= nil and positions[gridKey] ~= nil
end

function pending.add(event)
    local surface = event.surface.name
    local bySurface = storage.PendingTileChanges[surface]
    if not bySurface then
        bySurface = {}
        storage.PendingTileChanges[surface] = bySurface
    end
    local key = hot_utils.GridKey(event.position)
    bySurface[key] = (bySurface[key] or 0) + 1
end

function pending.finish(event)
    local surface = event.surface.name
    local bySurface = storage.PendingTileChanges[surface]
    local key = hot_utils.GridKey(event.position)
    local count = bySurface and bySurface[key]
    if count and count > 1 then
        bySurface[key] = count - 1
    elseif count then
        bySurface[key] = nil
        if next(bySurface) == nil then storage.PendingTileChanges[surface] = nil end
    end
end

function pending.rebuild(queue)
    storage.PendingTileChanges = {}
    for offset = 0, queue.size - 1 do
        pending.add(queue.buffer[(queue.head + offset - 1) % queue.capacity + 1])
    end
end

function pending.ensure(queue)
    if storage.PendingTileChanges == nil then pending.rebuild(queue) end
end

return pending
