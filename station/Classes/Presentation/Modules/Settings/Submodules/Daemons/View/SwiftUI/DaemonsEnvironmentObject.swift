import SwiftUI
import Combine

@available(iOS 13, *)
final class DaemonsEnvironmentObject: ObservableObject  {
    @Published var daemons = [DaemonsViewModel]()
}
