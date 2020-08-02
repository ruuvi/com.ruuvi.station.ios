import UIKit
class AddMacModalViewController: UIViewController {
    var output: (AddMacModalViewOutput & MacPasteboardAccessoryViewOutput)!
    var viewModel: AddMacModalViewModel! {
        didSet {
            bindViewModel()
        }
    }
    private var canSendMac: Bool = false {
        didSet {
            if oldValue != canSendMac {
                hexadecimalKeyboard.okButton.isEnabled = canSendMac
            }
        }
    }

    @IBOutlet weak var firstTextField: UITextField!
    @IBOutlet weak var secondTextField: UITextField!
    @IBOutlet weak var thirdTextField: UITextField!
    @IBOutlet weak var fourthTextField: UITextField!
    @IBOutlet weak var fifthTextField: UITextField!
    @IBOutlet weak var sixthTextField: UITextField!
    @IBOutlet weak var macStackView: UIStackView!

    private var hexadecimalKeyboard: HexadecimalKeyboard!

    private let ranges: [NSRange] = [
        NSRange(location: 0, length: 2),
        NSRange(location: 2, length: 2),
        NSRange(location: 4, length: 2),
        NSRange(location: 6, length: 2),
        NSRange(location: 8, length: 2),
        NSRange(location: 10, length: 2)
    ]

    private lazy var pasteboardAccessoryView: MacPasteboardAccessoryView = {
        let size = CGSize(width: view.frame.width, height: 44)
        let rect = CGRect(origin: .zero, size: size)
        let accessocyView = MacPasteboardAccessoryView(frame: rect)
        accessocyView.output = self.output
        return accessocyView
    }()

    private lazy var macTextField: UITextField = {
        $0.clearButtonMode = .never
        return $0
    }(UITextField(frame: .zero))

    private lazy var labels = {
        return [
            firstTextField!,
            secondTextField!,
            thirdTextField!,
            fourthTextField!,
            fifthTextField!,
            sixthTextField!
        ]
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
        setupLocalization()
        output.viewDidLoad()
    }

    private func configure() {
        pasteboardAccessoryView.sizeToFit()
        macTextField.inputAccessoryView = pasteboardAccessoryView

        view.addSubview(macTextField)
        configureKeyboard(for: macTextField)

        macTextField.addTarget(self, action: #selector(self.textDidChange(_:)), for: .editingChanged)
        macTextField.becomeFirstResponder()
    }

    @IBAction func didCloseButtonTap(_ sender: Any) {
        output.viewDidTriggerDismiss()
    }
}

// MARK: - AddMacModalViewInput
extension AddMacModalViewController: AddMacModalViewInput {
    func localize() {
        title = "AddMacModalViewController.EnterMacAddress".localized()
    }

    func didSelectMacAddress(_ mac: String) {
        macTextField.text = nil
        macTextField.insertText(mac)
        if #available(iOS 13.0, *) {
            let feedback = UIImpactFeedbackGenerator(style: .soft)
            feedback.impactOccurred()
        }
    }
}

// MARK: - RemoveKeyboardDelegate
extension AddMacModalViewController: RemoveKeyboardDelegate {
    func removeKeyboard() {
    }
}

// MARK: - Private
extension AddMacModalViewController {

    @objc private func textDidChange(_ sender: UITextField) {
        let text = sender.text ?? ""
        canSendMac = text.count >= 12
        guard text.count < 13 else {
            sender.text = String(text.prefix(12))
            shake()
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.error)
            notification.prepare()
            return
        }
        labels.enumerated().forEach({
            $0.element.text = text[safe: ranges[$0.offset]]?.uppercased()
        })
    }

    private func shake() {
        let propertyAnimator = UIViewPropertyAnimator(duration: 0.5, dampingRatio: 0.3) {
            self.macStackView.transform = CGAffineTransform(translationX: -3, y: 0)
        }
        propertyAnimator.addAnimations({
            self.macStackView.transform = CGAffineTransform(translationX: 3, y: 0)
        }, delayFactor: 0.2)
        propertyAnimator.addAnimations({
            self.macStackView.transform = CGAffineTransform(translationX: 0, y: 0)
        }, delayFactor: 0.2)
        propertyAnimator.startAnimation()
    }

    private func bindViewModel() {
        bind(viewModel.pasteboardDetectedMacs) { (view, items) in
            view.pasteboardAccessoryView.setItems(items ?? [])
        }
    }

    private func configureKeyboard(for textField: UITextField) {
        hexadecimalKeyboard = HexadecimalKeyboard(target: textField)
        hexadecimalKeyboard.okButton.isEnabled = false
        hexadecimalKeyboard.delegate = self
        hexadecimalKeyboard.okButton.setTitle("AddMacModalViewController.Send".localized(), for: .normal)
        if #available(iOS 13.0, *) {
            hexadecimalKeyboard.okButton.setTitleColor(.label, for: .normal)
            hexadecimalKeyboard.okButton.setTitleColor(.placeholderText, for: .disabled)
        } else {
            // Fallback on earlier versions
        }
        hexadecimalKeyboard.okButton.addTarget(self, action: #selector(didSendButtonTap), for: .touchUpInside)
        textField.inputView = hexadecimalKeyboard
    }

    @objc private func didSendButtonTap() {
        guard let mac = macTextField.text else {
            return
        }
        output.viewDidTriggerSend(mac: mac)
    }
}
