import SwiftUI
import RuuviLocalization
import Combine
import RuuviOntology

// MARK: - CardsContainerView

// swiftlint:disable:next type_body_length
struct CardsContainerView: View {
    // MARK: - Properties

    @ObservedObject private var coordinator: CardsCoordinator

    @StateObject private var containerViewModel: CardsContainerViewModel
    @StateObject private var measurementVM: SensorMeasurementViewModel
    @StateObject private var graphVM: SensorGraphViewModel
    @StateObject private var alertsVM: SensorAlertsViewModel
    @StateObject private var settingsVM: SensorSettingsViewModel

    @State private var selectedTab: CardsTabType
    @State private var scrollProgress: CGFloat = 0
    @State private var isScrolling: Bool = false
    @State private var cardNameHeight: CGFloat = 0

    @Environment(\.verticalSizeClass) var verticalSizeClass

    // MARK: - Initialization

    init(container: DIContainer, initialTab: CardsTabType = .measurement) {
        let coordinator = container.resolve(CardsCoordinator.self)

        self._coordinator = ObservedObject(wrappedValue: coordinator)
        self._containerViewModel = StateObject(
            wrappedValue: container.resolve(CardsContainerViewModel.self)
        )
        self._measurementVM = StateObject(
            wrappedValue: container.resolve(SensorMeasurementViewModel.self)
        )
        self._graphVM = StateObject(
            wrappedValue: container.resolve(SensorGraphViewModel.self)
        )
        self._alertsVM = StateObject(
            wrappedValue: container.resolve(SensorAlertsViewModel.self)
        )
        self._settingsVM = StateObject(
            wrappedValue: container.resolve(SensorSettingsViewModel.self)
        )

        self._selectedTab = State(initialValue: initialTab)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            backgroundView

            VStack(spacing: 0) {
                topNavigationBar
                cardNavigationBar
                contentView
                footerView
            }
        }
        .onAppear {
            coordinator.setActiveTab(selectedTab)
        }
        .onChange(of: selectedTab) { newTab in
            coordinator.setActiveTab(newTab)
        }
        .alert(item: $containerViewModel.activeDialog) { alertType in
            switch alertType {
            case .bluetoothDisabled:
                return Alert(
                    title: Text(RuuviLocalization.Cards.BluetoothDisabledAlert.title),
                    message: Text(RuuviLocalization.Cards.BluetoothDisabledAlert.message),
                    primaryButton: .default(
                        Text(RuuviLocalization.PermissionPresenter.settings),
                        action: {
                            coordinator.handleBluetoothPermissionDialog()
                        }
                    ),
                    secondaryButton: .cancel(
                        Text(RuuviLocalization.ok),
                        action: {
                            coordinator.dismissAlert()
                        }
                    )
                )

            case .keepConnection(let viewModel, let targetTab):
                return Alert(
                    title: Text(""),
                    message: Text(RuuviLocalization.Cards.KeepConnectionDialog.message),
                    primaryButton: .default(
                        Text(RuuviLocalization.Cards.KeepConnectionDialog.KeepConnection.title),
                        action: {
                            coordinator
                                .handleKeepConnectionConfirmed(
                                    true,
                                    for: viewModel,
                                    targetTab: targetTab
                                )
                        }
                    ),
                    secondaryButton: .cancel(
                        Text(RuuviLocalization.Cards.KeepConnectionDialog.Dismiss.title),
                        action: {
                            coordinator
                                .handleKeepConnectionConfirmed(
                                    false,
                                    for: viewModel,
                                    targetTab: targetTab
                                )
                        }
                    )
                )

            case .firmwareUpdate(let viewModel):
                return Alert(
                    title: Text(""),
                    message: Text(RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.message),
                    primaryButton: .default(
                        Text(RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CheckForUpdate.title),
                        action: {
                            coordinator.handleFirmwareUpdateConfirmed(for: viewModel)
                        }
                    ),
                    secondaryButton: .cancel(
                        Text(RuuviLocalization.Cards.KeepConnectionDialog.Dismiss.title),
                        action: {
                            coordinator.handleFirmwareUpdateDialogIgnored(for: viewModel)
                        }
                    )
                )

            case .firmwareDismissConfirmation(let viewModel):
                return Alert(
                    title: Text(""),
                    message: Text(RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CancelConfirmation.message),
                    primaryButton: .default(
                        Text(RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CheckForUpdate.title),
                        action: {
                            coordinator.handleFirmwareUpdateConfirmed(for: viewModel)
                        }
                    ),
                    secondaryButton: .cancel(
                        Text(RuuviLocalization.Cards.KeepConnectionDialog.Dismiss.title),
                        action: {
                            coordinator.handleFirmwareUpdateDialogDismissed(for: viewModel)
                        }
                    )
                )
            }
        }
    }

    // MARK: - UI Components

    private var backgroundView: some View {
        Group {
            if let activeCard = containerViewModel.activeCard {
                CardsBackgroundViewRepresentable(
                    viewModel: activeCard,
                    withAnimation: true
                )
                .edgesIgnoringSafeArea(.all)

                RoundedRectangle(cornerRadius: 0)
                    .fill(Color.black.opacity(selectedTab == .measurement ?
                          Constants.MeasurementOpacity : Constants.OtherTabsOpacity))
                    .edgesIgnoringSafeArea(.all)
            }
        }
    }

    private var topNavigationBar: some View {
        ZStack {
            HStack {
                Spacer()
                if containerViewModel.isRefreshing {
                    ProgressView()
                        .progressViewStyle(
                            CircularProgressViewStyle(tint: Color.white)
                        )
                        .foregroundColor(.white)
                }
                Spacer()
            }

            HStack {
                backButtonWithLogo
                Spacer()
                CardsTabBar(
                    selectedTab: $selectedTab,
                    alertState: $containerViewModel.alertState
                )
                .frame(height: Constants.TabBarHeight)
            }
            .padding(.trailing)
        }
        .padding(.top, verticalSizeClass == .regular ? 0 : Constants.CompactVerticalPadding)
        .padding(.bottom, Constants.NavigationBottomPadding)
    }

    private var backButtonWithLogo: some View {
        HStack {
            Button(action: {
                containerViewModel.onBackButtonTapped()
            }) { // swiftlint:disable:this multiple_closures_with_trailing_closure
                ZStack {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                .frame(width: Constants.BackButtonSize, height: Constants.BackButtonSize)
                .clipShape(Rectangle())
            }

            // Ruuvi logo
            Image(uiImage: RuuviAsset.ruuviLogo.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: Constants.LogoHeight)
                .foregroundColor(Constants.LogoColor)
                .padding(.leading, Constants.LogoPadding)
        }
    }

    private var cardNavigationBar: some View {
        HStack(alignment: .firstTextBaseline, spacing: Constants.NavigationSpacing) {
            navigationArrowButton(direction: .left)
            cardNameView
            navigationArrowButton(direction: .right)
        }
        .padding(.leading, Constants.HorizontalPadding)
        .padding(.trailing, Constants.HorizontalPadding)
    }

    private var cardNameView: some View {
        Group {
            if let activeCard = containerViewModel.activeCard {
                Text(activeCard.name)
                    .font(.muli(.extraBold, size: Constants.CardTitleSize))
                    .foregroundColor(.white)
                    .lineLimit(Constants.CardTitleLineLimit)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .onAppear {
                                    cardNameHeight = geometry.size.height
                                }
                        }
                    )
            }
        }
    }

    private func navigationArrowButton(direction: NavigationDirection) -> some View {
        VStack {
            Button(action: {
                withAnimation {
                    performNavigationAction(direction: direction)
                }
            }) { // swiftlint:disable:this multiple_closures_with_trailing_closure
                Image(systemName: direction.iconName)
                    .font(.system(size: Constants.NavigationArrowSize))
                    .foregroundColor(.white)
            }
            .opacity(isNavigationButtonVisible(direction: direction) ? 1 : 0)
            .padding(.top, Constants.NavigationArrowTopPadding)

            Spacer()
        }
        .frame(height: cardNameHeight)
    }

    @ViewBuilder
    private var contentView: some View {
        ZStack {
            switch selectedTab {
            case .measurement:
                SensorMeasurementView(
                    viewModel: measurementVM,
                    scrollProgress: $scrollProgress,
                    isScrolling: $isScrolling
                )
                .tag(0)
            case .graph:
                graphTabContent
            case .alerts:
                alertsTabContent
            case .settings:
                settingsTabContent
            }
        }
    }

    private var graphTabContent: some View {
        VStack {
            Spacer()
            Text("Graph")
                .foregroundColor(.white)
            Spacer()
        }
    }

    private var alertsTabContent: some View {
        VStack {
            Spacer()
            Text("Alerts")
                .foregroundColor(.white)
            Spacer()
        }
    }

    private var settingsTabContent: some View {
        VStack {
            Spacer()
            Text("Settings")
                .foregroundColor(.white)
            Spacer()
        }
    }

    private var footerView: some View {
        Group {
            if hasValidCardViewModel {
                UpdatedAtView(
                    viewModel: containerViewModel
                        .cardViewModels[containerViewModel.activeCardIndex]
                )
            }
        }
    }

    // MARK: - Helper Methods

    private var hasValidCardViewModel: Bool {
        containerViewModel.cardViewModels.count > 0 &&
        containerViewModel.activeCardIndex < containerViewModel.cardViewModels.count
    }

    private func isNavigationButtonVisible(direction: NavigationDirection) -> Bool {
        switch direction {
        case .left:
            return containerViewModel.activeCardIndex > 0
        case .right:
            return containerViewModel.activeCardIndex < containerViewModel.cardViewModels.count - 1
        }
    }

    private func performNavigationAction(direction: NavigationDirection) {
        switch direction {
        case .left:
            if containerViewModel.activeCardIndex > 0 {
                containerViewModel.onCardSwiped(to: containerViewModel.activeCardIndex - 1)
            }
        case .right:
            if containerViewModel.activeCardIndex < containerViewModel.cardViewModels.count - 1 {
                containerViewModel.onCardSwiped(to: containerViewModel.activeCardIndex + 1)
            }
        }
    }

    // MARK: - Constants

    private enum Constants {
        // Dimensions
        static let TabBarHeight: CGFloat = 30
        static let NavigationSpacing: CGFloat = 8
        static let BackButtonSize: CGFloat = 44
        static let LogoHeight: CGFloat = 24
        static let CardTitleSize: CGFloat = 20
        static let NavigationArrowSize: CGFloat = 20

        // Padding
        static let CompactVerticalPadding: CGFloat = 12
        static let NavigationBottomPadding: CGFloat = 8
        static let LogoPadding: CGFloat = 8
        static let HorizontalPadding: CGFloat = 15
        static let NavigationArrowTopPadding: CGFloat = 4

        // Others
        static let MeasurementOpacity: Double = 0.3
        static let OtherTabsOpacity: Double = 0.8
        static let CardTitleLineLimit: Int = 2

        // Colors
        static let LogoColor = Color(#colorLiteral(red: 0.3, green: 0.85, blue: 0.7, alpha: 1))
    }

    // MARK: - Custom Enums

    private enum NavigationDirection {
        case left
        case right

        var iconName: String {
            switch self {
            case .left: return "chevron.left"
            case .right: return "chevron.right"
            }
        }
    }
}

