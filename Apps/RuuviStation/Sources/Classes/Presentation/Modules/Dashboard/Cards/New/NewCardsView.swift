import SwiftUI
import Combine

struct NewCardsView: View {
    @EnvironmentObject var state: NewCardsViewState

    var body: some View {
        ZStack {
            Color.white
                .edgesIgnoringSafeArea(.all)
            VStack {
                HStack {
                    Button(action: {
                        state.backButtonTapped.send()
                    }) {
                        Text("<")
                            .foregroundColor(.black)
                    }
                    .padding()
                    Spacer()
                }
                Spacer()
            }
        }
    }
}

class NewCardsViewProvider: NSObject {
    private let state = NewCardsViewState()
    private var cancellables = Set<AnyCancellable>()
    private var viewController: UIViewController?

    func makeViewController() -> UIViewController {
        let hostingController = UIHostingController(
            rootView: NewCardsView().environmentObject(state)
        )
        self.viewController = hostingController

        return hostingController
    }

    override init() {
        super.init()
        // Subscribe to back button tap events
        state.backButtonTapped
            .sink { [weak self] _ in
                print("Back button tapped")
                // Get the navigation controller and pop
                if let navigationController = self?.viewController?.navigationController {
                    navigationController.popViewController(animated: true)
                }
            }
            .store(in: &cancellables)
    }
}

class NewCardsViewState: ObservableObject {
//    @Published var model: CardsViewModel!

    let backButtonTapped = PassthroughSubject<Void, Never>()
}

//class NewCardsViewController: UIHostingController<View> {
//
//}
