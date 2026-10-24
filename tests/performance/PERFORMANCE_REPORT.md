# Pending-terrain visual guard: performance and decision record

Measured 24 October 2026. The user accepted the narrow guard on 25 October and it
is now merged into local development. The comparisons below retain their historical
unguarded-master/guard-branch labels. This is developer documentation, outside
the portal description; native Factorio 2.0 acceptance remains pending.

## What was compared

1. **Master:** shared performance workloads, no pending index or visual guard.
2. **Guard branch enabled:** the complete optional implementation, including
   enqueue/dequeue bookkeeping, old-state reconstruction, visual lookup, and
   candidate-attempt budgeting.
3. **Branch bypass:** test-only no-op index maintenance with an empty pending map.
   The branch's call sites, lookup instructions, and candidate bounds remain.
   This deliberately reproduces the known terrain race and is not a playable
   configuration or a new mod setting.

Two general rounds reverse checkout order, with two measured repetitions per
round and one discarded warmup per case. Focused comparisons alternate on/off
order inside one Lua process, with five measured pairs and discarded warmups.
The shared workload and runner files are byte-equivalent after line-ending
normalization in the compared checkouts; hashes are recorded in the manifest.

The 19 workloads range from small controls to 262,144-tile lakes, 1,024 pumps on
64 lakes, 16,384-tile visual work, and sixteen bursts of 8,192 queued edits. Large
standalone scans intentionally use a high throughput/budget (100,000) to stress
CPU work; the mixed scan/construction case uses the ordinary 2,000 work budget
and 1,000 scan tiles/second. Topology settlement also has a budget-500 case.

Timings use Windows native Lua 5.2 `os.clock()` CPU time with millisecond
resolution. GC stays enabled; setup and reporting are excluded, and full GC
precedes repetitions. Timed code includes mock API implementations, callback
instrumentation and deterministic sorted iteration. This is not a Factorio UPS
measurement. Four general observations and five focused pairs cannot establish
small differences, especially where identical pump code itself varies between
runs. Per-tick and per-slice tails have many more observations but remain
clock-limited, instrumented mock measurements.

## How to read the costs

The queue/index microbenchmarks isolate registration plus consumption on unowned
terrain. They still dispatch real landfill events, but have no topology work.
The repeated-position variant keeps only 16 unique pending positions; the unique
variant has 8,192 outstanding positions at each burst peak. Memory values are
retained Lua memory after collection for the whole queued representation, not
isolated map allocations or native-save size.

The pending visual cases intentionally put 95% of a lake under a queued brush.
The baseline can overwrite those landfills before accounting drains. Its later
split work therefore sees different physical terrain. The whole-branch timing
is useful as an observed behavior comparison, but the difference must not be
attributed entirely to checking a hash map—or described as pure overhead if it
includes necessary topology work that the incorrect baseline avoided.

An additional diagnostic uses identical correct physical terrain **and identical
dry-grid state** in both index modes, with no intervening visual work. This
decouples map bookkeeping from the effect of preserved landfill. Diagnostic
profiles record calls and inclusive/self CPU time in registration, dispatch,
owned-land searches, component checks, scans, successor creation, and bin work.
Those wrappers add overhead, so use them for attribution and deterministic work
counts; use the uninstrumented comparisons for throughput.

## Measurements

See [complete measured tables](results/2026-10-24/TABLES.md), the adjacent raw CSVs,
`summary.json`, and `manifest.json`. Phase totals, mean/min/max, individual
dry/reflood cycles, scan-slice/tick distributions, drain batches, completion ticks,
terrain corruption counts and retained queue memory are retained there.

## Findings and decision

