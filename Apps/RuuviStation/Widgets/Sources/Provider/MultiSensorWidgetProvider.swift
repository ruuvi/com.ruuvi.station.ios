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

        Task {
            completion(await makeEntry(for: configuration))
        }
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

        let cloudSensors = await viewModel.fetchRuuviTagsAsync()
        let cloudMap = Dictionary(uniqueKeysWithValues: cloudSensors.map { ($0.sensor.id, $0) })
        let localSnapshots = WidgetSensorCache().loadAll()

        let items: [MultiSensorWidgetSensorItem] = selectedSensorIds.enumerated().compactMap {
            index,
            sensorId in
            let localSnapshot = localSnapshots.first(where: { $0.matches(identifier: sensorId) })

            if let sensor = cloudMap[sensorId] ?? cloudSensors.first(
                where: {
                    sensorIdentifiers(
                        for: $0
                    ).contains(
                        sensorId
                    )
                }) {
                let localSettings = localSnapshot.flatMap { snapshot in
                    sensorSettings(from: snapshot)
                }
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
        (1 ... 6).map { index in
            let key = "sensor\(index)"
            let selector = NSSelectorFromString(key)
            guard configuration.responds(to: selector) else {
                return nil
            }
            return configuration.value(forKey: key) as? RuuviWidgetTag
        }
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
