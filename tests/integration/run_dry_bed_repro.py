"""Retained native diagnostic; independent of the passing acceptance suite.

Replays the recorded GUI inventory brushes on a disposable user checkpoint.
No production source, installed mods, original saves or Steam data are edited.
Released runtime is a negative control; current runtime must satisfy the invariants.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import uuid
import zipfile

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = Path(__file__).parent / "repros/dry-bed-loop"
LOCAL = ROOT / "tests/artifacts/active-drain-20261025"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def lua(value):
    if isinstance(value, dict):
        return "{" + ",".join("[" + json.dumps(k) + "]=" + lua(v) for k, v in value.items()) + "}"
    if isinstance(value, list):
        return "{" + ",".join(map(lua, value)) + "}"
    return json.dumps(value)


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--factorio-bin", type=Path, default=Path(
        "C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe"))
    p.add_argument("--checkpoint", type=Path)
    p.add_argument("--recovery", action="store_true", help="Test actual upgrade of the retained damaged GUI checkpoint")
    p.add_argument("--support-mods", type=Path, default=LOCAL / "mods")
    p.add_argument("--release-zip", type=Path, default=ROOT / "releases/WaterAsAResourceExtended_2.1.0.zip")
    p.add_argument("--variants", nargs="+", choices=("released", "current"),
        default=["released", "current"])
    p.add_argument("--cases", nargs="+", choices=("closed", "open"), default=["closed", "open"])
    p.add_argument("--require-clean", action="store_true",
        help="Exit nonzero if any dry-count/landfill invariant fails (released 2.1.0 is a negative control)")
    p.add_argument("--output", type=Path, default=ROOT / "tests/artifacts" / ("exact-dry-bed-" + uuid.uuid4().hex[:8]))
    args = p.parse_args()
    plan = json.loads((FIXTURE / "schedule.json").read_text(encoding="utf-8"))
    if args.recovery:
        args.cases = ["recovery"]
    args.checkpoint = args.checkpoint or (LOCAL / ("manual-editor-trial/water-manual-dry-bed-repro.zip"
        if args.recovery else "user/saves/_autosave-water-drain-with-player.zip"))
    expected_sha = plan["recovery_checkpoint_sha256"] if args.recovery else plan["checkpoint_sha256"]
    assert digest(args.checkpoint) == expected_sha, "Unexpected initial checkpoint; use the recorded fixture"
    version = subprocess.check_output([str(args.factorio_bin), "--version"], text=True)
    assert "2.1.23" in version, "This timing fixture requires Factorio 2.1.23"
    args.output.mkdir(parents=True, exist_ok=False)
    frozen = args.output / "initial.zip"
    shutil.copy2(args.checkpoint, frozen)
    report = {"engine": version, "checkpoint_sha256": digest(frozen),
        "release_zip_sha256": digest(args.release_zip), "schedule_sha256": digest(FIXTURE / "schedule.json"),
        "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "source_dirty": subprocess.check_output(["git", "status", "--short"], cwd=ROOT, text=True), "runs": []}
    for variant in args.variants:
        for case in args.cases:
            folder = args.output / (variant + "-" + case)
            mods = folder / "mods"
            shutil.copytree(args.support_mods, mods,
                ignore=shutil.ignore_patterns("WaterAsAResourceExtended*", "WaterAcceptanceHarness*", "__pycache__"))
            with zipfile.ZipFile(args.release_zip) as z:
                names = z.namelist()
                prefix = next(n for n in names if n.endswith("/info.json")).rsplit("/", 1)[0]
                assert all(not Path(n).is_absolute() and ".." not in Path(n).parts for n in names)
                z.extractall(mods)
                water = mods / prefix
                if variant != "released":
                    for name in names:
                        relative = Path(name).relative_to(prefix)
                        source = ROOT / relative
                        if source.is_file(): shutil.copy2(source, water / relative)
            # Source variants may have a newer manifest than the released ZIP.
            # A plain mod-name directory is valid independently of its version.
            plain = mods / "WaterAsAResourceExtended"
            water.rename(plain)
            water = plain
            production_hashes = {str(path.relative_to(water)): digest(path) for path in water.rglob("*.lua")}
            shutil.copy2(FIXTURE / "probe.lua", water / "exact_repro_probe.lua")
            with (water / "control.lua").open("a", encoding="utf-8") as f:
                f.write('\nrequire("exact_repro_probe")\n')
            companion_version = "0.1.1" if args.recovery else "0.1.0"
            companion = mods / ("WaterAcceptanceHarness_" + companion_version)
            companion.mkdir()
            (companion / "info.json").write_text(json.dumps({"name": "WaterAcceptanceHarness", "version": companion_version,
                "title": "Isolated exact dry-bed replay", "author": "PiotrKaszuba", "factorio_version": "2.1",
                "dependencies": ["base >= 2.1.23", "WaterAsAResourceExtended"]}), encoding="utf-8")
            shutil.copy2(FIXTURE / ("recovery.lua" if args.recovery else "control.lua"), companion / "control.lua")
            trial = dict(plan, variant=variant, case=case, end_tick=9876)
            if case == "open": trial["actions"] = plan["actions"][:-1]
            (companion / "plan.lua").write_text("return " + lua(trial), encoding="utf-8")
            user = folder / "user"
            user.mkdir()
            config = folder / "factorio.ini"
            config.write_text("[path]\nwrite-data=" + user.as_posix() + "\n", encoding="utf-8")
            with (folder / "engine.log").open("w", encoding="utf-8") as log:
                process = subprocess.run([str(args.factorio_bin), "--mod-directory", str(mods), "--config", str(config),
                    "--benchmark", str(frozen), "--benchmark-ticks", "2502", "--benchmark-runs", "1"],
                    stdout=log, stderr=subprocess.STDOUT, timeout=120)
            result_path = user / "script-output/result.json"
            assert process.returncode == 0 and result_path.exists(), "Engine/harness failure: " + str(folder / "engine.log")
            result = json.loads(result_path.read_text(encoding="utf-8"))
            assert result["harness_valid"], "Replay did not match the recorded GUI states: " + str(result_path)
            result["production_hashes_before_probe"] = production_hashes
            report["runs"].append(result)
            (args.output / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
            print(json.dumps({k: result[k] for k in ("variant", "case", "events", "covered", "lost", "settled", "invariant_passed")}
                | {"first_gap_tick": result.get("first_gap", {}).get("tick"), "final": result["final"]["bodies"],
                   "timeline_differences": len(result["before_differences"])}), flush=True)
    print("Retained report: " + str(args.output / "report.json"))
    if args.require_clean and any(not r["invariant_passed"] for r in report["runs"]):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
