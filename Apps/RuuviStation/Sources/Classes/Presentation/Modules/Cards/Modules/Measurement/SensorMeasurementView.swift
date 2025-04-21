import SwiftUI
import RuuviService

struct SensorMeasurementView: View {

    @ObservedObject var viewModel: SensorMeasurementViewModel
    @Binding var scrollProgress: CGFloat
    @Binding var isScrolling: Bool

    var body: some View {
        PageViewController(
            pages: viewModel.cardViewModels.map {
                SensorCardView(
                    viewModel: $0,
                    measurementService: viewModel.measurementService
                )
            },
            currentPage: $viewModel.activeCardIndex,
            scrollProgress: $scrollProgress,
            isScrolling: $isScrolling,
            onPageChanged: { index in
                viewModel.onCardSwiped(to: index)
            }
        )
    }
}
