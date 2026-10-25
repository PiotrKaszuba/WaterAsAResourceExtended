"""Small native-engine acceptance runner. Standard library only; independent of mocks.

The isolation / CLI-and-result-file approach follows PoweredBeltsExtended's runner.
This version stages an unchanged candidate ZIP and retains all logs and test saves.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import sys
import time
import uuid
import zipfile

ROOT = Path(__file__).resolve().parents[2]
BASE_CASES = ("prototypes", "prototypes-disabled", "pumping", "landfill", "resume", "pump-transitions", "upgrade", "persist", "scan_merge")
CASES = (*BASE_CASES, "partners")


def invoke(binary: Path, args: list[str], log: Path, timeout: int) -> None:
    with log.open("w", encoding="utf-8") as output:
        try:
            process = subprocess.run([str(binary), *args], stdout=output,
                                     stderr=subprocess.STDOUT, timeout=timeout)
        except subprocess.TimeoutExpired as exc:
            raise RuntimeError(f"Factorio timed out; see {log}") from exc
    if process.returncode:
        raise RuntimeError(f"Factorio exited {process.returncode}; see {log}\n"
                           + log.read_text(encoding="utf-8", errors="replace")[-3500:])


def archive_info(archive: Path) -> dict:
    with zipfile.ZipFile(archive) as z:
        candidates = [n for n in z.namelist() if n.replace("\\", "/").split("/")[-1] == "info.json"]
        if len(candidates) != 1:
            raise ValueError("Candidate ZIP must contain exactly one info.json")
        return json.loads(z.read(candidates[0]).decode("utf-8-sig"))


def serve_until_result(binary: Path, args: list[str], log: Path, result: Path,
                       saves: Path, timeout: int) -> None:
    """Stop our isolated server after the result and any checkpoint are written."""
    with log.open("w", encoding="utf-8") as output:
        process = subprocess.Popen([str(binary), *args], stdout=output, stderr=subprocess.STDOUT)
        deadline = time.monotonic() + timeout
        try:
            while process.poll() is None and time.monotonic() < deadline:
                if result.exists():
                    try:
                        status = json.loads(result.read_text(encoding="utf-8"))["status"]
                    except (json.JSONDecodeError, KeyError):
                        status = None
                    if status in {"passed", "failed"}:
                        return
                    if status == "checkpoint" and any(zipfile.is_zipfile(p)
                            for p in saves.glob("*water-acceptance-checkpoint*.zip")):
                        return
                time.sleep(0.05)
            raise RuntimeError(f"Server exited or timed out before its result/checkpoint; see {log}")
        finally:
            if process.poll() is None:
                process.terminate()
            process.wait(timeout=10)


def run_case(binary: Path, archive: Path, info: dict, case: str, output: Path,
             timeout: int, partner_mods: list[Path]) -> dict:
    output.mkdir()
    fixture = None
    if case == "upgrade":
        origin = ROOT / "tests/integration/fixtures/2.0.4"
        fixture = json.loads((origin / "provenance.json").read_text(encoding="utf-8"))
        original = origin / "water-acceptance-checkpoint.zip"
        if hashlib.sha256(original.read_bytes()).hexdigest() != fixture["save_sha256"]:
            raise ValueError("Old-engine fixture checksum mismatch")
    mods, user = output / "mods", output / "user-data"
    mods.mkdir()
    user.mkdir()
    (user / "saves").mkdir()
    shutil.copy2(archive, mods / f"{info['name']}_{info['version']}.zip")
    partners = []
    names = {"base", info["name"], "WaterAcceptanceHarness"}
    for partner in partner_mods:
        metadata = archive_info(partner)
        if metadata["name"] in names:
            raise ValueError(f"Duplicate staged mod: {metadata['name']}")
        names.add(metadata["name"])
        shutil.copy2(partner, mods / f"{metadata['name']}_{metadata['version']}.zip")
        partners.append({"name": metadata["name"], "version": metadata["version"],
            "sha256": hashlib.sha256(partner.read_bytes()).hexdigest()})
    harness = mods / "WaterAcceptanceHarness_0.1.0"
    shutil.copytree(ROOT / "tests/integration/harness_mod", harness)
    setting_overrides = {"Enable-Waterfill": False} if case == "prototypes-disabled" else {}
    scenario = "prototypes" if case == "prototypes-disabled" else case
    (harness / "config.lua").write_text(
        "return {scenario=" + json.dumps(scenario) + ", target_version=" + json.dumps(info["version"])
        + ", reference_remaining=" + (str(fixture["expected_settled_remaining"]) if fixture else "nil") + ", settings={"
        + ",".join(f"[{json.dumps(k)}]={json.dumps(v)}" for k, v in setting_overrides.items())
        + "}}\n", encoding="utf-8")
    (mods / "mod-list.json").write_text(json.dumps({"mods": [
        {"name": n, "enabled": True} for n in sorted(names)
    ] + [{"name": n, "enabled": False} for n in ("space-age", "quality", "elevated-rails")
         if n not in names]}), encoding="utf-8")
    config = output / "factorio.ini"
    config.write_text("[path]\nread-data=" + (binary.parents[2] / "data").as_posix()
                      + "\nwrite-data=" + user.as_posix() + "\n", encoding="utf-8")
    map_settings = output / "map-gen.json"
    map_settings.write_text(json.dumps({"seed": 51773, "width": 256, "height": 256,
                                       "water": "none", "starting_area": "none",
                                       "peaceful_mode": True}), encoding="utf-8")
    common = ["--mod-directory", str(mods), "--config", str(config)]
    if os.name == "nt":
        common.append("--disable-audio")
    save = output / "initial.zip"
    if case == "upgrade":
        shutil.copy2(original, save)
    else:
        invoke(binary, common + ["--create", str(save), "--map-gen-settings", str(map_settings)],
               output / "create.log", timeout)
    result_file = user / "script-output/water-result.json"
    phases = []
    for phase in (1, 2):
        launch = ["--load-game", str(save)]
        if case in {"resume", "upgrade", "persist"}:
            server_settings = output / "server-settings.json"
            example = binary.parents[2] / "data/server-settings.example.json"
            server_config = json.loads(example.read_text(encoding="utf-8-sig"))
            server_config.update({"name": "Water acceptance (local)", "auto_pause": False,
                "require_user_verification": False, "autosave_interval": 0,
                "non_blocking_saving": False})
            server_config["visibility"] = {key: False for key in server_config["visibility"]}
            server_settings.write_text(json.dumps(server_config), encoding="utf-8")
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
                sock.bind(("127.0.0.1", 0))
                port = sock.getsockname()[1]
            launch = ["--start-server", str(save), "--server-settings", str(server_settings),
                      "--bind", "127.0.0.1", "--port", str(port)]
        if case in {"resume", "upgrade", "persist"}:
            serve_until_result(binary, common + launch, output / f"phase-{phase}.log",
                               result_file, user / "saves", timeout)
        else:
            trial = (launch + ["--until-tick", str(18000 * phase)] if os.name == "nt" else
                     ["--benchmark", str(save), "--benchmark-ticks", str(18000 * phase), "--benchmark-runs", "1"])
            invoke(binary, common + trial,
                   output / f"phase-{phase}.log", timeout)
        if not result_file.exists():
            raise RuntimeError(f"Harness did not finish {case}; see {output / f'phase-{phase}.log'}")
        result = json.loads(result_file.read_text(encoding="utf-8"))
        phases.append(result)
        result_file.rename(output / f"phase-{phase}.json")
        if result["status"] == "passed":
            return {"case": case, "status": "passed", "phases": phases,
                    "fixture": fixture, "partners": partners}
        if result["status"] != "checkpoint" or phase != 1:
            raise RuntimeError(f"{case}: {result.get('extra')}; see {output}")
        saves = list((user / "saves").glob("*water-acceptance-checkpoint*.zip"))
        if len(saves) != 1:
            raise RuntimeError(f"Expected one native checkpoint save; found {saves}")
        save = saves[0]
    raise RuntimeError(f"{case} did not complete after native restart")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mod-zip", type=Path, required=True)
    parser.add_argument("--factorio-bin", type=Path, default=os.environ.get("FACTORIO_BIN"))
    parser.add_argument("--scenario", choices=CASES, action="append")
    parser.add_argument("--artifacts-dir", type=Path, default=ROOT / "tests/artifacts")
    parser.add_argument("--timeout", type=int, default=120)
    parser.add_argument("--partner-mod", type=Path, action="append", default=[],
                        help="Stage an actual partner ZIP unchanged; repeat for its dependencies")
    args = parser.parse_args()
    binary = args.factorio_bin or Path("C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe")
    binary, archive = binary.resolve(), args.mod_zip.resolve()
    output = args.artifacts_dir.resolve() / (time.strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:6])
    output.mkdir(parents=True)
    report = {"status": "failed", "archive": str(archive), "cases": []}
    try:
        # Rebuilding the source archive during a long run cannot change later
        # cases or make their bytes disagree with the recorded candidate hash.
        staged_archive = output / archive.name
        shutil.copy2(archive, staged_archive)
        archive = staged_archive
        version = subprocess.check_output([str(binary), "--version"], text=True, timeout=30)
        match = re.search(r"Version:\s*(\d+\.\d+\.\d+)", version)
        if not match or not match[1].startswith("2.1."):
            raise RuntimeError(f"This suite requires Factorio 2.1; binary reports {version.strip()}")
        report["engine"] = match[1]
        info = archive_info(archive)
        if info["name"] != "WaterAsAResourceExtended" or info["factorio_version"] != "2.1":
            raise ValueError("Expected a WaterAsAResourceExtended Factorio 2.1 candidate")
        report["mod_version"] = info["version"]
        report["sha256"] = hashlib.sha256(archive.read_bytes()).hexdigest()
        report["source_commit"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        report["source_dirty"] = bool(subprocess.check_output(
            ["git", "status", "--porcelain"], cwd=ROOT, text=True).strip())
        cases = args.scenario or (("partners", "landfill") if args.partner_mod else BASE_CASES)
        if "partners" in cases and not args.partner_mod:
            raise ValueError("The partners scenario needs explicit --partner-mod ZIPs")
        for case in cases:
            result = run_case(binary, archive, info, case, output / case, args.timeout, args.partner_mod)
            report["cases"].append(result)
            print(f"PASS {case}: {len(result['phases'][-1]['checks'])} checks", flush=True)
        report["status"] = "passed"
    except Exception as exc:
        report["error"] = str(exc)
        print(str(exc), file=sys.stderr)
    finally:
        (output / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(f"Artifacts: {output}", flush=True)
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
