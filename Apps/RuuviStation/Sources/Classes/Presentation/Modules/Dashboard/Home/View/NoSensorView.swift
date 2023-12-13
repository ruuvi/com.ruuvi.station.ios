import RuuviLocalization
import UIKit

protocol NoSensorViewDelegate: NSObjectProtocol {
    func didTapSignInButton(sender: NoSensorView)
    func didTapAddSensorButton(sender: NoSensorView)
    func didTapBuySensorButton(sender: NoSensorView)
}

class NoSensorView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    weak var delegate: NoSensorViewDelegate?
    var userSignedInOnce: Bool = false

    private lazy var scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.showsVerticalScrollIndicator = false
        return scroll
    }()

    private lazy var container = UIView(color: .clear)

    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.ruuviTextColor
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.Muli(.semiBoldItalic, size: UIDevice.isiPhoneSE() ? 16 : 20)
        return label
    }()

    private lazy var centerButtonStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.distribution = .fillEqually
        stackView.axis = .vertical
        stackView.spacing = 16
        return stackView
    }()

    private lazy var signInButton: UIButton = {
        let button = UIButton(
            color: RuuviColor.ruuviTintColor,
            cornerRadius: UIDevice.isiPhoneSE() ? 20 : 25
        )
        button.setTitle(
            RuuviLocalization.SignIn.Title.text,
            for: .normal
        )
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.Muli(
            .bold,
            size: UIDevice.isiPhoneSE() ? 14 : 16
        )
        button.addTarget(
            self,
            action: #selector(handleSignInTap),
            for: .touchUpInside
        )
        return button
    }()

    private lazy var addSensorButton: UIButton = {
        let button = UIButton(
            color: RuuviColor.ruuviTintColor,
            cornerRadius: UIDevice.isiPhoneSE() ? 20 : 25
        )
        button.setTitle(
            RuuviLocalization.addASensor,
            for: .normal
        )
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.Muli(
            .bold,
            size: UIDevice.isiPhoneSE() ? 14 : 16
        )
        button.addTarget(
            self,
            action: #selector(handleAddSensorTap),
            for: .touchUpInside
        )
        return button
    }()

    private lazy var buySensorButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(RuuviColor.ruuviTextColor, for: .normal)
        button.setTitle(
            RuuviLocalization.DiscoverTable.GetMoreSensors.Button.title,
            for: .normal
        )
        button.titleLabel?.font = UIFont.Muli(
            .bold,
            size: 14
        )
        button.addTarget(
            self,
            action: #selector(handleBuySensorTap),
            for: .touchUpInside
        )
        button.underline()
        return button
    }()

    var messageLabelTopAnchor: NSLayoutConstraint!
    var centerButtonCenterYAnchor: NSLayoutConstraint!
    var buySensorsButtonBottomAnchor: NSLayoutConstraint!
}

extension NoSensorView {
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        centerButtonCenterYAnchor.isActive = activateCenterButtonStackConstraint()
    }
}

// MARK: - Public

extension NoSensorView {
    func updateView(userSignInOnce: Bool) {
        if centerButtonStackView.subviews.count > 0 {
            centerButtonStackView.subviews.forEach { $0.removeFromSuperview() }
        }

        let buttons = userSignInOnce ? [signInButton, addSensorButton] : [addSensorButton]
        for button in buttons {
            centerButtonStackView.addArrangedSubview(button)
        }
        messageLabel.text = userSignInOnce ?
            RuuviLocalization.dashboardNoSensorsMessageSignedOut :
            RuuviLocalization.dashboardNoSensorsMessage
        centerButtonCenterYAnchor.isActive =
            userSignInOnce ? activateCenterButtonStackConstraint() : true
    }
}

extension NoSensorView {
    @objc private func handleSignInTap() {
        delegate?.didTapSignInButton(sender: self)
    }

    @objc private func handleAddSensorTap() {
        delegate?.didTapAddSensorButton(sender: self)
    }

    @objc private func handleBuySensorTap() {
        delegate?.didTapBuySensorButton(sender: self)
    }
}

extension NoSensorView {
    // swiftlint:disable:next function_body_length
    private func setUpUI() {
        addSubview(scrollView)
        scrollView.fillSuperview()

        scrollView.addSubview(container)
        container.fillSuperview()
        container
            .widthAnchor
            .constraint(
                equalTo: widthAnchor
            ).isActive = true

        container.addSubview(messageLabel)
        messageLabel.anchor(
            top: nil,
            leading: container.safeLeftAnchor,
            bottom: nil,
            trailing: container.safeRightAnchor,
            padding: .init(
                top: 0,
                left: 30,
                bottom: 0,
                right: 30
            )
        )
        messageLabelTopAnchor = messageLabel
            .topAnchor
            .constraint(
                greaterThanOrEqualTo: container.topAnchor,
                constant: 30
            )
        messageLabelTopAnchor.priority = .defaultLow
        messageLabelTopAnchor.isActive = true

        container.addSubview(centerButtonStackView)
        addSensorButton.constrainHeight(constant: UIDevice.isiPhoneSE() ? 40 : 50)
        if UIDevice.isiPhoneSE() {
            centerButtonStackView.anchor(
                top: nil,
                leading: container.leadingAnchor,
                bottom: nil,
                trailing: container.trailingAnchor,
                padding: .init(top: 0, left: 8, bottom: 0, right: 8)
            )
        } else {
            centerButtonStackView.widthAnchor.constraint(
                greaterThanOrEqualToConstant: 300
            ).isActive = true
        }
        centerButtonStackView.centerXInSuperview()
        centerButtonStackView
            .topAnchor
            .constraint(
                equalTo: messageLabel.bottomAnchor,
                constant: 30
            ).isActive = true
        centerButtonCenterYAnchor = centerButtonStackView
            .centerYAnchor
            .constraint(
                equalTo: centerYAnchor
            )
        centerButtonCenterYAnchor.priority = .defaultLow
        centerButtonCenterYAnchor.isActive = activateCenterButtonStackConstraint()

        container.addSubview(buySensorButton)
        buySensorButton.anchor(
            top: centerButtonStackView.bottomAnchor,
            leading: container.safeLeftAnchor,
            bottom: nil,
            trailing: container.safeRightAnchor,
            padding: .init(
                top: 24,
                left: 30,
                bottom: 0,
                right: 30
            )
        )
        buySensorsButtonBottomAnchor = buySensorButton
            .bottomAnchor
            .constraint(
                lessThanOrEqualTo: container.bottomAnchor
            )
        buySensorsButtonBottomAnchor.priority = .defaultLow
        buySensorsButtonBottomAnchor.isActive = true
    }

    private func activateCenterButtonStackConstraint() -> Bool {
        if !userSignedInOnce {
            return true
        }

        if UIDevice.isTablet() {
            return true
        }

        return
            UIScreen.main.traitCollection.horizontalSizeClass == .compact &&
            UIScreen.main.traitCollection.verticalSizeClass == .regular
    }
}
