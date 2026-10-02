import Intents
import RuuviLocal
import RuuviOntology

class IntentHandler: INExtension, RuuviTagSelectionIntentHandling, RuuviMultiSensorSelectionIntentHandling {
    private let viewModel = WidgetViewModel()
    private let localCache = WidgetSensorCache()
    private let cloudCache = WidgetCloudCache()

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

        // Serve from local cache when cloud data is still fresh — no network round-trip
        if cloudCache.isFresh(intervalMinutes: viewModel.refreshIntervalMins()),
           !localSnapshots.isEmpty {
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

        let delivery = WidgetOptionsDelivery(completion: completion)
        // Preserve cloud discovery when no local sensor list is available.
        if !localSnapshots.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                let latest = self.localCache.loadAll()
                let fallback = latest.isEmpty ? localSnapshots : latest
                let items = INObjectCollection(items: self.widgetTagOptions(from: self.localTags(from: fallback)))
                delivery.finish(items)
            }
        }

        viewModel.fetchRuuviTags(completion: { response in
            // Keep late results for the next edit session, even if the local list was already delivered.
            let latest = self.localCache.loadAll()
            let fallbackSnapshots = latest.isEmpty ? localSnapshots : latest
            if !response.isEmpty {
                self.persistCloudData(response)
                self.cloudCache.markFresh()
            }
            delivery.finish(self.widgetTagOptionsCollection(from: response, localSnapshots: fallbackSnapshots))
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
        let record: RuuviTagSensorRecord? = {
            guard let identifier = intent.ruuviWidgetTag?.identifier else { return nil }
            return localCache.snapshot(matching: identifier)?.record?.toRecord()
        }()
        let options = viewModel.measurementOptions(for: type, using: record)
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
    private func widgetTagOptionsCollection(
        from response: [RuuviCloudSensorDense],
        localSnapshots: [WidgetSensorSnapshot]
    ) -> INObjectCollection<RuuviWidgetTag> {
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

        return INObjectCollection(items: widgetTagOptions(from: tags))
    }

    private func persistCloudData(_ tags: [RuuviCloudSensorDense]) {
        for tag in tags {
            guard let record = tag.record else { continue }
            let recordSnapshot = WidgetSensorRecordSnapshot(from: record)
            let sensor = tag.sensor.any
            let settingsSnapshot = WidgetSensorSettingsSnapshot(
                temperatureOffset: sensor.offsetTemperature,
                humidityOffset: sensor.offsetHumidity.map { $0 / 100 },
                pressureOffset: sensor.offsetPressure.map { $0 / 100 },
                displayOrder: tag.settings?.displayOrderCodes,
                defaultDisplayOrder: tag.settings?.defaultDisplayOrder
            )
            localCache.upsert(
                sensorId: tag.sensor.id,
                name: tag.sensor.name,
                macId: record.macId?.value,
                luid: record.luid?.value,
                record: recordSnapshot,
                settings: settingsSnapshot
            )
        }
    }

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

// Intent option requests must complete once, even if the cloud returns after the fallback.
private final class WidgetOptionsDelivery {
    private let lock = NSLock()
    private var completion: ((INObjectCollection<RuuviWidgetTag>?, Error?) -> Void)?

    init(completion: @escaping (INObjectCollection<RuuviWidgetTag>?, Error?) -> Void) {
        self.completion = completion
    }

    func finish(_ items: INObjectCollection<RuuviWidgetTag>) {
        lock.lock()
        let callback = completion
        completion = nil
        lock.unlock()
        callback?(items, nil)
    }
}
