#!/usr/bin/env python3
"""Refresh typed localization API fixtures; expected text comes from bundled .strings files."""
import argparse
import json
from pathlib import Path
import re


def symbols(path):
    namespaces = []
    for index, line in enumerate(path.read_text().splitlines()):
        indent = len(line) - len(line.lstrip())
        enum = re.match(r"\s*public enum (\w+) \{", line)
        if enum:
            while namespaces and namespaces[-1][0] >= indent:
                namespaces.pop()
            namespaces.append((indent, enum[1]))
        elif "public static " in line:
            while namespaces and namespaces[-1][0] >= indent:
                namespaces.pop()
            yield ".".join(name for _, name in namespaces), line, index


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    source = root / "Common/RuuviLocalization/Sources"
    output = args.output
    output.mkdir(parents=True, exist_ok=True)
    lines = (source / "RuuviLocalization.swift").read_text().splitlines()
    # Each API reference is captured once. Tests independently read packaged resources.
    pending = iter(symbols(source / "RuuviLocalization.swift"))
    entries = []
    for namespace, line, index in pending:
        constant = re.search(r'public static let (`?\w+`?) = .*?tr\("Localizable", "([^"]+)"', line)
        if constant:
            name, key = constant.groups()
            reference = namespace + "." + name
            entries.append((key, [], "{ " + reference + " }", "{ " + reference + "($0) }"))
            continue
        function = re.search(r"public static func (`?\w+`?)\(([^)]*)\)", line)
        if not function or "_ locale:" in function[2]:
            continue
        parameters = re.findall(r"_ p\d: (\w+)", function[2])
        if not parameters:
            continue
        body = lines[index + 1]
        key = re.search(r'tr\("Localizable", "([^"]+)"', body)[1]
        values = []
        for index, kind in enumerate(parameters):
            values.append({
                "Any": json.dumps("Sensor " + str(index + 1) + " 🌡️", ensure_ascii=False),
                "Int": str(1234 + index),
                "Float": "Float(" + str(13.25 + index) + ")",
            }[kind])
        reference = namespace + "." + function[1]
        call = ", ".join(values)
        entries.append((key, values, "{ " + reference + "(" + call + ") }",
                        "{ " + reference + "(" + call + ", $0) }"))
    assert len({key for key, *_ in entries}) == len(entries)
    groups = []
    for number, offset in enumerate(range(0, len(entries), 32)):
        name = "catalog" + str(number)
        groups.append(name)
        text = "import Foundation\nimport RuuviLocalization\n\nextension LocalizationCatalog {\n"
        text += "    static let " + name + ": [LocalizedStringContract] = [\n"
        for key, values, default, localized in entries[offset:offset + 32]:
            text += '        .init(key: "' + key + '", arguments: [' + ", ".join(values) + "],\n"
            text += "              defaultValue: " + default + ",\n"
            text += "              localized: " + localized + "),\n"
        text += "    ]\n}\n"
        (output / ("LocalizationCatalog" + str(number) + ".swift")).write_text(text)
    (output / "LocalizationCatalog.swift").write_text(
        "enum LocalizationCatalog {\n    static let all: [LocalizedStringContract] =\n        "
        + " +\n        ".join(groups) + "\n}\n")
    for file, kind in [("RuuviAsset", "Image"), ("RuuviColor", "Color")]:
        entries = []
        for namespace, line, _ in symbols(source / (file + ".swift")):
            match = re.search(r'public static let (`?\w+`?) = ' + kind + r'Asset\(name: "([^"]+)"', line)
            if match:
                entries.append((match[2], namespace + "." + match[1]))
        text = "import RuuviLocalization\n\nextension AssetCatalog {\n"
        text += "    static let " + kind.lower() + "s: [(String, " + kind + "Asset)] = [\n"
        for name, reference in entries:
            text += '        ("' + name + '", ' + reference + "),\n"
        text += "    ]\n}\n"
        (output / (kind + "Catalog.swift")).write_text(text)
    print(f"Wrote {len(groups)} string fixture groups and image/color catalogs to {output}")


if __name__ == "__main__":
    main()
