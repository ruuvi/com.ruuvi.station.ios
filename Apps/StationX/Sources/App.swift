import ComposableArchitecture
import SwiftUI

@main
struct StationXApp: App {
    var body: some Scene {
        WindowGroup {
            WithPerceptionTracking {
                ChartView(
                    store: StoreOf<ChartFeature>(
                        initialState: ChartFeature.State(
                            records: exampleRecords()
                        ),
                        reducer: {
                            ChartFeature()
                        })
                )
            }
        }
    }
}

private func exampleRecords() -> [ChartFeature.Record] {
    var result = [ChartFeature.Record]()
    for i in 0 ..< 10000 {
        result.append(
            ChartFeature.Record(
                date: Date.now.addingTimeInterval(TimeInterval(i)),
                value: Double.random(in: Double(i - 1000) ... Double(i + 1000))
            )
        )
    }
    return result
}
