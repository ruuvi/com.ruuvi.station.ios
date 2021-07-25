import Foundation

public protocol VirtualTagSensorRecord: Sensor {
    var sensorId: String { get }
    var date: Date { get }
    var temperature: Temperature? { get }
    var humidity: Humidity? { get }
    var pressure: Pressure? { get }
    var location: Location? { get }
}

extension VirtualTagSensorRecord {
    public var id: String {
        return sensorId + "\(date.timeIntervalSince1970)"
    }

    public var any: AnyVirtualTagSensorRecord {
        return AnyVirtualTagSensorRecord(object: self)
    }
}

public struct VirtualTagSensorRecordStruct: VirtualTagSensorRecord {
    public var sensorId: String
    public var date: Date
    public var temperature: Temperature?
    public var humidity: Humidity?
    public var pressure: Pressure?
    public var location: Location?

    public init(
        sensorId: String,
        date: Date,
        temperature: Temperature?,
        humidity: Humidity?,
        pressure: Pressure?,
        location: Location?
    ) {
        self.sensorId = sensorId
        self.date = date
        self.temperature = temperature
        self.humidity = humidity
        self.pressure = pressure
        self.location = location
    }
}

public struct AnyVirtualTagSensorRecord: VirtualTagSensorRecord, Equatable, Hashable {
    private var object: VirtualTagSensorRecord

    public init(object: VirtualTagSensorRecord) {
        self.object = object
    }

    public var sensorId: String {
        return object.sensorId
    }

    public var date: Date {
        return object.date
    }

    public var temperature: Temperature? {
        return object.temperature
    }

    public var humidity: Humidity? {
        return object.humidity
    }

    public var pressure: Pressure? {
        return object.pressure
    }

    public var location: Location? {
        return object.location
    }

    public static func == (lhs: AnyVirtualTagSensorRecord, rhs: AnyVirtualTagSensorRecord) -> Bool {
        return lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
