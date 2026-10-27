# Performance workloads

Run from the mod root using native Lua 5.2:

```text
lua tests/performance/run.lua 7
lua tests/performance/run.lua 7 pending_dense label
```

Arguments: measured repetitions, optional literal case filter, optional CSV label.
Each case also gets one discarded warmup. Fixture construction and initial scans
are excluded except for the explicit scan workloads. Full GC precedes each
repetition; normal GC remains enabled during measured work. Console warnings are
silenced in timed code. Assertion failures terminate the run.

The shared suite covers:

| Concern | Workload / scale |
|---|---|
| Large connected resource / discovery | 4,096; 16,384; 65,536; 262,144 tiles |
| Tick hot path | 256 idle pumps; 1,024 mixed active/idle/inactive pumps on 64 lakes |
| Dry/reflood throughput | 24 full cycles of 1,024 tiles; four cycles of 16,384 tiles |
| Construction ingestion / FIFO maintenance | Sixteen bursts of 8,192 events, unique or repeated across 16 positions |
| Actual shoreline accounting | 192 removed tiles, batches of eight, conserved depletion |
| Topology and lifecycle | Eight lakes cut then reopened; budget 500; exact zero-water reopening |
| Pending visual overlap | 2% and 95%; 1,024 / 4,096 / 16,384 tiles; separate drying case |
| Mixed workload | 2,048 pending removals + restoration + new 16,384-tile scan; default budget 2,000 |
| Old-save/configuration derived-index rebuilding | 8,192 queued edits; 32 rebuilds when the implementation exists |

The large cases are stress envelopes for mid/late-game factories, not a claim
that every factory has that pump count or queue length. Queue microbenchmarks
deliberately isolate index maintenance on unowned terrain; shoreline, topology
and mixed cases separately exercise expensive real accounting.

CSV includes complete phase CPU times, individual dry/reflood cycle distributions,
scan-slice and tick distributions during settlement, event-drain batch timings,
completion ticks, selected/changed counts, and overwritten landfill. Quantiles
use nearest rank. Native `os.clock()` on the measured Windows Lua build resolves
milliseconds: sub-millisecond requests often report zero. Use aggregate timings
for throughput; individual maxima are observations, not guaranteed upper bounds.
Do not infer precise sub-millisecond p99 costs from these counters.

Known baseline visual races are counted rather than asserted away. A faster
baseline that overwrites terrain has performed incorrect work. Common assertions
still enforce FIFO completion, unaffected visual progress, stable capacity and
zero-water reopening where those invariants are comparable. The ordinary fast
correctness suite remains `lua tests/run.lua`; these longer workloads run separately.

These are mock CPU measurements including Lua mock API, deterministic `pairs`,
instrumentation and GC costs. They cannot predict Factorio UPS, native `set_tiles`
costs, save serialization or a different machine. No fragile percentage timing
threshold is used as a correctness gate.

## 2.0.5 / 2.1.1 scan and upgrade regressions

`dry_merge_16384` retains a 128×128 depleted lake, seven pumps and a gradual
cut through dry terrain. It measures the fixed lifecycle window, merge count,
dry-count gap and remaining visual work. `repair_wet_262144` and
`repair_dry_65536` separately measure the one-time affected-save repair, excluding
fixture setup. These run with the optional suite, independently of fast mocks.
See [the measured comparison and limits](COUNTER-FIX-2026-10-25.md).

The original 2.1 API-normalized port comparison found no reproduced large pump
collection regression: seven alternating pairs measured 0.572 / 0.584 s for
1024000 mixed pump samples, with overlapping ranges. This compares algorithms
against the same mock API, not native engine versions. Historical raw port samples
are available at `b445cd3`; final bugfix data remain linked above.
