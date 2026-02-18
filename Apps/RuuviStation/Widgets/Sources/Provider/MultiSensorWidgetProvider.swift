import AppIntents
import RuuviCloud
import RuuviOntology
import WidgetKit

@available(iOSApplicationExtension 17.0, *)
struct MultiSensorWidgetProvider: AppIntentTimelineProvider {
    typealias Intent = MultiSensorWidgetConfigurationIntent
    typealias Entry = MultiSensorWidgetEntry

    private let viewModel = WidgetViewModel()

    func placeholder(in _: Context) -> Entry {
        .placeholder()
    }

    func snapshot(
        for configuration: Intent,
        in _: Context
    ) async -> Entry {
        await makeEntry(for: configuration)
    }

    func timeline(
        for configuration: Intent,
        in _: Context
    ) async -> Timeline<Entry> {
        let entry = await makeEntry(for: configuration)
        let nextUpdateDate = Calendar.current.date(
            byAdding: .minute,
            value: viewModel.refreshIntervalMins(),
            to: Date()
        ) ?? Date()

        return Timeline(
            entries: [entry],
            policy: .after(nextUpdateDate)
        )
    }
}

@available(iOSApplicationExtension 17.0, *)
private extension MultiSensorWidgetProvider {
    func makeEntry(
        for configuration: Intent
    ) async -> Entry {
        guard viewModel.isAuthorized() else {
            return .unauthorized(configuration: configuration)
        }

        let selectedSlots = slotSelections(
            from: configuration
        )

        guard !selectedSlots.isEmpty else {
            return .empty(configuration: configuration)
        }

        let sensors = await viewModel.fetchRuuviTagsAsync()
        let sensorMap = Dictionary(
            uniqueKeysWithValues: sensors.map { ($0.sensor.id, $0) }
        )

        let items: [MultiSensorWidgetSensorItem] = selectedSlots.compactMap { selected in
            guard let sensor = sensorMap[selected.sensorId] else {
                return nil
            }

            let settings = SensorSettingsStruct.settings(from: sensor.sensor.any)
            let deviceType = viewModel.deviceType(from: sensor.record)
            return MultiSensorWidgetSensorItem(
                id: "\(selected.slot)-\(selected.sensorId)",
                sensorId: selected.sensorId,
                name: sensor.sensor.name,
                record: sensor.record,
                settings: settings,
                cloudSettings: sensor.settings,
                deviceType: deviceType,
                selectedCodes: []
            )
        }

        if items.isEmpty {
            return .empty(configuration: configuration)
        }

        return MultiSensorWidgetEntry(
            date: Date(),
            isAuthorized: true,
            isPreview: false,
            sensors: items,
            configuration: configuration
        )
    }

    struct SensorSlotSelection {
        let slot: Int
        let sensorId: String
    }

    func slotSelections(
        from configuration: Intent
    ) -> [SensorSlotSelection] {
        let first = slotSelection(
            slot: 1,
            sensor: configuration.sensor1
        )

        let second = slotSelection(
            slot: 2,
            sensor: configuration.sensor2
        )

        return [
            first,
            second,
        ]
        .compactMap { $0 }
    }

    func slotSelection(
        slot: Int,
        sensor: WidgetSensorEntity?
    ) -> SensorSlotSelection? {
        guard let sensor else {
            return nil
        }

        return SensorSlotSelection(
            slot: slot,
            sensorId: sensor.id
        )
    }
}
