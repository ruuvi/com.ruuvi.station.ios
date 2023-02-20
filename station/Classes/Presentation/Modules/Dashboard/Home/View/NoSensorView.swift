import UIKit

protocol NoSensorViewDelegate: NSObjectProtocol {
    func didTapAddSensorButton(sender: NoSensorView)
    func didTapBuySensorButton(sender: NoSensorView)
}

class NoSensorView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    weak var delegate: NoSensorViewDelegate?

    private lazy var container = UIView(color: .clear)

    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.ruuviTextColor
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "dashboard_no_sensors_message".localized()
        label.font = UIFont.Muli(.semiBoldItalic, size: UIDevice.isiPhoneSE() ? 16 : 20)
        return label
    }()

    private lazy var addSensorButton: UIButton = {
        let button = UIButton(color: RuuviColor.ruuviTintColor,
                              cornerRadius: UIDevice.isiPhoneSE() ? 20 : 25)
        button.setTitle("+ " + "add_your_first_sensor".localized(),
                        for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.Muli(.bold,
                                              size: UIDevice.isiPhoneSE() ? 12 : 16)
        button.addTarget(self,
                         action: #selector(handleAddSensorTap),
                         for: .touchUpInside)
        return button
    }()

    private lazy var buySensorButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(RuuviColor.ruuviTextColor, for: .normal)
        button.setTitle("DiscoverTable.GetMoreSensors.button.title".localized(),
                        for: .normal)
        button.titleLabel?.font = UIFont.Muli(.bold,
                                              size: UIDevice.isiPhoneSE() ? 10 : 14)
        button.addTarget(self,
                         action: #selector(handleBuySensorTap),
                         for: .touchUpInside)
        button.underline()
        return button
    }()
}

extension NoSensorView {
    @objc private func handleAddSensorTap() {
        delegate?.didTapAddSensorButton(sender: self)
    }

    @objc private func handleBuySensorTap() {
        delegate?.didTapBuySensorButton(sender: self)
    }
}

extension NoSensorView {
    private func setUpUI() {
        addSubview(container)
        container.fillSuperview()

        container.addSubview(addSensorButton)
        addSensorButton.constrainHeight(constant: UIDevice.isiPhoneSE() ? 40 : 50)
        if UIDevice.isiPhoneSE() {
            addSensorButton.centerYInSuperview()
            addSensorButton.anchor(top: nil,
                                   leading: container.leadingAnchor,
                                   bottom: nil,
                                   trailing: container.trailingAnchor,
                                   padding: .init(top: 0, left: 8, bottom: 0, right: 8))
        } else {
            addSensorButton.centerInSuperview()
            addSensorButton.widthAnchor.constraint(
                greaterThanOrEqualToConstant: 300
            ).isActive = true
        }

        container.addSubview(messageLabel)
        messageLabel.anchor(top: nil,
                            leading: container.safeLeftAnchor,
                            bottom: addSensorButton.topAnchor,
                            trailing: container.safeRightAnchor,
                            padding: .init(top: 0, left: 30,
                                           bottom: 30, right: 30))

        container.addSubview(buySensorButton)
        buySensorButton.anchor(top: addSensorButton.bottomAnchor,
                               leading: container.safeLeftAnchor,
                               bottom: nil,
                               trailing: container.safeRightAnchor,
                               padding: .init(top: 24, left: 30,
                                              bottom: 0, right: 30))
    }
}
