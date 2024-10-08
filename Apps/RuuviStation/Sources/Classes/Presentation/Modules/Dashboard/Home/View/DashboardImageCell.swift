import RuuviLocal
import RuuviLocalization
import RuuviOntology
import RuuviService

import UIKit

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
class DashboardImageCell: DashboardCell {
    private lazy var cardBackgroundView = CardsBackgroundView()

    private lazy var ruuviTagNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicatorBig.color
        label.textAlignment = .left
        label.numberOfLines = 2
        label.font = UIFont.Montserrat(.bold, size: 14)
        return label
    }()

    private lazy var alertIcon: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        iv.tintColor = RuuviColor.dashboardIndicatorBig.color
        iv.alpha = 0
        return iv
    }()

    /// This is used as a touch target only, and we will keep it accessible from
    /// other class to be able to set it's actions.
    lazy var alertButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(alertButtonDidTap), for: .touchUpInside)
        return button
    }()

    private lazy var moreIconView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear

        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        iv.image = RuuviAsset.more3dot.image
        iv.tintColor = RuuviColor.dashboardIndicatorBig.color
        view.addSubview(iv)
        iv.fillSuperview(padding: .init(top: 12, left: 0, bottom: 2, right: 4))
        return view
    }()

    /// This is used as a touch target only, and we will keep it accessible from
    /// other class to be able to set it's actions.
    private lazy var moreButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .clear
        button.showsMenuAsPrimaryAction = true
        return button
    }()

    private lazy var temperatureLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicatorBig.color
        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = UIFont.Oswald(.bold, size: 30)
        return label
    }()

    private lazy var temperatureUnitLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicatorBig.color
        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = UIFont.Oswald(.regular, size: 16)
        return label
    }()

    private lazy var humidityView = DashboardIndicatorView()
    private lazy var pressureView = DashboardIndicatorView()
    private lazy var movementView = DashboardIndicatorView()

    private lazy var dataSourceIconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        iv.alpha = 0.7
        iv.tintColor = RuuviColor
            .dashboardIndicator.color
            .withAlphaComponent(0.8)
        return iv
    }()

    private lazy var updatedAtLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor
            .dashboardIndicator.color
            .withAlphaComponent(0.8)
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.Muli(.regular, size: 10)
        return label
    }()

    private lazy var batteryLevelView = BatteryLevelView()
    private lazy var noDataView = NoDataView()

    private var humidityViewHeight: NSLayoutConstraint!
    private var pressureViewHeight: NSLayoutConstraint!
    private var emptyViewHeight: NSLayoutConstraint!
    private var movementViewHeight: NSLayoutConstraint!

    private var dataSourceIconViewWidthConstraint: NSLayoutConstraint!
    private let dataSourceIconViewRegularWidth: CGFloat = 22
    private let dataSourceIconViewCompactWidth: CGFloat = 16

    private var timer: Timer?

    private var viewModel: CardsViewModel?
    weak var delegate: DashboardCellDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    override func configure(
        with viewModel: CardsViewModel,
        measurementService: RuuviServiceMeasurement?
    ) {
        self.viewModel = viewModel

        cardBackgroundView
            .setBackgroundImage(
                with: viewModel.background.value,
                withAnimation: false
            )

        // Name
        ruuviTagNameLabel.text = viewModel.name.value

        // Temp
        if let temp = measurementService?.stringWithoutSign(for: viewModel.temperature.value) {
            temperatureLabel.text = temp.components(separatedBy: String.nbsp).first
        } else {
            temperatureLabel.text = RuuviLocalization.na
        }

        if let temperatureUnit = measurementService?.units.temperatureUnit {
            temperatureUnitLabel.text = temperatureUnit.symbol
        } else {
            temperatureUnitLabel.text = RuuviLocalization.na
        }

        // Humidity
        if let humidity = viewModel.humidity.value,
           let measurementService {
            hideHumidityView(hide: false)
            let humidityValue = measurementService.stringWithoutSign(
                for: humidity,
                temperature: viewModel.temperature.value
            )
            let humidityUnit = measurementService.units.humidityUnit
            let humidityUnitSymbol = humidityUnit.symbol
            let temperatureUnitSymbol = measurementService.units.temperatureUnit.symbol
            let unit = humidityUnit == .dew ? temperatureUnitSymbol
                : humidityUnitSymbol
            humidityView.setValue(
                with: humidityValue,
                unit: unit
            )
        } else {
            hideHumidityView(hide: true)
        }

        // Pressure
        if let pressure = viewModel.pressure.value {
            hidePressureView(hide: false)
            let pressureValue = measurementService?.stringWithoutSign(for: pressure)
            pressureView.setValue(
                with: pressureValue,
                unit: measurementService?.units.pressureUnit.symbol
            )
        } else {
            hidePressureView(hide: true)
        }

        // Movement
        switch viewModel.type {
        case .ruuvi:
            if let movement = viewModel.movementCounter.value {
                hideMovementView(hide: false)
                movementView.setValue(
                    with: "\(movement)",
                    unit: RuuviLocalization.Cards.Movements.title
                )
            } else {
                hideMovementView(hide: true)
            }
        }

        // Ago
        if let date = viewModel.date.value?.ruuviAgo() {
            updatedAtLabel.text = date
            noDataView.isHidden = true
        } else {
            updatedAtLabel.text = RuuviLocalization.Cards.UpdatedLabel.NoData.message
            noDataView.isHidden = false
        }
        startTimer(with: viewModel.date.value)

        // Source
        if let source = viewModel.source.value {
            switch source {
            case .unknown:
                dataSourceIconView.image = nil
            case .advertisement, .bgAdvertisement:
                dataSourceIconView.image = RuuviAsset.iconBluetooth.image
            case .heartbeat, .log:
                dataSourceIconView.image = RuuviAsset.iconBluetoothConnected.image
            case .ruuviNetwork:
                dataSourceIconView.image = RuuviAsset.iconGateway.image
            }
        } else {
            dataSourceIconView.image = nil
        }

        switch viewModel.source.value {
        case .ruuviNetwork:
            dataSourceIconViewWidthConstraint.constant = dataSourceIconViewRegularWidth
        default:
            dataSourceIconViewWidthConstraint.constant = dataSourceIconViewCompactWidth
        }

        dataSourceIconView.image = dataSourceIconView
            .image?
            .withRenderingMode(.alwaysTemplate)

        // Battery state
        if let batteryLow = viewModel.batteryNeedsReplacement.value,
           batteryLow {
            batteryLevelView.isHidden = false
        } else {
            batteryLevelView.isHidden = true
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    override func restartAlertAnimation(for viewModel: CardsViewModel) {
        // Alert
        let alertVisible = viewModel.isCloud.value ?? false ||
            viewModel.isConnected.value ?? false ||
            viewModel.serviceUUID.value != nil

        let mutedTills = [
            viewModel.temperatureAlertMutedTill.value,
            viewModel.relativeHumidityAlertMutedTill.value,
            viewModel.pressureAlertMutedTill.value,
            viewModel.signalAlertMutedTill.value,
            viewModel.movementAlertMutedTill.value,
            viewModel.connectionAlertMutedTill.value,
        ]

        if mutedTills.first(where: { $0 != nil }) != nil || !alertVisible {
            alertIcon.image = nil
            alertButton.isUserInteractionEnabled = false
            removeAlertAnimations(alpha: 0)
            return
        }

        if let isOn = viewModel.isTemperatureAlertOn.value, isOn,
           let temperatureAlertState = viewModel.temperatureAlertState.value {
            highlightTemperatureValues(highlight: temperatureAlertState == .firing)
        } else {
            highlightTemperatureValues(highlight: false)
        }

        if let isOn = viewModel.isRelativeHumidityAlertOn.value, isOn,
           let rhAlertState = viewModel.relativeHumidityAlertState.value {
            humidityView.changeColor(highlight: rhAlertState == .firing)
        } else {
            humidityView.changeColor(highlight: false)
        }

        if let isOn = viewModel.isPressureAlertOn.value, isOn,
           let pressureAlertState = viewModel.pressureAlertState.value {
            pressureView.changeColor(highlight: pressureAlertState == .firing)
        } else {
            pressureView.changeColor(highlight: false)
        }

        if let isOn = viewModel.isMovementAlertOn.value, isOn,
           let movementAlertState = viewModel.movementAlertState.value {
            movementView.changeColor(highlight: movementAlertState == .firing)
        } else {
            movementView.changeColor(highlight: false)
        }

        if let state = viewModel.alertState.value {
            switch state {
            case .empty:
                if alertIcon.image != nil {
                    alertIcon.alpha = 0
                    alertIcon.image = nil
                    removeAlertAnimations(alpha: 0)
                }
                alertButton.isUserInteractionEnabled = false
            case .registered:
                alertButton.isUserInteractionEnabled = true
                if alertIcon.image != RuuviAsset.iconAlertOn.image {
                    alertIcon.alpha = 1
                    alertIcon.image = RuuviAsset.iconAlertOn.image
                    removeAlertAnimations()
                }
                alertIcon.tintColor = RuuviColor.logoTintColor.color
            case .firing:
                alertButton.isUserInteractionEnabled = true
                alertIcon.alpha = 1.0
                alertIcon.tintColor = RuuviColor.orangeColor.color
                if alertIcon.image != RuuviAsset.iconAlertActive.image {
                    alertIcon.image = RuuviAsset.iconAlertActive.image
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    UIView.animate(
                        withDuration: 0.5,
                        delay: 0,
                        options: [
                            .repeat,
                            .autoreverse,
                        ],
                        animations: { [weak self] in
                            self?.alertIcon.alpha = 0.0
                        }
                    )
                }
            }
        } else {
            alertIcon.image = nil
            alertButton.isUserInteractionEnabled = false
            removeAlertAnimations(alpha: 0)
        }
    }

    override func removeAlertAnimations(alpha: Double = 1) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.alertIcon.layer.removeAllAnimations()
            self?.alertIcon.alpha = alpha
        }
    }

    override func resetMenu(menu: UIMenu) {
        moreButton.menu = menu
    }
}