// MARK: - CardsTabBar

extension CardsContainerView {
    struct CardsTabBar: View {
        // MARK: - Properties

        @Binding var selectedTab: CardsTabType
        @Binding var alertState: AlertState?
        @Namespace private var namespace

        // Define tab items
        private var tabs: [CardsTabItem] {
            [
                CardsTabItem(
                    image: Image(
                        systemName: "thermometer.medium"
                    ),
                    type: .measurement
                ),

                CardsTabItem(
                    image: Image(
                        systemName: "chart.bar.xaxis"
                    ),
                    type: .graph
                ),

                CardsTabItem(
                    image: alertIcon,
                    type: .alerts
                ),

                CardsTabItem(
                    image: Image(
                        systemName: "gearshape.fill"
                    ),
                    type: .settings
                ),
            ]
        }

        // computed alert icon – derives from `alertState`
        private var alertIcon: Image {
            switch alertState {
            case .empty:
                return Image(systemName: "bell")
            case .registered:
                return Image(systemName: "bell.fill")
            case .firing:
                return Image(systemName: "bell.badge.fill")
            default:
                return Image(systemName: "bell")
            }
        }

        // MARK: - Body

        var body: some View {
            HStack(spacing: Constants.TabSpacing) {
                Spacer()
                ForEach(0..<tabs.count, id: \.self) { index in
                    tabButton(for: tabs[index])
                }
            }
        }

