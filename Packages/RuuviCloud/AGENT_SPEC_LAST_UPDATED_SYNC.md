# Agent Specification: lastUpdated-based Data Sync Collision Handling

## Overview

This document provides a complete specification for implementing "latest data wins" synchronization between the local SQLite database and cloud API in the Ruuvi Station iOS app.

### Problem Statement
- Cloud API already returns `lastUpdated` timestamps for sensors and settings
- Local database had NO `lastUpdated` fields
- Current sync logic blindly overwrites local data with cloud data
- Users lose local changes when they sync

### Solution
- When cloud data is newer → update local database
- When local data is newer → keep local data AND queue changes for cloud sync
- Never lose data

---

## Implementation Status

### COMPLETED

#### Phase 1: Database Schema & Model Updates

**1.1 Migration v19 Added**
- File: `Packages/RuuviContext/Sources/RuuviContextSQLite/SQLiteContextGRDB.swift`
- Added after line 325 (after v18 migration)
- Adds `lastUpdated` column to `RuuviTagSQLite` table
- Adds `displayOrderLastUpdated` and `defaultDisplayOrderLastUpdated` columns to `SensorSettingsSQLite` table

**1.2 RuuviTagSQLite Model Updated**
- File: `Packages/RuuviOntology/Sources/RuuviOntologySQLite/RuuviTagSQLite.swift`
- Added: `public var lastUpdated: Date?` property
- Added: `static let lastUpdatedColumn = Column("lastUpdated")`
- Updated: `init()`, `FetchableRecord`, `PersistableRecord`, `==` operator

**1.3 SensorSettingsSQLite Model Updated**
- File: `Packages/RuuviOntology/Sources/RuuviOntologySQLite/SensorSettingsSQLite.swift`
- Added: `displayOrderLastUpdated: Date?`, `defaultDisplayOrderLastUpdated: Date?`
- Added columns and updated all encoding/decoding/converters

**1.4 Protocol Definitions Updated**
- `Packages/RuuviOntology/Sources/RuuviOntology/Sensor/Sensor.swift`
  - `Claimable` protocol now includes `var lastUpdated: Date? { get }`
- `Packages/RuuviOntology/Sources/RuuviOntology/Sensor/SensorSettings.swift`
  - Added `displayOrderLastUpdated: Date?` and `defaultDisplayOrderLastUpdated: Date?`
- `Packages/RuuviOntology/Sources/RuuviOntology/Sensor/CloudSensor.swift`
  - `CloudSensorStruct` has `lastUpdated: Date?`
  - `AnyCloudSensor` has `lastUpdated` getter

**1.5 Struct Implementations & Helper Methods Updated**
- File: `Packages/RuuviOntology/Sources/RuuviOntology/Sensor/RuuviTag/RuuviTagSensor.swift`
- `RuuviTagSensorStruct` has `lastUpdated: Date?` property
- `AnyRuuviTagSensor` has `lastUpdated` getter
- ALL `with(...)` helper methods updated to preserve `lastUpdated`
- NEW: `func with(lastUpdated: Date?) -> RuuviTagSensor` helper added
- CRITICAL: `with(cloudSensor:)` now passes `cloudSensor.lastUpdated`

#### Phase 2: API Response Parsing

**2.1 CloudApiSensor Parsing Updated**
- File: `Packages/RuuviCloud/Sources/RuuviCloudApi/URLSession/Models/Response/RuuviCloudApiGetSensorsDenseResponse.swift`
- Added: `public let lastUpdated: Int?` (Unix timestamp)
- Added: `public var lastUpdatedDate: Date?` computed property
- Added to CodingKeys

**2.2 CloudApiSensorSettings Parsing Updated**
- Same file as above
- Added: `displayOrderLastUpdated: Int?`, `defaultDisplayOrderLastUpdated: Int?`
- Added: `displayOrderLastUpdatedDate: Date?`, `defaultDisplayOrderLastUpdatedDate: Date?` computed properties
- CodingKeys map to `displayOrder_lastUpdated` and `defaultDisplayOrder_lastUpdated`

**2.3 RuuviCloudSensorSettings Updated**
- File: `Packages/RuuviOntology/Sources/RuuviOntology/Sensor/CloudSensorDense.swift`
- Added: `displayOrderLastUpdated: Date?`, `defaultDisplayOrderLastUpdated: Date?`

**2.4 RuuviCloudPure Mapping Updated**
- File: `Packages/RuuviCloud/Sources/RuuviCloudPure/RuuviCloudPure.swift`
- `loadSensorsDense()` now passes `lastUpdated: sensor.lastUpdatedDate` to `CloudSensorStruct`
- Settings mapping passes `displayOrderLastUpdated` and `defaultDisplayOrderLastUpdated`