extension DashboardImageCell {
    override func prepareForReuse() {
        super.prepareForReuse()
        viewModel = nil
        ruuviTagNameLabel.text = nil
        temperatureLabel.text = nil
        temperatureUnitLabel.text = nil
        humidityView.clearValues()
        pressureView.clearValues()
        movementView.clearValues()
        updatedAtLabel.text = nil
        batteryLevelView.isHidden = true
        timer?.invalidate()
        alertIcon.image = nil
        alertIcon.layer.removeAllAnimations()
        highlightTemperatureValues(highlight: false)
        dataSourceIconViewWidthConstraint.constant = dataSourceIconViewCompactWidth
        noDataView.isHidden = true
    }
}

extension DashboardImageCell {
    // swiftlint:disable:next function_body_length
    fileprivate func setUpUI() {
        let container = UIView(
            color: RuuviColor.dashboardCardBG.color,
            cornerRadius: 8
        )
        contentView.addSubview(container)
        container.fillSuperview()

        container.addSubview(cardBackgroundView)
        cardBackgroundView.anchor(
            top: container.topAnchor,
            leading: container.leadingAnchor,
            bottom: container.bottomAnchor,
            trailing: nil
        )
        cardBackgroundView.widthAnchor.constraint(
            equalTo: container.widthAnchor,
            multiplier: 0.25
        ).isActive = true

        container.addSubview(ruuviTagNameLabel)
        ruuviTagNameLabel.anchor(
            top: container.topAnchor,
            leading: cardBackgroundView.trailingAnchor,
            bottom: nil,
            trailing: nil,
            padding: .init(top: 8, left: 8, bottom: 0, right: 0)
        )
        ruuviTagNameLabel.heightAnchor.constraint(
            greaterThanOrEqualToConstant: 14
        ).isActive = true

        container.addSubview(temperatureLabel)
        temperatureLabel.anchor(
            top: ruuviTagNameLabel.bottomAnchor,
            leading: ruuviTagNameLabel.leadingAnchor,
            bottom: nil,
            trailing: nil,
            padding: .init(top: -4, left: 0, bottom: 0, right: 0)
        )

        container.addSubview(temperatureUnitLabel)
        temperatureUnitLabel.anchor(
            top: temperatureLabel.topAnchor,
            leading: temperatureLabel.trailingAnchor,
            bottom: nil,
            trailing: nil,
            padding: .init(
                top: 6,
                left: 2,
                bottom: 0,
                right: 0
            )
        )

        let leftContainerView = UIView()
        container.addSubview(leftContainerView)
        leftContainerView.anchor(
            top: nil,
            leading: ruuviTagNameLabel.leadingAnchor,
            bottom: nil,
            trailing: nil,
            padding: .init(
                top: 4,
                left: 0,
                bottom: 0,
                right: 0
            )
        )

        leftContainerView.addSubview(humidityView)
        humidityView.anchor(
            top: leftContainerView.topAnchor,
            leading: leftContainerView.leadingAnchor,
            bottom: nil,
            trailing: leftContainerView.trailingAnchor
        )
        humidityViewHeight = humidityView.heightAnchor.constraint(equalToConstant: indicatorViewHeight())
        humidityViewHeight.isActive = true

        leftContainerView.addSubview(movementView)
        movementView.anchor(
            top: humidityView.bottomAnchor,
            leading: leftContainerView.leadingAnchor,
            bottom: leftContainerView.bottomAnchor,
            trailing: leftContainerView.trailingAnchor
        )
        movementViewHeight = movementView.heightAnchor.constraint(equalToConstant: indicatorViewHeight())
        movementViewHeight.isActive = true

        let rightContainerView = UIView()
        container.addSubview(rightContainerView)
        rightContainerView.anchor(
            top: nil,
            leading: leftContainerView.trailingAnchor,
            bottom: leftContainerView.bottomAnchor,
            trailing: container.trailingAnchor,
            padding: .init(
                top: 0,
                left: 4,
                bottom: 0,
                right: 4
            )
        )

        rightContainerView.addSubview(pressureView)
        pressureView.anchor(
            top: rightContainerView.topAnchor,
            leading: rightContainerView.leadingAnchor,
            bottom: nil,
            trailing: rightContainerView.trailingAnchor
        )
        pressureViewHeight = pressureView.heightAnchor.constraint(equalToConstant: indicatorViewHeight())
        pressureViewHeight.isActive = true

        let emptySpacer = UIView()
        emptySpacer.backgroundColor = .clear
        rightContainerView.addSubview(emptySpacer)
        emptySpacer.anchor(
            top: pressureView.bottomAnchor,
            leading: rightContainerView.leadingAnchor,
            bottom: rightContainerView.bottomAnchor,
            trailing: rightContainerView.trailingAnchor
        )
        emptyViewHeight = emptySpacer.heightAnchor.constraint(equalToConstant: indicatorViewHeight())
        emptyViewHeight.isActive = true

        leftContainerView
            .widthAnchor
            .constraint(equalTo: rightContainerView.widthAnchor)
            .isActive = true

        let sourceAndUpdateStack = UIStackView(arrangedSubviews: [
            dataSourceIconView, updatedAtLabel
        ])
        sourceAndUpdateStack.axis = .horizontal
        sourceAndUpdateStack.spacing = 6
        sourceAndUpdateStack.distribution = .fill
        dataSourceIconView.constrainHeight(constant: 22)

        dataSourceIconViewWidthConstraint = dataSourceIconView.widthAnchor
            .constraint(lessThanOrEqualToConstant: dataSourceIconViewRegularWidth)
        dataSourceIconViewWidthConstraint.isActive = true

        let footerStack = UIStackView(arrangedSubviews: [
            sourceAndUpdateStack, batteryLevelView
        ])
        footerStack.spacing = 4
        footerStack.axis = .horizontal
        footerStack.distribution = .fillProportionally

        container.addSubview(footerStack)
        footerStack.anchor(
            top: leftContainerView.bottomAnchor,
            leading: ruuviTagNameLabel.leadingAnchor,
            bottom: container.bottomAnchor,
            trailing: container.trailingAnchor,
            padding: .init(
                top: 4,
                left: 0,
                bottom: 6,
                right: 12
            )
        )
        batteryLevelView.isHidden = true

        container.addSubview(alertIcon)
        alertIcon.anchor(
            top: ruuviTagNameLabel.topAnchor,
            leading: ruuviTagNameLabel.trailingAnchor,
            bottom: nil,
            trailing: nil,
            padding: .init(top: 4, left: 12, bottom: 0, right: 0),
            size: .init(width: 24, height: 18)
        )

        container.addSubview(alertButton)
        alertButton.match(view: alertIcon)

        container.addSubview(moreIconView)
        moreIconView.anchor(
            top: container.topAnchor,
            leading: alertIcon.trailingAnchor,
            bottom: nil,
            trailing: container.trailingAnchor,
            size: .init(width: 36, height: 32)
        )

        container.addSubview(moreButton)
        moreButton.match(view: moreIconView)

        // No data view
        container.insertSubview(noDataView, belowSubview: moreIconView)
        noDataView.anchor(
          top: ruuviTagNameLabel.bottomAnchor,
          leading: cardBackgroundView.trailingAnchor,
          bottom: container.bottomAnchor,
          trailing: container.trailingAnchor
        )
        noDataView.isHidden = true
    }
}