        // MARK: - UI Components

        private func tabButton(for item: CardsTabItem) -> some View {
            Button(action: {
                withAnimation(.spring) {
                    selectedTab = item.type
                }
            }) {
                VStack(spacing: 0) {
                    Spacer()

                    item.image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: Constants.TabIconSize,
                            height: Constants.TabIconSize
                        )
                        .foregroundColor(.white)

                    tabIndicator(for: item.type)
                        .padding(.top, Constants.IndicatorTopPadding)

                    Spacer()
                }
            }
        }

        private func tabIndicator(for tabType: CardsTabType) -> some View {
            ZStack {
                if selectedTab == tabType {
                    Rectangle()
                        .frame(
                            width: Constants.IndicatorWidth,
                            height: Constants.IndicatorHeight
                        )
                        .foregroundColor(.white)
                        .matchedGeometryEffect(id: "underline", in: namespace)
                } else {
                    Rectangle()
                        .frame(
                            width: Constants.IndicatorWidth,
                            height: Constants.IndicatorHeight
                        )
                        .foregroundColor(.clear)
                }
            }
        }

        // MARK: - Constants

        private enum Constants {
            static let TabSpacing: CGFloat = 16
            static let TabIconSize: CGFloat = 20
            static let IndicatorWidth: CGFloat = 16
            static let IndicatorHeight: CGFloat = 2
            static let IndicatorTopPadding: CGFloat = 6
        }
    }

    struct CardsTabItem {
        let image: Image
        let type: CardsTabType
    }
}

