import UIKit
import RuuviLocalization

private final class NotesEditorTextView: UITextView {
    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        builder.remove(menu: .lookup)
        builder.remove(menu: .replace)
        builder.remove(menu: .share)
        builder.remove(menu: .learn)
        builder.remove(menu: .find)
        builder.remove(menu: .spelling)
        builder.remove(menu: .substitutions)
        builder.remove(menu: .transformations)
        builder.remove(menu: .speech)
        if #available(iOS 17.0, *) {
            builder.remove(menu: .autoFill)
        }
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        let allowedActions: Set<Selector> = [
            #selector(copy(_:)),
            #selector(cut(_:)),
            #selector(paste(_:)),
            #selector(select(_:)),
            #selector(selectAll(_:)),
        ]
        guard allowedActions.contains(action) else {
            return false
        }
        return super.canPerformAction(action, withSender: sender)
    }
}

final class NotesSettingsViewController: UIViewController {
    var onSave: ((String?, @escaping (Result<Void, Error>) -> Void) -> Void)?

    private struct Constants {
        static let maxCharacters: Int = 1000
        static let horizontalPadding: CGFloat = 12
        static let topPadding: CGFloat = 12
        static let editorBottomSpacing: CGFloat = 8
        static let bottomPadding: CGFloat = 12
        static let minimumEditorHeight: CGFloat = 160
        static let editorCornerRadius: CGFloat = 12
        static let editorBorderWidth: CGFloat = 1
    }

    private let initialNotes: String
    private var isSaving = false

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

    private lazy var textView: UITextView = {
        let textView = NotesEditorTextView()
        textView.backgroundColor = .clear
        textView.textColor = RuuviColor.textColor.color
        textView.font = UIFont.ruuviBody()
        textView.delegate = self
        textView.isEditable = true
        textView.isSelectable = true
        textView.keyboardDismissMode = .interactive
        textView.textContentType = .none
        textView.textContainerInset = .init(top: 8, left: 8, bottom: 8, right: 8)
        return textView
    }()

    private lazy var editorContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.cornerRadius = Constants.editorCornerRadius
        view.layer.borderWidth = Constants.editorBorderWidth
        view.layer.borderColor = RuuviColor.tintColor.color.cgColor
        return view
    }()

    private lazy var characterCountLabel: UILabel = {
        let label = UILabel()
        label.textColor = .secondaryLabel
        label.font = UIFont.ruuviFootnote()
        label.textAlignment = .right
        return label
    }()

    private lazy var updateButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = RuuviColor.tintColor.color
        config.baseForegroundColor = .white
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 0,
            leading: 20,
            bottom: 0,
            trailing: 20
        )
        config.cornerStyle = .capsule

        let button = UIButton(configuration: config)
        button.setTitle(RuuviLocalization.update, for: .normal)
        button.titleLabel?.font = UIFont.ruuviButtonMedium()
        button.addTarget(self, action: #selector(saveButtonDidTap), for: .touchUpInside)
        return button
    }()

    init(notes: String?) {
        self.initialNotes = notes ?? ""
        super.init(nibName: nil, bundle: nil)
        title = RuuviLocalization.notes
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
    }
}

private extension NotesSettingsViewController {

    // swiftlint:disable:next function_body_length
    func setUpUI() {
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

        view.addSubview(editorContainerView)
        editorContainerView.anchor(
            top: view.safeTopAnchor,
            leading: view.safeLeftAnchor,
            bottom: nil,
            trailing: view.safeRightAnchor,
            padding: .init(
                top: Constants.topPadding,
                left: Constants.horizontalPadding,
                bottom: 0,
                right: Constants.horizontalPadding
            )
        )
        editorContainerView.heightAnchor.constraint(
            greaterThanOrEqualToConstant: Constants.minimumEditorHeight
        ).isActive = true

        editorContainerView.addSubview(textView)
        textView.fillSuperview()

        view.addSubview(characterCountLabel)
        characterCountLabel.anchor(
            top: editorContainerView.bottomAnchor,
            leading: view.safeLeftAnchor,
            bottom: nil,
            trailing: view.safeRightAnchor,
            padding: .init(
                top: Constants.editorBottomSpacing,
                left: Constants.horizontalPadding,
                bottom: 0,
                right: Constants.horizontalPadding
            )
        )

        view.addSubview(updateButton)
        updateButton.anchor(
            top: nil,
            leading: nil,
            bottom: nil,
            trailing: nil
        )
        updateButton.centerXInSuperview()
        updateButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true

        NSLayoutConstraint.activate([
            updateButton.bottomAnchor.constraint(
                equalTo: view.keyboardLayoutGuide.topAnchor,
                constant: -Constants.bottomPadding
            ),
            characterCountLabel.bottomAnchor.constraint(
                equalTo: updateButton.topAnchor,
                constant: -Constants.editorBottomSpacing
            ),
            characterCountLabel.bottomAnchor.constraint(
                greaterThanOrEqualTo: editorContainerView.bottomAnchor,
                constant: Constants.editorBottomSpacing
            ),
        ])

        textView.text = initialNotes
        updateCharacterCount()
    }

    func updateCharacterCount() {
        characterCountLabel.text = "\(textView.text.count)/\(Constants.maxCharacters)"
    }

    func presentSaveError(_ error: Error) {
        let controller = UIAlertController(
            title: nil,
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        controller.addAction(
            UIAlertAction(
                title: RuuviLocalization.ok,
                style: .cancel
            )
        )
        present(controller, animated: true)
    }

    @objc func saveButtonDidTap() {
        guard !isSaving else { return }

        let notes = textView.text ?? ""
        let isCurrentEmpty = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isInitialEmpty = initialNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if isCurrentEmpty, isInitialEmpty {
            _ = navigationController?.popViewController(animated: true)
            return
        }

        let value: String? = isCurrentEmpty ? nil : notes

        guard let onSave else {
            _ = navigationController?.popViewController(animated: true)
            return
        }

        isSaving = true
        updateButton.isEnabled = false

        onSave(value) { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                self.isSaving = false
                self.updateButton.isEnabled = true
                switch result {
                case .success:
                    _ = self.navigationController?.popViewController(animated: true)
                case let .failure(error):
                    self.presentSaveError(error)
                }
            }
        }
    }

    @objc func backButtonDidTap() {
        _ = navigationController?.popViewController(animated: true)
    }
}

extension NotesSettingsViewController: UITextViewDelegate {
    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        guard let current = textView.text,
              let swiftRange = Range(range, in: current) else {
            return false
        }
        let updated = current.replacingCharacters(in: swiftRange, with: text)
        return updated.count <= Constants.maxCharacters
    }

    func textViewDidChange(_ textView: UITextView) {
        if textView.text.count > Constants.maxCharacters {
            textView.text = String(textView.text.prefix(Constants.maxCharacters))
        }
        updateCharacterCount()
    }
}
