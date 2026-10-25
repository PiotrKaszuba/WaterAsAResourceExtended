# Water history cleanup — 26 October 2026

## Purpose and preserved state

History/documentation cleanup only. Start from `release/2.0.5` at `0f5ae99`,
retaining the existing shared ownership, geometry, scan-accumulator and upgrade
repair fixes, default regressions, native scan_merge, ZIP packaging and measured
performance evidence. Reapply only the tested 2.1 layer from frozen `eb88e9c`.

- Original 2.1 tip: `archive/factorio-2.1-before-2.0.5-rebuild-2026-10-26`.
- Original 2.0.5 tip: `archive/release-2.0.5-before-history-cleanup-2026-10-26`.
- `v2.0.4` remains at `4ef5a4d`; `v2.1.0` and published 2.1 tip remain at `2870d11`.
- Current checkout's local `info.json` version 2.0.0 override and unrelated files
  stay untouched. A separate saved patch, manifest copy, file inventory and both
  accepted ZIPs live outside the repository under the history-rebuild work area.
- Accepted 2.0.5 ZIP SHA-256:
  `14f80c7eab962fdb9617e9bb22b2126a38fe054d1ede5aedd36163e615583b1a`.
- Previously tested 2.1.1 ZIP SHA-256:
  `c65d861d2a74424ae80cf522a7843faf0e5bd3052baf92379c4bc01f33791890`.

## Ownership of shared material

Shared fixes and combined 2026-10-25 reports originate on the 2.0.5 baseline and
are inherited, not reapplied. Historical source hashes/candidate hashes in those
reports retain their original meaning; archive references keep commits reachable.
A focused test verifies all supported old/new version pairs, including that
2.0.5 → 2.1.1 skips the already-applied one-time repair. Production code is unchanged.

The 2.1 layer is extracted into production APIs, test APIs, additional native
coverage, diagnostics/historical evidence, and final metadata/documentation.
Its commit messages identify source commits for partial adaptations.

Additional 2.0-native opportunities are [recorded separately](integration/2.0-NATIVE-COVERAGE-OPPORTUNITIES.md),
not added as part of this cleanup. The maintained branches use their respective
engine-specific mocks/fixtures; shared sources need not have identical API calls.

## Review and remote safety

The rebuilt lineage descends from 2.0.5, not published `factorio-2.1`. No remote
replacement or release-tag creation is authorized by this cleanup. Review the
rebuilt graph, comparison and fresh validation before choosing a new canonical
remote branch or explicitly approving a guarded replacement of the old branch.
The current checkout and published historical tags remain unchanged.

Fresh rebuild results belong in a separately dated record on the rebuilt 2.1
branch; the combined 2026-10-25 report must not be relabelled as new evidence.
