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
        let isAuthorized = viewModel.isAuthorized()
        guard configuration.ruuviWidgetTag != nil else {
            return emptyTimeline(
                for: configuration,
                completion: completion
            )
        }

        let localSnapshot = localSnapshot(for: configuration)
        if !isAuthorized {
            return buildTimeline(
                configuration: configuration,
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
                for: configuration,
                localSnapshot: localSnapshot,
                completion: completion
            )
        }

        return fetchData(
            for: configuration,
            localSnapshot: localSnapshot,
            completion: completion
        )
    }

    private func fetchData(
        for configuration: RuuviTagSelectionIntent,
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
        for configuration: RuuviTagSelectionIntent,
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
        for configuration: RuuviTagSelectionIntent
    ) -> WidgetSensorSnapshot? {
        guard let identifier = configuration.ruuviWidgetTag?.identifier else { return nil }
        return localCache.snapshot(matching: identifier)
    }

    private func emptyTimeline(
        for configuration: RuuviTagSelectionIntent,
        completion: @escaping (Timeline<WidgetEntry>) -> Void
    ) {
        var entries: [WidgetEntry] = []

        let entry = WidgetEntry.empty(
            with: configuration,
            authorized: true
        )
        entries.append(entry)
        let timeline = Timeline(
            entries: entries,
            policy: .atEnd
        )
        return completion(timeline)
    }

    private func buildTimeline(
        configuration: RuuviTagSelectionIntent,
        cloudTags: [RuuviCloudSensorDense]?,
        localSnapshot: WidgetSensorSnapshot?,
        completion: @escaping (Timeline<WidgetEntry>) -> Void
    ) {
        guard let configuredTag = configuration.ruuviWidgetTag else {
            return emptyTimeline(for: configuration, completion: completion)
        }

        let cloudMatch = cloudTags?.first(where: { result in
            result.sensor.id == configuredTag.identifier
        })
        let cloudRecord = cloudMatch?.record
        let cloudSensor = cloudMatch?.sensor.any

        let localRecord = localSnapshot?.record?.toRecord()
        let localSettings = localSnapshot.flatMap { settings(from: $0) }
        let localTag = localSnapshot.map {
            RuuviWidgetTag(identifier: $0.id, display: $0.name)
        }

        if let cloudRecord, let cloudSensor, let localRecord, let localTag {
            if localRecord.date > cloudRecord.date {
                timeline(
                    tag: localTag,
                    record: localRecord,
                    settings: localSettings,
                    configuration: configuration,
                    completion: completion
                )
            } else {
                timeline(
                    from: cloudSensor,
                    configuration: configuration,
                    record: cloudRecord,
                    completion: completion
                )
            }
            return
        }

        if let cloudRecord, let cloudSensor {
            return timeline(
                from: cloudSensor,
                configuration: configuration,
                record: cloudRecord,
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

    private func timeline(
        from ruuviTag: AnyCloudSensor,
        configuration: RuuviTagSelectionIntent,
        record: RuuviTagSensorRecord,
        completion: @escaping (Timeline<WidgetEntry>) -> Void
    ) {
        let settings = SensorSettingsStruct.settings(from: ruuviTag)
        let tag = RuuviWidgetTag(identifier: ruuviTag.id, display: ruuviTag.name)
        timeline(
            tag: tag,
            record: record,
            settings: settings,
            configuration: configuration,
            completion: completion
        )
    }

    private func timeline(
        tag: RuuviWidgetTag,
        record: RuuviTagSensorRecord,
        settings: SensorSettings?,
        configuration: RuuviTagSelectionIntent,
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
