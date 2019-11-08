#if canImport(SwiftUI) && canImport(Combine)
import Combine
import SwiftUI
import BTKit

@available(iOS 13, *)
final class TagActionsEnvironmentObject: ObservableObject  {
    @Published var viewModel = TagActionsViewModel(uuid: UUID().uuidString)
    @Published var syncProgress: BTServiceProgress?
}
#endif
