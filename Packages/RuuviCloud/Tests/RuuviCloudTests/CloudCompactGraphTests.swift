import XCTest
@testable import RuuviCloud

final class CloudCompactGraphTests: XCTestCase {
    private let columnJSON = """
    {"sensor":"AA:BB:CC:DD:EE:FF","name":"Synthetic","since":0,"until":180,
     "resolutionSeconds":60,"offsetTemperature":1,"offsetHumidity":2,"offsetPressure":3,
     "timestamps":[0,60,120],"metrics":{
       "temperature":{"mean":[10,null,20],"min":[8,null,18],"max":[12,null,22],"count":[2,0,1]},
       "co2":{"mean":[600.25,null,701.75],"min":[400,null,650],"max":[800,null,900],"count":[2,0,1]},
       "measurementSequenceNumber":{"mean":[null,null,null],"min":[1,null,16],"max":[15,null,22],
         "count":[2,0,1],"last":[15,null,22]}
     }}
    """
    private let pointJSON = """
    {"sensor":"AA:BB:CC:DD:EE:FF","name":"Synthetic","since":0,"until":180,
     "resolutionSeconds":60,"offsetTemperature":1,"offsetHumidity":2,"offsetPressure":3,
     "points":[
       {"timestamp":0,"metrics":{
         "temperature":{"mean":10,"min":8,"max":12,"count":2},
         "co2":{"mean":600.25,"min":400,"max":800,"count":2},
         "measurementSequenceNumber":{"min":1,"max":15,"count":2,"last":15}}},
       {"timestamp":60,"metrics":{
         "temperature":{"mean":null,"min":null,"max":null,"count":0},
         "co2":{"mean":null,"min":null,"max":null,"count":0},
         "measurementSequenceNumber":{"mean":null,"min":null,"max":null,"count":0,"last":null}}},
       {"timestamp":120,"metrics":{
         "temperature":{"mean":20,"min":18,"max":22,"count":1},
         "co2":{"mean":701.75,"min":650,"max":900,"count":1},
         "measurementSequenceNumber":{"min":16,"max":22,"count":1,"last":22}}}
     ]}
    """

    func testColumnsPreserveAllValuesGapsOffsetsAndCounterLast() throws {
        let columns = try decode(columnJSON)
        let points = try decode(pointJSON)
        assertEqual(columns, points)
        XCTAssertEqual(columns.samples(.measurementSequenceNumber).map(\.value), [15, 22])
        XCTAssertNil(columns.statistics(.measurementSequenceNumber)?.mean)
        XCTAssertEqual(columns.samples(.temperature).map(\.value), [11, 21])
        let segments = columns.samples(.temperature).map(\.segment)
        XCTAssertNotEqual(segments[0], segments[1])
        XCTAssertEqual(segments, points.samples(.temperature).map(\.segment))
        XCTAssertEqual(try XCTUnwrap(columns.statistics(.temperature)?.mean), 14 + 1.0 / 3, accuracy: 1e-10)
        XCTAssertEqual(columns.statistics(.temperature)?.min, 9)
        XCTAssertEqual(columns.statistics(.temperature)?.max, 23)
        XCTAssertEqual(try XCTUnwrap(columns.statistics(.co2)?.mean), (600.25 * 2 + 701.75) / 3, accuracy: 1e-10)
    }

    func testEmptyAndAllNullColumnsStayEmpty() throws {
        var object = try fixture()
        object["timestamps"] = [] as [Int]
        object["metrics"] = ["co2": ["mean": [], "min": [], "max": [], "count": []]]
        XCTAssertTrue(try decode(object).points.isEmpty)
        object["timestamps"] = [0, 60, 120]
        object["metrics"] = [
            "co2": [
                "mean": [NSNull(), NSNull(), NSNull()], "min": [NSNull(), NSNull(), NSNull()],
                "max": [NSNull(), NSNull(), NSNull()], "count": [0, 0, 0],
            ],
        ]
        let series = try decode(object)
        XCTAssertTrue(series.samples(.co2).isEmpty)
        XCTAssertNil(series.statistics(.co2))
        XCTAssertFalse(CloudGraphViewport(overview: series).hasMetric(.co2))
    }

