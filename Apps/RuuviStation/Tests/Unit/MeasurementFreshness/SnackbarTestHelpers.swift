@testable import station
import UIKit

@MainActor
final class SnackbarTestClock {
    private struct Job {
        let id: UUID
        let deadline: TimeInterval
        let action: () -> Void
    }
    private var now: TimeInterval = 0
    private var jobs: [Job] = []

    func schedule(after delay: TimeInterval, action: @escaping () -> Void) -> (() -> Void) {
        let id = UUID()
        jobs.append(Job(id: id, deadline: now + delay, action: action))
        return { [weak self] in self?.jobs.removeAll { $0.id == id } }
    }

    func advance(by interval: TimeInterval) {
        now += interval
        while let index = jobs.firstIndex(where: { $0.deadline <= now }) {
            let job = jobs.remove(at: index)
            job.action()
        }
    }
}

@MainActor
final class SnackbarTestAnimator {
    var beforeAnimation: (() -> Void)?
    private var completions: [(Bool) -> Void] = []

    func animate(
        duration: TimeInterval, options: UIView.AnimationOptions,
        animations: @escaping () -> Void, completion: ((Bool) -> Void)?
    ) {
        beforeAnimation?()
        animations()
        if let completion { completions.append(completion) }
    }

    func finishAll() {
        let pending = completions
        completions.removeAll()
        pending.forEach { $0(true) }
    }

    static func immediately(
        duration: TimeInterval, options: UIView.AnimationOptions,
        animations: @escaping () -> Void, completion: ((Bool) -> Void)?
    ) {
        animations()
        completion?(true)
    }
}
