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
                ZStack {
                    if state.viewModels.count > 0 && state.currentPage < state.viewModels.count {
                        NetworkSyncView(
                            viewModel: NetworkSyncViewModel(macId: state.viewModels[state.currentPage].mac)
                        )
                    }

                    HStack {
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
                        }

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
                }
                .padding(.top, verticalSizeClass == .regular ? 0 : 12)
                .padding(.bottom, 8)

                // Horizontal navigation indicators
                HStack(alignment: .top, spacing: 8) {
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

                    Text(state.viewModels[state.currentPage].name)
                        .font(.muli(.extraBold, size: 20))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Spacer()

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
                }
                .padding(.horizontal)

                // Pages
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
                        VStack(spacing: 0) {
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

                // Updated at
                if state.viewModels.count > 0 && state.currentPage < state.viewModels.count {
                    UpdatedAtView(viewModel: state.viewModels[state.currentPage])
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
        HStack(spacing: 16) {
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

class NetworkSyncViewModel: ObservableObject {
    @Published var syncStatus: NetworkSyncStatus = .none
    private var notificationCancellable: AnyCancellable?

    let macId: AnyMACIdentifier?

    init(macId: AnyMACIdentifier?) {
        self.macId = macId
        startObservingNetworkSyncNotification()
    }

    private func startObservingNetworkSyncNotification() {
        notificationCancellable = NotificationCenter.default
            .publisher(for: .NetworkSyncDidChangeStatus)
            .compactMap { notification -> NetworkSyncStatus? in
                guard let mac = notification.userInfo?[NetworkSyncStatusKey.mac] as? MACIdentifier,
                      let status = notification.userInfo?[NetworkSyncStatusKey.status] as? NetworkSyncStatus,
                      mac.any == self.macId
                else {
                    return nil
                }
                return status
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.updateSyncState(with: status)
            }
    }

    private func updateSyncState(with status: NetworkSyncStatus) {
        withAnimation {
            self.syncStatus = status
        }
    }
}

struct NetworkSyncView: View {
    @StateObject var viewModel: NetworkSyncViewModel

    var body: some View {
        HStack {
            Spacer()
            if viewModel.syncStatus == .syncing {
                ProgressView()
                    .progressViewStyle(
                        CircularProgressViewStyle(tint: Color.white)
                    )
                    .foregroundColor(.white)
            }
            Spacer()
        }
    }
}

struct UpdatedAtView: View {
    @ObservedObject var viewModel: CardsViewModel

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Group {
                    if let source = viewModel.source {
                        switch source {
                        case .advertisement, .bgAdvertisement:
                            Image(uiImage: RuuviAsset.iconBluetooth.image)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 16, height: 16)
                        case .heartbeat, .log:
                            Image(uiImage: RuuviAsset.iconBluetoothConnected.image)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 16, height: 16)
                        case .ruuviNetwork:
                            Image(uiImage: RuuviAsset.iconGateway.image)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 24, height: 24)
                        default:
                            EmptyView()
                        }
                    }
                }

                UpdatedAtTextView(viewModel: viewModel)
            }

            Spacer()

            // Low battery indicator (only if hasLowBattery == true)
            if viewModel.batteryNeedsReplacement ?? false {
                HStack(spacing: 4) {
                    Image(systemName: "battery.25")
                        .foregroundColor(.orange)
                    Text("Low battery")
                        .foregroundColor(.orange)
                }
                .padding(.leading, 8)
            }
        }
        .font(.system(size: 14))
        .padding(.horizontal)
    }
}

struct UpdatedAtTextView: View {
    @ObservedObject var viewModel: CardsViewModel
    @State private var timeAgo: String = ""

    var body: some View {
        Text(timeAgo)
            .foregroundColor(.white.opacity(0.7))
            .onAppear { startTimer() }
            .onChange(of: viewModel.date) { _ in
                updateText()
            }
    }

    private func startTimer() {
        updateText()
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            updateText()
        }
    }

    private func updateText() {
        timeAgo = viewModel.date?
            .ruuviAgo() ?? RuuviLocalization.Cards.UpdatedLabel.NoData.message
    }
}
