# Genuine old-engine upgrade fixture

`water-acceptance-checkpoint.zip` was saved by **Factorio 2.0.77**, with Water
**2.0.4**, during synthetic native acceptance. It is not a personal save and has
not been rewritten by 2.1. The runner verifies the SHA-256 in `provenance.json`
and loads only disposable copies.

The original run used mod source `56383b8`; the final `v2.0.4` tag only added
acceptance documentation, changelog and README changes afterward. Original tested
ZIP SHA-256: `e5ce762578e3882e540bb1a91b2b303bb6a50f1e8a2c738c8a1633e2759c9c6c`.

The saved lake has 512 tiles, three pumps, partial depletion and active visual
work, with 128 announced landfill edits queued. The original continuation settled
to 384 tiles / 76,800 capacity and no pending entries. The upgrade test also
compares its settled reserve with that original 2.0 continuation. Historical phase results
are included; phase 1 was emitted shortly after the save request, not at precisely
the saved tick. Do not require identical cross-engine tick timing.

This fixture proves conversion of the represented state. Nondefault settings,
completed research and covered typed dry-bed persistence are additionally tested
by the 2.1-created `persist` profile; they are not all present in this old save.

Run from the repository root:

```text
python tests/integration/run.py --mod-zip releases/WaterAsAResourceExtended_2.1.0.zip --scenario upgrade
```

The old engine is not required. Neither this save nor the test companion is
included in release packages.
