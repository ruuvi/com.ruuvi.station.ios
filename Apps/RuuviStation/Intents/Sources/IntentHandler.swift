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
        let options = viewModel.measurementOptions(for: type)
        let items = options.map {
            RuuviWidgetTagSensor(
                identifier: $0.code.rawValue,
                display: $0.title
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
        let firmwareType = RuuviDataFormat.dataFormat(
            from: record.version
        )
        return (firmwareType == .e1 || firmwareType == .v6) ? .ruuviAir : .ruuviTag
    }
}
