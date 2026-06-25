import Intents
import RuuviCloud
import RuuviLocal
import RuuviOntology
import WidgetKit

@available(iOSApplicationExtension 16.0, *)
struct MultiSensorWidgetProvider: IntentTimelineProvider {
    typealias Intent = RuuviMultiSensorSelectionIntent
    typealias Entry = MultiSensorWidgetEntry

    private let viewModel = WidgetViewModel()
    private let cloudCache = WidgetCloudCache()

    func placeholder(in context: Context) -> Entry {
        .placeholder(for: context.family)
    }

    func getSnapshot(
        for configuration: Intent,
        in context: Context,
        completion: @escaping (Entry) -> Void
    ) {
        if context.isPreview {
            completion(.placeholder(for: context.family))
            return
        }

        // Always instant — build from local cache with no network calls
        let localSnapshots = WidgetSensorCache().loadAll()
        let selectedIds = selectedSensors(from: configuration)

        if !selectedIds.isEmpty, !localSnapshots.isEmpty {
            let items: [MultiSensorWidgetSensorItem] = selectedIds.enumerated().compactMap { index, sensorId in
                guard let snap = localSnapshots.first(where: { $0.matches(identifier: sensorId) }) else { return nil }
                let settings = sensorSettings(from: snap)
                let record = snap.record?.toRecord()
                let deviceType = viewModel.deviceType(from: record)
                return MultiSensorWidgetSensorItem(
                    id: "\(index + 1)-\(sensorId)",
                    sensorId: sensorId,
                    name: snap.name,
                    record: record,
                    settings: settings,
                    cloudSettings: nil,
                    deviceType: deviceType,
                    selectedCodes: []
                )
            }
            if !items.isEmpty {
                completion(MultiSensorWidgetEntry(
                    date: Date(),
                    isAuthorized: viewModel.isAuthorized(),
                    isPreview: true,
                    sensors: items
                ))
                return
            }
        }

        completion(.placeholder(for: context.family))
    }

    func getTimeline(
        for configuration: Intent,
        in context: Context,
        completion: @escaping (Timeline<Entry>) -> Void
    ) {
        if context.isPreview {
            completion(
                Timeline(
                    entries: [.placeholder(for: context.family)],
                    policy: .never
                )
            )
            return
        }

        Task {
            let entry = await makeEntry(for: configuration)
            let nextUpdateDate = Calendar.current.date(
                byAdding: .minute,
                value: viewModel.refreshIntervalMins(),
                to: Date()
            ) ?? Date()

            completion(
                Timeline(
                    entries: [entry],
                    policy: .after(nextUpdateDate)
                )
            )
        }
    }
}

@available(iOSApplicationExtension 16.0, *)
private extension MultiSensorWidgetProvider {
    // swiftlint:disable:next function_body_length
    func makeEntry(
        for configuration: Intent
    ) async -> Entry {
        let selectedSensorIds = selectedSensors(from: configuration)
        guard !selectedSensorIds.isEmpty else {
            return .empty()
        }

        let localSnapshots = WidgetSensorCache().loadAll()

        // Cache-first: serve from disk if cloud data is still fresh
        if cloudCache.isFresh(intervalMinutes: viewModel.refreshIntervalMins()),
           !viewModel.shouldForceRefresh(),
           !localSnapshots.isEmpty {
            let items = buildItems(from: selectedSensorIds, localSnapshots: localSnapshots)
            if !items.isEmpty {
                return MultiSensorWidgetEntry(
                    date: Date(),
                    isAuthorized: viewModel.isAuthorized(),
                    isPreview: false,
                    sensors: items
                )
            }
        }

        // Fetch fresh cloud data
        let cloudSensors = await viewModel.fetchRuuviTagsAsync()
        if !cloudSensors.isEmpty {
            persistCloudData(cloudSensors)
            cloudCache.markFresh()
        }

        // Rebuild items merging cloud + local (cloud has priority)
        let refreshedSnapshots = cloudSensors.isEmpty ? localSnapshots : WidgetSensorCache().loadAll()
        let items = buildItems(
            from: selectedSensorIds,
            localSnapshots: refreshedSnapshots,
            cloudSensors: cloudSensors
        )

        if items.isEmpty {
            return .empty()
        }

        return MultiSensorWidgetEntry(
            date: Date(),
            isAuthorized: viewModel.isAuthorized(),
            isPreview: false,
            sensors: items
        )
    }