extension DashboardImageCell {
    private func startTimer(with date: Date?) {
        timer?.invalidate()
        timer = nil

        timer = Timer.scheduledTimer(
            withTimeInterval: 1,
            repeats: true,
            block: { [weak self] _ in
                if let date = date?.ruuviAgo() {
                    self?.updatedAtLabel.text = date
                } else {
                    self?.updatedAtLabel.text = date?.ruuviAgo() ?? RuuviLocalization.Cards.UpdatedLabel.NoData.message
                }
            }
        )
    }

    private func hideHumidityView(hide: Bool) {
        if hide {
            humidityView.isHidden = true
            humidityViewHeight.constant = 0
        } else {
            humidityView.isHidden = false
            humidityViewHeight.constant = indicatorViewHeight()
        }
    }

    private func hidePressureView(hide: Bool) {
        if hide {
            pressureView.isHidden = true
            pressureViewHeight.constant = 0
        } else {
            pressureView.isHidden = false
            pressureViewHeight.constant = indicatorViewHeight()
        }
    }

    private func hideMovementView(hide: Bool) {
        if hide {
            movementView.isHidden = true
            movementViewHeight.constant = 0
        } else {
            movementView.isHidden = false
            movementViewHeight.constant = indicatorViewHeight()
        }
    }

    private func indicatorViewHeight() -> CGFloat {
        GlobalHelpers.isDeviceTablet() ? 24 : 18
    }

    @objc private func alertButtonDidTap() {
        guard let viewModel
        else {
            return
        }
        delegate?.didTapAlertButton(for: viewModel)
    }

    private func highlightTemperatureValues(highlight: Bool) {
        temperatureLabel.textColor =
        highlight ? RuuviColor.orangeColor.color : RuuviColor.dashboardIndicatorBig.color
        temperatureUnitLabel.textColor =
        highlight ? RuuviColor.orangeColor.color : RuuviColor.dashboardIndicatorBig.color
    }
}
