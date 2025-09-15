import Intents
import RuuviOntology

class IntentHandler: INExtension, RuuviTagSelectionIntentHandling {
    private let viewModel = WidgetViewModel()
    func provideRuuviWidgetTagOptionsCollection(
        for _: RuuviTagSelectionIntent,
        with completion: @escaping (
            INObjectCollection<RuuviWidgetTag>?,
            Error?
        ) -> Void
    ) {
        viewModel.fetchRuuviTags(completion: { response in
            let tags = response.compactMap { sensor in
                let tag = RuuviWidgetTag(
                    identifier: sensor.sensor.id,
                    display: sensor.sensor.name
                )
                tag.deviceType = self.deviceType(from: sensor.record)
                return tag
            }
            let items = INObjectCollection(items: tags)
            completion(items, nil)
        })
    }

    func provideSensorSelectionOptionsCollection(
        for intent: RuuviTagSelectionIntent,
        with completion: @escaping (
            INObjectCollection<RuuviWidgetTagSensor>?,
            (any Error)?
        ) -> Void
    ) {
        let type = intent.ruuviWidgetTag?.deviceType ?? .unknown
        let allowed: [WidgetSensorEnum]
        switch type {
        case .ruuviAir: allowed = WidgetSensorEnum.ruuviAir
        default: allowed = WidgetSensorEnum.ruuviTag
        }

        let items = allowed.map {
            RuuviWidgetTagSensor(
                identifier: "\($0.rawValue)",
                display: $0.displayName() + unit(for: $0)
            )
        }
        completion(INObjectCollection(items: items), nil)
    }
}

extension IntentHandler {
    private func deviceType(from record: RuuviTagSensorRecord?) -> RuuviDeviceType {
        guard let record else {
            return .unknown
        }
        let firmwareType = RuuviFirmwareVersion.firmwareVersion(
            from: record.version
        )
        return (firmwareType == .e1 || firmwareType == .v6) ? .ruuviAir : .ruuviTag
    }

    private func unit(for widgetSensor: WidgetSensorEnum) -> String {
        if hasUnits(for: widgetSensor) {
            return " (\(widgetSensor.unit(from: viewModel.getAppSettings())))"
        } else {
            return ""
        }
    }

    private func hasUnits(for widgetSensor: WidgetSensorEnum) -> Bool {
        switch widgetSensor {
        case .air_quality, .voc, .nox, .movement_counter:
            return false
        default:
            return true
        }
    }
}
