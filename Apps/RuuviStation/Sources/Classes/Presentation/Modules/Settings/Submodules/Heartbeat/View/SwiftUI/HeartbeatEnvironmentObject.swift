#if canImport(SwiftUI) && canImport(Combine)
    import Combine
    import SwiftUI

    @available(iOS 13, *)
    final class HeartbeatEnvironmentObject: ObservableObject {
        @Published var viewModel = HeartbeatViewModel()
    }
#endif
