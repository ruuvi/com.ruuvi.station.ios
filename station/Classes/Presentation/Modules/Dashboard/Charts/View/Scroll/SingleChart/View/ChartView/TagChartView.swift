//
//  TagChartView.swift
//  station
//
//  Created by Viik.ufa on 21.03.2020.
//  Copyright © 2020 Ruuvi Innovations Oy. BSD-3-Clause.
//

import UIKit
import Charts

class TagChartView: LineChartView {
    private let noChartDataText = "TagCharts.NoChartData.text"
    let chartDataType: MeasurementType
    var tagUuid: String?
    weak var output: TagChartViewOutput?
    // MARK: - LifeCycle
    init(frame: CGRect, dataType: MeasurementType) {
        chartDataType = dataType
        super.init(frame: frame)
        delegate = self
        configure()
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    // MARK: - Private
    private func configure() {
        chartDescription?.enabled = false

        dragEnabled = true
        setScaleEnabled(true)
        pinchZoomEnabled = false
        highlightPerDragEnabled = false

        backgroundColor = .clear

        legend.enabled = false

        xAxis.labelPosition = .bottom
        xAxis.labelFont = .systemFont(ofSize: 10, weight: .light)
        xAxis.labelTextColor = UIColor.white
        xAxis.drawAxisLineEnabled = false
        xAxis.drawGridLinesEnabled = true
        xAxis.centerAxisLabelsEnabled = false
        xAxis.granularity = 300
        xAxis.valueFormatter = DateValueFormatter()
        xAxis.granularityEnabled = true

        leftAxis.labelPosition = .outsideChart
        leftAxis.labelFont = .systemFont(ofSize: 10, weight: .light)
        leftAxis.drawGridLinesEnabled = true

        leftAxis.labelTextColor = UIColor.white

        rightAxis.enabled = false
        legend.form = .line

        noDataTextColor = UIColor.white
        noDataText = noChartDataText.localized()

        scaleXEnabled = true
        scaleYEnabled = true
    }

    private func getOffset(dX: CGFloat, dY: CGFloat) -> TimeInterval {
        var pt = CGPoint(
            x: viewPortHandler.contentLeft + dX,
            y: viewPortHandler.contentBottom + dY)
        getTransformer(forAxis: .left).pixelToValues(&pt)
        return lowestVisibleX - max(xAxis.axisMinimum, Double(pt.x))
    }

    private func getScaleOffset(scaleX: CGFloat, scaleY: CGFloat) -> TimeInterval {
        var pt = CGPoint(
            x: viewPortHandler.contentLeft / scaleX,
            y: viewPortHandler.contentBottom / scaleY)
        getTransformer(forAxis: .left).pixelToValues(&pt)
        return lowestVisibleX - max(xAxis.axisMinimum, Double(pt.x))
    }
}
// MARK: - TagChartViewInput
extension TagChartView: TagChartViewInput {
    func clearChartData() {
        clearValues()
        resetZoom()
    }
    func fitZoomTo(min: TimeInterval, max: TimeInterval) {
        let scaleX = CGFloat(xAxis.axisMaximum - xAxis.axisMinimum) / CGFloat((max - min))
        zoom(scaleX: 0, scaleY: 0, x: 0, y: 0)
        zoom(scaleX: scaleX, scaleY: 0, x: 0, y: 0)
        moveViewToX(min)
    }
    func reloadData() {
        data?.notifyDataChanged()
        notifyDataSetChanged()
    }
}
extension TagChartView: ChartViewDelegate {
    func chartTranslated(_ chartView: ChartViewBase, dX: CGFloat, dY: CGFloat) {
        let offset = getOffset(dX: dX, dY: dY)
        let newVisibleRange = (min: lowestVisibleX - offset * 2, max: highestVisibleX + offset * 2)
        output?.didChartChangeVisibleRange(self, newRange: newVisibleRange)
    }
    func chartScaled(_ chartView: ChartViewBase, scaleX: CGFloat, scaleY: CGFloat) {
        let offset = getScaleOffset(scaleX: scaleX, scaleY: scaleY)
        let newVisibleRange = (min: lowestVisibleX - offset * 2, max: highestVisibleX + offset * 2)
        output?.didChartChangeVisibleRange(self, newRange: newVisibleRange)
    }
}
