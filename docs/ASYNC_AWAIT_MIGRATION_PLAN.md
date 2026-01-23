# Future to Swift 6 Concurrency Migration Plan

## Executive Summary

This document outlines the comprehensive plan to migrate the Ruuvi iOS application from the deprecated **Future library** (https://github.com/kean/Future v1.3.0) to Swift's native **async/await** concurrency model with **Swift 6 strict concurrency** compliance.

### Why Combine Future Migration with Swift 6 Concurrency?

| Factor | Separate Migrations | Combined Migration |
|--------|--------------------|--------------------|
| Files touched | 54 files x 2 times | 54 files x 1 time |
| Code review cycles | 2 major reviews | 1 comprehensive review |
| Testing overhead | Test twice | Test once thoroughly |
| Technical debt | Accumulates between | Resolved immediately |
| Data race safety | Deferred | Immediate |

### Migration Scope
| Metric | Count |
|--------|-------|
| Files with Future imports | 51+ |
| `Future<>` declarations | 507 |
| `Promise` usages | 207 |
| `.on()` / `.observe()` callbacks | 341 |
| `Future.zip()` chains | 12+ |
| Packages with Future dependency | 8 |

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Swift 6 Concurrency Overview](#swift-6-concurrency-overview)
3. [Migration Strategy](#migration-strategy)
4. [Pattern Conversion Reference](#pattern-conversion-reference)
5. [Swift 6 Specific Patterns](#swift-6-specific-patterns)
6. [Phase-by-Phase Migration Plan](#phase-by-phase-migration-plan)
7. [Package Migration Order](#package-migration-order)
8. [File-by-File Checklist](#file-by-file-checklist)
9. [Testing Strategy](#testing-strategy)
10. [Rollback Plan](#rollback-plan)
11. [Common Pitfalls](#common-pitfalls)

---

## Prerequisites

### Requirements
- **Xcode 16.0+** (required for Swift 6)
- **Swift 6.0+** (for strict concurrency)
- **iOS Deployment Target**: iOS 15.0+ recommended (iOS 13.0+ minimum with back-deployment)

### Before Starting
1. Ensure all tests pass on the current codebase
2. Create a dedicated branch: `feature/swift6-concurrency-migration`
3. Review Swift Concurrency documentation
4. Set up CI to run tests on each commit
5. **Enable strict concurrency warnings first** (before errors):
   ```swift
   // In Package.swift, add to each target:
   swiftSettings: [
       .enableExperimentalFeature("StrictConcurrency")
   ]
   ```
   Or in Xcode: Build Settings → "Strict Concurrency Checking" → "Complete"

---

## Swift 6 Concurrency Overview

Swift 6 introduces **strict concurrency checking** that eliminates data races at compile time. This section covers the key concepts you'll need during migration.

### Key Concepts

#### 1. Sendable Protocol
Types that can safely cross concurrency boundaries must conform to `Sendable`:

```swift
// Value types are implicitly Sendable
struct SensorReading: Sendable {
    let temperature: Double
    let humidity: Double
    let timestamp: Date
}

// Reference types need explicit conformance
final class SensorConfig: Sendable {
    let id: String          // immutable = safe
    let name: String
    // No mutable state allowed!
}

// For classes with mutable state, use @unchecked Sendable carefully
// or convert to an actor
```

#### 2. Actors
Actors protect mutable state with automatic synchronization:

```swift
actor SensorCache {
    private var cache: [String: RuuviTagSensor] = [:]

    func get(_ id: String) -> RuuviTagSensor? {
        cache[id]
    }

    func store(_ sensor: RuuviTagSensor) {
        cache[sensor.id] = sensor
    }

    func clear() {
        cache.removeAll()
    }
}

// Usage requires await
let sensor = await sensorCache.get("abc123")
```

#### 3. @MainActor
UI code must run on the main thread:

```swift
@MainActor
class DashboardPresenter {
    weak var view: DashboardViewInput?

    func showSensors(_ sensors: [RuuviTagSensor]) {
        view?.display(sensors)  // Safe - guaranteed main thread
    }
}

// Or for individual functions
@MainActor
func updateUI(with data: SensorData) {
    // ...
}
```

#### 4. Isolation Boundaries
Understanding where isolation boundaries exist:

```swift
// nonisolated - opt out of actor isolation
actor DataManager {
    let identifier: String  // immutable, safe to access

    nonisolated var id: String {
        identifier  // No await needed
    }

    func process() async {
        // isolated to this actor
    }
}
```

#### 5. Sendable Closures
Closures crossing async boundaries must be `@Sendable`:

```swift
func fetchData(completion: @Sendable @escaping (Data) -> Void) {
    Task {
        let data = await loadData()
        completion(data)
    }
}
```

### Ruuvi-Specific Recommendations

Based on your codebase architecture:

| Layer | Recommendation |
|-------|----------------|
| **RuuviCloud** | Make all API response models `Sendable` (structs preferred) |
| **RuuviPersistence** | Convert `RuuviPersistenceSQLite` to an `actor` |
| **RuuviPool/Storage** | Convert coordinators to actors |
| **RuuviService** | Use `@MainActor` for services that update UI state |
| **Presenters** | Mark with `@MainActor` since they interact with views |
| **Data Models** | Ensure `RuuviTagSensor`, `SensorSettings`, etc. are `Sendable` |

---

## Migration Strategy

### Approach: Bottom-Up Package Migration

We will migrate packages from the **lowest dependency level** to the **highest**, ensuring each layer is stable before moving up.

```
Level 1 (Foundation): RuuviCore, RuuviLocal
         |
Level 2 (Persistence): RuuviPersistence, RuuviPool, RuuviStorage
         |
Level 3 (Network): RuuviCloud
         |
Level 4 (Business Logic): RuuviRepository, RuuviService
         |
Level 5 (App Layer): Apps/RuuviStation, Modules/RuuviDiscover
```

### Dual-Support Transition Period

During migration, use wrapper functions to maintain backwards compatibility:

```swift
// Old interface (to be deprecated)
func fetchData() -> Future<Data, Error>

// New interface
func fetchData() async throws -> Data

// Bridge for transition period
func fetchData() -> Future<Data, Error> {
    let promise = Promise<Data, Error>()
    Task {
        do {
            let result = try await fetchDataAsync()
            promise.succeed(value: result)
        } catch {
            promise.fail(error: error)
        }
    }
    return promise.future
}
```

---

## Pattern Conversion Reference

### Pattern 1: Basic Future Return Type

**Before:**
```swift
func fetchSensor(id: String) -> Future<Sensor, RuuviError> {
    let promise = Promise<Sensor, RuuviError>()
    database.fetch(id) { result in
        switch result {
        case .success(let sensor):
            promise.succeed(value: sensor)
        case .failure(let error):
            promise.fail(error: .database(error))
        }
    }
    return promise.future
}
```

**After:**
```swift
func fetchSensor(id: String) async throws -> Sensor {
    try await withCheckedThrowingContinuation { continuation in
        database.fetch(id) { result in
            switch result {
            case .success(let sensor):
                continuation.resume(returning: sensor)
            case .failure(let error):
                continuation.resume(throwing: RuuviError.database(error))
            }
        }
    }
}
```

**Or with modern async APIs:**
```swift
func fetchSensor(id: String) async throws -> Sensor {
    try await database.fetch(id)
}
```

---

### Pattern 2: Callback Chaining with `.on()`

**Before:**
```swift
ruuviCloud.getSensor(id: sensorId)
    .on(success: { sensor in
        self.updateUI(with: sensor)
    }, failure: { error in
        self.showError(error)
    })
```

**After:**
```swift
Task {
    do {
        let sensor = try await ruuviCloud.getSensor(id: sensorId)
        await MainActor.run {
            self.updateUI(with: sensor)
        }
    } catch {
        await MainActor.run {
            self.showError(error)
        }
    }
}
```

---

### Pattern 3: Queue Dispatch with `.observe(on:)`

**Before:**
```swift
ruuviCloud.getCloudSettings()
    .observe(on: .global(qos: .utility))
    .on(success: { settings in
        // runs on utility queue
    })
```

**After:**
```swift
Task(priority: .utility) {
    let settings = try await ruuviCloud.getCloudSettings()
    // runs on cooperative thread pool with utility priority
}
```

---

### Pattern 4: Future.zip() for Parallel Operations

**Before:**
```swift
let future1 = fetchSensor(id: "1")
let future2 = fetchSensor(id: "2")
let future3 = fetchSensor(id: "3")

Future.zip(future1, future2, future3)
    .on(success: { sensor1, sensor2, sensor3 in
        // handle all results
    }, failure: { error in
        // handle error
    })
```

**After:**
```swift
async let sensor1 = fetchSensor(id: "1")
async let sensor2 = fetchSensor(id: "2")
async let sensor3 = fetchSensor(id: "3")

do {
    let (s1, s2, s3) = try await (sensor1, sensor2, sensor3)
    // handle all results
} catch {
    // handle error
}
```

**Or with TaskGroup for dynamic arrays:**
```swift
func fetchAllSensors(ids: [String]) async throws -> [Sensor] {
    try await withThrowingTaskGroup(of: Sensor.self) { group in
        for id in ids {
            group.addTask {
                try await self.fetchSensor(id: id)
            }
        }

        var sensors: [Sensor] = []
        for try await sensor in group {
            sensors.append(sensor)
        }
        return sensors
    }
}
```

---

### Pattern 5: Protocol Definitions

**Before:**
```swift
protocol RuuviPool {
    func create(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPoolError>
    func update(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPoolError>
    func delete(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPoolError>
}
```

**After:**
```swift
protocol RuuviPool {
    func create(_ ruuviTag: RuuviTagSensor) async throws -> Bool
    func update(_ ruuviTag: RuuviTagSensor) async throws -> Bool
    func delete(_ ruuviTag: RuuviTagSensor) async throws -> Bool
}
```

---

### Pattern 6: Error Handling

**Before:**
```swift
enum RuuviCloudError: Error {
    case network(Error)
    case parsing(Error)
}

func fetch() -> Future<Data, RuuviCloudError>
```

**After:**
```swift
// Errors work the same way with async/await
enum RuuviCloudError: Error {
    case network(Error)
    case parsing(Error)
}

func fetch() async throws -> Data  // throws RuuviCloudError
```

---

### Pattern 7: Chained Futures with map/flatMap

**Before:**
```swift
fetchUser()
    .flatMap { user in
        self.fetchSettings(for: user)
    }
    .map { settings in
        settings.theme
    }
    .on(success: { theme in
        self.applyTheme(theme)
    })
```

**After:**
```swift
Task {
    let user = try await fetchUser()
    let settings = try await fetchSettings(for: user)
    let theme = settings.theme
    applyTheme(theme)
}
```

---

## Swift 6 Specific Patterns

### Pattern 8: Converting Classes to Actors (Shared State)

**Before (Thread-unsafe class):**
```swift
class RuuviPoolCoordinator: RuuviPool {
    private let sqlite: RuuviPersistence
    private var cache: [String: RuuviTagSensor] = [:]  // Mutable state!

    func create(_ tag: RuuviTagSensor) -> Future<Bool, RuuviPoolError> {
        let promise = Promise<Bool, RuuviPoolError>()
        sqlite.create(tag).on(success: { result in
            self.cache[tag.id] = tag  // Data race potential!
            promise.succeed(value: result)
        })
        return promise.future
    }
}
```

**After (Thread-safe actor):**
```swift
actor RuuviPoolCoordinator: RuuviPool {
    private let sqlite: RuuviPersistence
    private var cache: [String: RuuviTagSensor] = [:]  // Protected by actor

    func create(_ tag: RuuviTagSensor) async throws -> Bool {
        let result = try await sqlite.create(tag)
        cache[tag.id] = tag  // Safe - actor isolated
        return result
    }
}
```

---

### Pattern 9: Making Data Models Sendable

**Before:**
```swift
class RuuviTagSensorStruct {
    var id: String
    var name: String?
    var temperature: Double?
}
```

**After (Immutable Sendable struct):**
```swift
struct RuuviTagSensorStruct: Sendable {
    let id: String
    let name: String?
    let temperature: Double?

    // Use copy-on-write for mutations
    func with(name: String) -> RuuviTagSensorStruct {
        RuuviTagSensorStruct(id: id, name: name, temperature: temperature)
    }
}
```

**Or with mutable properties using @unchecked (use sparingly):**
```swift
final class RuuviTagSensorClass: @unchecked Sendable {
    private let lock = NSLock()
    private var _name: String?

    var name: String? {
        get { lock.withLock { _name } }
        set { lock.withLock { _name = newValue } }
    }
}
```

---

### Pattern 10: MainActor for Presenters/ViewModels

**Before:**
```swift
class DashboardPresenter {
    weak var view: DashboardViewInput?

    func viewDidLoad() {
        ruuviService.fetchSensors()
            .on(success: { [weak self] sensors in
                DispatchQueue.main.async {
                    self?.view?.display(sensors)
                }
            })
    }
}
```

**After:**
```swift
@MainActor
final class DashboardPresenter {
    weak var view: DashboardViewInput?

    func viewDidLoad() {
        Task {
            do {
                let sensors = try await ruuviService.fetchSensors()
                view?.display(sensors)  // Already on main actor
            } catch {
                view?.showError(error)
            }
        }
    }
}
```

---

### Pattern 11: Sendable Closures in Callbacks

**Before:**
```swift
func observe(callback: @escaping (RuuviTagSensor) -> Void) {
    // ...
}
```

**After:**
```swift
func observe(callback: @Sendable @escaping (RuuviTagSensor) -> Void) {
    // ...
}

// Or better - use AsyncSequence
func sensorUpdates() -> AsyncStream<RuuviTagSensor> {
    AsyncStream { continuation in
        // Set up observation
        let observer = NotificationCenter.default.addObserver(/*...*/) { sensor in
            continuation.yield(sensor)
        }
        continuation.onTermination = { _ in
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
```

---

### Pattern 12: Protocol with Actor Isolation

**Before:**
```swift
protocol RuuviCloud {
    func getSensor(id: String) -> Future<CloudSensor, RuuviCloudError>
    func updateSensor(_ sensor: CloudSensor) -> Future<Void, RuuviCloudError>
}
```

**After:**
```swift
protocol RuuviCloud: Sendable {
    func getSensor(id: String) async throws -> CloudSensor
    func updateSensor(_ sensor: CloudSensor) async throws
}

// Implementation as actor
actor RuuviCloudImpl: RuuviCloud {
    private let urlSession: URLSession
    private let baseURL: URL

    func getSensor(id: String) async throws -> CloudSensor {
        let url = baseURL.appendingPathComponent("sensors/\(id)")
        let (data, _) = try await urlSession.data(from: url)
        return try JSONDecoder().decode(CloudSensor.self, from: data)
    }
}
```

---

### Pattern 13: Global Actor for Subsystems

For related classes that share state but aren't a single actor:

```swift
@globalActor
actor RuuviPersistenceActor {
    static let shared = RuuviPersistenceActor()
}

@RuuviPersistenceActor
class RuuviPersistenceSQLite {
    // All methods run on the same actor
    func create(_ sensor: RuuviTagSensor) async throws -> Bool {
        // Database operations
    }
}

@RuuviPersistenceActor
class SensorSettingsPersistence {
    // Shares isolation with RuuviPersistenceSQLite
    func save(_ settings: SensorSettings) async throws {
        // ...
    }
}
```

---

### Pattern 14: Migrating Combine Publishers to AsyncSequence

**Before:**
```swift
var sensorsPublisher: AnyPublisher<[RuuviTagSensor], Never> {
    sensorsSubject.eraseToAnyPublisher()
}
```

**After:**
```swift
var sensors: AsyncStream<[RuuviTagSensor]> {
    AsyncStream { continuation in
        let cancellable = sensorsSubject.sink { sensors in
            continuation.yield(sensors)
        }
        continuation.onTermination = { _ in
            cancellable.cancel()
        }
    }
}

// Or use the built-in .values property (iOS 15+)
var sensors: some AsyncSequence<[RuuviTagSensor], Never> {
    sensorsSubject.values
}
```

---

## Phase-by-Phase Migration Plan

### Phase 1: Foundation Layer (Estimated: Week 1-2)

**Packages:** RuuviCore, RuuviLocal

**Files to migrate:**
- [ ] `Packages/RuuviCore/Sources/RuuviCore/RuuviCoreLocation.swift`
- [ ] `Packages/RuuviCore/Sources/RuuviCoreLocation/RuuviCoreLocationImpl.swift`
- [ ] `Packages/RuuviLocal/Sources/RuuviLocal/RuuviLocalImages.swift`
- [ ] `Packages/RuuviLocal/Sources/RuuviLocalUserDefaults/Background/Image/ImagePersistence.swift`
- [ ] `Packages/RuuviLocal/Sources/RuuviLocalUserDefaults/Background/Image/Documents/ImagePersistenceDocuments.swift`
- [ ] `Packages/RuuviLocal/Sources/RuuviLocalUserDefaults/Background/RuuviLocalImagesUserDefaults.swift`

**Tasks:**
1. Update Package.swift to remove Future dependency
2. Convert protocol definitions
3. Update implementations
4. Add unit tests for async versions
5. Verify build succeeds

---

### Phase 2: Persistence Layer (Estimated: Week 2-3)

**Packages:** RuuviPersistence, RuuviPool, RuuviStorage

**Files to migrate:**
- [ ] `Packages/RuuviPersistence/Sources/RuuviPersistence/RuuviPersistence.swift`
- [ ] `Packages/RuuviPersistence/Sources/RuuviPersistenceSQLite/RuuviPersistenceSQLite.swift` **(1140 lines - HIGH PRIORITY)**
- [ ] `Packages/RuuviPool/Sources/RuuviPool/RuuviPool.swift`
- [ ] `Packages/RuuviPool/Sources/RuuviPoolCoordinator/RuuviPoolCoordinator.swift` **(326 lines, 61 Promise usages)**
- [ ] `Packages/RuuviStorage/Sources/RuuviStorage/RuuviStorage.swift`
- [ ] `Packages/RuuviStorage/Sources/RuuviStorageCoordinator/RuuviStorageCoordinator.swift`

**Special Considerations:**
- Database operations need careful handling with actors or serial queues
- Consider using `@MainActor` for UI-related callbacks

---

### Phase 3: Network Layer (Estimated: Week 3-4)

**Package:** RuuviCloud

**Files to migrate:**
- [ ] `Packages/RuuviCloud/Sources/RuuviCloud/RuuviCloud.swift`
- [ ] `Packages/RuuviCloud/Sources/RuuviCloud/RuuviCloudCanonicalProxy.swift`
- [ ] `Packages/RuuviCloud/Sources/RuuviCloudApi/RuuviCloudApi.swift`
- [ ] `Packages/RuuviCloud/Sources/RuuviCloudApi/URLSession/RuuviCloudApiURLSession.swift`
- [ ] `Packages/RuuviCloud/Sources/RuuviCloudPure/RuuviCloudPure.swift` **(1513 lines, 87 Future/Promise usages - CRITICAL FILE)**

**Special Considerations:**
- Use `URLSession.data(for:)` async API
- Handle network errors properly
- Consider retry logic with async

---

### Phase 4: Business Logic Layer (Estimated: Week 4-6)

**Packages:** RuuviRepository, RuuviService

**Files to migrate:**

#### RuuviRepository
- [ ] `Packages/RuuviRepository/Sources/RuuviRepository/RuuviRepository.swift`
- [ ] `Packages/RuuviRepository/Sources/RuuviRepositoryCoordinator/RuuviRepositoryCoordinator.swift`

#### RuuviService (18 files - LARGEST PACKAGE)
- [ ] `Packages/RuuviService/Sources/RuuviService/GATTService.swift`
- [ ] `Packages/RuuviService/Sources/RuuviService/RuuviServiceAlert.swift`
- [ ] `Packages/RuuviService/Sources/RuuviService/RuuviServiceAppSettings.swift`
- [ ] `Packages/RuuviService/Sources/RuuviService/RuuviServiceAuth.swift`
- [ ] `Packages/RuuviService/Sources/RuuviService/RuuviServiceCloudNotification.swift`
- [ ] `Packages/RuuviService/Sources/RuuviService/RuuviServiceCloudSync.swift`
- [ ] `Packages/RuuviService/Sources/RuuviService/RuuviServiceExport.swift`
- [ ] `Packages/RuuviService/Sources/RuuviService/RuuviServiceOffsetCalibration.swift`
- [ ] `Packages/RuuviService/Sources/RuuviService/RuuviServiceOwnership.swift`
- [ ] `Packages/RuuviService/Sources/RuuviService/RuuviServiceSensorProperties.swift`
- [ ] `Packages/RuuviService/Sources/RuuviService/RuuviServiceSensorRecords.swift`
- [ ] `Packages/RuuviService/Sources/RuuviServiceAlert/RuuviServiceAlertImpl.swift` **(4262 lines - CRITICAL)**
- [ ] `Packages/RuuviService/Sources/RuuviServiceAppSettings/RuuviServiceAppSettingsImpl.swift`
- [ ] `Packages/RuuviService/Sources/RuuviServiceAuth/RuuviServiceAuthImpl.swift`
- [ ] `Packages/RuuviService/Sources/RuuviServiceCloudNotification/RuuviServiceCloudNotificationImpl.swift`
- [ ] `Packages/RuuviService/Sources/RuuviServiceCloudSync/RuuviServiceCloudSyncImpl.swift` **(912 lines, 12+ Future.zip())**
- [ ] `Packages/RuuviService/Sources/RuuviServiceExport/RuuviServiceExportImpl.swift` **(894 lines)**
- [ ] `Packages/RuuviService/Sources/RuuviServiceGATT/Queue/GATTServiceQueue.swift`
- [ ] `Packages/RuuviService/Sources/RuuviServiceOffsetCalibration/RuuviServiceAppOffsetCalibrationImpl.swift`
- [ ] `Packages/RuuviService/Sources/RuuviServiceOwnership/RuuviServiceOwnershipImpl.swift`
- [ ] `Packages/RuuviService/Sources/RuuviServiceSensorProperties/RuuviServiceSensorPropertiesImpl.swift`
- [ ] `Packages/RuuviService/Sources/RuuviServiceSensorRecords/RuuviServiceSensorRecordsImpl.swift`

---

### Phase 5: Daemon & Reactor Layer (Estimated: Week 6-7)

**Packages:** RuuviDaemon, RuuviReactor

**Files to migrate:**
- [ ] `Packages/RuuviDaemon/Sources/RuuviDaemon/RuuviTagHeartbeatDaemon.swift`
- [ ] `Packages/RuuviDaemon/Sources/RuuviDaemonBackground/BackgroundProcessServiceiOS13.swift`
- [ ] `Packages/RuuviDaemon/Sources/RuuviDaemonOperation/Data/DataPruningOperationsManager.swift`
- [ ] `Packages/RuuviReactor/Sources/RuuviReactorImpl/RuuviReactorImpl.swift`

---

### Phase 6: App Layer (Estimated: Week 7-8)

**Packages:** Apps/RuuviStation, Modules/RuuviDiscover

**Files to migrate:**
- [ ] `Apps/RuuviStation/Sources/Classes/Presentation/Modules/Dashboard/Interactor/DashboardInteractor.swift`
- [ ] `Apps/RuuviStation/Sources/Classes/Presentation/Modules/Dashboard/Interactor/DashboardInteractorInput.swift`
- [ ] `Apps/RuuviStation/Sources/Classes/Presentation/Modules/Full Sensor Card/Submodules/Graph/Interactor/CardsGraphViewInteractor.swift`
- [ ] `Apps/RuuviStation/Sources/Classes/Presentation/Modules/Full Sensor Card/Submodules/Graph/Interactor/CardsGraphViewInteractorInput.swift`
- [ ] `Apps/RuuviStation/Sources/Classes/Presentation/Modules/My Ruuvi/Presenter/MyRuuviAccountPresenter.swift`
- [ ] `Apps/RuuviStation/Sources/Classes/Presentation/Modules/Share/Presenter/SharePresenter.swift`
- [ ] `Apps/RuuviStation/Sources/Classes/Presentation/Modules/SignIn/Presenter/SignInPresenter.swift`
- [ ] `Apps/RuuviStation/Tests/Unit/MockCalibrationService.swift`
- [ ] `Modules/RuuviDiscover/Sources/RuuviDiscover/VMP/Presenter/DiscoverPresenter.swift`

---

### Phase 7: Cleanup (Estimated: Week 8)

1. Remove all Future dependencies from Package.swift files
2. Remove `import Future` from all files
3. Delete any bridge/wrapper code
4. Update documentation
5. Final test pass

---

## Package Migration Order

Execute in this exact order to minimize breaking changes:

| Order | Package | Dependencies | Estimated Effort |
|-------|---------|--------------|------------------|
| 1 | RuuviCore | None | Low |
| 2 | RuuviLocal | RuuviCore | Low |
| 3 | RuuviPersistence | RuuviCore | Medium |
| 4 | RuuviPool | RuuviPersistence | Medium |
| 5 | RuuviStorage | RuuviPersistence | Medium |
| 6 | RuuviCloud | RuuviCore | High |
| 7 | RuuviRepository | RuuviStorage, RuuviCloud | Medium |
| 8 | RuuviService | All above | **Very High** |
| 9 | RuuviDaemon | RuuviService | Medium |
| 10 | RuuviReactor | RuuviService | Low |
| 11 | Apps/RuuviStation | All | High |
| 12 | Modules/RuuviDiscover | RuuviService | Low |

---

## Testing Strategy

### Unit Tests
- Add async test versions using `XCTestCase` async support
- Use `XCTAssertThrowsError` for error cases

```swift
func testFetchSensor() async throws {
    let sensor = try await sut.fetchSensor(id: "test-id")
    XCTAssertEqual(sensor.name, "Expected Name")
}
```

### Integration Tests
- Test complete flows end-to-end
- Verify data integrity across async boundaries

### Regression Tests
- Compare behavior between old Future-based and new async/await implementations
- Use feature flags to toggle between implementations during transition

---

## Rollback Plan

If critical issues are discovered:

1. **Immediate:** Revert to the last stable commit before migration started
2. **Partial:** Use feature flags to disable async code paths
3. **Gradual:** Keep Future-based implementations alongside async versions during transition

---

## Common Pitfalls

### 1. Main Thread Issues
**Problem:** UI updates from background tasks
**Solution:** Always use `@MainActor` or `MainActor.run {}` for UI code

```swift
@MainActor
func updateUI(with data: Data) {
    label.text = String(data: data, encoding: .utf8)
}
```

### 2. Data Races
**Problem:** Concurrent access to shared mutable state
**Solution:** Use actors for shared state

```swift
actor SensorCache {
    private var sensors: [String: Sensor] = [:]

    func get(_ id: String) -> Sensor? {
        sensors[id]
    }

    func set(_ sensor: Sensor, for id: String) {
        sensors[id] = sensor
    }
}
```

### 3. Task Cancellation
**Problem:** Long-running tasks not respecting cancellation
**Solution:** Check for cancellation and use `withTaskCancellationHandler`

```swift
func fetchData() async throws -> Data {
    try Task.checkCancellation()
    // ... do work
}
```

### 4. Retain Cycles
**Problem:** Strong reference cycles in closures
**Solution:** Use `[weak self]` in Task closures when needed

```swift
Task { [weak self] in
    guard let self else { return }
    await self.doWork()
}
```

### 5. Structured vs Unstructured Concurrency
**Problem:** Overusing `Task {}` (unstructured) when structured concurrency works
**Solution:** Prefer `async let` and `TaskGroup` for parallel work

---

## Swift 6 Specific Pitfalls

### 6. Non-Sendable Type Crossing Isolation Boundary
**Problem:** Compiler error when passing non-Sendable types across async boundaries
```swift
// Error: Capture of 'mutableClass' with non-sendable type
let mutableClass = MutableClass()
Task {
    mutableClass.doSomething()  // Error!
}
```

**Solution:** Make the type Sendable or use an actor
```swift
// Option 1: Make it Sendable (if possible)
final class MutableClass: Sendable { /* immutable state only */ }

// Option 2: Use an actor
actor MutableActor {
    func doSomething() { }
}

// Option 3: Create inside the Task
Task {
    let mutableClass = MutableClass()
    mutableClass.doSomething()
}
```

### 7. Actor Reentrancy
**Problem:** Actor methods can suspend and allow other calls to interleave
```swift
actor BankAccount {
    var balance: Int = 100

    func withdraw(_ amount: Int) async -> Bool {
        guard balance >= amount else { return false }
        await someAsyncOperation()  // Another call could modify balance here!
        balance -= amount  // May overdraw!
        return true
    }
}
```

**Solution:** Check conditions after suspension or use synchronous paths
```swift
actor BankAccount {
    var balance: Int = 100

    func withdraw(_ amount: Int) async -> Bool {
        guard balance >= amount else { return false }
        balance -= amount  // Do state changes before suspension
        await notifyWithdrawal(amount)
        return true
    }
}
```

### 8. @MainActor Inheritance
**Problem:** Forgetting that @MainActor doesn't automatically apply to subclasses
```swift
@MainActor
class BasePresenter { }

class DerivedPresenter: BasePresenter {
    func updateView() { }  // NOT on MainActor unless class is marked!
}
```

**Solution:** Mark the derived class too
```swift
@MainActor
class DerivedPresenter: BasePresenter {
    func updateView() { }  // Now on MainActor
}
```

### 9. Protocol Conformance with Actors
**Problem:** Protocols can't require actor isolation
```swift
protocol DataSource {
    func fetch() async -> Data
}

actor MyActor: DataSource {
    func fetch() async -> Data {  // This is actor-isolated
        // ...
    }
}
```

**Solution:** Use `nonisolated` when protocol requires non-isolated methods, or redesign the protocol
```swift
actor MyActor: DataSource {
    nonisolated func fetch() async -> Data {
        await self.isolatedFetch()
    }

    private func isolatedFetch() async -> Data {
        // Actor-isolated implementation
    }
}
```

### 10. Sendable Conformance for Closures with Captures
**Problem:** Closures that capture non-Sendable values can't be Sendable
```swift
class ViewController {
    func setupCallback() {
        // Error: ViewController is not Sendable
        service.onComplete { [self] result in
            self.handleResult(result)
        }
    }
}
```

**Solution:** Use weak references or MainActor
```swift
@MainActor
class ViewController {
    func setupCallback() {
        service.onComplete { [weak self] result in
            Task { @MainActor in
                self?.handleResult(result)
            }
        }
    }
}
```

---

## Resources

### Swift Concurrency Fundamentals
- [Swift Concurrency Documentation](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [WWDC 2021: Meet async/await in Swift](https://developer.apple.com/videos/play/wwdc2021/10132/)
- [WWDC 2021: Swift concurrency: Update a sample app](https://developer.apple.com/videos/play/wwdc2021/10194/)

### Swift 6 Strict Concurrency
- [WWDC 2024: Migrate your app to Swift 6](https://developer.apple.com/videos/play/wwdc2024/10169/)
- [WWDC 2024: What's new in Swift](https://developer.apple.com/videos/play/wwdc2024/10136/)
- [Swift Evolution: SE-0302 Sendable and @Sendable closures](https://github.com/apple/swift-evolution/blob/main/proposals/0302-concurrent-value-and-concurrent-closures.md)
- [Swift Evolution: SE-0306 Actors](https://github.com/apple/swift-evolution/blob/main/proposals/0306-actors.md)
- [Swift Evolution: SE-0337 Incremental migration to concurrency checking](https://github.com/apple/swift-evolution/blob/main/proposals/0337-support-incremental-migration-to-concurrency-checking.md)

### Migration Guides
- [Migrating to Swift Concurrency - Antoine van der Lee](https://www.avanderlee.com/swift/async-await/)
- [Swift 6 Migration Guide - Swift.org](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/)
- [Data Race Safety in Swift 6](https://www.swift.org/documentation/concurrency/)

---

## Progress Tracking

Use this section to track overall migration progress:

- [ ] Phase 1: Foundation Layer
- [ ] Phase 2: Persistence Layer
- [ ] Phase 3: Network Layer
- [ ] Phase 4: Business Logic Layer
- [ ] Phase 5: Daemon & Reactor Layer
- [ ] Phase 6: App Layer
- [ ] Phase 7: Cleanup

**Last Updated:** <!-- Add date when migration begins -->

---

## Appendix A: Complete File List

### All Files Requiring Migration (51 files)

#### App Layer (8 files)
1. `Apps/RuuviStation/Sources/Classes/Presentation/Modules/Dashboard/Interactor/DashboardInteractor.swift`
2. `Apps/RuuviStation/Sources/Classes/Presentation/Modules/Dashboard/Interactor/DashboardInteractorInput.swift`
3. `Apps/RuuviStation/Sources/Classes/Presentation/Modules/Full Sensor Card/Submodules/Graph/Interactor/CardsGraphViewInteractor.swift`
4. `Apps/RuuviStation/Sources/Classes/Presentation/Modules/Full Sensor Card/Submodules/Graph/Interactor/CardsGraphViewInteractorInput.swift`
5. `Apps/RuuviStation/Sources/Classes/Presentation/Modules/My Ruuvi/Presenter/MyRuuviAccountPresenter.swift`
6. `Apps/RuuviStation/Sources/Classes/Presentation/Modules/Share/Presenter/SharePresenter.swift`
7. `Apps/RuuviStation/Sources/Classes/Presentation/Modules/SignIn/Presenter/SignInPresenter.swift`
8. `Apps/RuuviStation/Tests/Unit/MockCalibrationService.swift`

#### RuuviCore (2 files)
9. `Packages/RuuviCore/Sources/RuuviCore/RuuviCoreLocation.swift`
10. `Packages/RuuviCore/Sources/RuuviCoreLocation/RuuviCoreLocationImpl.swift`

#### RuuviLocal (4 files)
11. `Packages/RuuviLocal/Sources/RuuviLocal/RuuviLocalImages.swift`
12. `Packages/RuuviLocal/Sources/RuuviLocalUserDefaults/Background/Image/ImagePersistence.swift`
13. `Packages/RuuviLocal/Sources/RuuviLocalUserDefaults/Background/Image/Documents/ImagePersistenceDocuments.swift`
14. `Packages/RuuviLocal/Sources/RuuviLocalUserDefaults/Background/RuuviLocalImagesUserDefaults.swift`

#### RuuviPersistence (2 files)
15. `Packages/RuuviPersistence/Sources/RuuviPersistence/RuuviPersistence.swift`
16. `Packages/RuuviPersistence/Sources/RuuviPersistenceSQLite/RuuviPersistenceSQLite.swift`

#### RuuviPool (2 files)
17. `Packages/RuuviPool/Sources/RuuviPool/RuuviPool.swift`
18. `Packages/RuuviPool/Sources/RuuviPoolCoordinator/RuuviPoolCoordinator.swift`

#### RuuviStorage (2 files)
19. `Packages/RuuviStorage/Sources/RuuviStorage/RuuviStorage.swift`
20. `Packages/RuuviStorage/Sources/RuuviStorageCoordinator/RuuviStorageCoordinator.swift`

#### RuuviCloud (5 files)
21. `Packages/RuuviCloud/Sources/RuuviCloud/RuuviCloud.swift`
22. `Packages/RuuviCloud/Sources/RuuviCloud/RuuviCloudCanonicalProxy.swift`
23. `Packages/RuuviCloud/Sources/RuuviCloudApi/RuuviCloudApi.swift`
24. `Packages/RuuviCloud/Sources/RuuviCloudApi/URLSession/RuuviCloudApiURLSession.swift`
25. `Packages/RuuviCloud/Sources/RuuviCloudPure/RuuviCloudPure.swift`

#### RuuviRepository (2 files)
26. `Packages/RuuviRepository/Sources/RuuviRepository/RuuviRepository.swift`
27. `Packages/RuuviRepository/Sources/RuuviRepositoryCoordinator/RuuviRepositoryCoordinator.swift`

#### RuuviService (22 files)
28. `Packages/RuuviService/Sources/RuuviService/GATTService.swift`
29. `Packages/RuuviService/Sources/RuuviService/RuuviServiceAlert.swift`
30. `Packages/RuuviService/Sources/RuuviService/RuuviServiceAppSettings.swift`
31. `Packages/RuuviService/Sources/RuuviService/RuuviServiceAuth.swift`
32. `Packages/RuuviService/Sources/RuuviService/RuuviServiceCloudNotification.swift`
33. `Packages/RuuviService/Sources/RuuviService/RuuviServiceCloudSync.swift`
34. `Packages/RuuviService/Sources/RuuviService/RuuviServiceExport.swift`
35. `Packages/RuuviService/Sources/RuuviService/RuuviServiceOffsetCalibration.swift`
36. `Packages/RuuviService/Sources/RuuviService/RuuviServiceOwnership.swift`
37. `Packages/RuuviService/Sources/RuuviService/RuuviServiceSensorProperties.swift`
38. `Packages/RuuviService/Sources/RuuviService/RuuviServiceSensorRecords.swift`
39. `Packages/RuuviService/Sources/RuuviServiceAlert/RuuviServiceAlertImpl.swift`
40. `Packages/RuuviService/Sources/RuuviServiceAppSettings/RuuviServiceAppSettingsImpl.swift`
41. `Packages/RuuviService/Sources/RuuviServiceAuth/RuuviServiceAuthImpl.swift`
42. `Packages/RuuviService/Sources/RuuviServiceCloudNotification/RuuviServiceCloudNotificationImpl.swift`
43. `Packages/RuuviService/Sources/RuuviServiceCloudSync/RuuviServiceCloudSyncImpl.swift`
44. `Packages/RuuviService/Sources/RuuviServiceExport/RuuviServiceExportImpl.swift`
45. `Packages/RuuviService/Sources/RuuviServiceGATT/Queue/GATTServiceQueue.swift`
46. `Packages/RuuviService/Sources/RuuviServiceOffsetCalibration/RuuviServiceAppOffsetCalibrationImpl.swift`
47. `Packages/RuuviService/Sources/RuuviServiceOwnership/RuuviServiceOwnershipImpl.swift`
48. `Packages/RuuviService/Sources/RuuviServiceSensorProperties/RuuviServiceSensorPropertiesImpl.swift`
49. `Packages/RuuviService/Sources/RuuviServiceSensorRecords/RuuviServiceSensorRecordsImpl.swift`

#### RuuviDaemon (3 files)
50. `Packages/RuuviDaemon/Sources/RuuviDaemon/RuuviTagHeartbeatDaemon.swift`
51. `Packages/RuuviDaemon/Sources/RuuviDaemonBackground/BackgroundProcessServiceiOS13.swift`
52. `Packages/RuuviDaemon/Sources/RuuviDaemonOperation/Data/DataPruningOperationsManager.swift`

#### RuuviReactor (1 file)
53. `Packages/RuuviReactor/Sources/RuuviReactorImpl/RuuviReactorImpl.swift`

#### Modules (1 file)
54. `Modules/RuuviDiscover/Sources/RuuviDiscover/VMP/Presenter/DiscoverPresenter.swift`

---

## Appendix B: Package.swift Files to Update

Remove Future dependency from these 8 Package.swift files:

1. `Packages/RuuviCore/Package.swift`
2. `Packages/RuuviLocal/Package.swift`
3. `Packages/RuuviPersistence/Package.swift`
4. `Packages/RuuviPool/Package.swift`
5. `Packages/RuuviStorage/Package.swift`
6. `Packages/RuuviCloud/Package.swift`
7. `Packages/RuuviRepository/Package.swift`
8. `Packages/RuuviService/Package.swift`

**Line to remove from each:**
```swift
.package(url: "https://github.com/kean/Future", .exact("1.3.0"))
```

---

## Appendix C: Swift 6 Concurrency Annotations Guide

### Files to Convert to Actors

These files manage shared mutable state and should become actors:

| File | Current Type | Recommendation |
|------|--------------|----------------|
| `RuuviPoolCoordinator.swift` | Class | `actor` - manages sensor cache |
| `RuuviStorageCoordinator.swift` | Class | `actor` - manages storage state |
| `RuuviRepositoryCoordinator.swift` | Class | `actor` - manages repository state |
| `RuuviPersistenceSQLite.swift` | Class | `actor` - database operations |
| `RuuviCloudPure.swift` | Class | `actor` - network state/caching |
| `SensorCache` (if exists) | Class | `actor` - cache management |
| `DataPruningOperationsManager.swift` | Class | `actor` - operation queue |

### Files to Mark with @MainActor

These files interact with UI and should be `@MainActor`:

| File | Reason |
|------|--------|
| `DashboardPresenter.swift` | Updates dashboard view |
| `DashboardInteractor.swift` | Feeds data to presenter |
| `SharePresenter.swift` | UI interactions |
| `SignInPresenter.swift` | UI interactions |
| `MyRuuviAccountPresenter.swift` | UI interactions |
| `DiscoverPresenter.swift` | UI interactions |
| `CardsGraphViewInteractor.swift` | Updates graph view |
| All ViewControllers | UIKit requires main thread |

### Types to Make Sendable

Data models that cross async boundaries need `Sendable`:

```swift
// These should be Sendable structs (or conform if already structs):
- RuuviTagSensor
- SensorSettings
- RuuviCloudSettings
- CloudSensor
- AlertType / AlertState
- All API response/request models
- All database entity models
```

### Global Actor Candidates

Consider a global actor for related subsystems:

```swift
// Database subsystem
@globalActor actor RuuviDatabaseActor {
    static let shared = RuuviDatabaseActor()
}

// Apply to all persistence-related classes:
// - RuuviPersistenceSQLite
// - RuuviPoolCoordinator
// - RuuviStorageCoordinator

// Cloud subsystem
@globalActor actor RuuviCloudActor {
    static let shared = RuuviCloudActor()
}

// Apply to:
// - RuuviCloudPure
// - RuuviCloudApiURLSession
```

---

## Appendix D: Incremental Migration Strategy

If a full migration is too risky, use this incremental approach:

### Step 1: Enable Warnings (Week 1)
```swift
// Package.swift
swiftSettings: [
    .enableExperimentalFeature("StrictConcurrency=targeted")
]
```

### Step 2: Fix Warnings Without Breaking Changes (Weeks 2-3)
- Add `Sendable` conformance to data models
- Add `@MainActor` to presenters
- Add `nonisolated` where needed

### Step 3: Enable Complete Checking (Week 4)
```swift
swiftSettings: [
    .enableExperimentalFeature("StrictConcurrency=complete")
]
```

### Step 4: Convert to Async/Await (Weeks 5-8)
- Replace Future with async/await
- Convert classes to actors where needed

### Step 5: Enable Swift 6 Mode (Week 9)
```swift
// Package.swift
swiftLanguageVersions: [.v6]
```

---

## Appendix E: Testing Async Code

### Basic Async Test
```swift
func testFetchSensor() async throws {
    let sut = RuuviCloudImpl()
    let sensor = try await sut.getSensor(id: "test-123")
    XCTAssertEqual(sensor.name, "Test Sensor")
}
```

### Testing Actor State
```swift
func testActorState() async {
    let cache = SensorCache()
    let sensor = RuuviTagSensor(id: "1", name: "Test")

    await cache.store(sensor)
    let retrieved = await cache.get("1")

    XCTAssertEqual(retrieved?.name, "Test")
}
```

### Testing MainActor Code
```swift
@MainActor
func testPresenter() async {
    let presenter = DashboardPresenter()
    let mockView = MockDashboardView()
    presenter.view = mockView

    await presenter.loadSensors()

    XCTAssertTrue(mockView.displayCalled)
}
```

### Testing Concurrent Operations
```swift
func testConcurrentAccess() async {
    let cache = SensorCache()

    await withTaskGroup(of: Void.self) { group in
        for i in 0..<100 {
            group.addTask {
                let sensor = RuuviTagSensor(id: "\(i)", name: "Sensor \(i)")
                await cache.store(sensor)
            }
        }
    }

    let count = await cache.count
    XCTAssertEqual(count, 100)
}
```
