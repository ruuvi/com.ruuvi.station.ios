import Foundation

public struct RuuviCloudSensorDense {
    public let sensor: CloudSensor
    public let record: RuuviTagSensorRecord?
    public let alerts: RuuviCloudSensorAlerts
    public let subscription: CloudSensorSubscription?

    public init(sensor: CloudSensor,
                record: RuuviTagSensorRecord?,
                alerts: RuuviCloudSensorAlerts,
                subscription: CloudSensorSubscription?) {
        self.sensor = sensor
        self.record = record
        self.alerts = alerts
        self.subscription = subscription
    }
}

public struct AnyCloudSensorDense: CloudSensor, Equatable, Hashable, Reorderable {
    private let sensor: CloudSensor
    private let record: RuuviTagSensorRecord
    private let subscription: CloudSensorSubscription?

    public init(sensor: CloudSensor,
                record: RuuviTagSensorRecord,
                subscription: CloudSensorSubscription?) {
        self.sensor = sensor
        self.record = record
        self.subscription = subscription
    }

    public var id: String {
        return sensor.id
    }

    public var name: String {
        return sensor.name
    }

    public var isClaimed: Bool {
        return sensor.isClaimed
    }

    public var isOwner: Bool {
        return sensor.isOwner
    }

    public var owner: String? {
        return sensor.owner
    }

    public var ownersPlan: String? {
        return subscription?.subscriptionName
    }

    public var picture: URL? {
        return sensor.picture
    }

    public var offsetTemperature: Double? {
        return sensor.offsetTemperature
    }

    public var offsetHumidity: Double? {
        return sensor.offsetHumidity
    }

    public var offsetPressure: Double? {
        return sensor.offsetPressure
    }

    public var isCloudSensor: Bool? {
        return sensor.isCloudSensor
    }

    public var canShare: Bool {
        return sensor.canShare
    }

    public var sharedTo: [String] {
        return sensor.sharedTo
    }

    public static func == (lhs: AnyCloudSensorDense, rhs: AnyCloudSensorDense) -> Bool {
        return lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public var orderElement: String {
        return id
    }
}

extension AnyCloudSensorDense: RuuviTagSensorRecord {
    public var luid: LocalIdentifier? {
        return record.luid
    }

    public var date: Date {
        return record.date
    }

    public var source: RuuviTagSensorRecordSource {
        return record.source
    }

    public var macId: MACIdentifier? {
        return record.macId
    }

    public var rssi: Int? {
        return record.rssi
    }

    public var temperature: Temperature? {
        return record.temperature
    }

    public var humidity: Humidity? {
        return record.humidity
    }

    public var pressure: Pressure? {
        return record.pressure
    }

    public var acceleration: Acceleration? {
        return record.acceleration
    }

    public var voltage: Voltage? {
        return record.voltage
    }

    public var movementCounter: Int? {
        return record.movementCounter
    }

    public var measurementSequenceNumber: Int? {
        return record.measurementSequenceNumber
    }

    public var txPower: Int? {
        return record.txPower
    }

    public var temperatureOffset: Double {
        return record.temperatureOffset
    }

    public var humidityOffset: Double {
        return record.humidityOffset
    }

    public var pressureOffset: Double {
        return record.pressureOffset
    }
}
