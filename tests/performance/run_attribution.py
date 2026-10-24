"""Sequential, separate-process controls for the terrain-vs-bookkeeping effect."""
import argparse
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("out", type=Path)
parser.add_argument("--lua", default="lua")
args = parser.parse_args()
args.out.mkdir(parents=True, exist_ok=True)
profiles = args.out / "profiles"
profiles.mkdir(exist_ok=True)


def run(path, script, arguments):
    print(f"Starting {path.name}", flush=True)
    with path.open("wb") as output, path.with_suffix(".stderr.log").open("wb") as errors:
        result = subprocess.run([args.lua, f"tests/performance/{script}", *arguments], stdout=output,
                                stderr=errors, timeout=600)
    assert result.returncode == 0, f"{path.name} failed"


run(args.out / "preserved.csv", "compare_preserved.lua", ["3"])
for mode in ("off", "on"):
    run(profiles / f"behavior-{mode}.csv", "profile_drain.lua", ["pending_dense_4096", mode])
    run(profiles / f"preserved-{mode}.csv", "profile_drain.lua", ["pending_dense_4096", mode, "same-terrain"])
run(profiles / "experimental-interior-skip.csv", "profile_drain.lua",
    ["pending_dense_4096", "on", "same-terrain", "interior-skip"])
