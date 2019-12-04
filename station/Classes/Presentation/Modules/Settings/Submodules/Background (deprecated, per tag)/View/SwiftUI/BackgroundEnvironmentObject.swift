#if canImport(SwiftUI) && canImport(Combine)
import Combine
import SwiftUI

@available(iOS 13, *)
final class BackgroundEnvironmentObject: ObservableObject  {
    @Published var viewModels = [BackgroundViewModel]()
}
#endif
