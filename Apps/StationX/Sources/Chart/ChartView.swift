import Charts
import ComposableArchitecture
import SwiftUI

struct ChartView: View {
    let store: StoreOf<ChartFeature>

    var body: some View {
        WithPerceptionTracking {
            let records = store.records
            let temperatures = records.compactMap { $0.value }
            let minY = temperatures.min() ?? 0
            let maxY = temperatures.max() ?? 0

            Chart(store.state.records) { dataPoint in
                AreaMark(
                    x: .value("Time", dataPoint.date),
                    y: .value("Temperature (°C)", dataPoint.value)
                )
                .lineStyle(.init(lineWidth: 3))
                .foregroundStyle(
                    .linearGradient(
                        Gradient(
                            stops: [
                                .init(color: .gray, location: 0),
                                .init(color: .gray, location: 0.5),
                                .init(color: .red, location: 0.5 + 0.001),
                                .init(color: .red, location: 1),
                            ]),
                        startPoint: .bottom,
                        endPoint: .top)
                )
                .symbol(.circle)
                .symbolSize(150)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: Calendar.Component.day)) { _ in
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
}
