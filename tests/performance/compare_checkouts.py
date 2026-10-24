"""Read-only checkout comparison; run benchmarks sequentially, never concurrently."""
import argparse
import hashlib
import json
import platform
import shutil
import subprocess
import time
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--main", required=True, type=Path)
    parser.add_argument("--guard", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--lua", default="lua")
    parser.add_argument("--repeats", type=int, default=2)
    parser.add_argument("--rounds", type=int, default=2)
    parser.add_argument("--paired", type=int, default=5)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    shared = ["tests/performance/workloads.lua", "tests/performance/run.lua"]
    hashes = {}
    for name in shared:
        # Git checkouts may differ only in CRLF checkout normalization.
        contents = [(root / name).read_bytes().replace(b"\r\n", b"\n") for root in (args.main, args.guard)]
        assert contents[0] == contents[1], f"shared benchmark differs: {name}"
        hashes[name] = hashlib.sha256(contents[0]).hexdigest()
    metadata = {"started_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "platform": platform.platform(), "processor": platform.processor(),
                "lua": shutil.which(args.lua), "shared_sha256": hashes,
                "repeats": args.repeats, "rounds": args.rounds, "paired": args.paired}
    for label, root in (("main", args.main), ("guard", args.guard)):
        metadata[label] = {"path": str(root.resolve()), "commit": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()}
    (args.out / "manifest.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")

    def run(label, root, script, repetitions):
        print(f"Starting {label}", flush=True)
        start = time.monotonic()
        with (args.out / f"{label}.csv").open("wb") as output, (args.out / f"{label}.stderr.log").open("wb") as errors:
            result = subprocess.run([args.lua, f"tests/performance/{script}", str(repetitions), "", label]
                                    if script != "compare_guard.lua" else [args.lua, f"tests/performance/{script}", str(repetitions)],
                                    cwd=root, stdout=output, stderr=errors, timeout=1800)
        assert result.returncode == 0, f"{label} failed; see stderr log"
        print(f"Finished {label} in {time.monotonic() - start:.1f}s wall time", flush=True)

    variants = [("main", args.main, "run.lua"), ("guard-on", args.guard, "run.lua"),
                ("guard-off", args.guard, "run_disabled.lua")]
    for round_number in range(1, args.rounds + 1):
        order = variants if round_number % 2 else list(reversed(variants))
        for label, root, script in order:
            run(f"round{round_number}-{label}", root, script, args.repeats)
    run("paired", args.guard, "compare_guard.lua", args.paired)
    metadata["finished_utc"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    (args.out / "manifest.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
