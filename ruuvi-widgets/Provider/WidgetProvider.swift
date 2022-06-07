import WidgetKit
import SwiftUI
import Intents
import RuuviOntology

@available(iOS 14.0, *)
final class WidgetProvider: IntentTimelineProvider {
    @ObservedObject private var networkManager = NetworkManager()
    private let viewModel = WidgetViewModel()

    func placeholder(in context: Context) -> WidgetEntry {
        return WidgetEntry.placeholder()
    }

    func getSnapshot(for configuration: RuuviTagSelectionIntent,
                     in context: Context,
                     completion: @escaping (WidgetEntry) -> Void) {
        return completion(.placeholder())
    }

    func getTimeline(for configuration: RuuviTagSelectionIntent,
                     in context: Context,
                     completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        guard networkManager.isConnected, viewModel.isAuthorized() else {
            return emptyTimeline(for: configuration,
                                 completion: completion)
        }
        viewModel.fetchRuuviTags(completion: { [weak self] tags in
            guard let sSelf = self else { return }
            guard let configuredTag = configuration.ruuviWidgetTag,
                    let tag = tags.first(where: { result in
                        result.id == configuredTag.identifier
                    }) else {
                return sSelf.emptyTimeline(for: configuration,
                                    completion: completion)
            }

            sSelf.viewModel.fetchRuuviTagRecords(sensor: tag.ruuviTagSensor) { record in
                guard let record = record else {
                    return sSelf.emptyTimeline(for: configuration,
                                               completion: completion)
                }
                sSelf.timeline(from: tag,
                               configuration: configuration,
                               record: record,
                               completion: completion)
            }
        })
    }
}

extension WidgetProvider {
    private func emptyTimeline(for configuration: RuuviTagSelectionIntent,
                               completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        var entries: [WidgetEntry] = []

        let entry = WidgetEntry.empty(with: configuration,
                                      authorized: viewModel.isAuthorized())
        entries.append(entry)
        let timeline = Timeline(entries: entries,
                                policy: .atEnd)
        return completion(timeline)
    }

    private func timeline(from ruuviTag: AnyCloudSensor,
                          configuration: RuuviTagSelectionIntent,
                          record: RuuviTagSensorRecord,
                          completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        var entries: [WidgetEntry] = []

        let settings = SensorSettingsStruct.settings(from: ruuviTag)
        let entry = WidgetEntry(date: Date(),
                                isAuthorized: viewModel.isAuthorized(),
                                tag: RuuviWidgetTag(identifier: ruuviTag.id, display: ruuviTag.name),
                                record: record,
                                settings: settings,
                                config: configuration)
        entries.append(entry)
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}
