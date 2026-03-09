import Intents
import RuuviLocal
import RuuviOntology

class IntentHandler: INExtension, RuuviTagSelectionIntentHandling, RuuviMultiSensorSelectionIntentHandling {
    private let viewModel = WidgetViewModel()
    private let localCache = WidgetSensorCache()

    func provideRuuviWidgetTagOptionsCollection(
        for _: RuuviTagSelectionIntent,
        with completion: @escaping (
            INObjectCollection<RuuviWidgetTag>?,
            Error?
        ) -> Void
    ) {
        provideWidgetTagOptionsCollection(completion: completion)
    }

    func provideSensor1OptionsCollection(
        for _: RuuviMultiSensorSelectionIntent,
        with completion: @escaping (
            INObjectCollection<RuuviWidgetTag>?,
            Error?
        ) -> Void
    ) {
        provideWidgetTagOptionsCollection(completion: completion)
    }

    func provideSensor2OptionsCollection(
        for _: RuuviMultiSensorSelectionIntent,
        with completion: @escaping (
            INObjectCollection<RuuviWidgetTag>?,
            Error?
        ) -> Void
    ) {
        provideWidgetTagOptionsCollection(completion: completion)
    }

    func provideSensor3OptionsCollection(
        for _: RuuviMultiSensorSelectionIntent,
        with completion: @escaping (
            INObjectCollection<RuuviWidgetTag>?,
            Error?
        ) -> Void
    ) {
        provideWidgetTagOptionsCollection(completion: completion)
    }

    func provideSensor4OptionsCollection(
        for _: RuuviMultiSensorSelectionIntent,
        with completion: @escaping (
            INObjectCollection<RuuviWidgetTag>?,
            Error?
        ) -> Void
    ) {
        provideWidgetTagOptionsCollection(completion: completion)
    }

    func provideSensor5OptionsCollection(
        for _: RuuviMultiSensorSelectionIntent,
        with completion: @escaping (
            INObjectCollection<RuuviWidgetTag>?,
            Error?
        ) -> Void
    ) {
        provideWidgetTagOptionsCollection(completion: completion)
    }

    func provideSensor6OptionsCollection(
        for _: RuuviMultiSensorSelectionIntent,
        with completion: @escaping (
            INObjectCollection<RuuviWidgetTag>?,
            Error?
        ) -> Void
    ) {
        provideWidgetTagOptionsCollection(completion: completion)
    }

    func provideWidgetTagOptionsCollection(
        completion: @escaping (
            INObjectCollection<RuuviWidgetTag>?,
            Error?
        ) -> Void
    ) {
        let localSnapshots = localCache.loadAll()
        guard viewModel.isAuthorized() else {
            completion(
                INObjectCollection(
                    items: widgetTagOptions(
                        from: localTags(from: localSnapshots)
                    )
                ),
                nil
            )
            return
        }

        viewModel.fetchRuuviTags(completion: { response in
            var tags: [RuuviWidgetTag] = []
            tags.reserveCapacity(response.count + localSnapshots.count)
            var seenIdentifiers = Set<String>()

            response.forEach { sensor in
                let sensorIdentifiers = [
                    sensor.sensor.id,
                    sensor.record?.macId?.value,
                    sensor.record?.luid?.value,
                ].compactMap { $0 }
                let localName = localSnapshots.first(where: { snapshot in
                    sensorIdentifiers.contains { identifier in
                        snapshot.matches(identifier: identifier)
                    }
                })?.name

                let tag = RuuviWidgetTag(
                    identifier: sensor.sensor.id,
                    display: localName ?? sensor.sensor.name
                )
                tag.deviceType = self.deviceType(from: sensor.record)
                tags.append(tag)
                [
                    sensor.sensor.id,
                    sensor.record?.macId?.value,
                    sensor.record?.luid?.value,
                ].compactMap { $0 }.forEach {
                    seenIdentifiers.insert($0)
                }
            }

            localSnapshots.forEach { snapshot in
                let identifiers = [snapshot.id, snapshot.macId, snapshot.luid].compactMap { $0 }
                guard !identifiers.contains(where: { seenIdentifiers.contains($0) }) else { return }
                tags.append(self.localTag(from: snapshot))
                identifiers.forEach { seenIdentifiers.insert($0) }
            }

            let items = INObjectCollection(items: self.widgetTagOptions(from: tags))
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
    private func localTags(from snapshots: [WidgetSensorSnapshot]) -> [RuuviWidgetTag] {
        snapshots.map(localTag(from:))
    }

    private func localTag(from snapshot: WidgetSensorSnapshot) -> RuuviWidgetTag {
        let tag = RuuviWidgetTag(
            identifier: snapshot.id,
            display: snapshot.name
        )
        tag.deviceType = deviceType(from: snapshot.record)
        return tag
    }

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

    private func widgetTagOptions(
        from tags: [RuuviWidgetTag]
    ) -> [RuuviWidgetTag] {
        guard !tags.isEmpty else {
            return tags
        }

        return [WidgetConfigurationSelection.noneTag()] + tags
    }
}
