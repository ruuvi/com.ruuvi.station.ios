import RuuviLocal
import RuuviOntology

enum WidgetCloudSnapshotStore {
    static func persist(_ tags: [RuuviCloudSensorDense], in cache: WidgetSensorCache) {
        for tag in tags {
            guard let record = tag.record else { continue }
            let identifiers = [tag.sensor.id, record.macId?.value, record.luid?.value].compactMap { $0 }
            let existing = identifiers.lazy.compactMap { cache.snapshot(matching: $0) }.first
            let sensor = tag.sensor.any
            let settings = WidgetSensorSettingsSnapshot(
                temperatureOffset: sensor.offsetTemperature,
                humidityOffset: sensor.offsetHumidity.map { $0 / 100 },
                pressureOffset: sensor.offsetPressure.map { $0 / 100 },
                displayOrder: tag.settings?.displayOrderCodes,
                defaultDisplayOrder: tag.settings?.defaultDisplayOrder)
            cache.upsert(
                sensorId: existing?.id ?? tag.sensor.id, name: existing?.name ?? tag.sensor.name,
                macId: record.macId?.value, luid: record.luid?.value,
                record: WidgetSensorRecordSnapshot(from: record), settings: settings)
        }
    }
}
