import Foundation

class RUObservationToken {
    private let cancellationClosure: () -> Void

    init(cancellationClosure: @escaping () -> Void) {
        self.cancellationClosure = cancellationClosure
    }

    public func invalidate() {
        cancellationClosure()
    }
}
