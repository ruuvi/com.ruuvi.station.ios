import Foundation
import RuuviCloud
import RuuviOntology
import WidgetKit

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

struct MultiSensorWidgetEntry: TimelineEntry {
    let date: Date
    let isAuthorized: Bool
    let isPreview: Bool
    let sensors: [MultiSensorWidgetSensorItem]
}

extension MultiSensorWidgetEntry {
    static func placeholder(
        for family: WidgetFamily? = nil
    ) -> MultiSensorWidgetEntry {
        let previewSensors: [MultiSensorWidgetSensorItem]
        switch family {
        case .systemMedium:
            previewSensors = mediumPreviewSensors()
        case .systemLarge:
            previewSensors = largePreviewSensors()
        case .systemExtraLarge:
            previewSensors = extraLargePreviewSensors()
        default:
            previewSensors = largePreviewSensors()
        }

        return MultiSensorWidgetEntry(
            date: Date(),
            isAuthorized: true,
            isPreview: true,
            sensors: previewSensors
        )
    }

    private static func mediumPreviewSensors() -> [MultiSensorWidgetSensorItem] {
        [
            previewSensor(
                index: 1,
                sensorId: "preview-air-living-room",
                name: "Living Room",
                record: RuuviTagSensorRecordStruct.previewAirC044(),
                deviceType: .ruuviAir,
                selectedCodes: [
                    .co2ppm,
                    .temperatureC,
                    .humidityRelative,
                    .vocIndex,
                ]
            ),
            previewSensor(
                index: 2,
                sensorId: "preview-bedroom",
                name: "Bedroom",
                record: RuuviTagSensorRecordStruct.previewBedroom(),
                deviceType: .ruuviTag,
                selectedCodes: [
                    .temperatureC,
                    .humidityRelative,
                    .pressureHectopascal,
                ]
            ),
        ]
    }

    private static func largePreviewSensors() -> [MultiSensorWidgetSensorItem] {
        [
            previewSensor(
                index: 1,
                sensorId: "preview-air-living-room",
                name: "Living Room",
                record: RuuviTagSensorRecordStruct.previewAirC044(),
                deviceType: .ruuviAir,
                selectedCodes: []
            ),
            previewSensor(
                index: 2,
                sensorId: "preview-bedroom",
                name: "Bedroom",
                record: RuuviTagSensorRecordStruct.previewBedroom(),
                deviceType: .ruuviTag,
                selectedCodes: []
            ),
            previewSensor(
                index: 3,
                sensorId: "preview-outdoor",
                name: "Outdoor",
                record: RuuviTagSensorRecordStruct.previewOutdoor(),
                deviceType: .ruuviTag,
                selectedCodes: []
            ),
        ]
    }

    private static func extraLargePreviewSensors() -> [MultiSensorWidgetSensorItem] {
        [
            previewSensor(
                index: 1,
                sensorId: "preview-air-living-room",
                name: "Living Room",
                record: RuuviTagSensorRecordStruct.previewAirC044(),
                deviceType: .ruuviAir,
                selectedCodes: []
            ),
            previewSensor(
                index: 2,
                sensorId: "preview-bedroom",
                name: "Bedroom",
                record: RuuviTagSensorRecordStruct.previewBedroom(),
                deviceType: .ruuviTag,
                selectedCodes: []
            ),
            previewSensor(
                index: 3,
                sensorId: "preview-kids-room",
                name: "Kids Room",
                record: RuuviTagSensorRecordStruct.previewLivingRoom(),
                deviceType: .ruuviTag,
                selectedCodes: []
            ),
            previewSensor(
                index: 4,
                sensorId: "preview-kitchen",
                name: "Kitchen",
                record: RuuviTagSensorRecordStruct.previewKitchen(),
                deviceType: .ruuviTag,
                selectedCodes: []
            ),
            previewSensor(
                index: 5,
                sensorId: "preview-outdoor",
                name: "Outdoor",
                record: RuuviTagSensorRecordStruct.previewOutdoor(),
                deviceType: .ruuviTag,
                selectedCodes: []
            ),
            previewSensor(
                index: 6,
                sensorId: "preview-sauna",
                name: "Sauna",
                record: RuuviTagSensorRecordStruct.previewSauna(),
                deviceType: .ruuviTag,
                selectedCodes: []
            ),
        ]
    }

    // swiftlint:disable:next function_parameter_count
    private static func previewSensor(
        index: Int,
        sensorId: String,
        name: String,
        record: RuuviTagSensorRecord,
        deviceType: RuuviDeviceType,
        selectedCodes: [RuuviCloudSensorVisibilityCode]
    ) -> MultiSensorWidgetSensorItem {
        MultiSensorWidgetSensorItem(
            id: "\(index)-preview",
            sensorId: sensorId,
            name: name,
            record: record,
            settings: nil,
            cloudSettings: nil,
            deviceType: deviceType,
            selectedCodes: selectedCodes
        )
    }

    static func empty() -> MultiSensorWidgetEntry {
        MultiSensorWidgetEntry(
            date: Date(),
            isAuthorized: true,
            isPreview: false,
            sensors: []
        )
    }
}
