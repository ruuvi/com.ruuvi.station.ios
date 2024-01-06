import BTKit
import Charts
import ComposableArchitecture
import SwiftUI

struct DashboardItemView: View {
    let store: StoreOf<DashboardItemFeature>

    var body: some View {
        let records = store.records
        let temperatures = records.compactMap { $0.value.celsius }
        let minY = temperatures.min() ?? 0
        let maxY = temperatures.max() ?? 0

        Chart(store.state.records) { dataPoint in
            LineMark(
                x: .value("Time", dataPoint.date),
                y: .value("Temperature (°C)", dataPoint.value.celsius ?? 0)
            )
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: Calendar.Component.second)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.second())
            }
        }
        .chartYAxis {
            AxisMarks()
        }
        .chartYScale(domain: [minY, maxY])
        .navigationTitle("RuuviTag Temperature Over Time")
        .padding()
    }
}
