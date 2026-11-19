import Foundation

// Decode both wire shapes into the existing bounded chart model. Graphs, statistics
// and zoom detail use exactly the same values regardless of the JSON representation.
extension CloudGraphSeries {
    private enum CodingKeys: String, CodingKey {
        case sensor, name, since, until, resolutionSeconds
        case offsetTemperature, offsetHumidity, offsetPressure
        case points, timestamps, metrics
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let points: [CloudGraphPoint]
        if values.contains(.points) {
            guard !values.contains(.timestamps), !values.contains(.metrics) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .points, in: values, debugDescription: "Ambiguous graph response format."
                )
            }
            points = try values.decode([CloudGraphPoint].self, forKey: .points)
        } else {
            points = try Self.decodeColumns(from: values)
        }
        guard points.count <= CloudGraphQuery.pointLimit,
              zip(points, points.dropFirst()).allSatisfy({ $0.timestamp < $1.timestamp }),
              points.allSatisfy({ point in
                  point.metrics.count <= CloudGraphMetricName.allCases.count && point.metrics.values.allSatisfy {
                      $0.count >= 0 && [$0.mean, $0.min, $0.max, $0.last].compactMap { $0 }.allSatisfy(\.isFinite)
                          && ($0.count != 0 || [$0.mean, $0.min, $0.max, $0.last].allSatisfy { $0 == nil })
                          && ($0.min == nil || $0.max == nil || $0.min! <= $0.max!)
                  }
              }) else {
            throw DecodingError.dataCorruptedError(
                forKey: .points, in: values, debugDescription: "Graph exceeds the point limit."
            )
        }
        self.init(
            sensor: try values.decode(String.self, forKey: .sensor),
            name: try values.decode(String.self, forKey: .name),
            since: try values.decode(Int64.self, forKey: .since),
            until: try values.decode(Int64.self, forKey: .until),
            resolutionSeconds: try values.decode(Int64.self, forKey: .resolutionSeconds),
            offsetTemperature: try values.decode(Double.self, forKey: .offsetTemperature),
            offsetHumidity: try values.decode(Double.self, forKey: .offsetHumidity),
            offsetPressure: try values.decode(Double.self, forKey: .offsetPressure),
            points: points
        )
    }

    private static func decodeColumns(
        from values: KeyedDecodingContainer<CodingKeys>
    ) throws -> [CloudGraphPoint] {
        let timestamps = try values.decode([Int64].self, forKey: .timestamps)
        // Enforce the server budget before allocating the expanded point dictionaries.
        guard timestamps.count <= CloudGraphQuery.pointLimit else {
            throw DecodingError.dataCorruptedError(
                forKey: .timestamps, in: values, debugDescription: "Graph exceeds the point limit."
            )
        }
        let columns = try values.decode([String: CloudGraphColumn].self, forKey: .metrics)
        guard columns.count <= CloudGraphMetricName.allCases.count,
              columns.values.allSatisfy({ $0.isAligned(with: timestamps.count) }) else {
            throw DecodingError.dataCorruptedError(
                forKey: .metrics, in: values, debugDescription: "Invalid graph column lengths or counts."
            )
        }
        return timestamps.enumerated().map { index, timestamp in
            var metrics: [String: CloudGraphMetric] = [:]
            metrics.reserveCapacity(columns.count)
            for (name, column) in columns {
                metrics[name] = CloudGraphMetric(
                    mean: column.mean[index], min: column.min[index], max: column.max[index],
                    count: column.count[index], last: column.last?[index]
                )
            }
            return CloudGraphPoint(timestamp: timestamp, metrics: metrics)
        }
    }
}

private struct CloudGraphColumn: Decodable {
    let mean: [Double?]
    let min: [Double?]
    let max: [Double?]
    let count: [Int64]
    let last: [Double?]?

    func isAligned(with length: Int) -> Bool {
        mean.count == length && min.count == length && max.count == length
            && count.count == length && (last == nil || last?.count == length)
            && count.allSatisfy { $0 >= 0 }
    }
}
