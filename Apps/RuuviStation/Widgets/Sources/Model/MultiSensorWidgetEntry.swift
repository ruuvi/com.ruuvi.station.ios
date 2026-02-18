import Foundation
import RuuviCloud
import RuuviOntology
import WidgetKit

@available(iOSApplicationExtension 17.0, *)
struct MultiSensorWidgetSensorItem: Identifiable {
    let id: String
    let sensorId: String
    let name: String
    let record: RuuviTagSensorRecord?
    let settings: SensorSettings?
    let cloudSettings: RuuviCloudSensorSettings?
    let deviceType: RuuviDeviceType
    let selectedCodes: [RuuviCloudSensorVisibilityCode]
}

@available(iOSApplicationExtension 17.0, *)
struct MultiSensorWidgetEntry: TimelineEntry {
    let date: Date
    let isAuthorized: Bool
    let isPreview: Bool
    let sensors: [MultiSensorWidgetSensorItem]
    let configuration: MultiSensorWidgetConfigurationIntent
}

@available(iOSApplicationExtension 17.0, *)
extension MultiSensorWidgetEntry {
    static func placeholder() -> MultiSensorWidgetEntry {
        let previewSensor = MultiSensorWidgetSensorItem(
            id: "1-preview",
            sensorId: "preview",
            name: "Sauna",
            record: RuuviTagSensorRecordStruct.preview(),
            settings: nil,
            cloudSettings: nil,
            deviceType: .ruuviTag,
            selectedCodes: []
        )

        return MultiSensorWidgetEntry(
            date: Date(),
            isAuthorized: true,
            isPreview: true,
            sensors: [previewSensor],
            configuration: .init()
        )
    }

    static func unauthorized(
        configuration: MultiSensorWidgetConfigurationIntent
    ) -> MultiSensorWidgetEntry {
        MultiSensorWidgetEntry(
            date: Date(),
            isAuthorized: false,
            isPreview: false,
            sensors: [],
            configuration: configuration
        )
    }

    static func empty(
        configuration: MultiSensorWidgetConfigurationIntent
    ) -> MultiSensorWidgetEntry {
        MultiSensorWidgetEntry(
            date: Date(),
            isAuthorized: true,
            isPreview: false,
            sensors: [],
            configuration: configuration
        )
    }
}
