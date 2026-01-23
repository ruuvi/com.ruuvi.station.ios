import SwiftUI
import RuuviLocalization

final class VisibilitySettingsViewController: UIViewController, VisibilitySettingsViewInput {
    var output: VisibilitySettingsViewOutput?

    private let state = VisibilitySettingsViewState()
    private var hostingController: UIHostingController<VisibilitySettingsView>!

    private lazy var backButton: UIButton = {
        let button = UIButton()
        button.tintColor = .label
        let buttonImage = RuuviAsset.chevronBack.image
        button.setImage(buttonImage, for: .normal)
        button.setImage(buttonImage, for: .highlighted)
        button.imageView?.tintColor = .label
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(backButtonDidTap), for: .touchUpInside)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        configureHostingController()
        output?.viewDidLoad()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        output?.viewWillDisappear()
    }

    private func setUpUI() {
        title = RuuviLocalization.visibleMeasurements
        view.backgroundColor = RuuviColor.primary.color

        if #unavailable(iOS 26) {
            let backBarButtonItemView = UIView()
            backBarButtonItemView.addSubview(backButton)
            backButton.anchor(
                top: backBarButtonItemView.topAnchor,
                leading: backBarButtonItemView.leadingAnchor,
                bottom: backBarButtonItemView.bottomAnchor,
                trailing: backBarButtonItemView.trailingAnchor,
                padding: .init(top: 0, left: -16, bottom: 0, right: 0),
                size: .init(width: 48, height: 48)
            )
            navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backBarButtonItemView)
        }
    }

    @objc func backButtonDidTap() {
        output?.viewDidAskToDismiss()
    }

    private func configureHostingController() {
        let rootView = VisibilitySettingsView(
            state: state,
            onToggleUseDefault: { [weak self] isOn in
                self?.output?.viewDidToggleUseDefault(isOn: isOn)
            },
            onHideVisible: { [weak self] index in
                self?.output?.viewDidRequestHideItem(at: index)
            },
            onShowHidden: { [weak self] index in
                self?.output?.viewDidRequestShowItem(at: index)
            },
            onStartVisibleMove: { [weak self] in
                self?.output?.viewDidStartReorderingVisibleItems()
            },
            onMoveVisible: { [weak self] source, destination in
                self?.output?
                    .viewDidMoveVisibleItem(from: source, to: destination)
            },
            onFinishVisibleMove: { [weak self] in
                self?.output?.viewDidFinishReorderingVisibleItems()
            }
        )
        hostingController = UIHostingController(rootView: rootView)
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.backgroundColor = .clear
        hostingController.view.fillSuperview()
        hostingController.didMove(toParent: self)
    }

    // MARK: VisibilitySettingsViewInput
    func display(viewModel: VisibilitySettingsViewModel) {
        state.viewModel = viewModel
    }

    func setUseDefaultSwitch(isOn: Bool) {
        var current = state.viewModel
        current = VisibilitySettingsViewModel(
            descriptionText: current.descriptionText,
            useDefault: isOn,
            visibleItems: current.visibleItems,
            hiddenItems: current.hiddenItems,
            preview: current.preview
        )
        state.viewModel = current
    }

    func setSaving(_ isSaving: Bool) {
        state.isSaving = isSaving
    }

    func showMessage(_ message: String) {
        let controller = UIAlertController(
            title: nil,
            message: message,
            preferredStyle: .alert
        )
        controller.addAction(UIAlertAction(title: RuuviLocalization.ok, style: .default))
        present(controller, animated: true)
    }

    // swiftlint:disable:next function_parameter_count
    func presentConfirmation(
        title: String?,
        message: String,
        confirmTitle: String,
        cancelTitle: String,
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)?
    ) {
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: cancelTitle, style: .cancel, handler: { _ in
            onCancel?()
        }))
        controller.addAction(UIAlertAction(title: confirmTitle, style: .default, handler: { _ in
            onConfirm()
        }))
        present(controller, animated: true)
    }
}
