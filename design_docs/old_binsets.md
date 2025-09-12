
# Dev notes

1. Old binsets is a chain of previous binsets that are not emptied yet. Binset becomes obsolete and is inserted to the front (1st index) of old binsets when centroid changes. There is no preserving of binsets from "loser" of merge. The binset might change due to potential centroid change, and its tiles will be tracked by callback that adds to pending tiles while copying from lazy tables of water/dried grids of that "loser" ("truth sources" of its contents).

a) Old binsets are used to pop from and push to new binset (potentially through pending tiles first). 
b) If we dropped them we would lose references to which current water tiles are being tracked by new binset and pending tiles. This way we don't have to look at/iterate the whole table/grid of water tiles and compare which ones do we track or not.
c) New binset is being popped from when drying process demands. If it is missing sufficient amount of tiles required run copying procedure immediately for required amount of tiles.
d) There is a potential problem with order of visual depletion around existing old binsets, their writing to pending tiles and also restored tiles that end up in pending tiles. However, it might probably be ignored as it will probably happen infrequently and might still look acceptable.
e) There needs to be some sort of balance between copying from old binsets and consuming pending tiles. One could get clever and depending on the situation prioritize one or even check distances from old binsets against current tiles in new binset to prioritize better. However, as in point d - it might probably be ignored and still look good enough most of the time.
f) There is a potential to generate a lot of repeated moving work from old binsets during times of frequent centroid change - such as scanning. If the waterbody is scanning prefer to first consume all pending tiles.
g) When restoring tiles remember to **somehow** bring front back, i.e. reduce front index or disable front and fill bins normally (depending on implementation).
h) When front becomes inactive - the backfill could be consumed and added to bins.


# AI notes

**Some of notes were reviewed and edited by dev.**

---

This is solid! I’d add a few clarifications and guard-rails so future you (or another dev) knows *why* things look the way they do—and how to keep them stable.

Here’s what I’d append to your summary as “design notes & operating rules”:

---

## Why old binsets exist (design intent)

* **Continuity across centroid shifts.** When the centroid jumps, `newBinset` may be small/cold; the most recently-built geometry still holds lots of good candidates. Keeping them as **old binsets** preserves that work so you don’t rescan truth.
* **Bounded work.** Every candidate is popped at most once from *some* binset and validated against truth; no global scans.

## When a binset becomes “old”

* On **significant centroid change**: if current `newBinset` is nonempty, push it to **front of `oldBinsets`** and start a fresh `newBinset` at the new centroid.
* On **merge**: nothing, most likely this results in centroid change, however.
* **Do nothing** special with old binsets; they’ll be evacuated over time.

## Source of truth & duplicates

* **Truth sets** (`waterGridWithData`, `driedTilesGridWithData`, + lazy layers) are authoritative.
* Binsets/queues/stacks hold **ids only**. Always **validate on pop**; stale/duplicate ids are dropped once and never seen again.

## Pending tiles policy

* `pendingTiles` is for **new water tiles entering the system** (waterfill, restore, merge in as water).
* Prefer **direct rehoming** for internal moves:

  * From **old binset → newBinset**: **pop** from old and **push** directly to new (no need to route through `pendingTiles`).
  * Rationale: one fewer hop, less dedupe work, same correctness.
* If you keep your “old → pending → new” path, ensure:

  * **dedupe** on `pendingTiles`,
  * a **small per-tick cap** so `pendingTiles` doesn’t starve evacuation.

## Drying order (pop source priority)

1. **`newBinset` first** (always dry from the freshest geometry).
2. If `newBinset` is empty, either:
   **(A)** evacuate a burst from `oldBinsets[1]` into `newBinset` and continue drying, or
   **(B)** dry directly from `oldBinsets[1]` **but** divert tiles that fall within `guard_bins` of `newBinset`’s frontier back into `newBinset`.
   (A) is purist; (B) keeps throughput under tight budgets.

## Backfill (lagging tiles)

* Use **DynamicBins backfill**: if a pushed tile has `ring ≤ frontier.max_ring`, it goes to `backfill` and is popped **before** frontier bins. This ensures tiles that show up “behind” the front dry first (prevents holes).

## Failure modes & fallbacks

* If `newBinset` + `oldBinsets` become empty but truth has water (rare): temporarily allow a **bounded sampling** from truth to re-prime `pendingTiles`.
* If a dry tile is discovered **not** on `driedStack`: push its id **now** (deduped). No ordering requirement for restore.

## Metrics worth tracking (cheap counters)

* `ticks_since_new_created`, `new.total`, `old[1].total`, `pending.size`, `driedStack.size`.
* Frontier window fill (`near_front_count`) each tick.

## Testing hooks (quick invariants)

* **Monotone pop** inside a bin: sort-on-first-use in DynamicBins head bin.
* **Bin capacity invariant**: after splits, no bin exceeds `cap`.
* **Disjointness**: `bin[i].min_ring ≤ bin[i+1].max_ring`.
* **Chain emptying**: with repeated centroid changes, all ids still drain once.

---

