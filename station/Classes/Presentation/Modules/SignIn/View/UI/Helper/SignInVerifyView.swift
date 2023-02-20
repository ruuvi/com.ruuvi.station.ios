import UIKit

protocol SignInVerifyViewDelegate: NSObjectProtocol {
    func didFinishTypingCode(code: String, sender: SignInVerifyView)
}

class SignInVerifyView: UIView {

    weak var delegate: SignInVerifyViewDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var container = UIView(color: .clear)

    private lazy var titleStack = UIStackView()
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "enter_code".localized()
        label.font = UIFont.Montserrat(.extraBold, size: 30)
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "SignIn.CheckMailbox".localized()
        label.font = UIFont.Muli(.semiBoldItalic, size: 18)
        return label
    }()

    private lazy var ruuviCodeView = RuuviCodeView()

    private lazy var beaverImageView: UIImageView = {
        let iv = UIImageView(
            image: nil,
            contentMode: .scaleAspectFit
        )
        iv.backgroundColor = .clear
        return iv
    }()
    private var beaverImageViewTopAnchor: NSLayoutConstraint!
}

extension SignInVerifyView {
    private func setUpUI() {
        setUpTitleView()
        setUpCodeEnterView()
        setUpBeaverView()
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
        titleStack.anchor(top: nil,
                         leading: container.safeLeftAnchor,
                         bottom: nil,
                         trailing: container.safeRightAnchor,
                         padding: .init(top: 0, left: !UIDevice.isTablet() ? 20 : 80,
                                        bottom: 0, right: !UIDevice.isTablet() ? 20 : 80))
        titleStack.topAnchor.constraint(
            equalTo: container.safeTopAnchor
        ).isActive = true
    }

    private func setUpCodeEnterView() {
        container.addSubview(ruuviCodeView)
        ruuviCodeView.delegate = self
        ruuviCodeView.anchor(top: titleStack.bottomAnchor,
                             leading: nil,
                             bottom: nil, trailing: nil,
                             padding: .init(top: 30, left: 0, bottom: 0, right: 0),
                             size: .init(width: 0, height: 50))
        ruuviCodeView.centerXInSuperview()
    }

    private func setUpBeaverView() {

        let beaverContainerView = UIView(color: .clear)
        container.addSubview(beaverContainerView)

        beaverContainerView.anchor(top: ruuviCodeView.bottomAnchor,
                                   leading: container.leadingAnchor,
                                   bottom: container.bottomAnchor,
                                   trailing: container.trailingAnchor)
        beaverContainerView.addSubview(beaverImageView)

        beaverImageView.anchor(top: nil,
                               leading: beaverContainerView.leadingAnchor,
                               bottom: nil,
                               trailing: beaverContainerView.trailingAnchor)
        beaverImageView.constrainHeight(constant: 400)
        beaverImageView.image = RuuviAssets.signInBeaver.resize(targetHeight: 400)
        beaverImageView.centerYInSuperview()
    }
}

extension SignInVerifyView {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        endEditing(true)
    }
}

extension SignInVerifyView: RuuviCodeViewDelegate {
    func didFinishTypingCode() {
        guard ruuviCodeView.isValidCode else {
            return
        }
        let code = ruuviCodeView.ruuviCode()
        delegate?.didFinishTypingCode(code: code, sender: self)
    }
}

extension SignInVerifyView {
    func populate(from code: String?) {
        ruuviCodeView.autofill(with: code)
    }

    func reset() {
        ruuviCodeView.reset()
    }
}
