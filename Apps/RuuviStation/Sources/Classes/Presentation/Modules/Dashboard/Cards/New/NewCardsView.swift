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

    @State private var selectedHistoryLength = HistoryLengthOptions.all
    @State private var selectedMoreAction = MoreActions.exportCSV

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
                            .font(.system(size: 20))
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
                            .font(.system(size: 20))
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
                            HStack(spacing: 2) {
                                Button(action: {
                                    // Sync
                                }) {
                                    HStack {
                                        RuuviAsset.iconSyncBt.swiftUIImage
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 22, height: 22)
                                        Text(RuuviLocalization.TagCharts.Sync.title)
                                            .font(.muli(.bold, size: 14))
                                    }
                                }
                                .foregroundColor(.white)
//                                    .hidden()

                                Button(action: {
                                    // Syncing
                                }) {
                                    HStack {
                                        Image(systemName: "xmark")
                                        Text(RuuviLocalization.TagCharts.Status.connecting)
                                            .font(.muli(.regular, size: 16))
                                    }
                                    .foregroundColor(.white)
                                }
                                .hidden()

                                Spacer()

                                Menu {
                                    Picker("History", selection: $selectedHistoryLength) {
                                        ForEach(HistoryLengthOptions.allCases) {
                                            Text($0.title)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(RuuviLocalization.all)
                                            .font(.muli(.bold, size: 14))
                                        RuuviAsset.arrowDropDown.swiftUIImage
                                            .renderingMode(.template)
                                            .foregroundColor(
                                                RuuviColor.logoTintColor.swiftUIColor
                                            )
                                    }
                                    .foregroundColor(.white)
                                }

                                Menu {
                                    ForEach(MoreActions.allCases) { action in
                                        Button {
                                            // Handle the action when tapped
                                            handleMoreAction(action)
                                        } label: {
                                            Text(action.title)
                                        }
                                    }
                                } label: {
                                    RuuviAsset.more3dot.swiftUIImage
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 24, height: 18)
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.leading)
                            .padding([.top, .trailing], 8)

                            Spacer()
                            let activeViewModel = state.viewModels[state.currentPage]
                            if let chartViewModel = state.chartViewModel,
                               let graphId = chartViewModel.chartViewData.first?.ruuviTagId,
                               activeViewModel.id == graphId {
                                ChartContainerView(
                                    viewModel: chartViewModel
                                ).environmentObject(state)
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

    func handleMoreAction(_ action: MoreActions) {
        switch action {
        case .exportCSV:
            // Handle edit action
            print("Edit tapped")
        case .exportXlsx:
            // Handle delete action
            print("Delete tapped")
        case .clearData:
            // Handle share action
            print("Share tapped")
        case .hideMinMaxAvg:
            // Handle hide action
            print("Hide tapped")
        case .increaseGraphHeight:
            // Handle increase action
            print("Increase tapped")
        }
    }
}

enum HistoryLengthOptions: String, CaseIterable, Identifiable {
    case all
    case day1
    case day2
    case day3
    var id: Self { return self }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .day1:
            return "1 Day"
        case .day2:
            return "2 Days"
        case .day3:
            return "3 Days"
        }
    }
}

enum MoreActions: String, CaseIterable, Identifiable {
    case exportCSV
    case exportXlsx
    case clearData
    case hideMinMaxAvg
    case increaseGraphHeight
    var id: Self { return self }

    var title: String {
        switch self {
        case .exportCSV:
            return "Export CSV"
        case .exportXlsx:
            return "Export XLSX"
        case .clearData:
            return "Clear Data"
        case .hideMinMaxAvg:
            return "Hide Min/Max/Avg"
        case .increaseGraphHeight:
            return "Increase Graph Height"
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
            image: Image(systemName: "thermometer.medium"),
            type: .home
        ),
        TabItem(
            image: RuuviAsset.iconChartsButton.swiftUIImage,
            type: .graph
        ),
        TabItem(
            image: RuuviAsset.iconAlertOn.swiftUIImage,
            type: .alerts
        ),
        TabItem(
            image: RuuviAsset.baselineSettingsWhite48pt.swiftUIImage,
            type: .settings
        ),
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
