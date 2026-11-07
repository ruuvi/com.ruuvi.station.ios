#!/usr/bin/env python3
"""Build libraries and run all app/module tests on a booted iOS simulator."""
import argparse
from datetime import datetime
import json
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", default="iPhone 18 Pro", help="Booted simulator name or UDID")
    parser.add_argument("--output", type=Path, required=True, help="New artifact directory")
    parser.add_argument("--minimum-coverage", type=float, help="Per-target coverage percentage to enforce")
    parser.add_argument("--minimum-total-coverage", type=float, help="Aggregate production coverage percentage to enforce")
    parser.add_argument("--minimum-app-coverage", type=float, help="Application production coverage percentage to enforce")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "booted", "-j"]))
    matches = [d for group in devices["devices"].values() for d in group
               if args.device in (d["name"], d["udid"]) and d["state"] == "Booted"]
    if len(matches) != 1:
        raise SystemExit("Specify exactly one booted simulator with --device.")
    device = matches[0]
    (output / "environment.json").write_text(json.dumps({
        "device": device, "startedAt": datetime.now().isoformat(),
        "commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
        "xcode": subprocess.check_output(["xcodebuild", "-version"], text=True).strip(),
    }, indent=2) + "\n")

    def run(label, command, cwd=root):
        print(label, flush=True)
        with (output / (label + ".log")).open("w") as log:
            subprocess.run(command, cwd=cwd, stdout=log, stderr=subprocess.STDOUT, check=True)

    run("behavior-baseline", [sys.executable, str(root / "scripts/test/generate_measurement_baseline.py"), "--check"])
    run("generate", ["make", "xcodeproj"])
    run("strings", [str(root / ".tools/swiftgen/bin/swiftgen"), "--config", ".swiftgen.localizable.yml"])
    run("assets", [str(root / ".tools/swiftgen/bin/swiftgen"), "--config", ".swiftgen.assets.yml"])
    destination = "platform=iOS Simulator,id=" + device["udid"]
    run("packages", ["xcodebuild", "-scheme", "RuuviPackageVerification", "-destination", destination,
                     "-derivedDataPath", str(output / "PackageBuild"), "build", "CODE_SIGNING_ALLOWED=NO"],
        cwd=root / "Tests/PackageVerification")
    for manifest in sorted(root.glob("*/Ruuvi*/Package.swift")):
        package = json.loads(subprocess.check_output([
            "swift", "package", "--package-path", str(manifest.parent), "dump-package"
        ]))
        name = package["name"]
        scheme = name if len(package["products"]) == 1 else name + "-Package"
        run("package-tests-" + name, ["xcodebuild", "-scheme", scheme, "-destination", destination,
                                     "-derivedDataPath", str(output / "PackageTestBuild"),
                                     "build-for-testing", "CODE_SIGNING_ALLOWED=NO"], cwd=manifest.parent)
    result = output / "AllTests.xcresult"
    run("tests", ["xcodebuild", "-project", "Ruuvi.xcodeproj", "-scheme", "AllTests",
                  "-destination", destination, "-derivedDataPath", str(output / "AppBuild"),
                  "-enableCodeCoverage", "YES", "-resultBundlePath", str(result), "test",
                  "CODE_SIGN_IDENTITY=-", "CODE_SIGNING_ALLOWED=YES"])
    coverage = [sys.executable, str(root / "scripts/test/coverage.py"), str(result),
                "--output", str(output / "coverage.json")]
    if args.minimum_coverage is not None:
        coverage.extend(["--minimum", str(args.minimum_coverage)])
    if args.minimum_total_coverage is not None:
        coverage.extend(["--minimum-total", str(args.minimum_total_coverage)])
    if args.minimum_app_coverage is not None:
        coverage.extend(["--minimum-app", str(args.minimum_app_coverage)])
    run("coverage", coverage)
    run("screenshots", ["xcrun", "xcresulttool", "export", "attachments", "--path", str(result),
                        "--output-path", str(output / "Screenshots")])
    print("Artifacts: " + str(output))


if __name__ == "__main__":
    main()