**The position index is not the cause of the multi-second drain cost.** Paired
queue-only tests measured approximately 66 ms additional combined enqueue/consume
time per 131,072 unique-position edits (0.504 microseconds/edit), or 60 ms for
repeated-position edits (0.458 microseconds/edit). Separate enqueue medians were
131 versus 167 ms; consumption medians were 75 versus 113 ms. The combined delta
uses medians of whole phase sums, so it need not equal the sum of separate median
deltas. These are bulk-throughput estimates, not sub-millisecond event timers.

At 8,192 unique outstanding positions, retained queued-state memory rose by about
320 KiB. At only 16 unique positions it rose by less than 1 KiB. Reconstructing
8,192 queued positions took about 2.6 ms per rebuild in the paired test (84 ms
for 32 rebuilds). A test of larger real-save queues is still needed to extrapolate.

**Preserved landfill exposes an expensive existing neighbor-search pattern.**
In the 4,096-tile profile, 5.142 of 5.242 seconds went into repeated searches
through land still owned by the old lake. There were 590,532 terrain reads.
The overwritten baseline needed only 69,971 terrain reads and drained in 0.366 s.
This was **not additional component scanning**: scan starts fell from 393 to 1,
and component-search calls from 533 to 1. Neither case performed visual rebinning.
Those are diagnostic counts/times, not native API measurements.

The independent uninstrumented control keeps the same physical landfill and dry
grid in both modes: median consumption was 4.982 s with index maintenance
bypassed and 5.204 s enabled. Instrumented controls have exactly the same 590,532
terrain reads and one scan start in both modes. The expensive work remains even
without index bookkeeping. The small difference between those three-pair timings
cannot explain the order-of-magnitude difference from corrupted terrain.

The 16,384-tile/95%-overlap stress case is consequently very costly: whole-branch
paired phase medians were 58.997 s enabled versus 1.032 s bypassed, with different
physical terrain. General runs observed an eight-event drain batch as high as
110 ms. Those are deliberately severe accumulated workloads, not per-tick game
predictions. In the mixed default-budget case, preserved terrain instead reduced
settlement from 1,901 to 1,260 ticks and avoided overwritten landfill. There is no
single meaningful average percentage across these different behaviors.

### Why these searches repeat

The game applies a brush immediately, while the mod removes positions from lake
accounting later, in FIFO order. For a time, ground in the game is still listed
as belonging to the old lake. The split check walks through nearby owned ground
to find surviving wet/dry neighbors or evidence that it hit its search limit.
Subsequent queued removals can walk much of that same area again. Each walk is
bounded; the accumulated number of overlapping walks is expensive. This is
different from a new lake scan or visual rebinning.

### Remedy investigated, not accepted into production

A test-only variant skips the deep split search if a removed position has no
immediate surviving owned wet/dry neighbor. Frontier positions still run the
original search. The instrumented control dropped from 5.278 to 0.291 s, and
terrain reads from 590,532 to 66,200. It skipped 3,820 interior checks.

This also changed when the parent was invalidated: 3,821 removals occurred under
the valid parent versus 1,185 without the shortcut. Therefore matching appearance
and speed in this fixture is insufficient. Before accepting this small fast path,
test eventual topology and reserves with multiple cuts/islands, different brush
orders, delayed family finalization, pumps on separate successors, mixed wet/dry
capacity classes, and partial drains/reloads. The ordinary seedless-brush fix
already checks eventual two-component splitting and conserved depletion, but it
does not validate this experimental shortcut.

Combining split checks across a brush/body is another possible remedy, with more
state and ordering complexity. Increasing search bounds would increase the cost.
Optimizing the visual hash lookup or adding eager per-tile accounting would
target the wrong bottleneck demonstrated here.

**Recommendation:** accept the narrow index/visual guard on the performance
evidence, retain the current split algorithm, and investigate its repeated work
separately. The experimental shortcut is not a prerequisite for the guard and
must not be merged merely because it is faster. The user subsequently accepted
the narrow guard; ordinary Factorio 2.0 acceptance is still a release gate.

