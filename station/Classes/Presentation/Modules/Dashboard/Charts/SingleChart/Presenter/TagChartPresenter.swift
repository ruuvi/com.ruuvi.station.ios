//
//  TagChartPresenter.swift
//  station
//
//  Created by Viik.ufa on 21.03.2020.
//  Copyright © 2020 Ruuvi Innovations Oy. BSD-3-Clause.
//

import RealmSwift
import Foundation
import Charts
import Accelerate

class TagChartPresenter {
    weak var view: TagChartViewInput!
    var realmContext: RealmContext!
    var settings: Settings!
    private var ruuviTagUUID: String = ""
    private var chartDataType: MeasurementType!
    private var ruuviTagDataToken: NotificationToken?
    private var lastSyncDate = Date()
    private var isInUpdate = false
    private var ruuviTagDataRealm: Results<RuuviTagDataRealm>?
    private var points: [(x: Double, y: Double)] = []
    private lazy var dataSet: LineChartDataSet = {
        $0.axisDependency = .left
        $0.setColor(UIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1))
        $0.lineWidth = 1.5
        $0.drawCirclesEnabled = false
        $0.drawValuesEnabled = false
        $0.fillAlpha = 0.26
        $0.fillColor = UIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1)
        $0.highlightColor = UIColor(red: 244/255, green: 117/255, blue: 117/255, alpha: 1)
        $0.drawCircleHoleEnabled = false
        $0.drawFilledEnabled = true
        $0.highlightEnabled = false
        return $0
    }(LineChartDataSet())

    lazy var chartData: LineChartData = {
        return LineChartData(dataSet: self.dataSet)
    }()

    private func createDataSet(entries: [ChartDataEntry]) {
        let firstPoint = dataSet.first
        let lastPoint = dataSet.last
        dataSet.removeAll(keepingCapacity: true)
        if let first = firstPoint {
            _ = dataSet.addEntryOrdered(first)
        }
        entries.forEach({
            _ = dataSet.addEntryOrdered($0)
        })
        if let last = lastPoint {
            _ = dataSet.addEntryOrdered(last)
        }
        if dataSet.entries.count == 1 {
            dataSet.circleRadius = 6
        } else {
            dataSet.circleRadius = 2
        }
        self.view.updataChart()
    }
    // data updating
    private func insertData(_ measurement: [RuuviMeasurement]) {
        let newPoints: [(x: Double, y: Double)] = measurement.compactMap({
            let point: (x: Double, y: Double)
            switch self.chartDataType {
            case .temperature:
                guard let value = $0.temperature?.converted(to: .celsius).value else { return nil}
                point = (x: $0.date.timeIntervalSince1970, y: value)
            case .humidity:
                guard let value = $0.humidity?.rh else { return nil}
                point = (x: $0.date.timeIntervalSince1970, y: value)
            case .pressure:
                guard let value = $0.pressure?.converted(to: .hectopascals).value else { return nil}
                point = (x: $0.date.timeIntervalSince1970, y: value)
            default:
                return nil
            }
            return point
        }).sorted(by: {$0.x < $1.x})
        self.points.append(contentsOf: newPoints)
        newPoints.forEach({
            _ = self.chartData.dataSets.first?.addEntryOrdered(ChartDataEntry(x: $0.x, y: $0.y))
        })
        isInUpdate = false
        self.view.updataChart()
    }
    private func createData(_ measurement: [RuuviMeasurement]) {
        self.points = measurement.compactMap({
            let point: (x: Double, y: Double)
            switch self.chartDataType {
            case .temperature:
                guard let value = $0.temperature?.converted(to: .celsius).value else { return nil}
                point = (x: $0.date.timeIntervalSince1970, y: value)
            case .humidity:
                guard let value = $0.humidity?.rh else { return nil}
                point = (x: $0.date.timeIntervalSince1970, y: value)
            case .pressure:
                guard let value = $0.pressure?.converted(to: .hectopascals).value else { return nil}
                point = (x: $0.date.timeIntervalSince1970, y: value)
            default:
                return nil
            }
            return point
        }).sorted(by: {$0.x < $1.x})
        let downsampled = self.downSample(dataSet: self.points, threshold: 100)
        self.createDataSet(entries: downsampled)
        self.chartData.dataSets.first?.notifyDataSetChanged()
        self.isInUpdate = false
    }
}
extension TagChartPresenter: TagChartPresenterInput {
}
extension TagChartPresenter: TagChartModuleInput {
    func configure(for tagUUID: String, with type: MeasurementType) {
        self.ruuviTagUUID = tagUUID
        self.chartDataType = type
        self.startObserving()
    }
    func startObserving() {
        ruuviTagDataToken?.invalidate()
        let date = Calendar.current.date(byAdding: .hour, value: -settings.chartDurationHours, to: Date()) ?? Date()
        let ruuviTagsData = realmContext.main.objects(RuuviTagDataRealm.self)
            .filter("ruuviTag.uuid = %@ AND date > %@",
                    ruuviTagUUID,
                    date)
            .sorted(byKeyPath: "date")
        ruuviTagDataToken = ruuviTagsData.observe { [weak self] (change) in
            switch change {
            case .initial(let results):
                var date: Date?
                self?.isInUpdate = true
                self?.ruuviTagDataRealm = results
                self?.createData(results.compactMap({
                    if let last = date,
                        let chartIntervalSeconds = self?.settings.chartIntervalSeconds {
                        let elapsed = Int(Date().timeIntervalSince(last))
                        if elapsed > chartIntervalSeconds {
                            return $0.measurement
                        } else {
                            return nil
                        }
                    } else {
                        date = $0.measurement.date
                        return $0.measurement
                    }
                }))
            case .update(let results, _, let insertions, _):
                // sync every 1 second
                self?.isInUpdate = false
                self?.lastSyncDate = Date()
                self?.insertData(insertions.map({results[$0].measurement}))
            default:
                break
            }
        }
    }
    func stopObserving() {
        ruuviTagDataToken?.invalidate()
        ruuviTagDataToken = nil
    }
    func fetchPointsByDates(start: TimeInterval, stop: TimeInterval) {
        DispatchQueue(label: "CalculatePoints").async {
            let sorted: [(x: Double, y: Double)] = self.points.compactMap({
                guard $0.x > start, $0.x < stop else { return nil }
                return $0
            }).sorted(by: {$0.x < $1.x })
            let downsampled = self.downSample(dataSet: sorted, threshold: 100)
            DispatchQueue.main.async {
                self.createDataSet(entries: downsampled)
                self.isInUpdate = false
            }
        }
    }
}
extension TagChartPresenter: ChartViewDelegate {
    func chartViewDidEndPanning(_ chartView: ChartViewBase) {
        guard let chartView = chartView as? LineChartView,
            isInUpdate == false else {
                return
        }
        isInUpdate = true
        fetchPointsByDates(start: chartView.lowestVisibleX, stop: chartView.highestVisibleX)
    }
    func chartTranslated(_ chartView: ChartViewBase, dX: CGFloat, dY: CGFloat) {
        guard let chartView = chartView as? LineChartView,
            isInUpdate == false else {
                return
        }
        isInUpdate = true
        fetchPointsByDates(start: chartView.lowestVisibleX, stop: chartView.highestVisibleX)    }
}
extension TagChartPresenter {
    // swiftlint:disable function_body_length
    private func downSample(dataSet: [(x: Double, y: Double)] = [], threshold: Int = 100 ) -> [ChartDataEntry] {
        let data_length = dataSet.count
        if threshold >= data_length
            || threshold == 0 {
            return dataSet.map { ChartDataEntry(x: $0.x, y: $0.y)} // Nothing to do
        }
        var sampled: [ChartDataEntry] = []
        // Bucket size. Leave room for start and end data points
        let every = (data_length - 2) / (threshold - 2)
        var a = 0  // Initially a is the first point in the triangle
        var max_area_point: (Double, Double) = (0, 0)
        var max_area: Double = 0
        var area: Double = 0
        var next_a: Int = 0
        var avg_x: Double = 0
        var avg_y: Double = 0
        var avg_range_start: Int = 0
        var avg_range_end: Int = 0
        var avg_range_length: Int = 0
        var range_offs: Int = 0
        var range_to: Int = 0
        var point_a_x: Double = 0
        var point_a_y: Double = 0
        let firstPoint = dataSet.first!
        sampled.append(ChartDataEntry(x: firstPoint.x, y: firstPoint.y)) // Always add the first point
        for i in 0..<(threshold - 2) {
            // Calculate point average for next bucket (containing c)
            avg_x = 0
            avg_y = 0
            avg_range_start  = Int( floor( Double( ( i + 1 ) * every) ) + 1)
            avg_range_end    = Int( floor( Double( ( i + 2 ) * every ) ) + 1)
            avg_range_end = avg_range_end < data_length ? avg_range_end : data_length
            avg_range_length = avg_range_end - avg_range_start
            for avg_range_start in avg_range_start..<avg_range_end {
                avg_x += dataSet[ avg_range_start ].0
                avg_y += dataSet[ avg_range_start ].1
            }
            avg_x /= Double(avg_range_length)
            avg_y /= Double(avg_range_length)
            // Get the range for this bucket
            range_offs = Int(floor( Double((i + 0) * every) ) + 1)
            range_to   = Int(floor( Double((i + 1) * every )) + 1)
            // Point a
            point_a_x = dataSet[ a ].0
            point_a_y = dataSet[ a ].1
            max_area = -1
            area = -1
            for range_offs in range_offs..<range_to {
                // Calculate triangle area over three buckets
                area = abs( ( point_a_x - avg_x ) * ( dataSet[ range_offs ].1  - point_a_y ) -
                    ( point_a_x - dataSet[ range_offs ].0 ) * ( avg_y - point_a_y )
                )
                area *= 0.5
                if area > max_area {
                    max_area = area
                    max_area_point = dataSet[ range_offs ]
                    next_a = range_offs // Next a is this b
                }
            }
            sampled.append(ChartDataEntry(x: max_area_point.0, y: max_area_point.1))
            a = next_a; // This a is the next a (chosen b)
        }
        let lastItem = dataSet.last!
        sampled.append(ChartDataEntry(x: lastItem.x, y: lastItem.y))
        return sampled
    }
    // swiftlint:enable function_body_length
}
