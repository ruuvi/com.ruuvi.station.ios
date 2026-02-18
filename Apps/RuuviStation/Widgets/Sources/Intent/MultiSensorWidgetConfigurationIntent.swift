import AppIntents
import Foundation

@available(iOSApplicationExtension 17.0, *)
struct MultiSensorWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Sensors"
    static var description = IntentDescription(
        "Select up to two sensors. Measurements follow each sensor visibility profile."
    )

    @Parameter(title: "Sensor 1")
    var sensor1: WidgetSensorEntity?

    @Parameter(title: "Sensor 2")
    var sensor2: WidgetSensorEntity?

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$sensor1
            \.$sensor2
        }
    }

    init() {
        sensor1 = nil
        sensor2 = nil
    }
}

@available(iOSApplicationExtension 17.0, *)
struct WidgetSensorEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Sensor"
    )

    static var defaultQuery = WidgetSensorEntityQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

@available(iOSApplicationExtension 17.0, *)
struct WidgetSensorEntityQuery: EntityStringQuery {
    func entities(for identifiers: [WidgetSensorEntity.ID]) async throws -> [WidgetSensorEntity] {
        let all = await WidgetIntentDataSource.sensorEntities()
        let entityMap = Dictionary(
            uniqueKeysWithValues: all.map { ($0.id, $0) }
        )
        return identifiers.compactMap { entityMap[$0] }
    }

    func suggestedEntities() async throws -> [WidgetSensorEntity] {
        await WidgetIntentDataSource.sensorEntities()
    }

    func entities(matching string: String) async throws -> [WidgetSensorEntity] {
        let all = await WidgetIntentDataSource.sensorEntities()
        guard !string.isEmpty else {
            return all
        }

        let query = string.lowercased()
        return all.filter { entity in
            entity.name.lowercased().contains(query)
        }
    }
}

@available(iOSApplicationExtension 17.0, *)
private enum WidgetIntentDataSource {
    static func sensorEntities() async -> [WidgetSensorEntity] {
        let viewModel = WidgetViewModel()
        let sensors = await viewModel.fetchRuuviTagsAsync()

        return sensors.map { sensor in
            WidgetSensorEntity(
                id: sensor.sensor.id,
                name: sensor.sensor.name
            )
        }
        .sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
