import RuuviLocalization
import UIKit

protocol SignInViewDelegate: NSObjectProtocol {
    func didTapRequestCodeButton(sender: SignInView)
}

class SignInView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    weak var delegate: SignInViewDelegate?

    private lazy var container = UIView(color: .clear)

    private lazy var titleStack = UIStackView()
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = RuuviLocalization.signInOrCreateFreeAccount
        label.font = UIFont.Montserrat(
            .extraBold,
            size: UIDevice.isiPhoneSE() ? 24 : 30
        )
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = RuuviLocalization.toUseAllAppFeatures
        label.font = UIFont.Muli(.semiBoldItalic, size: UIDevice.isiPhoneSE() ? 14 : 18)
        return label
    }()

    private lazy var emailTextField: UITextField = {
        let textField = UITextField()
        textField.backgroundColor = .white.withAlphaComponent(0.6)
        textField.tintColor = .white
        textField.layer.cornerRadius = 25
        textField.textColor = .white
        textField.textAlignment = .left
        textField.font = UIFont.Muli(.bold, size: UIDevice.isiPhoneSE() ? 14 : 16)
        textField.placeholder = RuuviLocalization.typeYourEmail
        textField.addPadding(padding: .equalSpacing(16))
        textField.setPlaceHolderColor(color: UIColor.darkGray.withAlphaComponent(0.7))
        textField.keyboardType = .emailAddress
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        return textField
    }()

    private lazy var requestCodeButton: UIButton = {
        let button = UIButton(
            color: RuuviColor.tintColor.color,
            cornerRadius: 25
        )
        button.setTitle(
            RuuviLocalization.requestCode,
            for: .normal
        )
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.Muli(.bold, size: UIDevice.isiPhoneSE() ? 14 : 16)
        button.addTarget(
            self,
            action: #selector(handleRequestTap),
            for: .touchUpInside
        )
        return button
    }()

    private lazy var noPasswordLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = RuuviLocalization.noPasswordNeeded
        label.font = UIFont.Muli(.semiBoldItalic, size: UIDevice.isiPhoneSE() ? 14 : 16)
        return label
    }()
}

extension SignInView {
    @objc private func handleRequestTap() {
        emailTextField.resignFirstResponder()
        delegate?.didTapRequestCodeButton(sender: self)
    }
}

extension SignInView {
    private func setUpUI() {
        setUpTitleView()
        setUpTextFieldView()
    }

    private func setUpTitleView() {
        addSubview(container)
        container.fillSuperview()

        titleStack = UIStackView(arrangedSubviews: [
            titleLabel, subtitleLabel
        ])
        titleStack.axis = .vertical
        titleStack.distribution = .fillProportionally
        titleStack.spacing = 16

        container.addSubview(titleStack)
        titleStack.anchor(
            top: nil,
            leading: container.safeLeftAnchor,
            bottom: nil,
            trailing: container.safeRightAnchor,
            padding: .init(
                top: 0,
                left: !UIDevice.isTablet() ? 20 : 80,
                bottom: 0,
                right: !UIDevice.isTablet() ? 20 : 80
            )
        )
        titleStack.topAnchor.constraint(
            greaterThanOrEqualTo: container.safeTopAnchor
        ).isActive = true
    }

    private func setUpTextFieldView() {
        let textFieldStack = UIStackView(arrangedSubviews: [
            emailTextField, requestCodeButton
        ])
        textFieldStack.axis = .vertical
        textFieldStack.distribution = .fillEqually
        textFieldStack.spacing = 16
        emailTextField.constrainHeight(constant: 50)

        container.addSubview(textFieldStack)
        textFieldStack.anchor(
            top: titleStack.bottomAnchor,
            leading: container.safeLeftAnchor,
            bottom: nil,
            trailing: container.safeRightAnchor,
            padding: .init(
                top: 30,
                left: !UIDevice.isTablet() ? 30 : 100,
                bottom: 0,
                right: !UIDevice.isTablet() ? 30 : 100
            )
        )
        textFieldStack.centerYInSuperview()

        container.addSubview(noPasswordLabel)
        noPasswordLabel.anchor(
            top: textFieldStack.bottomAnchor,
            leading: container.safeLeftAnchor,
            bottom: nil,
            trailing: container.safeRightAnchor,
            padding: .init(
                top: 30,
                left: !UIDevice.isTablet() ? 30 : 100,
                bottom: 0,
                right: !UIDevice.isTablet() ? 30 : 100
            )
        )
        noPasswordLabel.bottomAnchor.constraint(
            lessThanOrEqualTo: container.bottomAnchor, constant: 20
        ).isActive = true
    }
}

extension SignInView {
    override func touchesBegan(_: Set<UITouch>, with _: UIEvent?) {
        emailTextField.resignFirstResponder()
    }
}

extension SignInView {
    func enteredEmail() -> String? {
        let email = emailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        return email
    }

    func populateEmail(from value: String?) {
        emailTextField.text = value
    }
}
