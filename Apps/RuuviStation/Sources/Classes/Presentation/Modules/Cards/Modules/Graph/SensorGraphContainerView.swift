import SwiftUI

struct GraphCardView: View {
    @ObservedObject var viewModel: SensorGraphViewModel
    @ObservedObject var containerModel: SensorGraphContainerViewModel

    var body: some View {
        VStack(alignment: .leading) {
            Text(viewModel.graphTitle)
                .font(.headline)

            SensorGraphView(
                viewModel: viewModel,
                chartContainerModel: containerModel
            )
            .frame(height: 220)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

import SwiftUI
import RuuviOntology

struct SensorGraphContainerView: View {
    @ObservedObject var viewModel: SensorGraphContainerViewModel

    var body: some View {
        VStack {
            chartControlsView

            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.graphViewModels) { graphViewModel in
                        GraphCardView(viewModel: graphViewModel,
                                     containerModel: viewModel)
                    }
                }
                .padding()
            }
        }
        .onAppear {
            viewModel.reloadCharts()
        }
        .onDisappear {
            viewModel.stopObserving()
        }
    }

    private var chartControlsView: some View {
        HStack {
            Button(action: {
                viewModel.toggleShowStatistics(!viewModel.showChartStat)
            }) {
                Label(
                    viewModel.showChartStat ? "Hide Stats" : "Show Stats",
                    systemImage: viewModel.showChartStat ? "chart.bar.xaxis" : "chart.bar"
                )
            }

            Spacer()

            Button(action: {
                viewModel.reloadCharts()
            }) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
        .padding(.horizontal)
    }
}
