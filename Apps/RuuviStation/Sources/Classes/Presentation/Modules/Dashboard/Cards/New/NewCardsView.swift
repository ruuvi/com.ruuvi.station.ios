import SwiftUI
import Combine
import RuuviLocalization

enum SensorCardSelectedTab {
    case home
    case graph
    case alerts
    case settings
}

struct NewCardsView: View {
    @EnvironmentObject var state: NewCardsViewState
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @State private var currentPage = 0
    @State private var selectedTab: SensorCardSelectedTab = .home
    let sensors = SensorDataProvider.sampleData

    var body: some View {

        ZStack {
            // Background
            Color.black.opacity(0.8).edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Top navigation bar
                HStack {
                    Button(action: {
                        state.backButtonTapped.send()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundColor(.white)
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
                .padding(.horizontal)
                .padding(.top, verticalSizeClass == .regular ? 0 : 12)
                .padding(.bottom, verticalSizeClass == .regular ? 24 : 8)

                // Horizontal navigation indicators
                HStack {
                    Button(action: {
                        if currentPage > 0 {
                            currentPage -= 1
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                    .opacity(currentPage == 0 ? 0 : 1)

                    Spacer()

                    Text(sensors[currentPage].sensorName)
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: {
                        if currentPage < sensors.count - 1 {
                            currentPage += 1
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                    .opacity(currentPage < sensors.count - 1 ? 1 : 0)
                }
                .padding(.horizontal)

                ZStack {
                    switch selectedTab {
                    case .home:
                        PageView(
                            sensors: sensors,
                            currentPage: $currentPage
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
    let sensors: [SensorData]
    @Binding var currentPage: Int

    var body: some View {
        PageViewController(
            pages: sensors.map {
                SensorCardView(
                    sensor: $0
                )
            },
            currentPage: $currentPage)
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

class NewCardsViewProvider: NSObject {
    private let state = NewCardsViewState()
    private var cancellables = Set<AnyCancellable>()
    private var transitionHandler: UIViewController?

    func makeViewController(transitionHandler: UIViewController?) -> UIViewController {
        // Store the transition handler
        self.transitionHandler = transitionHandler
        self.transitionHandler?.navigationController?.navigationBar.isHidden = true

        // Create the hosting controller with the state injected
        let hostingController = UIHostingController(
            rootView: NewCardsView()
                .environmentObject(state)
        )

        return hostingController
    }

    override init() {
        super.init()

        // Subscribe to back button tap events
        state.backButtonTapped
            .sink { [weak self] _ in
                print("Back button tapped in Combine")
                // Get the navigation controller and pop
                if let navigationController = self?.transitionHandler?.navigationController {
                    navigationController.popViewController(animated: true)
                } else {
                    print("Navigation controller not found")
                }
            }
            .store(in: &cancellables)
    }
}

class NewCardsViewState: ObservableObject {
    let backButtonTapped = PassthroughSubject<Void, Never>()
}
