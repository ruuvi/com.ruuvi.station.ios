#!/usr/bin/env python3
"""Report all first-party executable coverage; optionally enforce a per-target floor."""
import argparse
import json
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("result", type=Path, help="Xcode result bundle from AllTests")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--minimum", type=float, help="Required percentage for every executable target")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    project = json.loads(subprocess.check_output([
        "plutil", "-convert", "json", "-o", "-", str(root / "Ruuvi.xcodeproj/project.pbxproj")
    ]))
    objects = project["objects"]
    production_types = {
        "com.apple.product-type.framework", "com.apple.product-type.application",
        "com.apple.product-type.app-extension",
    }
    # Derive the denominator from the project, independently of the coverage scheme.
    # Omitting a production target from AllTests must fail verification, not hide that target.
    expected = {objects[target["productReference"]]["path"] for target in objects.values()
                if target.get("isa") == "PBXNativeTarget" and target.get("productType") in production_types}
    if not expected:
        raise SystemExit("The generated project must contain production coverage targets.")
    report = json.loads(subprocess.check_output([
        "xcrun", "xccov", "view", "--report", "--json", str(args.result)
    ]))
    targets = []
    for target in report["targets"]:
        if target["name"] not in expected:
            continue
        executable = target["executableLines"]
        targets.append({
            "name": target["name"],
            "coveredLines": target["coveredLines"],
            "executableLines": executable,
            "percent": 100 * target["coveredLines"] / executable if executable else None,
            "files": [{key: file[key] for key in ["path", "coveredLines", "executableLines", "lineCoverage"]}
                      for file in target.get("files", [])],
        })
    missing = sorted(expected - {t["name"] for t in targets})
    executable = sum(t["executableLines"] for t in targets)
    covered = sum(t["coveredLines"] for t in targets)
    output = {
        "result": str(args.result.resolve()), "missingTargets": missing,
        "coveredLines": covered, "executableLines": executable,
        "percent": 100 * covered / executable if executable else 0,
        "targets": sorted(targets, key=lambda t: t["name"]),
    }
    args.output.write_text(json.dumps(output, indent=2) + "\n")
    for target in output["targets"]:
        percent = target["percent"]
        value = f"{percent:.2f}%" if percent is not None else "no executable lines"
        print(f"{target['name']:36} {value}")
    print(f"Total: {output['percent']:.2f}% ({covered}/{executable})")
    if missing:
        print("Coverage is incomplete; missing: " + ", ".join(missing), file=sys.stderr)
        return 1
    if args.minimum is not None:
        below = [t["name"] for t in targets if t["percent"] is not None and t["percent"] < args.minimum]
        if below:
            print(f"Below {args.minimum:g}%: " + ", ".join(below), file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
