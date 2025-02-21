import SwiftUI
import Combine
import RuuviLocalization
import RuuviOntology
import RuuviService
import SwiftUIIntrospect
import RuuviLocal

enum SensorCardSelectedTab {
    case home
    case graph
    case alerts
    case settings
}

struct NewCardsView: View {
    @EnvironmentObject var state: NewCardsViewState
    @Environment(\.verticalSizeClass) var verticalSizeClass

    var measurementService: RuuviServiceMeasurement
    var settings: RuuviLocalSettings
    var flags: RuuviLocalFlags

    var body: some View {

        ZStack {
            // Background
            if state.viewModels.count > 0 && state.currentPage < state.viewModels.count {
                CardsBackgroundViewRepresentable(
                    viewModel: state.viewModels[state.currentPage],
                    withAnimation: true
                )
                .edgesIgnoringSafeArea(.all)
                // TODO: Remove this after discussing with design team
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color.black.opacity(state.selectedTab == .home ? 0.3 : 0.8))
                    .edgesIgnoringSafeArea(.all)
            }

            VStack(spacing: 0) {
                // Top navigation bar
                HStack {
                    Button(action: {
                        state.backButtonTapped.send()
                    }) {
                        ZStack {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                        .frame(width: 44, height: 44) // Expands tappable area
                        .clipShape(Rectangle())
                    }

                    // Ruuvi logo
                    Image(uiImage: RuuviAsset.ruuviLogo.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 24)
                        .foregroundColor(Color(#colorLiteral(red: 0.3, green: 0.85, blue: 0.7, alpha: 1)))
                        .padding(.leading, 8)

                    Spacer()

                    CustomTabBar(selectedTab: $state.selectedTab)
                        .frame(height: 30)
                        .onChange(of: state.selectedTab) { value in
                            if value == .graph {
                                state.graphButtonTapped.send(state.viewModels[state.currentPage])
                            }
                        }
                }
                .padding(.trailing)
                .padding(.top, verticalSizeClass == .regular ? 0 : 12)
                .padding(.bottom, verticalSizeClass == .regular ? 24 : 8)

                // Horizontal navigation indicators
                HStack(spacing: 8) {
                    VStack {
                        Button(action: {
                            if state.currentPage > 0 {
                                state.currentPage -= 1
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                        .opacity(state.currentPage == 0 ? 0 : 1)
                        Spacer()
                    }

                    Spacer()

                    VStack {
                        Text(state.viewModels[state.currentPage].name)
                            .font(.muli(.extraBold, size: 20))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }

                    Spacer()

                    VStack {
                        Button(action: {
                            if state.currentPage < state.viewModels.count - 1 {
                                state.currentPage += 1
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                        .opacity(
                            state.currentPage < state.viewModels.count - 1 ? 1 : 0
                        )
                        Spacer()
                    }
                }
                .frame(minHeight: 40, maxHeight: 60)
                .padding(.horizontal)

                ZStack {
                    switch state.selectedTab {
                    case .home:
                        PageView(
                            currentPage: $state.currentPage,
                            scrollProgress: $state.scrollProgress,
                            isScrolling: $state.isScrolling,
                            measurementService: measurementService
                        )
                        .tag(0)
                        .environmentObject(state)
                    case .graph:
                        VStack {
                            Spacer()
                            switch state.graphLoadingState {
                            case .initial:
                                Text("Graph")
                                    .foregroundColor(.white)
                            case .loading:
                                ProgressView("Loading")
                                    .progressViewStyle(
                                        CircularProgressViewStyle(tint: Color.white)
                                    )
                                    .foregroundColor(.white)
                            case .finished:
                                let activeViewModel = state.viewModels[state.currentPage]
                                if let chartViewModel = state.chartViewModel,
                                   let graphId = chartViewModel.chartViewData.first?.ruuviTagId,
                                   activeViewModel.id == graphId {
                                    ChartContainerView(
                                        viewModel: chartViewModel
                                    )
                                }
                            }
                            Spacer()
                        }

                    case .alerts:
                        VStack {
                            Spacer()
                            Text("Alerts")
                                .foregroundColor(.white)
                            Spacer()
                        }
                    case .settings:
                        VStack {
                            Spacer()
                            Text("Settings")
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }
                }
            }
        }
    }
}

struct PageView: View {
    @EnvironmentObject var state: NewCardsViewState
    @Binding var currentPage: Int
    @Binding var scrollProgress: CGFloat
    @Binding var isScrolling: Bool
    let measurementService: RuuviServiceMeasurement?

    var body: some View {
        PageViewController(
            pages: state.viewModels.map {
                SensorCardView(
                    viewModel: $0,
                    measurementService: measurementService
                )
            },
            currentPage: $currentPage,
            scrollProgress: $scrollProgress,
            isScrolling: $isScrolling
        )
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: SensorCardSelectedTab
    @Namespace private var namespace

    // Define tab items
    private let tabs: [TabItem] = [
        TabItem(
            image: Image(uiImage: RuuviAsset.ruuviActivityPresenterLogo.image),
            type: .home
        ),
        TabItem(
            image: Image(systemName: "chart.bar.xaxis.ascending"),
            type: .graph
        ),
        TabItem(
            image: Image(systemName: "bell.fill"),
            type: .alerts
        ),
        TabItem(
            image: Image(systemName: "gearshape.fill"),
            type: .settings
        )
    ]

    var body: some View {
        HStack(spacing: 24) {
            Spacer()
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.spring) {
                        selectedTab = tabs[index].type
                    }
                }) {
                    VStack(spacing: 0) {
                        // Fixed height spacer to ensure consistent alignment
                        Spacer()

                        // Image
                        Group {
                            tabs[index].image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                        }
                        .foregroundColor(.white)

                        // Animated underline container with fixed position
                        ZStack {
                            if selectedTab == tabs[index].type {
                                Rectangle()
                                    .frame(width: 16, height: 2)
                                    .foregroundColor(.white)
                                    .matchedGeometryEffect(id: "underline", in: namespace)
                            } else {
                                Rectangle()
                                    .frame(width: 16, height: 2)
                                    .foregroundColor(.clear)
                            }
                        }.padding(.top, 6)

                        Spacer()
                    }
                }
            }
        }
    }
}

struct TabItem {
    let image: Image
    let type: SensorCardSelectedTab
}
