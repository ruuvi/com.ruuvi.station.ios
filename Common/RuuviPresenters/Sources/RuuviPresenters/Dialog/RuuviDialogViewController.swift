import UIKit

/// Presents a reusable Ruuvi dialog over a dimmed screen. Actions are controlled by the caller.
public final class RuuviDialogViewController: UIViewController {
    public var onPrimaryAction: (() -> Void)?
    public var onSecondaryAction: (() -> Void)?
    public var onDidAppear: (() -> Void)?
    public var onDismiss: (() -> Void)?

    private let dialogView: RuuviDialogView
    private var heightConstraint: NSLayoutConstraint!

    public init(configuration: RuuviDialogConfiguration) {
        dialogView = RuuviDialogView(configuration: configuration)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
        isModalInPresentation = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        view.accessibilityViewIsModal = true
        view.addSubview(dialogView)
        dialogView.translatesAutoresizingMaskIntoConstraints = false
        let preferredWidth = dialogView.widthAnchor.constraint(equalToConstant: 340)
        preferredWidth.priority = UILayoutPriority(999)
        heightConstraint = dialogView.heightAnchor.constraint(equalToConstant: 1)
        NSLayoutConstraint.activate([
            preferredWidth,
            heightConstraint,
            dialogView.widthAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.widthAnchor, constant: -48),
            dialogView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            dialogView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
        ])
        dialogView.onPrimaryAction = { [weak self] in self?.onPrimaryAction?() }
        dialogView.onSecondaryAction = { [weak self] in self?.onSecondaryAction?() }
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let availableHeight = max(0, view.safeAreaLayoutGuide.layoutFrame.height - 32)
        let height = min(dialogView.preferredHeight(for: dialogView.bounds.width), availableHeight)
        if abs(heightConstraint.constant - height) > 0.5 {
            heightConstraint.constant = height
            view.layoutIfNeeded()
        }
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        dialogView.focusTitle()
        onDidAppear?()
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || presentingViewController == nil {
            onDismiss?()
        }
    }

    public func configure(_ configuration: RuuviDialogConfiguration) {
        dialogView.configure(configuration)
        view.setNeedsLayout()
        if view.window != nil { dialogView.focusTitle() }
    }

    public func setLoading(_ loading: Bool) {
        dialogView.setLoading(loading)
    }

    public func showError(_ message: String?) {
        dialogView.showError(message)
        view.setNeedsLayout()
    }
}