The direct bookkeeping/lookup cost is small in these mocks. The indirect effect
is real: by preserving landfill, the guard can make existing expensive terrain
processing occur instead of processing corrupted terrain. It would be wrong to
claim end-to-end timing cannot change, but also wrong to attribute that existing
search cost to maintaining or looking up pending positions.

### Why the first bypass scan timings looked much faster

Whole-suite sessions showed large differences even in unchanged pump code.
Neither scan-only implementation changed, and those fixtures have no pending
terrain edits. Session/system variation and cross-case mock heap/GC carryover
confound small causal comparisons; exact contributions were not measured.

Additional fresh-process controls rotate checkout order for each case, with six
observations per variant. The 65,536-tile scan medians became 1.764 s master,
1.871 s guard and 1.826 s bypass: the large bypass advantage disappeared. The
16,384-tile visual-cycle workload became 499.5, 500.0 and 511.5 ms respectively.
These do not resolve tiny lookup costs, but they contradict a large inherent scan
speedup. Keep the earlier tables as observed data, not evidence of such a speedup.

There are no new per-scanned-tile guards in `waterbody_scan.lua`. Shared periodic
queue processing does call `pending.ensure` even for an empty queue, so there is
a small real path cost outside scanning. The fresh scan ranges overlap: master
1.712–1.855 s, bypass 1.754–1.858 s, enabled 1.802–2.058 s. Their ordered medians
do not establish that this check causes the full difference, or that overhead is
zero. No CPU-frequency, allocator or GC attribution was measured.

## Final verification

- Master default regressions: 30 files, 910 passing assertion lines, zero failures.
- Rebased optional branch: 32 files, 933 passing assertion lines, zero failures.
- Both explicit deferred terrain-race diagnostics pass on the optional branch.
- All 19 shared workloads pass on master, enabled branch and test-only bypass.
- Eight paired workloads, fresh-process controls and identical-terrain controls
  pass their applicable queue/progress/corruption assertions.
- The experimental interior shortcut was profiled in one controlled fixture;
  it has not passed general topology/family verification and is not production.
- Shared benchmark files remain identical on master and the rebased branch.

## Production changes made while building the tests

Two independently reproduced existing crashes were fixed on master, before the
guard comparison, and are shared by both checkouts:

- An empty visual-bin pop now returns its numeric count as zero. Repeated drying
  work previously compared a missing count with a number.
- A large queued brush can leave only border landfill within the bounded split
  search and no wet/dry seed. Retain the current body until later removals expose
  real seeds rather than attempting to choose among zero successors. This does
  not widen the search or add another pending-position guard.

These are separate commits with regression tests, not performance optimizations
hidden in the optional guard.

## Reproduction

From the guarded checkout, with a separate unguarded baseline checkout (for
example `c6204ba`, immediately before the guard merge):

```text
python tests/performance/compare_checkouts.py --main PATH_TO_UNGUARDED_BASELINE --guard . --out OUTPUT_DIRECTORY
python tests/performance/compare_controls.py --main PATH_TO_UNGUARDED_BASELINE --out OUTPUT_DIRECTORY/controls
python tests/performance/run_attribution.py OUTPUT_DIRECTORY
python tests/performance/summarize.py OUTPUT_DIRECTORY
lua tests/performance/profile_drain.lua pending_dense_4096 on
lua tests/performance/profile_drain.lua pending_dense_4096 off
lua tests/performance/profile_drain.lua pending_dense_4096 on same-terrain
lua tests/performance/profile_drain.lua pending_dense_4096 off same-terrain
```

`profile_drain.lua ... on same-terrain interior-skip` is a diagnostic hypothesis:
skip deep split searching for a removed position with no immediate surviving
owned wet/dry neighbor. It does not modify production code. Any apparent speedup
needs separate topology/family regression coverage before it can be accepted.

No native Factorio 2.0 performance or gameplay acceptance has been performed for
this comparison. The real-engine release gate remains in place.
