--[[
  binsets: Ring-bins data structure for distance-ordered tile processing.

  Concept
  -------
  Tiles are grouped into concentric "rings" around a centroid. Each ring is an
  integer index computed from the squared distance to the centroid divided by a
  quantization width (also squared). We avoid sqrt for performance.

  This module stores:
    • centerX, centerY           -- centroid used for quantization
    • ringWidthTiles             -- ring width in tiles (human-friendly)
    • ringWidthSquared           -- ringWidthTiles^2 (used for key computation)
    • ringsByIndex[ringIndex]    -- array (stack) of candidate tile ids
    • totalCandidates            -- total ids enqueued across all rings
    • headRingIndex              -- smallest nonempty ring index (frontier)
    • nonEmptyPrev/Next         -- DLL over existing ring indices for O(1) advance

  Usage in the tick pipeline
  --------------------------
  • push(): enqueue a tile id into the appropriate ring of the current binset
  • pop():  remove and return one id from the nearest (frontier) ring
  • All popped candidates must be validated against truth tables before use

  Notes
  -----
  • This structure is a cache for ordering only; membership truth lives elsewhere.
  • Duplicates and stale ids are fine: each id will be validated once on pop
    and then discarded or used.
]]
binsets = {}

-- ---- Constant accessors (placeholders; wire to settings/config later) ----

-- Width of each ring in tile units (human-readable).
function binsets.getDefaultRingWidthTiles()
    return 2.0
end

-- Minimum size that the building binset (newBinset) should reach before we
-- strongly prefer drying from it ("readiness" threshold).
function binsets.getDefaultMinNewBinsetSize()
    return 600
end

-- Number of rings near newBinset's frontier that we avoid drying from oldBinset
-- while rebuilding (freshness guard).
function binsets.getDefaultGuardBins()
    return 2
end

-- Hard cap on how many bin pops/inspections we allow per tick overall.
function binsets.getDefaultMaxLookPerTick()
    return 4000
end

-- Timeout (in ticks) to flip to the building binset even if below readiness.
function binsets.getDefaultFlipTimeoutTicks()
    return 180 -- ~3s at 60 tps
end

--[[
  Creates a new binset centered at (center_x, center_y).
  If ring_width_tiles is nil, a default is used (see getDefaultRingWidthTiles).

  Returns a table with fields described in the header comment.
]]
function binsets.new(center_x, center_y, ring_width_tiles)
    ring_width_tiles = ring_width_tiles or binsets.getDefaultRingWidthTiles()
    local ring_width_squared = ring_width_tiles * ring_width_tiles
    return {
        centerX = center_x,
        centerY = center_y,
        ringWidthTiles = ring_width_tiles,
        ringWidthSquared = ring_width_squared,

        ringsByIndex = {}, -- map: ringIndex -> array (stack) of ids
        totalCandidates = 0, -- total ids across all rings

        headRingIndex = nil, -- current frontier (smallest nonempty ring index)
        nonEmptyPrev = {}, -- DLL: prev ringIndex among nonempty rings
        nonEmptyNext = {}, -- DLL: next ringIndex among nonempty rings
    }
end

function binsets.set_center(binset, x, y)
    binset.centerX = x
    binset.centerY = y
end

--[[
  Computes the integer ring index for a tile position (x, y) relative to
  binset.centerX/Y using squared distance and the configured ring width.
]]
function binsets.computeRingIndex(binset, x, y)
    local dx = x - binset.centerX
    local dy = y - binset.centerY
    local d2 = dx * dx + dy * dy
    return math.floor(d2 / binset.ringWidthSquared)
end

-- Internal: insert a ringIndex into the nonempty DLL in sorted order.
local function linkRingIndex(binset, ringIndex)
    if binset.nonEmptyNext[ringIndex] or binset.headRingIndex == ringIndex then return end
    local head = binset.headRingIndex
    if not head then
        binset.headRingIndex = ringIndex
        return
    end
    if ringIndex < head then
        -- new head
        binset.nonEmptyNext[ringIndex] = head
        binset.nonEmptyPrev[head] = ringIndex
        binset.headRingIndex = ringIndex
        return
    end
    -- walk forward until position found (DLL keeps order sparse and short)
    local cur = head
    while true do
        local nxt = binset.nonEmptyNext[cur]
        if not nxt or ringIndex <= nxt then
            -- insert after cur
            binset.nonEmptyNext[cur] = ringIndex
            if nxt then binset.nonEmptyPrev[nxt] = ringIndex end
            binset.nonEmptyPrev[ringIndex] = cur
            binset.nonEmptyNext[ringIndex] = nxt
            return
        end
        cur = nxt
    end
end

-- Internal: remove ringIndex from the nonempty DLL (if present).
local function unlinkRingIndex(binset, ringIndex)
    local prev = binset.nonEmptyPrev[ringIndex]
    local nxt  = binset.nonEmptyNext[ringIndex]
    if prev then binset.nonEmptyNext[prev] = nxt end
    if nxt then binset.nonEmptyPrev[nxt] = prev end
    if binset.headRingIndex == ringIndex then binset.headRingIndex = nxt end
    binset.nonEmptyPrev[ringIndex] = nil
    binset.nonEmptyNext[ringIndex] = nil
end

-- Internal: ensure a bucket exists for ringIndex and return it.
local function ensureBucket(binset, ringIndex)
    local bucket = binset.ringsByIndex[ringIndex]
    if not bucket then
        bucket = {}
        binset.ringsByIndex[ringIndex] = bucket
        linkRingIndex(binset, ringIndex)
    end
    return bucket
end

--[[
  Enqueue a candidate id into its ring.
  Returns the computed ringIndex for convenience (e.g., metrics or debugging).

  NOTE: this does not validate membership; call sites must validate on pop.
]]
function binsets.push(binset, id, x, y)
    local ringIndex = binsets.computeRingIndex(binset, x, y)
    local bucket = ensureBucket(binset, ringIndex)
    bucket[#bucket + 1] = id
    binset.totalCandidates = binset.totalCandidates + 1
    return ringIndex
end

--[[
  Pop one id from the frontier (nearest nonempty ring).
  Returns (id, ringIndex) or (nil, nil) if empty.

  Robust to accidental empty buckets (defensive unlinking if needed).
]]
function binsets.pop(binset)
    local ringIndex = binset.headRingIndex
    while ringIndex do
        local bucket = binset.ringsByIndex[ringIndex]
        local n = bucket and #bucket or 0
        if n > 0 then
            local id = bucket[n]
            bucket[n] = nil
            binset.totalCandidates = binset.totalCandidates - 1
            if n - 1 == 0 then
                binset.ringsByIndex[ringIndex] = nil
                unlinkRingIndex(binset, ringIndex)
            end
            return id, ringIndex
        end
        -- Empty or missing bucket: clean up and try again at the new head
        if bucket ~= nil then binset.ringsByIndex[ringIndex] = nil end
        unlinkRingIndex(binset, ringIndex)
        ringIndex = binset.headRingIndex
    end
    return nil, nil
end

--[[
  Optional heuristic hook: split a too-large bucket into two adjacent rings.
  This is rarely necessary in Factorio-scale workloads, but provided for
  completeness. The current implementation is a no-op placeholder. You can
  implement by re-quantizing with a temporary finer granularity and repartition.
]]
function binsets.maybeSplitBucket(binset, ringIndex, maxBucketSize)
    local bucket = binset.ringsByIndex[ringIndex]
    if not bucket then return false end
    if #bucket <= (maxBucketSize or math.huge) then return false end
    -- TODO: implement partition into ringIndex and ringIndex+1 (or similar)
    return false
end
