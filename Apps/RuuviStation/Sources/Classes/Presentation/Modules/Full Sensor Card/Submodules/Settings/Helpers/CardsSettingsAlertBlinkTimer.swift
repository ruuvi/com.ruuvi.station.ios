import SwiftUI
import Combine

final class CardsSettingsAlertBlinkTimer: ObservableObject {
    static let shared = CardsSettingsAlertBlinkTimer()

    @Published var isVisible: Bool = true

    private let delay: TimeInterval = 0.5
    private let tolerance: TimeInterval = 0.05
    private var cancellable: AnyCancellable?

    private init() {
        cancellable = Timer.publish(
            every: delay,
            tolerance: tolerance,
            on: .main,
            in: .common
        )
        .autoconnect()
        .sink { [weak self] _ in
            guard let self else { return }
            withAnimation(.easeInOut(duration: self.delay)) {
                self.isVisible.toggle()
            }
        }
    }
}
