import Foundation

public enum CloudGraphMetricName: String, CaseIterable, Codable, Sendable {
    case temperature, humidity, pressure, accelerationX, accelerationY, accelerationZ
    case battery, txPower, movementCounter, measurementSequenceNumber, rssi
    // Wire names pm10/pm100 mean PM1.0/PM10, respectively.
    case pm10, pm25, pm40, pm100, co2, voc, nox, luminosity
    case dbAverage, dbPeak, dbInstant
    case absoluteHumidity, dewPoint, aqi

    public var isCounter: Bool { self == .movementCounter || self == .measurementSequenceNumber }
    public var unit: String {
        switch self {
        case .temperature, .dewPoint: return "°C"
        case .absoluteHumidity: return "g/m³"
        case .aqi: return ""
        case .humidity: return "%"
        case .pressure: return "Pa"
        case .accelerationX, .accelerationY, .accelerationZ: return "mg"
        case .battery: return "mV"
        case .txPower, .rssi: return "dBm"
        case .pm10, .pm25, .pm40, .pm100: return "µg/m³"
        case .co2: return "ppm"
        case .voc, .nox: return ""
        case .luminosity: return "lx"
        case .dbAverage, .dbPeak, .dbInstant: return "dB"
        case .movementCounter, .measurementSequenceNumber: return ""
        }
    }
}
public struct CloudGraphMetric: Decodable, Sendable {
    public let mean: Double?
    public let min: Double?
    public let max: Double?
    public let count: Int64
    public let last: Double?
}
public struct CloudGraphPoint: Decodable, Sendable {
    public let timestamp: Int64
    public let metrics: [String: CloudGraphMetric]
}
public struct CloudGraphSeries: Decodable, Sendable {
    public let sensor: String
    public let name: String
    public let since: Int64
    public let until: Int64
    public let resolutionSeconds: Int64
    public let offsetTemperature: Double
    public let offsetHumidity: Double
    public let offsetPressure: Double
    public let points: [CloudGraphPoint]
    public func offset(_ metric: CloudGraphMetricName) -> Double {
        switch metric {
        case .temperature: return offsetTemperature
        case .humidity: return offsetHumidity
        case .pressure: return offsetPressure
        default: return 0
        }
    }
    public func statistics(_ metric: CloudGraphMetricName, in range: ClosedRange<Double>? = nil) -> CloudGraphStatistics? {
        let values = points.filter { range?.contains(Double($0.timestamp)) ?? true }.compactMap { $0.metrics[metric.rawValue] }.filter { $0.count > 0 }
        guard let minimum = values.compactMap(\.min).min(), let maximum = values.compactMap(\.max).max()
        else { return nil }
        let counted = values.filter { $0.mean != nil }
        let count = counted.reduce(0.0) { $0 + Double($1.count) }
        let average =
            count > 0 && !metric.isCounter
            ? counted.reduce(0.0) { $0 + $1.mean! * Double($1.count) } / count + offset(metric) : nil
        return CloudGraphStatistics(
            min: minimum + offset(metric),
            max: maximum + offset(metric),
            mean: average
        )
    }
    public func samples(_ metric: CloudGraphMetricName) -> [CloudGraphSample] {
        var segment = 0
        var previous: Int64?
        return points.sorted { $0.timestamp < $1.timestamp }.compactMap { point in
            guard let value = point.metrics[metric.rawValue], value.count > 0,
                let numeric = metric.isCounter ? value.last : value.mean
            else {
                segment += 1
                return nil
            }
            if let previous, point.timestamp - previous > resolutionSeconds { segment += 1 }
            previous = point.timestamp
            return CloudGraphSample(
                timestamp: max(since, point.timestamp),
                value: numeric + offset(metric),
                segment: segment
            )
        }
    }
}
public struct CloudGraphSample: Identifiable, Sendable {
    public var id: Int64 { timestamp }
    public let timestamp: Int64
    public let value: Double
    public let segment: Int
}
public struct CloudGraphStatistics: Sendable {
    public let min: Double
    public let max: Double
    public let mean: Double?
}
public struct CloudGraphResponse: Decodable, Sendable {
    public let series: [CloudGraphSeries]
    public let maxPoints: Int
    public let targetPoints: Int
}
public struct CloudGraphQuery: Encodable, Sendable {
    static let pointLimit = 1500

    /// Server-authorized history, independent of local storage retention and plan names.
    public static func historyHours(maxHistoryDays: Int?) -> Int? {
        guard let days = maxHistoryDays, days > 0 else { return nil }
        return min(1096, days) * 24
    }
    public let sensors: [String]
    public let since: Int64
    public let until: Int64
    public let metrics: [CloudGraphMetricName]
    public let maxPoints = Self.pointLimit
    public let format: String
    public let targetPoints = 1000
    public init(
        sensors: [String],
        since: Int64,
        until: Int64,
        metrics: [CloudGraphMetricName] = CloudGraphMetricName.allCases,
        compact: Bool = true
    ) throws {
        let sensors = sensors.map { $0.uppercased() }
        guard (1...8).contains(sensors.count), Set(sensors).count == sensors.count,
            sensors.allSatisfy({ $0.range(of: "^[0-9A-F]{2}(:[0-9A-F]{2}){5}$", options: .regularExpression) != nil }),
            since >= 0, until > since, until <= 253_402_300_799,
            until - since <= 1096 * 86400, !metrics.isEmpty, Set(metrics).count == metrics.count
        else {
            throw CloudGraphError.invalid("Invalid graph range or sensors.")
        }
        self.sensors = sensors
        self.since = since
        self.until = until
        self.metrics = metrics
        self.format = compact ? "columns" : "points"
    }
    public func validate(_ response: CloudGraphResponse) throws {
        guard response.series.count == sensors.count, Set(response.series.map(\.sensor)) == Set(sensors),
              response.maxPoints <= maxPoints, response.targetPoints <= maxPoints,
              response.series.allSatisfy({ series in
                  series.resolutionSeconds > 0 && series.resolutionSeconds <= 1096 * 86400
                      && series.since >= since && series.until >= series.since && series.until <= until
                      && series.points.allSatisfy { point in
                          point.timestamp >= 0 && point.timestamp <= series.until
                              && point.timestamp + series.resolutionSeconds > series.since
                              && Set(point.metrics.keys).isSubset(of: Set(metrics.map(\.rawValue)))
                      }
              }) else { throw CloudGraphError.invalid("Invalid graph response.") }
    }
}
