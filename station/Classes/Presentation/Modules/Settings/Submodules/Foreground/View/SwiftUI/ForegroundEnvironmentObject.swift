#if canImport(SwiftUI) && canImport(Combine)
import Combine
import SwiftUI

@available(iOS 13, *)
final class ForegroundEnvironmentObject: ObservableObject  {
    @Published var daemons = [ForegroundViewModel]()
}
#endif
