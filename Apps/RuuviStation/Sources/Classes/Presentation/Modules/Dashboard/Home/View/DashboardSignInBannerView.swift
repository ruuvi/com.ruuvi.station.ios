import UIKit
import RuuviLocalization

protocol DashboardSignInBannerViewDelegate: NSObjectProtocol {
    func didTapCloseButton(sender: DashboardSignInBannerView)
    func didTapSignInButton(sender: DashboardSignInBannerView)
}

class DashboardSignInBannerView: UIView {

    weak var delegate: DashboardSignInBannerViewDelegate?

    // Private
    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.text = RuuviLocalization.dashboardBannerSignedOut
        label.textColor = RuuviColor.textColor.color
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.Muli(.bold, size: UIDevice.isiPhoneSE() ? 16 : 20)
        return label
    }()

    private lazy var signInButton: UIButton = {
        let button = UIButton(
            color: RuuviColor.tintColor.color,
            cornerRadius: 22
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
        button.contentEdgeInsets = UIEdgeInsets(
            top: 0,
            left: 32,
            bottom: 0,
            right: 32
        )
        return button
    }()

    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = RuuviColor.textColor.color
        button.addTarget(
            self,
            action: #selector(handleCloseButtonTap),
            for: .touchUpInside
        )
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
}

// MARK: Actions
extension DashboardSignInBannerView {
    @objc private func handleCloseButtonTap() {
        delegate?.didTapCloseButton(sender: self)
    }

    @objc private func handleSignInTap() {
        delegate?.didTapSignInButton(sender: self)
    }
}

// MARK: Private
extension DashboardSignInBannerView {
    private func setupView() {
        backgroundColor = RuuviColor.dashboardNoSensorViewColor.color

        addSubview(messageLabel)
        messageLabel.anchor(
            top: topAnchor,
            leading: leadingAnchor,
            bottom: nil,
            trailing: nil,
            padding: .init(
                top: 12,
                left: 52,
                bottom: 0,
                right: 0
            )
        )

        addSubview(closeButton)
        closeButton.anchor(
            top: nil,
            leading: messageLabel.trailingAnchor,
            bottom: nil,
            trailing: trailingAnchor,
            padding: .init(
                top: 0,
                left: 16,
                bottom: 0,
                right: 16
            ),
            size: .init(width: 20, height: 20)
        )
        closeButton.centerYAnchor.constraint(
            equalTo: messageLabel.centerYAnchor
        ).isActive = true

        addSubview(signInButton)
        signInButton.anchor(
            top: messageLabel.bottomAnchor,
            leading: nil,
            bottom: bottomAnchor,
            trailing: nil,
            padding: .init(
                top: 12,
                left: 0,
                bottom: 12,
                right: 0
            ),
            size: .init(width: 0, height: 44)
        )
        signInButton.centerXInSuperview()
    }
}