// TODO: Use this below code after refactoring the code

//// MARK: - NetworkSyncViewModel
//
//class NetworkSyncViewModel: ObservableObject {
//    // MARK: - Properties
//
//    @Published var syncStatus: NetworkSyncStatus = .none
//    private var notificationCancellable: AnyCancellable?
//
//    let macId: AnyMACIdentifier?
//
//    // MARK: - Initialization
//
//    init(macId: AnyMACIdentifier?) {
//        self.macId = macId
//        startObservingNetworkSyncNotification()
//    }
//
//    // MARK: - Private Methods
//
//    private func startObservingNetworkSyncNotification() {
//        notificationCancellable = NotificationCenter.default
//            .publisher(for: .NetworkSyncLatestDataDidChangeStatus)
//            .compactMap { [weak self] notification -> NetworkSyncStatus? in
//                guard let self = self,
//                      let mac = notification.userInfo?[NetworkSyncStatusKey.mac] as? MACIdentifier,
//                      let status = notification.userInfo?[NetworkSyncStatusKey.status] as? NetworkSyncStatus,
//                      mac.any == self.macId
//                else {
//                    return nil
//                }
//                return status
//            }
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] status in
//                self?.updateSyncState(with: status)
//            }
//    }
//
//    private func updateSyncState(with status: NetworkSyncStatus) {
//        withAnimation {
//            self.syncStatus = status
//        }
//    }
//}
//
//// MARK: - NetworkSyncView
//
//struct NetworkSyncView: View {
//    // MARK: - Properties
//
//    @StateObject var viewModel: NetworkSyncViewModel
//
//    // MARK: - Body
//
//    var body: some View {
//        HStack {
//            Spacer()
//            if viewModel.syncStatus == .syncing {
//                ProgressView()
//                    .progressViewStyle(
//                        CircularProgressViewStyle(tint: .white)
//                    )
//                    .foregroundColor(.white)
//            }
//            Spacer()
//        }
//    }
//}
//
//// MARK: - UpdatedAtView
//
//struct UpdatedAtView: View {
//    // MARK: - Properties
//
//    @ObservedObject var viewModel: CardsViewModel
//
//    // MARK: - Body
//
//    var body: some View {
//        HStack {
//            dataSourceWithTimestamp
//            Spacer()
//            batteryStatusView
//        }
//        .font(.system(size: Constants.FontSize))
//        .padding(.horizontal)
//    }
//
//    // MARK: - UI Components
//
//    private var dataSourceWithTimestamp: some View {
//        HStack(spacing: Constants.IconTextSpacing) {
//            dataSourceIcon
//            UpdatedAtTextView(viewModel: viewModel)
//                .id(viewModel.id) // Force view recreation when viewModel changes
//        }
//    }
//
//    @ViewBuilder
//    private var dataSourceIcon: some View {
//        Group {
//            if let source = viewModel.source {
//                switch source {
//                case .advertisement, .bgAdvertisement:
//                    sourceIconImage(RuuviAsset.iconBluetooth.image)
//                case .heartbeat, .log:
//                    sourceIconImage(RuuviAsset.iconBluetoothConnected.image)
//                case .ruuviNetwork:
//                    sourceIconImage(RuuviAsset.iconGateway.image, size: Constants.GatewayIconSize)
//                default:
//                    EmptyView()
//                }
//            }
//        }
//    }
//
//    private func sourceIconImage(_ image: UIImage, size: CGFloat = Constants.StandardIconSize) -> some View {
//        Image(uiImage: image)
//            .renderingMode(.template)
//            .resizable()
//            .scaledToFit()
//            .foregroundColor(Constants.IconColor)
//            .frame(width: size, height: size)
//    }
//
//    @ViewBuilder
//    private var batteryStatusView: some View {
//        if viewModel.batteryNeedsReplacement ?? false {
//            HStack(spacing: Constants.BatteryIconTextSpacing) {
//                Image(systemName: "battery.25")
//                    .foregroundColor(Constants.BatteryWarningColor)
//                Text("Low battery")
//                    .foregroundColor(Constants.BatteryWarningColor)
//            }
//            .padding(.leading, Constants.BatteryTextPadding)
//        }
//    }
//
//    // MARK: - Constants
//
//    private enum Constants {
//        static let FontSize: CGFloat = 14
//        static let IconTextSpacing: CGFloat = 8
//        static let StandardIconSize: CGFloat = 16
//        static let GatewayIconSize: CGFloat = 24
//        static let BatteryIconTextSpacing: CGFloat = 4
//        static let BatteryTextPadding: CGFloat = 8
//        static let IconColor = Color.white.opacity(0.7)
//        static let BatteryWarningColor = Color.orange
//    }
//}
//
//// MARK: - UpdatedAtTextView
//
//struct UpdatedAtTextView: View {
//    // MARK: - Properties
//
//    @ObservedObject var viewModel: CardsViewModel
//    @State private var timeAgo: String = ""
//    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
//
//    // MARK: - Body
//
//    var body: some View {
//        Text(timeAgo)
//            .foregroundColor(Constants.TextColor)
//            .onAppear(perform: updateText)
//            .onReceive(timer) { _ in updateText() }
//            .onChange(of: viewModel) { _ in updateText() }
//            .onChange(of: viewModel.date) { _ in updateText() }
//    }
//
//    // MARK: - Methods
//
//    private func updateText() {
//        timeAgo = viewModel.date?.ruuviAgo() ??
//                  RuuviLocalization.Cards.UpdatedLabel.NoData.message
//    }
//
//    // MARK: - Constants
//
//    private enum Constants {
//        static let TextColor = Color.white.opacity(0.7)
//    }
//}
