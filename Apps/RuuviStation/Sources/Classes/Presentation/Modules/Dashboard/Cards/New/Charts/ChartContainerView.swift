import SwiftUI
import DGCharts
import RuuviLocal
import RuuviOntology
import RuuviService
import RuuviLocalization
import SwiftUIIntrospect

struct ChartContainerView: View {
    @ObservedObject var viewModel: ChartContainerViewModel

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        VStack {
            Text("Header goes here")
                .foregroundColor(.white)

            if viewModel.chartViewData.isEmpty {
                Spacer()
                Text("No data available for the selected period")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Spacer()
            } else {
                VStack {
                    GeometryReader { geometry in
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(viewModel.chartViewData, id: \.id) { chartData in
                                    createChartView(for: chartData)
                                        .frame(
                                            height:
                                                verticalSizeClass == .compact ?
                                            geometry.size.height : geometry.size.height/3
                                        )
                                }
                            }
                        }
                        .introspect(
                            .scrollView, on: .iOS(.v15, .v16, .v17, .v18)
                        ) { scrollView in
                            scrollView.isPagingEnabled = verticalSizeClass == .compact
                        }
                    }

                }
            }
        }
    }

    @ViewBuilder
    private func createChartView(
        for chartData: NewTagChartViewData
    ) -> some View {
        let chartViewModel = viewModel.getOrCreateViewModel(for: chartData)
        TagChartViewRepresentable(
            viewModel: chartViewModel,
            chartSync: viewModel.chartSync
        )
        .id(chartData.id)
    }
}
