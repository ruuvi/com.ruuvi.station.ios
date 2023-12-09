#if canImport(SwiftUI) && canImport(Combine)
    import Combine
    import SwiftUI

    @available(iOS 13, *)
    final class DefaultsEnvironmentObject: ObservableObject {
        @Published var viewModels = [DefaultsViewModel]()
    }
#endif
