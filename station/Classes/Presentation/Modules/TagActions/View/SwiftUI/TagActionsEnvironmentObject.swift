#if canImport(SwiftUI) && canImport(Combine)
import Combine
import SwiftUI

@available(iOS 13, *)
final class TagActionsEnvironmentObject: ObservableObject  {
    @Published var viewModel = TagActionsViewModel(uuid: UUID().uuidString)
}
#endif
