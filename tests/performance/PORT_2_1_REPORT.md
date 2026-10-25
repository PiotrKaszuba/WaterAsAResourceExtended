# Water 2.1 port: focused performance check

25 October 2026. **No reproducible large collection regression was found.**
Accounting/terrain algorithms are unchanged from `v2.0.4`. This check reuses four
retained workloads; it does not replace the existing 19-case suite, claim native
UPS performance, or repeat the earlier visual-guard adoption comparison.

## Comparable baseline

An isolated `git archive v2.0.4` export used the **same current mock, helper and
performance files** as the candidate (`c4fe954` for those fixtures). Only its three
old `active` writes were translated to inverse `disabled_by_script` writes so the
old algorithms could run against the same 2.1 mock API. No baseline gameplay or
algorithm fix was introduced. All production runtime modules except the gated
test-snapshot module then matched current source, after line-ending normalization.

This is deliberately an **API-normalized algorithm comparison**, not a timing
comparison of the old and new native engines. Comparing the original flat 2.0
mock `active` field with the new computed getter would measure a change in mock
implementation too. Native setter/getter costs cannot be established here.

Three measured repetitions and one discarded warmup were run for each side.
Native engine trials had finished before the reported runs. An earlier overlapping
pilot was excluded. The noisy 1,024-pump result was repeated with seven independent
pairs, each process doing a warmup and one measured repetition, alternating which
side ran first. CPU time is `os.clock()` from stock Windows Lua 5.2; sub-millisecond
ticks have insufficient resolution for precise tail-latency claims.

## Results

Times are seconds of mock CPU work. The collection rows cover many complete
collection passes, **not one game tick**.

| Workload / measured phase | Normalized 2.0 median | 2.1 median | Scope |
| --- | ---: | ---: | --- |
| 256 idle pumps, collection | 0.305 | 0.241 | 512,000 pump samples; three repetitions |
| 1,024 pumps / 64 lakes, collection | 0.572 | 0.584 | 1,024,000 mixed active/idle/inactive samples; seven alternating pairs |
| Dense 4,096-tile visual overlap, enqueue | 0.057 | 0.044 | 95% pending coverage |
| Same workload, visual phase | 0.040 | 0.021 | Existing guarded visual work |
| Same workload, queue drain | 10.627 | 8.542 | Existing expensive shoreline/split-neighbor processing |
| Mixed backlog + 16,384-tile scan, lifecycle | 1.080 | 1.073 | Default budget 2,000 and 2,048 pending removals |

The first quiet three-repetition 1,024-pump comparison gave medians **0.753 vs
0.940**. Its candidate samples ranged **0.650–1.068** despite identical collection
code. Alternating repeats narrowed this to baseline **0.547–0.637** and candidate
**0.551–0.597**, with medians **0.572 / 0.584** (about 2.1% apart, overlapping
ranges). The earlier apparent large increase did not reproduce. These results
also do not establish a speed improvement in workloads that timed faster.

Correctness/work counters agree:

- Dense overlap: **8,192 examined, 205 changed, 487 drain calls**, zero overwritten
  landfill on both sides, every measured repetition.
- Mixed workload: **1,260 settlement ticks**, zero overwritten landfill on both
  sides. Largest observed mocked tick was **0.126 s on both sides**; largest
  observed scan slice was **0.021 / 0.020 s**. These are stress-test mock CPU
  timings, not native simulation tick costs.
- Existing workload assertions enforce queue settlement and conservation.

The port therefore supplies no reason to change scanning/splitting or broaden
pending-position guards. Expensive dense-brush processing remains the existing
algorithm; its optimization stays deferred.

## Reproduce and retained data

[Raw CSVs, paired summary and method metadata](results/2026-10-25-water-2.1/)
retain all reported measured samples. On the candidate:

```text
lua tests/performance/run.lua 3 pumps_ water_2_1
lua tests/performance/run.lua 3 pending_dense_4096 water_2_1
lua tests/performance/run.lua 3 mixed_backlog_scan water_2_1
lua tests/performance/run.lua 1 pumps_1024_many_lakes water_2_1
```

For a comparable baseline, export `v2.0.4`, copy the current
`tests/mock`, `tests/helpers` and `tests/performance` fixtures into that disposable
export, and translate only the three activation writes in `modules/entities.lua`
to the 2.1 flag. Run the same commands there. The original branch/tag must not be
modified. The local prepared export remains under ignored
`tests/artifacts/water-2.1-performance-20261025/baseline/` and can be regenerated.

The full retained performance suite is still independently runnable as
`lua tests/performance/run.lua 7`; fast functional tests remain separate.
