import Intents
import RuuviLocal
import RuuviOntology

class IntentHandler: INExtension, RuuviTagSelectionIntentHandling {
    private let viewModel = WidgetViewModel()
    private let localCache = WidgetSensorCache()
    func provideRuuviWidgetTagOptionsCollection(
        for _: RuuviTagSelectionIntent,
        with completion: @escaping (
            INObjectCollection<RuuviWidgetTag>?,
            Error?
        ) -> Void
    ) {
        let localSnapshots = localCache.loadAll()

        viewModel.fetchRuuviTags(completion: { response in
            var tags: [RuuviWidgetTag] = []
            tags.reserveCapacity(response.count + localSnapshots.count)
            var seenIdentifiers = Set<String>()

            response.forEach { sensor in
                let tag = RuuviWidgetTag(
                    identifier: sensor.sensor.id,
                    display: sensor.sensor.name
                )
                tag.deviceType = self.deviceType(from: sensor.record)
                tags.append(tag)
                seenIdentifiers.insert(sensor.sensor.id)
            }

            localSnapshots.forEach { snapshot in
                let identifiers = [snapshot.id, snapshot.macId, snapshot.luid].compactMap { $0 }
                guard !identifiers.contains(where: { seenIdentifiers.contains($0) }) else { return }
                let tag = RuuviWidgetTag(
                    identifier: snapshot.id,
                    display: snapshot.name
                )
                tag.deviceType = self.deviceType(from: snapshot.record)
                tags.append(tag)
                identifiers.forEach { seenIdentifiers.insert($0) }
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
        let firmwareType = RuuviDataFormat.dataFormat(
            from: record.version
        )
        return (firmwareType == .e1 || firmwareType == .v6) ? .ruuviAir : .ruuviTag
    }

    private func deviceType(from record: WidgetSensorRecordSnapshot?) -> RuuviDeviceType {
        guard let version = record?.version else {
            return .unknown
        }
        let firmwareType = RuuviDataFormat.dataFormat(
            from: version
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
