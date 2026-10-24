"""Fresh-process per-case controls reduce drift/heap carryover between checkouts."""
import argparse
import json
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--main", required=True, type=Path)
parser.add_argument("--out", required=True, type=Path)
parser.add_argument("--lua", default="lua")
args = parser.parse_args()
args.out.mkdir(parents=True, exist_ok=True)
cases = ["pumps_1024_many_lakes", "visual_16384", "scan_65536", "queue_unique_8192"]
variants = [("main", args.main, "run.lua"), ("on", Path.cwd(), "run.lua"),
            ("off", Path.cwd(), "run_disabled.lua")]
for round_number in range(1, 4):
    for case in cases:
        order = variants[round_number - 1:] + variants[:round_number - 1]
        for label, root, script in order:
            name = f"round{round_number}-{label}-{case}"
            print(name, flush=True)
            with (args.out / f"{name}.csv").open("wb") as output, (args.out / f"{name}.stderr.log").open("wb") as errors:
                result = subprocess.run([args.lua, f"tests/performance/{script}", "2", case, f"control-{label}"],
                                        cwd=root, stdout=output, stderr=errors, timeout=300)
            assert result.returncode == 0, name
(args.out / "protocol.json").write_text(json.dumps({"rounds": 3, "repetitions": 2,
    "warmups_per_process": 1, "cases": cases, "rotation": "main/on/off; on/off/main; off/main/on"}, indent=2) + "\n")
