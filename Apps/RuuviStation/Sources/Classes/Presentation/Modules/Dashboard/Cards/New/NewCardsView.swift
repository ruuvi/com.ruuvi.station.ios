import SwiftUI
import Combine
import RuuviLocalization
import RuuviOntology
import RuuviService
import RuuviStorage

enum SensorCardSelectedTab {
    case home
    case graph
    case alerts
    case settings
}

struct NewCardsView: View {
    @EnvironmentObject var state: NewCardsViewState
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @State private var selectedTab: SensorCardSelectedTab = .home

    var measurementService: RuuviServiceMeasurement?
    var ruuviStorage: RuuviStorage?

    var body: some View {

        ZStack {
            // Background
            if state.viewModels.count > 0 && state.currentPage < state.viewModels.count {
                CardsBackgroundViewRepresentable(
                    image: state.viewModels[state.currentPage].background,
                    withAnimation: true
                )
                .edgesIgnoringSafeArea(.all)
                // TODO: Remove this after discussing with design team
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color.black.opacity(0.3))
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

                    CustomTabBar(selectedTab: $selectedTab)
                        .frame(height: 30)
                }
                .padding(.trailing)
                .padding(.top, verticalSizeClass == .regular ? 0 : 12)
                .padding(.bottom, verticalSizeClass == .regular ? 24 : 8)

                // Horizontal navigation indicators
                HStack {
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

                    // TODO: Fix long name two lines
                    // Also align center.
                    Text(state.viewModels[state.currentPage].name)
                        .font(.muli(.extraBold, size: 20))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .lineLimit(2)

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

                ZStack {
                    switch selectedTab {
                    case .home:
                        PageView(
                            viewModels: state.viewModels,
                            currentPage: $state.currentPage,
                            measurementService: measurementService
                        )
                        .tag(0)
                    case .graph:
                        VStack {
                            Spacer()
                            Text("Graph")
                                .foregroundColor(.white)
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
    let viewModels: [CardsViewModel]
    @Binding var currentPage: Int
    let measurementService: RuuviServiceMeasurement?

    var body: some View {
        PageViewController(
            pages: viewModels.map {
                SensorCardView(
                    viewModel: $0,
                    measurementService: measurementService
                )
            },
            currentPage: $currentPage
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

class NewCardsViewProvider: NSObject {
    var output: CardsModuleOutput?
    var measurementService: RuuviServiceMeasurement?
    var ruuviStorage: RuuviStorage?

    private let state = NewCardsViewState()
    private var cancellables = Set<AnyCancellable>()
    private var transitionHandler: UIViewController?

    // MARK: CardsViewInput
    var viewModels: [CardsViewModel] = [] {
        didSet {
            state.viewModels = viewModels
        }
    }

    var ruuviTags: [AnyRuuviTagSensor] = [] {
        didSet {
            state.ruuviTags = ruuviTags
        }
    }

    var scrollIndex: Int = 0 {
        didSet {
            state.currentPage = scrollIndex
        }
    }

    func makeViewController(transitionHandler: UIViewController?) -> UIViewController {
        // Store the transition handler
        self.transitionHandler = transitionHandler
        self.transitionHandler?.navigationController?.navigationBar.isHidden = true

        // Create the hosting controller with the state injected
        let hostingController = UIHostingController(
            rootView: NewCardsView(
                measurementService: measurementService,
                ruuviStorage: ruuviStorage
            )
            .environmentObject(state)
        )

        return hostingController
    }

    override init() {
        super.init()

        // Subscribe to back button tap events
        state.backButtonTapped
            .sink { [weak self] _ in
                // TODO: CLEANUP
                self?.transitionHandler?.navigationController?.navigationBar.isHidden = false
                // Get the navigation controller and pop
                if let navigationController = self?.transitionHandler?.navigationController {
                    navigationController.popViewController(animated: true)
                }
            }
            .store(in: &cancellables)
    }
}

extension NewCardsViewProvider: CardsViewInput {

    func applyUpdate(to viewModel: CardsViewModel) {

    }

    func scroll(to index: Int) {

    }

    func showBluetoothDisabled(userDeclined: Bool) {

    }

    func showKeepConnectionDialogChart(for viewModel: CardsViewModel) {

    }

    func showKeepConnectionDialogSettings(for viewModel: CardsViewModel) {

    }

    func showFirmwareUpdateDialog(for viewModel: CardsViewModel) {

    }

    func showFirmwareDismissConfirmationUpdateDialog(
        for viewModel: CardsViewModel
    ) {

    }

    func showReverseGeocodingFailed() {

    }

    func showAlreadyLoggedInAlert(with email: String) {

    }

    func viewShouldDismiss() {

    }

}

class NewCardsViewState: ObservableObject {
    // MARK: Properties
    @Published var currentPage: Int = 0
    @Published var viewModels: [CardsViewModel] = []
    @Published var ruuviTags: [AnyRuuviTagSensor] = []

    // MARK: Actions
    let backButtonTapped = PassthroughSubject<Void, Never>()
}