#### Phase 3: Sync Collision Resolution (PARTIAL)

**3.1 SyncCollisionResolver Helper Created**
- File: `Packages/RuuviService/Sources/RuuviServiceCloudSync/SyncCollisionResolver.swift`
- NEW FILE with:
```swift
public enum SyncAction {
    case updateLocal      // Cloud is newer
    case keepLocalAndQueue  // Local is newer
    case noAction         // Equal or both nil
}

public struct SyncCollisionResolver {
    private static let tolerance: TimeInterval = 2.0  // Clock skew tolerance

    public static func resolve(
        localTimestamp: Date?,
        cloudTimestamp: Date?
    ) -> SyncAction

    public static func resolve(
        isOwner: Bool,
        localTimestamp: Date?,
        cloudTimestamp: Date?
    ) -> SyncAction  // For shared sensors - always accept cloud if not owner
}
```

**3.2 Sensor Metadata Sync Modified**
- File: `Packages/RuuviService/Sources/RuuviServiceCloudSync/RuuviServiceCloudSyncImpl.swift`
- `syncSensors()` method now uses `SyncCollisionResolver`
- On `.updateLocal`: Updates local with cloud data (existing behavior)
- On `.keepLocalAndQueue`: Calls `queueSensorUpdateToCloud()`
- On `.noAction`: Returns nil (no update)

**3.3 Queue Helper Methods Added**
- Same file as above
- `queueSensorUpdateToCloud(_ sensor: RuuviTagSensor, macId: MACIdentifier)` - Calls `ruuviCloud.update(name:for:)`
- `queueDisplaySettingsToCloud(sensor:displayOrder:defaultDisplayOrder:)` - Calls `ruuviCloud.updateSensorSettings()`

---

### REMAINING WORK

#### Phase 3: Sync Collision Resolution (INCOMPLETE)

**3.4 Display Settings Sync - NOT DONE**
- File: `Packages/RuuviService/Sources/RuuviServiceCloudSync/RuuviServiceCloudSyncImpl.swift`
- Method: `displaySettingsSyncs()` (line ~340)
- Current code blindly updates local with cloud:
```swift
private func displaySettingsSyncs(
    denseSensors: [RuuviCloudSensorDense]
) -> [Future<SensorSettings, RuuviPoolError>] {
    denseSensors.compactMap { denseSensor in
        guard let sensorSettings = denseSensor.settings else { return nil }
        return ruuviPool.updateDisplaySettings(
            for: denseSensor.sensor.ruuviTagSensor,
            displayOrder: sensorSettings.displayOrderCodes,
            defaultDisplayOrder: sensorSettings.defaultDisplayOrder
        )
    }
}
```

**REQUIRED CHANGES:**
```swift
private func displaySettingsSyncs(
    denseSensors: [RuuviCloudSensorDense]
) -> [Future<SensorSettings, RuuviPoolError>] {
    denseSensors.compactMap { [weak self] denseSensor in
        guard let sensorSettings = denseSensor.settings else { return nil }

        // Get local settings to compare timestamps
        // Need to read local settings first via ruuviStorage

        let displayOrderAction = SyncCollisionResolver.resolve(
            isOwner: denseSensor.sensor.isOwner,
            localTimestamp: localSettings?.displayOrderLastUpdated,
            cloudTimestamp: sensorSettings.displayOrderLastUpdated
        )

        switch displayOrderAction {
        case .updateLocal:
            return self?.ruuviPool.updateDisplaySettings(
                for: denseSensor.sensor.ruuviTagSensor,
                displayOrder: sensorSettings.displayOrderCodes,
                defaultDisplayOrder: sensorSettings.defaultDisplayOrder,
                displayOrderLastUpdated: sensorSettings.displayOrderLastUpdated,
                defaultDisplayOrderLastUpdated: sensorSettings.defaultDisplayOrderLastUpdated
            )
        case .keepLocalAndQueue:
            // Queue local to cloud
            self?.queueDisplaySettingsToCloud(
                sensor: denseSensor.sensor.ruuviTagSensor,
                displayOrder: localSettings?.displayOrder,
                defaultDisplayOrder: localSettings?.defaultDisplayOrder
            )
            return nil
        case .noAction:
            return nil
        }
    }
}
```

**3.5 Offset Syncs - NOT DONE**
- File: `Packages/RuuviService/Sources/RuuviServiceCloudSync/RuuviServiceCloudSyncImpl.swift`
- Method: `offsetSyncs()` (line ~289)
- Use sensor-level `lastUpdated` for offset collision handling
- All offsets treated as part of sensor metadata

