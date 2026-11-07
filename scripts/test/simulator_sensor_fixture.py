#!/usr/bin/env python3
"""Temporarily populate an empty simulator database for real sensor UI tests.

The app must already have launched and migrated its database. Existing sensors,
measurements, and sensor settings are never replaced. Restoration removes only
the inserted fixture identities and preserves any other data added meanwhile.
"""
import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path
import sqlite3
import subprocess
import uuid


BUNDLE = "com.ruuvi.station"
SENSOR_ID = "C0:DE:25:02:00:01"
LOCAL_ID = "00000000-0000-4000-8000-000000002502"
SENSOR_TABLES = (
    "ruuvi_tag_sensors", "ruuvi_tag_sensor_records",
    "ruuvi_tag_sensor_record_latest", "sensor_settings",
)


def connect(path):
    # mode=rw avoids silently creating a new database at a mistaken path.
    return sqlite3.connect(path.as_uri() + "?mode=rw", uri=True)


def sensor_counts(connection):
    return {table: connection.execute(f'SELECT COUNT(*) FROM "{table}"').fetchone()[0]
            for table in SENSOR_TABLES}


def insert(connection, table, row):
    columns = ", ".join('"' + key + '"' for key in row)
    placeholders = ", ".join("?" for _ in row)
    connection.execute(f'INSERT INTO "{table}" ({columns}) VALUES ({placeholders})', tuple(row.values()))


def prepare(database, backup_dir, device):
    with connect(database) as connection:
        counts = sensor_counts(connection)
        if any(counts.values()):
            raise SystemExit("Refusing to replace existing sensor data: " + json.dumps(counts))
        backup_dir.mkdir(parents=True, exist_ok=False)
        backup = backup_dir / "original.sqlite"
        with sqlite3.connect(backup) as destination:
            connection.backup(destination)
        manifest = {
            "device": device, "bundle": BUNDLE, "originalDatabase": str(database),
            "sensorID": SENSOR_ID, "localID": LOCAL_ID, "originalCounts": counts,
            "backupSHA256": hashlib.sha256(backup.read_bytes()).hexdigest(),
            "status": "prepared", "preparedAt": datetime.now(timezone.utc).isoformat(),
        }
        # Save recovery information before the first write to the simulator.
        (backup_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        connection.execute("BEGIN IMMEDIATE")
        if any(sensor_counts(connection).values()):
            raise SystemExit("Sensor data appeared before fixture insertion; original data was not changed.")
        now = datetime.now(timezone.utc)
        insert(connection, "ruuvi_tag_sensors", {
            "id": SENSOR_ID, "mac": SENSOR_ID, "luid": LOCAL_ID,
            "name": "UI Test RuuviTag", "version": 5, "firmwareVersion": "3.31.1",
            "isConnectable": 0, "isClaimed": 0, "isOwner": 1,
            "isCloudSensor": 0, "canShare": 0, "sharedTo": "[]", "sharedToPending": "[]",
        })
        for index in range(24):
            row = {
                "id": str(uuid.uuid4()), "ruuviTagId": SENSOR_ID, "mac": SENSOR_ID,
                "luid": LOCAL_ID, "date": (now - timedelta(minutes=23-index)).strftime("%Y-%m-%d %H:%M:%S.%f")[:-3],
                "source": "advertisement", "rssi": -55, "version": 5,
                "celsius": 20 + index / 20, "relativeHumidityInPercent": 0.45,
                "hectopascals": 1013.25, "accelerationX": 0, "accelerationY": 0,
                "accelerationZ": 1, "volts": 3.0, "movementCounter": 2,
                "measurementSequenceNumber": index, "txPower": 4,
                "temperatureOffset": 0, "humidityOffset": 0, "pressureOffset": 0,
            }
            insert(connection, "ruuvi_tag_sensor_records", row)
        insert(connection, "ruuvi_tag_sensor_record_latest", row)
    print("Prepared one synthetic sensor and 24 measurements; original database backed up.")


def restore(database, backup_dir, device):
    manifest = json.loads((backup_dir / "manifest.json").read_text())
    if manifest["device"] != device or manifest["bundle"] != BUNDLE:
        raise SystemExit("Backup belongs to a different simulator or app.")
    if manifest["status"] == "restored":
        print("Fixture was already removed; nothing changed.")
        return
    backup = backup_dir / "original.sqlite"
    if hashlib.sha256(backup.read_bytes()).hexdigest() != manifest["backupSHA256"]:
        raise SystemExit("Backup checksum does not match; nothing restored.")
    with connect(database) as connection:
        connection.execute("BEGIN IMMEDIATE")
        for table in ("ruuvi_tag_sensor_records", "ruuvi_tag_sensor_record_latest"):
            connection.execute(f'DELETE FROM "{table}" WHERE ruuviTagId IN (?, ?)', (SENSOR_ID, LOCAL_ID))
        connection.execute("DELETE FROM sensor_settings WHERE macId = ? OR luid = ?", (SENSOR_ID, LOCAL_ID))
        connection.execute("DELETE FROM ruuvi_tag_sensors WHERE id = ?", (SENSOR_ID,))
        counts = sensor_counts(connection)
    manifest.update(status="restored", restoredAt=datetime.now(timezone.utc).isoformat(), restoredCounts=counts)
    (backup_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("Removed only the temporary sensor fixture; other data and the backup are preserved.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("prepare", "restore"))
    parser.add_argument("--device", required=True, help="Explicit booted simulator UDID")
    parser.add_argument("--backup-dir", type=Path, required=True)
    args = parser.parse_args()
    container = Path(subprocess.check_output(
        ["xcrun", "simctl", "get_app_container", args.device, BUNDLE, "data"], text=True).strip())
    database = container / "Documents/grdb.sqlite"
    if not database.is_file():
        raise SystemExit("Launch the installed app once to create its database before preparing a fixture.")
    termination = subprocess.run(["xcrun", "simctl", "terminate", args.device, BUNDLE], capture_output=True, text=True)
    if termination.returncode and "found nothing to terminate" not in termination.stderr.lower():
        raise SystemExit(termination.stderr)
    operation = prepare if args.action == "prepare" else restore
    operation(database, args.backup_dir.resolve(), args.device)


if __name__ == "__main__":
    main()
