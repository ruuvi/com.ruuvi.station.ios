import UIKit
import RuuviLocalization

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
        static let placeholderTopInset: CGFloat = 12
        static let placeholderLeadingInset: CGFloat = 16
        static let placeholderTrailingInset: CGFloat = 16
        static let placeholderText: String = "Write notes here..."
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
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.textColor = RuuviColor.textColor.color
        textView.font = UIFont.ruuviBody()
        textView.delegate = self
        textView.isEditable = true
        textView.isSelectable = true
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = .init(top: 8, left: 8, bottom: 8, right: 8)
        return textView
    }()

    private lazy var editorContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = Constants.editorCornerRadius
        view.layer.borderWidth = Constants.editorBorderWidth
        view.layer.borderColor = RuuviColor.lineColor.color.cgColor
        return view
    }()

    private lazy var placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = Constants.placeholderText
        label.textColor = .secondaryLabel
        label.font = UIFont.ruuviBody()
        label.numberOfLines = 0
        return label
    }()

    private lazy var characterCountLabel: UILabel = {
        let label = UILabel()
        label.textColor = .secondaryLabel
        label.font = UIFont.ruuviFootnote()
        label.textAlignment = .right
        return label
    }()

    init(notes: String?) {
        self.initialNotes = notes ?? ""
        super.init(nibName: nil, bundle: nil)
        title = "Notes"
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

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Update",
            style: .done,
            target: self,
            action: #selector(saveButtonDidTap)
        )

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

        textView.addSubview(placeholderLabel)
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(
                equalTo: textView.topAnchor,
                constant: Constants.placeholderTopInset
            ),
            placeholderLabel.leadingAnchor.constraint(
                equalTo: textView.leadingAnchor,
                constant: Constants.placeholderLeadingInset
            ),
            placeholderLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: textView.trailingAnchor,
                constant: -Constants.placeholderTrailingInset
            ),
        ])

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
        NSLayoutConstraint.activate([
            characterCountLabel.bottomAnchor.constraint(
                equalTo: view.keyboardLayoutGuide.topAnchor,
                constant: -Constants.bottomPadding
            ),
        ])

        textView.text = initialNotes
        updateCharacterCount()
        updatePlaceholderVisibility()
    }

    func updateCharacterCount() {
        characterCountLabel.text = "\(textView.text.count)/\(Constants.maxCharacters)"
    }

    func updatePlaceholderVisibility() {
        placeholderLabel.isHidden = !(textView.text ?? "").isEmpty
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
        let value: String? = notes.isEmpty ? nil : notes

        guard let onSave else {
            _ = navigationController?.popViewController(animated: true)
            return
        }

        isSaving = true
        navigationItem.rightBarButtonItem?.isEnabled = false

        onSave(value) { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                self.isSaving = false
                self.navigationItem.rightBarButtonItem?.isEnabled = true
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
        updatePlaceholderVisibility()
    }
}
