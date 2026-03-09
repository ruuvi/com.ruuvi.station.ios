import Intents
import RuuviOntology
import WidgetKit

struct WidgetEntry: TimelineEntry {
    let date: Date
    let isAuthorized: Bool
    let isPreview: Bool
    let tag: RuuviWidgetTag
    let record: RuuviTagSensorRecord?
    let settings: SensorSettings?
    let cloudSettings: RuuviCloudSensorSettings?
    let config: SingleSensorWidgetConfiguration
}

extension WidgetEntry {
    static func placeholder() -> WidgetEntry {
        WidgetEntry(
            date: Date(),
            isAuthorized: true,
            isPreview: true,
            tag: .preview,
            record: RuuviTagSensorRecordStruct.preview(),
            settings: nil,
            cloudSettings: nil,
            config: .preview
        )
    }

    static func empty() -> WidgetEntry {
        WidgetEntry(
            date: Date(),
            isAuthorized: true,
            isPreview: false,
            tag: .preview,
            record: nil,
            settings: nil,
            cloudSettings: nil,
            config: .preview
        )
    }

    static func empty(
        with configuration: SingleSensorWidgetConfiguration
    ) -> WidgetEntry {
        WidgetEntry(
            date: Date(),
            isAuthorized: true,
            isPreview: false,
            tag: .preview,
            record: nil,
            settings: nil,
            cloudSettings: nil,
            config: configuration
        )
    }
}
