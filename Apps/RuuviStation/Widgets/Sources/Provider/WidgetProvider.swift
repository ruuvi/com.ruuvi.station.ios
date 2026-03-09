import Intents
import RuuviLocal
import RuuviOntology
import WidgetKit

final class WidgetProvider: IntentTimelineProvider {
    private let viewModel = WidgetViewModel()
    private let localCache = WidgetSensorCache()
    private var cachedTags: [RuuviCloudSensorDense] = []
    private var cacheTimestamp: Date?

    func placeholder(in _: Context) -> WidgetEntry {
        WidgetEntry.placeholder()
    }

    func getSnapshot(
        for _: RuuviTagSelectionIntent,
        in _: Context,
        completion: @escaping (WidgetEntry) -> Void
    ) {
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
        let cacheIsRecent = {
            guard let cacheTimestamp else { return false }
            let refreshSeconds = Double(viewModel.refreshIntervalMins() * 60)
            return Date().timeIntervalSince(cacheTimestamp) < refreshSeconds
        }()

        if cacheIsRecent, !cachedTags.isEmpty, !viewModel.shouldForceRefresh() {
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
                sSelf.cachedTags = tags
                sSelf.cacheTimestamp = Date()
                sSelf.buildTimeline(
                    configuration: configuration,
                    cloudTags: tags,
                    localSnapshot: localSnapshot,
                    completion: completion
                )
            } else if !sSelf.cachedTags.isEmpty {
                sSelf.buildTimeline(
                    configuration: configuration,
                    cloudTags: sSelf.cachedTags,
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
            cloudTags: cachedTags,
            localSnapshot: localSnapshot,
            completion: completion
        )
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
            pressureOffset: settings.pressureOffset
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
        from ruuviTag: AnyCloudSensor,
        configuration: SingleSensorWidgetConfiguration,
        record: RuuviTagSensorRecord,
        cloudSettings: RuuviCloudSensorSettings?,
        completion: @escaping (Timeline<WidgetEntry>) -> Void
    ) {
        let settings = SensorSettingsStruct.settings(from: ruuviTag)
        let tag = RuuviWidgetTag(identifier: ruuviTag.id, display: ruuviTag.name)
        timeline(
            tag: tag,
            record: record,
            settings: settings,
            cloudSettings: cloudSettings,
            configuration: configuration,
            completion: completion
        )
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