    func testEveryColumnMustMatchTimestampCount() throws {
        for field in ["mean", "min", "max", "count", "last"] {
            for length in [0, 2, 4] {
                var object = try fixture()
                var metrics = try XCTUnwrap(object["metrics"] as? [String: [String: Any]])
                metrics["measurementSequenceNumber"]?[field] = Array(repeating: 1, count: length)
                object["metrics"] = metrics
                XCTAssertThrowsError(try decode(object), "Malformed \(field) length \(length) must fail")
            }
        }
    }

    func testMalformedCountsMissingArraysAndMixedShapesFail() throws {
        var object = try fixture()
        var metrics = try XCTUnwrap(object["metrics"] as? [String: [String: Any]])
        metrics["co2"]?["count"] = [2, -1, 1]
        object["metrics"] = metrics
        XCTAssertThrowsError(try decode(object))
        metrics["co2"]?.removeValue(forKey: "mean")
        object["metrics"] = metrics
        XCTAssertThrowsError(try decode(object))
        object = try fixture()
        object["points"] = [] as [Int]
        XCTAssertThrowsError(try decode(object), "Do not silently choose one of two conflicting shapes")
    }

    func testOversizeRowsAndMetricSetsAreRejected() throws {
        var object = try fixture()
        object["timestamps"] = Array(0...1500)
        XCTAssertThrowsError(try decode(object)) { error in
            guard case DecodingError.dataCorrupted(let context) = error else { return XCTFail("Wrong error") }
            XCTAssertEqual(context.codingPath.last?.stringValue, "timestamps")
        }
        object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(pointJSON.utf8)) as? [String: Any])
        let points = try XCTUnwrap(object["points"] as? [[String: Any]])
        object["points"] = Array(repeating: points[0], count: 1501)
        XCTAssertThrowsError(try decode(object))
        object = try fixture()
        let empty: [String: Any] = [
            "mean": [NSNull(), NSNull(), NSNull()], "min": [NSNull(), NSNull(), NSNull()],
            "max": [NSNull(), NSNull(), NSNull()], "count": [0, 0, 0],
        ]
        object["metrics"] = Dictionary(uniqueKeysWithValues: (0...CloudGraphMetricName.allCases.count).map {
            ("metric-\($0)", empty)
        })
        XCTAssertThrowsError(try decode(object))
    }

    func testCompactDetailPreservesViewportStatisticsAndEmptyWindow() throws {
        var viewport = CloudGraphViewport(overview: try decode(columnJSON))
        let request = try XCTUnwrap(viewport.move(to: 60...120))
        var detail = try fixture()
        detail["since"] = 60
        detail["until"] = 120
        detail["resolutionSeconds"] = 1
        detail["timestamps"] = [60, 61, 120]
        XCTAssertTrue(viewport.accept(try decode(detail), for: request))
        XCTAssertEqual(viewport.timeline.range, 0...180)
        XCTAssertEqual(viewport.segments(.co2).flatMap { $0 }.map(\.timestamp), [0, 60, 120])
        XCTAssertEqual(try XCTUnwrap(viewport.statistics(.co2, in: 60...120)?.mean),
                       (600.25 * 2 + 701.75) / 3, accuracy: 1e-10)
        XCTAssertNil(viewport.statistics(.co2, in: 61...119))
        let pan = try XCTUnwrap(viewport.move(to: 121...140))
        XCTAssertFalse(viewport.accept(try decode(detail), for: request))
        detail["since"] = 121
        detail["until"] = 140
        detail["timestamps"] = [] as [Int]
        detail["metrics"] = ["co2": ["mean": [], "min": [], "max": [], "count": []]]
        XCTAssertTrue(viewport.accept(try decode(detail), for: pan))
        XCTAssertNil(viewport.statistics(.co2, in: 121...140))
    }

    func testFullAirResponseKeepsValuesWithLessThanHalfTheJSON() throws {
        let metrics = CloudGraphMetricName.allCases
        var columnObject = try fixture()
        columnObject["until"] = 3_600_000
        columnObject["resolutionSeconds"] = 3600
        columnObject["timestamps"] = (0..<1000).map { $0 * 3600 }
        var columns: [String: [String: Any]] = [:]
        var points = (0..<1000).map { ["timestamp": $0 * 3600, "metrics": [:]] as [String: Any] }
        for (metricIndex, metric) in metrics.enumerated() {
            var means: [Any] = [], minima: [Any] = [], maxima: [Any] = [], lasts: [Any] = []
            var counts: [Int] = []
            for index in 0..<1000 {
                let missing = (index + metricIndex).isMultiple(of: 7)
                let value = Double(index + metricIndex * 1000) + 0.125
                let mean: Any = missing || metric.isCounter ? NSNull() : value
                let low: Any = missing ? NSNull() : value - 0.125
                let high: Any = missing ? NSNull() : value + 0.125
                let last: Any = missing ? NSNull() : value + 0.125
                let count = missing ? 0 : index % 10 + 1
                means.append(mean); minima.append(low); maxima.append(high); lasts.append(last); counts.append(count)
                var pointMetrics = try XCTUnwrap(points[index]["metrics"] as? [String: [String: Any]])
                var point: [String: Any] = ["mean": mean, "min": low, "max": high, "count": count]
                if metric.isCounter { point["last"] = last }
                pointMetrics[metric.rawValue] = point
                points[index]["metrics"] = pointMetrics
            }
            columns[metric.rawValue] = ["mean": means, "min": minima, "max": maxima, "count": counts]
            if metric.isCounter { columns[metric.rawValue]?["last"] = lasts }
        }
        columnObject["metrics"] = columns
        var pointObject = columnObject
        pointObject.removeValue(forKey: "timestamps")
        pointObject.removeValue(forKey: "metrics")
        pointObject["points"] = points
        let compact = try JSONSerialization.data(withJSONObject: columnObject, options: .sortedKeys)
        let original = try JSONSerialization.data(withJSONObject: pointObject, options: .sortedKeys)
        XCTAssertLessThan(compact.count * 2, original.count)
        assertEqual(try JSONDecoder().decode(CloudGraphSeries.self, from: compact), try decode(pointObject))
        print("Synthetic 1000-bucket Air JSON: columns \(compact.count) bytes, points \(original.count) bytes")
    }

    private func fixture() throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(columnJSON.utf8)) as? [String: Any])
    }

    private func decode(_ json: String) throws -> CloudGraphSeries {
        try JSONDecoder().decode(CloudGraphSeries.self, from: Data(json.utf8))
    }

    private func decode(_ object: [String: Any]) throws -> CloudGraphSeries {
        try JSONDecoder().decode(CloudGraphSeries.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private func assertEqual(_ lhs: CloudGraphSeries, _ rhs: CloudGraphSeries,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(lhs.sensor, rhs.sensor, file: file, line: line)
        XCTAssertEqual(lhs.points.map(\.timestamp), rhs.points.map(\.timestamp), file: file, line: line)
        for (left, right) in zip(lhs.points, rhs.points) {
            XCTAssertEqual(Set(left.metrics.keys), Set(right.metrics.keys), file: file, line: line)
            for (metric, value) in left.metrics {
                XCTAssertEqual(value.mean, right.metrics[metric]?.mean, file: file, line: line)
                XCTAssertEqual(value.min, right.metrics[metric]?.min, file: file, line: line)
                XCTAssertEqual(value.max, right.metrics[metric]?.max, file: file, line: line)
                XCTAssertEqual(value.count, right.metrics[metric]?.count, file: file, line: line)
                XCTAssertEqual(value.last, right.metrics[metric]?.last, file: file, line: line)
            }
        }
    }
}
