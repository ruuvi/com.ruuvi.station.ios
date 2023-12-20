import Intents
import RuuviOntology
import SwiftUI
import WidgetKit

final class WidgetProvider: IntentTimelineProvider {
    @ObservedObject private var networkManager = NetworkManager()
    private let viewModel = WidgetViewModel()

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
        guard networkManager.isConnected, viewModel.isAuthorized()
        else {
            return emptyTimeline(
                for: configuration,
                completion: completion
            )
        }
        viewModel.fetchRuuviTags(completion: { [weak self] tags in
            guard let sSelf = self else { return }
            guard let configuredTag = configuration.ruuviWidgetTag,
                  let tag = tags.first(where: { result in
                      result.sensor.id == configuredTag.identifier
                  })
            else {
                return sSelf.emptyTimeline(
                    for: configuration,
                    completion: completion
                )
            }

            guard let record = tag.record
            else {
                return sSelf.emptyTimeline(
                    for: configuration,
                    completion: completion
                )
            }
            sSelf.timeline(
                from: tag.sensor.any,
                configuration: configuration,
                record: record,
                completion: completion
            )
        })
    }
}

extension WidgetProvider {
    private func emptyTimeline(
        for configuration: RuuviTagSelectionIntent,
        completion: @escaping (Timeline<WidgetEntry>) -> Void
    ) {
        var entries: [WidgetEntry] = []

        let entry = WidgetEntry.empty(
            with: configuration,
            authorized: viewModel.isAuthorized()
        )
        entries.append(entry)
        let timeline = Timeline(
            entries: entries,
            policy: .atEnd
        )
        return completion(timeline)
    }

    private func timeline(
        from ruuviTag: AnyCloudSensor,
        configuration: RuuviTagSelectionIntent,
        record: RuuviTagSensorRecord,
        completion: @escaping (Timeline<WidgetEntry>) -> Void
    ) {
        var entries: [WidgetEntry] = []

        let settings = SensorSettingsStruct.settings(from: ruuviTag)
        let entry = WidgetEntry(
            date: Date(),
            isAuthorized: viewModel.isAuthorized(),
            tag: RuuviWidgetTag(identifier: ruuviTag.id, display: ruuviTag.name),
            record: record,
            settings: settings,
            config: configuration
        )
        entries.append(entry)
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}