**3.6 Alert Syncs - NOT DONE**
- Alerts stored in UserDefaults, not SQLite
- Files:
  - `Packages/RuuviService/Sources/RuuviServiceAlert/RuuviServiceAlertImpl.swift`
  - `Packages/RuuviService/Sources/RuuviServiceAlert/AlertPersistence/UserDefaults/AlertPersistenceUserDefaults.swift`
- Need to add `updatedAt` storage for each alert type in UserDefaults
- Modify `sync(cloudAlerts:)` method to use collision resolution

#### Phase 4: Queue Methods & Local Timestamp Updates

**4.1 Update RuuviPool Methods - NOT DONE**
- File: `Packages/RuuviPool/Sources/RuuviPool/RuuviPool.swift`
- `updateDisplaySettings()` needs to accept and pass timestamp parameters

**4.2 Update RuuviPersistence Methods - NOT DONE**
- File: `Packages/RuuviPersistence/Sources/RuuviPersistenceSQLite/RuuviPersistenceSQLite.swift`
- Persistence methods need to store timestamps

**4.3 Update Local Timestamp on User Edits - NOT DONE**
- File: `Packages/RuuviService/Sources/RuuviServiceSensorProperties/RuuviServiceSensorPropertiesImpl.swift`
- When user updates sensor name, set `lastUpdated = Date()`:
```swift
func set(name: String, for sensor: RuuviTagSensor) {
    let updatedSensor = sensor
        .with(name: name)
        .with(lastUpdated: Date())  // ADD THIS
    pool.update(updatedSensor)
    // ... existing code ...
}
```

---

## Key Files Summary

| File | Status | Changes |
|------|--------|---------|
| `SQLiteContextGRDB.swift` | DONE | Migration v19 |
| `RuuviTagSQLite.swift` | DONE | lastUpdated column |
| `SensorSettingsSQLite.swift` | DONE | timestamp columns |
| `Sensor.swift` | DONE | Claimable protocol |
| `SensorSettings.swift` | DONE | timestamp properties |
| `CloudSensor.swift` | DONE | CloudSensorStruct |
| `RuuviTagSensor.swift` | DONE | All helpers updated |
| `RuuviCloudApiGetSensorsDenseResponse.swift` | DONE | API parsing |
| `CloudSensorDense.swift` | DONE | Settings struct |
| `RuuviCloudPure.swift` | DONE | Mapping |
| `SyncCollisionResolver.swift` | DONE | NEW helper |
| `RuuviServiceCloudSyncImpl.swift` | PARTIAL | Sensor sync done, display/offset/alert TODO |
| `RuuviServiceSensorPropertiesImpl.swift` | TODO | Set lastUpdated on edits |
| `RuuviPool.swift` | TODO | Method signatures |
| `RuuviPersistenceSQLite.swift` | TODO | Store timestamps |
| `AlertPersistenceUserDefaults.swift` | TODO | Alert timestamps |

---

## Edge Cases to Handle

1. **First Sync (nil local timestamp)**: Always accept cloud data
2. **cloudModeEnabled Flag**: When `true`, always use cloud regardless of timestamps
3. **Shared Sensors**: If `!isOwner`, always accept cloud data
4. **Clock Skew**: 2-second tolerance in SyncCollisionResolver
5. **Race Conditions**: Sync uses async/Future with proper queueing
6. **API Missing lastUpdated**: If cloud returns nil, keep local if local has timestamp
7. **New Sensor Discovery**: Set `lastUpdated = Date()` when adding locally

---

## API Response Structure Reference

From `Response.json`:
```json
{
  "sensors": [{
    "sensor": "AA:BB:CC:DD:EE:FF",
    "name": "My Sensor",
    "lastUpdated": 1751486555,
    "settings": {
      "displayOrder": "[\"temperature\",\"humidity\"]",
      "displayOrder_lastUpdated": 1763324396,
      "defaultDisplayOrder": "false",
      "defaultDisplayOrder_lastUpdated": 1763324396
    }
  }]
}
```

---

## Build Verification

After completing all changes:
```bash
xcodebuild -workspace station.xcworkspace -scheme "Ruuvi Station" -configuration Debug build
```

---

## Testing Checklist

- [ ] Change sensor name locally, sync, verify name preserved
- [ ] Change sensor name in cloud, sync, verify cloud wins if newer
- [ ] Test with `cloudModeEnabled=true` (should always use cloud)
- [ ] Change display order locally, sync, verify preserved
- [ ] Enable alert locally, sync, verify alert stays enabled
- [ ] Test offset changes collision
- [ ] Verify queued requests execute on next sync
- [ ] Test app upgrade with existing data - migration works
- [ ] Test fresh install - all data syncs correctly
