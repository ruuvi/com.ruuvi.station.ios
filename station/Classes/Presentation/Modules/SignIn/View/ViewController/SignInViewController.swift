import UIKit

class SignInViewController: UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subTitleLabel: UILabel!
    @IBOutlet weak var textFieldHeaderLabel: UILabel!
    @IBOutlet weak var textTextField: UITextField!
    @IBOutlet weak var submitButton: UIButton!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var scrollView: SignInScrollView!
    @IBOutlet weak var containerView: UIView!

    var output: SignInViewOutput!
    var viewModel: SignInViewModel! {
        didSet {
            bindViewModel()
        }
    }

    deinit {
        unregisterFromKeyboardNotifications()
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
        addTapGesture()
        output.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        registerForKeyboardNotifications()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unregisterFromKeyboardNotifications()
    }

    @IBAction func didTapCloseButton(_ sender: Any) {
        output.viewDidClose()
    }

    @IBAction func didTapSubmit(_ sender: UIButton) {
        updateTextFieldText()
        output.viewDidTapSubmitButton()
    }
}

// MARK: - SignInViewInput
extension SignInViewController: SignInViewInput {
    func localize() {
        title = "SignIn.Title.text".localized()
    }

    func showEmailsAreDifferent(requestedEmail: String, validatedEmail: String) {
        let format = "SignIn.EmailMismatch.Alert.message".localized()
        let message = String(format: format, requestedEmail, validatedEmail, requestedEmail)
        let alertVC = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "OK".localized(), style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }

    func showFailedToGetRequestedEmail() {
        let message = "SignIn.EmailMissing.Alert.message".localized()
        let alertVC = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "OK".localized(), style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }
}

// MARK: - Keyboard
extension SignInViewController {
    func registerForKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onKeyboardAppear(_:)),
            name: UIResponder.keyboardDidShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onKeyboardDisappear(_:)),
            name: UIResponder.keyboardDidHideNotification,
            object: nil
        )
    }

    func unregisterFromKeyboardNotifications() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIResponder.keyboardDidShowNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: UIResponder.keyboardDidHideNotification,
            object: nil
        )
    }

    @objc func onKeyboardAppear(_ notification: NSNotification) {
        guard let info = notification.userInfo,
              let rect = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else { return }
        let kbSize = rect.size

        let insets = UIEdgeInsets(top: 0, left: 0, bottom: kbSize.height, right: 0)
        scrollView.contentInset = insets
        scrollView.scrollIndicatorInsets = insets

        let margin: CGFloat = 20
        let y = kbSize.height - containerView.frame.origin.y + margin
        let scrollPoint = CGPoint(x: 0, y: y)
        scrollView.setContentOffset(scrollPoint, animated: true)
    }

    @objc func onKeyboardDisappear(_ notification: NSNotification) {
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
    }
}

// MARK: - UITextFieldDelegate
extension SignInViewController: UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField) {
        updateTextFieldText()
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        viewModel.errorLabelText.value = nil
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}

// MARK: - Private
extension SignInViewController {

    func updateTextFieldText() {
        let email = textTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        textTextField.text = email
        viewModel.inputText.value = email
    }

    private func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapView))
        view.addGestureRecognizer(tapGesture)
    }

    @objc private func didTapView(_ sender: UITapGestureRecognizer) {
        view.endEditing(true)
    }

    private func bindViewModel() {
        guard isViewLoaded else {
            return
        }
        titleLabel.bind(viewModel.titleLabelText) { (label, value) in
            label.text = value
        }
        subTitleLabel.bind(viewModel.subTitleLabelText) { (label, value) in
            label.text = value
        }
        errorLabel.bind(viewModel.errorLabelText) { (label, value) in
            label.text = value
        }
        textFieldHeaderLabel.bind(viewModel.placeholder) { (label, placeholder) in
            label.text = placeholder
        }
        textTextField.bind(viewModel.textContentType) { (textField, textContentType) in
            if let textContentType = textContentType {
                textField.textContentType = textContentType
            }
        }
        textTextField.bind(viewModel.inputText) { (textField, text) in
            if textField.text != text {
                textField.text = text
            }
        }

        submitButton.bind(viewModel.submitButtonText) { button, text in
            button.setTitle(text, for: .normal)
        }

        navigationItem.leftBarButtonItem?.bind(viewModel.canPopViewController,
                                               block: { (buttonItem, canPopViewController) in
            buttonItem.image = canPopViewController ?? false ? #imageLiteral(resourceName: "icon_back_arrow") : #imageLiteral(resourceName: "dismiss-modal-icon")
        })
    }
}

final class SignInScrollView: UIScrollView {
    override func scrollRectToVisible(_ rect: CGRect, animated: Bool) {
    }
}