    func buildItems(
        from selectedSensorIds: [String],
        localSnapshots: [WidgetSensorSnapshot],
        cloudSensors: [RuuviCloudSensorDense] = []
    ) -> [MultiSensorWidgetSensorItem] {
        let cloudMap = Dictionary(uniqueKeysWithValues: cloudSensors.map { ($0.sensor.id, $0) })

        return selectedSensorIds.enumerated().compactMap { index, sensorId in
            let localSnapshot = localSnapshots.first(where: { $0.matches(identifier: sensorId) })

            // Cloud path: cloud sensor found for this ID
            if let sensor = cloudMap[sensorId] ?? cloudSensors.first(where: {
                sensorIdentifiers(for: $0).contains(sensorId)
            }) {
                let localSettings = localSnapshot.flatMap { sensorSettings(from: $0) }
                let settings = localSettings ?? SensorSettingsStruct.settings(from: sensor.sensor.any)
                let shouldPreferLocalVisibility = localSettings != nil
                let deviceType = viewModel.deviceType(from: sensor.record)
                return MultiSensorWidgetSensorItem(
                    id: "\(index + 1)-\(sensorId)",
                    sensorId: sensorId,
                    name: localSnapshot?.name ?? sensor.sensor.name,
                    record: sensor.record,
                    settings: settings,
                    cloudSettings: shouldPreferLocalVisibility ? nil : sensor.settings,
                    deviceType: deviceType,
                    selectedCodes: []
                )
            }

            // Local-only path
            if let snap = localSnapshot {
                let settings = sensorSettings(from: snap)
                let record = snap.record?.toRecord()
                let deviceType = viewModel.deviceType(from: record)
                return MultiSensorWidgetSensorItem(
                    id: "\(index + 1)-\(sensorId)",
                    sensorId: sensorId,
                    name: snap.name,
                    record: record,
                    settings: settings,
                    cloudSettings: nil,
                    deviceType: deviceType,
                    selectedCodes: []
                )
            }

            return nil
        }
    }

    func persistCloudData(_ tags: [RuuviCloudSensorDense]) {
        let cache = WidgetSensorCache()
        for tag in tags {
            guard let record = tag.record else { continue }
            let recordSnapshot = WidgetSensorRecordSnapshot(from: record)
            let sensor = tag.sensor.any
            let settingsSnapshot = WidgetSensorSettingsSnapshot(
                temperatureOffset: sensor.offsetTemperature,
                humidityOffset: sensor.offsetHumidity.map { $0 / 100 },
                pressureOffset: sensor.offsetPressure.map { $0 / 100 },
                displayOrder: tag.settings?.displayOrderCodes,
                defaultDisplayOrder: tag.settings?.defaultDisplayOrder
            )
            cache.upsert(
                sensorId: tag.sensor.id,
                name: tag.sensor.name,
                macId: record.macId?.value,
                luid: record.luid?.value,
                record: recordSnapshot,
                settings: settingsSnapshot
            )
        }
    }

    func selectedSensors(
        from configuration: Intent
    ) -> [String] {
        let configuredSensors = configuredSensors(from: configuration)

        var seen = Set<String>()
        var orderedUniqueIds: [String] = []

        for sensor in configuredSensors {
            guard let id = WidgetConfigurationSelection.normalizedSensorIdentifier(
                from: sensor
            ) else {
                continue
            }

            if seen.insert(id).inserted {
                orderedUniqueIds.append(id)
            }

            if orderedUniqueIds.count == 6 {
                break
            }
        }

        return orderedUniqueIds
    }

    func configuredSensors(
        from configuration: Intent
    ) -> [RuuviWidgetTag?] {
        [
            configuration.sensor1,
            configuration.sensor2,
            configuration.sensor3,
            configuration.sensor4,
            configuration.sensor5,
            configuration.sensor6,
        ]
    }

    func sensorSettings(
        from snapshot: WidgetSensorSnapshot
    ) -> SensorSettingsStruct? {
        snapshot.settings.map { settings in
            SensorSettingsStruct(
                luid: snapshot.luid?.luid,
                macId: snapshot.macId?.mac,
                temperatureOffset: settings.temperatureOffset,
                humidityOffset: settings.humidityOffset,
                pressureOffset: settings.pressureOffset,
                displayOrder: settings.displayOrder,
                defaultDisplayOrder: settings.defaultDisplayOrder
            )
        }
    }

    func sensorIdentifiers(
        for sensor: RuuviCloudSensorDense
    ) -> [String] {
        [
            sensor.sensor.id,
            sensor.record?.macId?.value,
            sensor.record?.luid?.value,
        ].compactMap { $0 }
    }
}
