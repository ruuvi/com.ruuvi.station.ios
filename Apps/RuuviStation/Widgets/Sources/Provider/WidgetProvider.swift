import Intents
import RuuviLocal
import RuuviOntology
import WidgetKit

final class WidgetProvider: IntentTimelineProvider {
    private let viewModel = WidgetViewModel()
    private let localCache = WidgetSensorCache()
    private let cloudCache = WidgetCloudCache()

    func placeholder(in _: Context) -> WidgetEntry {
        WidgetEntry.placeholder()
    }

    func getSnapshot(
        for configuration: RuuviTagSelectionIntent,
        in _: Context,
        completion: @escaping (WidgetEntry) -> Void
    ) {
        let resolvedConfiguration = SingleSensorWidgetConfiguration(intent: configuration)
        if let sensorId = resolvedConfiguration.sensorId,
           let snap = localCache.snapshot(matching: sensorId) {
            let record = snap.record?.toRecord()
            let tag = RuuviWidgetTag(identifier: snap.id, display: snap.name)
            let entry = WidgetEntry(
                date: Date(),
                isAuthorized: viewModel.isAuthorized(),
                isPreview: true,
                tag: tag,
                record: record,
                settings: settings(from: snap),
                cloudSettings: nil,
                config: resolvedConfiguration
            )
            completion(entry)
            return
        }
        completion(.placeholder())
    }

    func getTimeline(
        for configuration: RuuviTagSelectionIntent,
        in _: Context,
        completion: @escaping (Timeline<WidgetEntry>) -> Void
    ) {
        let resolvedConfiguration = SingleSensorWidgetConfiguration(intent: configuration)
        let isAuthorized = viewModel.isAuthorized()
        guard resolvedConfiguration.sensorId != nil else {
            return emptyTimeline(
                for: resolvedConfiguration,
                completion: completion
            )
        }

        let localSnapshot = localSnapshot(for: resolvedConfiguration)
        if !isAuthorized {
            return buildTimeline(
                configuration: resolvedConfiguration,
                cloudTags: nil,
                localSnapshot: localSnapshot,
                completion: completion
            )
        }

        let cacheIsRecent = cloudCache.isFresh(intervalMinutes: viewModel.refreshIntervalMins())
        if cacheIsRecent, localSnapshot != nil, !viewModel.shouldForceRefresh() {
            return useCachedData(
                for: resolvedConfiguration,
                localSnapshot: localSnapshot,
                completion: completion
            )
        }

        return fetchData(
            for: resolvedConfiguration,
            localSnapshot: localSnapshot,
            completion: completion
        )
    }

    private func fetchData(
        for configuration: SingleSensorWidgetConfiguration,
        localSnapshot: WidgetSensorSnapshot?,
        completion: @escaping (Timeline<WidgetEntry>) -> Void
    ) {
        viewModel.fetchRuuviTags(completion: { [weak self] tags in
            guard let sSelf = self else { return }
            if !tags.isEmpty {
                sSelf.persistCloudData(tags)
                sSelf.cloudCache.markFresh()
                sSelf.buildTimeline(
                    configuration: configuration,
                    cloudTags: tags,
                    localSnapshot: localSnapshot,
                    completion: completion
                )
            } else if localSnapshot != nil {
                sSelf.buildTimeline(
                    configuration: configuration,
                    cloudTags: nil,
                    localSnapshot: localSnapshot,
                    completion: completion
                )
            } else {
                sSelf.emptyTimeline(
                    for: configuration,
                    completion: completion
                )
            }
        })
    }

    private func useCachedData(
        for configuration: SingleSensorWidgetConfiguration,
        localSnapshot: WidgetSensorSnapshot?,
        completion: @escaping (Timeline<WidgetEntry>) -> Void
    ) {
        buildTimeline(
            configuration: configuration,
            cloudTags: nil,
            localSnapshot: localSnapshot,
            completion: completion
        )
    }

    private func persistCloudData(_ tags: [RuuviCloudSensorDense]) {
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
            localCache.upsert(
                sensorId: tag.sensor.id,
                name: tag.sensor.name,
                macId: record.macId?.value,
                luid: record.luid?.value,
                record: recordSnapshot,
                settings: settingsSnapshot
            )
        }
    }
}

