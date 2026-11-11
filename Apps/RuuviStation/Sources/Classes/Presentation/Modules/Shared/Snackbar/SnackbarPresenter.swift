import UIKit

/// A reusable, screen-owned snackbar. Repeated requests never queue additional messages.
@MainActor
final class SnackbarPresenter: NSObject {
    var isPresented: Bool { messageView != nil }

    private var messageView: UIView?
    typealias Schedule = @MainActor (TimeInterval, @escaping () -> Void) -> (() -> Void)
    typealias Animate = @MainActor (
        TimeInterval, UIView.AnimationOptions, @escaping () -> Void, ((Bool) -> Void)?
    ) -> Void

    private var cancelDismissal: (() -> Void)?
    private let schedule: Schedule
    private let animate: Animate
    private var isDismissing = false
    private var isDragging = false
    private var dragStartOffset: CGFloat = 0
    private let duration: TimeInterval
    private let animationDuration: TimeInterval
    private let notificationCenter: NotificationCenter
    private let reduceMotion: @MainActor () -> Bool

    init(
        duration: TimeInterval = 3,
        animationDuration: TimeInterval = 0.25,
        notificationCenter: NotificationCenter = .default,
        reduceMotion: @escaping @MainActor () -> Bool = { UIAccessibility.isReduceMotionEnabled },
        schedule: @escaping Schedule = SnackbarPresenter.scheduleOnMain,
        animate: @escaping Animate = SnackbarPresenter.animateView
    ) {
        self.duration = duration
        self.animationDuration = animationDuration
        self.notificationCenter = notificationCenter
        self.reduceMotion = reduceMotion
        self.schedule = schedule
        self.animate = animate
        super.init()
        notificationCenter.addObserver(
            self, selector: #selector(applicationWillResignActive(_:)),
            name: UIApplication.willResignActiveNotification, object: nil
        )
    }

    @discardableResult
    func show(message: String, in view: UIView, accessibilityIdentifier: String = "snackbar-message") -> Bool {
        guard messageView == nil, view.window != nil,
              UIApplication.shared.applicationState == .active else { return false }
        let snackbar = SnackbarView(message: message)
        snackbar.accessibilityIdentifier = accessibilityIdentifier
        snackbar.onDismiss = { [weak self] in self?.dismiss() }
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.delegate = self
        snackbar.addGestureRecognizer(pan)
        view.addSubview(snackbar)
        NSLayoutConstraint.activate([
            snackbar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            snackbar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            snackbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),
        ])
        view.layoutIfNeeded()
        messageView = snackbar
        let reducesMotion = reduceMotion()
        snackbar.alpha = reducesMotion ? 0 : 1
        snackbar.transform = reducesMotion ? .identity : offscreenTransform(for: snackbar)
        animate(animationDuration, [.curveEaseOut, .allowUserInteraction], {
            snackbar.alpha = 1
            snackbar.transform = .identity
        }, nil)
        UIAccessibility.post(notification: .announcement, argument: message)
        scheduleDismissal(for: snackbar)
        return true
    }

    /// Retarget the visible message without queuing another view. An exiting message is replaced by show().
    func restartDismissal(in host: UIView) -> Bool {
        guard let messageView else { return false }
        guard messageView.superview === host, !isDismissing else {
            dismiss(animated: false)
            return false
        }
        if !isDragging { scheduleDismissal(for: messageView) }
        return true
    }

    func dismiss(animated: Bool = true) {
        cancelDismissal?()
        cancelDismissal = nil
        isDragging = false
        guard let messageView else { return }
        guard animated, animationDuration > 0, UIView.areAnimationsEnabled else {
            messageView.layer.removeAllAnimations()
            finishDismissal(of: messageView)
            return
        }
        guard !isDismissing else { return }
        isDismissing = true
        let reducesMotion = reduceMotion()
        let destination = reducesMotion ? CGAffineTransform.identity : offscreenTransform(for: messageView)
        animate(
            animationDuration, [.curveEaseIn, .beginFromCurrentState, .allowUserInteraction], {
                messageView.alpha = reducesMotion ? 0 : 1
                messageView.transform = destination
            }, { [weak self] _ in
                messageView.removeFromSuperview()
                self?.finishDismissal(of: messageView)
            }
        )
    }

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let message = messageView, gesture.view === message, !isDismissing else { return }
        switch gesture.state {
        case .began:
            cancelDismissal?()
            cancelDismissal = nil
            isDragging = true
            let current = message.layer.presentation()?.affineTransform() ?? message.transform
            message.layer.removeAllAnimations()
            message.alpha = 1
            message.transform = current
            dragStartOffset = max(0, current.ty)
            gesture.setTranslation(.zero, in: message.superview)
        case .changed:
            guard isDragging else { return }
            updateDrag(gesture, message: message)
        case .ended:
            guard isDragging else { return }
            updateDrag(gesture, message: message)
            isDragging = false
            let velocity = gesture.velocity(in: message.superview).y
            let threshold = max(24, message.bounds.height / 2)
            if message.transform.ty >= threshold || (message.transform.ty > 0 && velocity >= 600) {
                dismiss()
            } else {
                returnToRest(message)
            }
        case .cancelled, .failed:
            guard isDragging else { return }
            isDragging = false
            returnToRest(message)
        default:
            break
        }
    }

    private func updateDrag(_ gesture: UIPanGestureRecognizer, message: UIView) {
        let offset = max(0, dragStartOffset + gesture.translation(in: message.superview).y)
        message.transform = CGAffineTransform(translationX: 0, y: min(offset, offscreenTransform(for: message).ty))
    }

    private func returnToRest(_ message: UIView) {
        animate(
            animationDuration, [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction],
            { message.transform = .identity },
            { [weak self] finished in
                guard let self, finished, self.messageView === message,
                      !self.isDragging, !self.isDismissing else { return }
                self.scheduleDismissal(for: message)
            }
        )
    }

    private func scheduleDismissal(for message: UIView) {
        cancelDismissal?()
        cancelDismissal = schedule(duration) { [weak self, weak message] in
            guard let self, let message, self.messageView === message, !self.isDragging else { return }
            self.dismiss()
        }
    }

    static func scheduleOnMain(after delay: TimeInterval, action: @escaping () -> Void) -> (() -> Void) {
        let work = DispatchWorkItem(block: action)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        return { work.cancel() }
    }

    static func animateView(
        duration: TimeInterval, options: UIView.AnimationOptions,
        animations: @escaping () -> Void, completion: ((Bool) -> Void)?
    ) {
        UIView.animate(
            withDuration: duration, delay: 0, options: options, animations: animations, completion: completion
        )
    }

    private func offscreenTransform(for message: UIView) -> CGAffineTransform {
        guard let container = message.superview else { return .identity }
        // Use the untransformed top so dismissing during entry still moves fully below the host.
        let top = message.center.y - message.bounds.height / 2
        return CGAffineTransform(translationX: 0, y: max(0, container.bounds.maxY - top))
    }

    private func finishDismissal(of message: UIView) {
        message.removeFromSuperview()
        guard messageView === message else { return }
        messageView = nil
        isDismissing = false
    }

    @objc private func applicationWillResignActive(_: Notification) {
        dismiss(animated: false)
    }

    deinit {
        notificationCenter.removeObserver(self)
        cancelDismissal?()
    }
}

extension SnackbarPresenter: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
              let messageView, pan.view === messageView, !isDismissing else { return false }
        let velocity = pan.velocity(in: messageView.superview)
        return velocity.y > abs(velocity.x)
    }
}
