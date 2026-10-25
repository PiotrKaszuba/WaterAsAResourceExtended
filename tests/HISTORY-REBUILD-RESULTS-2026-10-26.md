# Rebuilt Water 2.1.1 — history and verification

26 October 2026. History/documentation cleanup complete. Rebuilt branch:
`rebuild/factorio-2.1-on-2.0.5`. Local 2.0 maintenance branch:
`release/2.0.5`. No remote update or new release tag was performed.

## Resulting graph

```text
4ef5a4d  v2.0.4 / master
├─ shared fixes, regressions, packaging and performance evidence
│  └─ 0f5ae99  original completed 2.0.5 candidate
│     └─ 0922002  release/2.0.5: shared guidance + explicit upgrade routes
│        └─ 5d72b9f  2.1 production APIs
│           └─ d30d446  2.1 mock/native helper APIs
│              └─ e2ab560  extra native coverage
│                 └─ d997f17  2.1 diagnostics/historical evidence
│                    └─ 8fa4038  2.1.1 metadata and documentation
│                       └─ this dated verification record (documentation only)
└─ original 2.1 development
   └─ 2870d11  v2.1.0 / origin/factorio-2.1
      └─ eb88e9c  original factorio-2.1 checkout + archive reference
```

`0922002` and original `0f5ae99` are ancestors of the rebuilt 2.1.1.
Shared fixes `4ff318a`, `9432b11`, `392c146`, `7791b41` occur once in active
ancestry. Their duplicated old 2.1 commits are not ancestors of the rebuilt
branch. It does not descend from published `2870d11`.

Original 2.1 tip remains reachable as
`archive/factorio-2.1-before-2.0.5-rebuild-2026-10-26`; original 2.0.5 tip as
`archive/release-2.0.5-before-history-cleanup-2026-10-26`.
Both historical annotated tag objects and their targets are unchanged.

## Extraction provenance

| New commit | Extracted layer | Original source |
| --- | --- | --- |
| `5d72b9f` | `disabled_by_script` writes; recipe `categories` | Adapted from `a44fa3e`, final frozen `eb88e9c` |
| `d30d446` | Read-only active mock, engine fluid/connection helpers, API assertions and workload stop flag | Adapted from `c4fe954`, `a180331` |
| `e2ab560` | Upgrade/transitions/persistence/partners, test-only settings/force snapshots, retained 2.0 checkpoint | Adapted from `a180331`, `4b32576`, final frozen tree |
| `d997f17` | Exact GUI replay, damaged-save recovery, historical native/performance results | Adapted from `ea594bd`, `e442a0e`, `2870d11`, `150b3ab`, `eb88e9c` |
| `8fa4038` | Final 2.1.1 manifest, dependency floors and changelog/guidance | Adapted from `ab4f614`, `7b08c90` |

These are partial extractions, so commit bodies use “Adapted from” provenance
rather than pretending whole mixed historical commits were cherry-picked.
Shared fixes, native scan_merge, portable ZIP packaging, large workloads and
combined final reports are inherited directly from the 2.0 baseline.

## Content comparison with frozen eb88e9c

All **23 production Lua/prototype/locale files have identical Git blobs**.
The manifest is identical: mod 2.1.1, Factorio family 2.1,
`base >= 2.1.23`, optional `aai-industry >= 0.7.5` and existing incompatibilities.
All **14 measured workload/runner/mock/helper Lua sources are identical**.
No gameplay, pump logic, repair implementation or periodic work changed.

Every source-tree difference before this verification-only commit:

| File | Reason |
| --- | --- |
| `README.md` | Same 2.0.5 / 2.1.1 guidance on both branches; correct workload count; development-only history note |
| `changelog.txt` | 2.1.1 references inherited 2.0.5 fixes; historical 2.1.0 entry retained; actual 2.0.5 entry restored; earlier entries unchanged |
| `tests/HISTORY-REBUILD-2026-10-26.md` | Shared preservation/lineage/review policy |
| `tests/integration/2.0-NATIVE-COVERAGE-OPPORTUNITIES.md` | Deferred engine-coverage ideas, no harness expansion |
| `tests/integration/BUGFIX-2.0.5-2.1.1.md` | Distinguishes original cherry-pick preparation from rebuilt shared ancestry; dated original results unchanged |
| `tests/integration/LANDFILL-INVESTIGATION-2026-10-25.md` | Labels original diagnostic evidence; original versions and hashes retained |
| `tests/integration/RESULTS-2.1.md` | Labels original 2.1.0 evidence, not relabelled as fresh 2.1.1 |
| `tests/performance/PORT_2_1_REPORT.md` | Labels original port evidence; measurements unchanged |
| `tests/performance/README.md` | Repositions/clarifies historical port-report link |
| `tests/test_scan_accounting_upgrade.lua` | Explicit three affected old/new routes plus skip-repair assertion; originated on shared 2.0 baseline |