extension WidgetProvider {
    private func localSnapshot(
        for configuration: SingleSensorWidgetConfiguration
    ) -> WidgetSensorSnapshot? {
        guard let identifier = configuration.sensorId else { return nil }
        return localCache.snapshot(matching: identifier)
    }

    private func emptyTimeline(
        for configuration: SingleSensorWidgetConfiguration,
        completion: @escaping (Timeline<WidgetEntry>) -> Void
    ) {
        var entries: [WidgetEntry] = []

        let entry = WidgetEntry.empty(
            with: configuration
        )
        entries.append(entry)
        let timeline = Timeline(
            entries: entries,
            policy: .atEnd
        )
        return completion(timeline)
    }

    private func buildTimeline(
        configuration: SingleSensorWidgetConfiguration,
        cloudTags: [RuuviCloudSensorDense]?,
        localSnapshot: WidgetSensorSnapshot?,
        completion: @escaping (Timeline<WidgetEntry>) -> Void
    ) {
        guard let sensorId = configuration.sensorId else {
            return emptyTimeline(for: configuration, completion: completion)
        }

        let cloudMatch = cloudTags?.first(where: { result in
            sensorIdentifiers(for: result).contains(sensorId)
        })
        let cloudRecord = cloudMatch?.record
        let cloudSensor = cloudMatch?.sensor.any

        let localRecord = localSnapshot?.record?.toRecord()
        let localSettings = localSnapshot.flatMap { settings(from: $0) }
        let localTag = localSnapshot.map {
            RuuviWidgetTag(identifier: $0.id, display: $0.name)
        }

        if let cloudRecord, let cloudSensor {
            if let localRecord, let localTag, localRecord.date > cloudRecord.date {
                timeline(
                    tag: localTag,
                    record: localRecord,
                    settings: localSettings,
                    configuration: configuration,
                    completion: completion
                )
                return
            }

            let resolvedTag = localTag ?? RuuviWidgetTag(
                identifier: cloudSensor.id,
                display: cloudSensor.name
            )
            let resolvedSettings = localSettings ?? SensorSettingsStruct.settings(from: cloudSensor)

            return timeline(
                tag: resolvedTag,
                record: cloudRecord,
                settings: resolvedSettings,
                cloudSettings: cloudMatch?.settings,
                configuration: configuration,
                completion: completion
            )
        }

        if let localRecord, let localTag {
            return timeline(
                tag: localTag,
                record: localRecord,
                settings: localSettings,
                configuration: configuration,
                completion: completion
            )
        }

        return emptyTimeline(for: configuration, completion: completion)
    }

    private func settings(
        from snapshot: WidgetSensorSnapshot
    ) -> SensorSettingsStruct? {
        guard let settings = snapshot.settings else { return nil }
        return SensorSettingsStruct(
            luid: snapshot.luid?.luid,
            macId: snapshot.macId?.mac,
            temperatureOffset: settings.temperatureOffset,
            humidityOffset: settings.humidityOffset,
            pressureOffset: settings.pressureOffset,
            displayOrder: settings.displayOrder,
            defaultDisplayOrder: settings.defaultDisplayOrder
        )
    }

    private func sensorIdentifiers(
        for sensor: RuuviCloudSensorDense
    ) -> [String] {
        [
            sensor.sensor.id,
            sensor.record?.macId?.value,
            sensor.record?.luid?.value,
        ].compactMap { $0 }
    }

    private func timeline(
        tag: RuuviWidgetTag,
        record: RuuviTagSensorRecord,
        settings: SensorSettings?,
        cloudSettings: RuuviCloudSensorSettings? = nil,
        configuration: SingleSensorWidgetConfiguration,
        completion: @escaping (Timeline<WidgetEntry>) -> Void
    ) {
        var entries: [WidgetEntry] = []

        let entry = WidgetEntry(
            date: Date(),
            isAuthorized: true,
            isPreview: false,
            tag: tag,
            record: record,
            settings: settings,
            cloudSettings: cloudSettings,
            config: configuration
        )
        entries.append(entry)

        // Set the next update to be based on widget refresh interval
        let nextUpdateDate = Calendar.current.date(
            byAdding: .minute,
            value: viewModel.refreshIntervalMins(),
            to: Date()
        ) ?? Date()
        let timeline = Timeline(
            entries: entries,
            policy: .after(nextUpdateDate)
        )
        completion(timeline)
    }
}
