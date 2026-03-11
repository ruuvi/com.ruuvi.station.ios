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
                sensorId: "preview-air-showroom",
                name: "Showroom Air",
                record: RuuviTagSensorRecordStruct.previewAirC044(),
                deviceType: .ruuviAir,
                selectedCodes: [
                    .aqiIndex,
                    .co2ppm,
                    .vocIndex,
                    .humidityRelative,
                ]
            ),
            previewSensor(
                index: 2,
                sensorId: "preview-wellness-spa",
                name: "Wellness Spa",
                record: RuuviTagSensorRecordStruct.previewSauna(),
                deviceType: .ruuviTag,
                selectedCodes: [
                    .temperatureC,
                    .humidityRelative,
                    .pressureHectopascal,
                    .movementCount,
                ]
            ),
        ]
    }

    private static func largePreviewSensors() -> [MultiSensorWidgetSensorItem] {
        [
            previewSensor(
                index: 1,
                sensorId: "preview-air-showroom",
                name: "Showroom Air",
                record: RuuviTagSensorRecordStruct.previewAirC044(),
                deviceType: .ruuviAir,
                selectedCodes: []
            ),
            previewSensor(
                index: 2,
                sensorId: "preview-air-studio",
                name: "Loft Air",
                record: RuuviTagSensorRecordStruct.previewAirOld(),
                deviceType: .ruuviAir,
                selectedCodes: []
            ),
            previewSensor(
                index: 3,
                sensorId: "preview-office-comfort",
                name: "Executive Office",
                record: RuuviTagSensorRecordStruct.previewOffice(),
                deviceType: .ruuviTag,
                selectedCodes: [
                    .temperatureC,
                    .humidityRelative,
                    .pressureHectopascal,
                    .batteryVoltage,
                ]
            ),
        ]
    }

    private static func extraLargePreviewSensors() -> [MultiSensorWidgetSensorItem] {
        [
            previewSensor(
                index: 1,
                sensorId: "preview-air-showroom",
                name: "Showroom Air",
                record: RuuviTagSensorRecordStruct.previewAirC044(),
                deviceType: .ruuviAir,
                selectedCodes: []
            ),
            previewSensor(
                index: 2,
                sensorId: "preview-air-studio",
                name: "Loft Air",
                record: RuuviTagSensorRecordStruct.previewAirOld(),
                deviceType: .ruuviAir,
                selectedCodes: []
            ),
            previewSensor(
                index: 3,
                sensorId: "preview-office",
                name: "Executive Office",
                record: RuuviTagSensorRecordStruct.previewOffice(),
                deviceType: .ruuviTag,
                selectedCodes: []
            ),
            previewSensor(
                index: 4,
                sensorId: "preview-sauna",
                name: "Wellness Spa",
                record: RuuviTagSensorRecordStruct.previewSauna(),
                deviceType: .ruuviTag,
                selectedCodes: []
            ),
            previewSensor(
                index: 5,
                sensorId: "preview-living-room",
                name: "Living Room",
                record: RuuviTagSensorRecordStruct.previewLivingRoom(),
                deviceType: .ruuviTag,
                selectedCodes: []
            ),
            previewSensor(
                index: 6,
                sensorId: "preview-bedroom",
                name: "Bedroom",
                record: RuuviTagSensorRecordStruct.previewBedroom(),
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