This final commit adds only this report, machine-readable validation and a
2.1 integration README link. It does not replace the dated 2026-10-25 evidence.

## ZIP comparison

Against the previously accepted 2.1.1 ZIP, the new ZIP has the corrected changelog
and one text line-ending difference: `modules/water_tiles.lua` is checked out as
CRLF rather than LF by Windows Git. Its committed blob and normalized bytes are
identical; no Lua text/token or runtime behavior differs. Every other packaged
file is byte-identical, including metadata. ZIP paths are portable forward-slash
paths and CRC/source-file checks passed. Archive timestamps/compression identity
are not a behavior comparison.

The accepted 2.0.5 ZIP is preserved byte-for-byte. No packaged 2.0 source or
changelog content changed; the fresh worktree has the same harmless water_tiles
checkout line endings, so there is no reason to replace its accepted archive.
Both prior ZIPs and the original checkout's version 2.0.0 override are untouched.

## Fresh verification

- Shared 2.0 mocks: 37 files, 1030 passing assertions.
- Rebuilt 2.1 mocks: 37 files, 1036 passing assertions.
- Exact rebuilt ZIP in Factorio 2.1.23: **nine profiles passed, 239 assertions across all phases**.
  Includes prototypes enabled/disabled, real pumping, robot landfill/mining,
  pending-state save/restart, pump transitions, real 2.0.4 upgrade/restart,
  extended persistence, and dry-enclosure scan/merge invariants. Base game only.
- Source, content, ancestor, non-ancestor, CRC, changelog order and identical
  README guidance assertions passed. Original checkout patches/untracked-file
  hashes and original tag/ZIP hashes were checked against the saved inventory.

| Upgrade route | Verification |
| --- | --- |
| 2.0.4 → 2.0.5 | Shared mock: repair once, counts/geometry corrected, reserve and pending FIFO preserved; accepted native 2.0.5 evidence retained |
| 2.0.4 → 2.1.1 | Same explicit mock route plus fresh native actual old-checkpoint upgrade and restart |
| 2.1.0 → 2.1.1 | Same explicit mock route; previous actual damaged-checkpoint recovery retained with identical runtime/replay sources |
| 2.0.5 → 2.1.1 | Mock explicitly spies zero calls to the already-applied repair |

Native routes not rerun here are clearly distinguished from fresh evidence.
No new 2.0-native harness work was added. Player update paths do not depend on
Git ancestry or require installing each intermediate mod release.

## Performance evidence reuse

No measured production/workload/mock/helper implementation changed against
frozen eb88e9c. Reuse the dated [bugfix performance review](performance/COUNTER-FIX-2026-10-25.md)
and its raw samples; no timing rerun is warranted for history, Markdown and test
assertion changes. The minor Lua checkout newline conversion changes no work.
No new periodic checks, queues, scans or saved data were introduced.

## Artifact and review gate

New `WaterAsAResourceExtended_2.1.1.zip` SHA-256:
`f545f571d93e3f3d2814092a8c3d35797acdf8f01ab50f5f16a640f2410eef06`.

Native run: `tests/artifacts/20261026-001723-168bbb/`.
Source used for the frozen build: `8fa4038e7791cefd08736667a6b0b61d8345853d`.

Full native results, exact blob lists and difference inventory:
[`integration/results/2026-10-26-history-rebuild.json`](integration/results/2026-10-26-history-rebuild.json).
Original backup copies/manifest patch/inventory remain outside the repo in
`catch-up-2026-10-26/water-history-rebuild/preserved-state/`.

**Recommended publication choice:** publish the rebuilt lineage under a new
canonical remote branch such as `release/2.1`, preserving `factorio-2.1`.
Alternatively, explicitly approve replacement of `factorio-2.1` with the rebuilt
branch, retaining its archive and historical tag. That needs an exact
`--force-with-lease` against a freshly checked remote tip, not an unconditional
force push. The original published tip observed during this task is
`2870d11cd7013b579391d750964d1391acb8e9a5`.

No branch replacement, remote publication or new v2.0.5/v2.1.1 tag has been done;
user review/choice comes first, as requested. The maintenance release branch was
fast-forwarded locally to the shared documentation/test commit only.
