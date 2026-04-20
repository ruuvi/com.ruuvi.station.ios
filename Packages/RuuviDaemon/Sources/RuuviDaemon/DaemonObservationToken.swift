import Foundation

final class DaemonObservationToken {
    private let invalidationClosure: () -> Void

    init(invalidationClosure: @escaping () -> Void = {}) {
        self.invalidationClosure = invalidationClosure
    }

    func invalidate() {
        invalidationClosure()
    }
}
