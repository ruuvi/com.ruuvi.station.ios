// swiftlint:disable file_length
import UIKit
import RuuviService
import RuuviLocal
import RuuviOntology

class DashboardPlainCell: UICollectionViewCell {

    private lazy var ruuviTagNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicatorBigTextColor
        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = UIFont.Montserrat(.bold, size: 14)
        return label
    }()

    private lazy var alertIcon: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        iv.tintColor = RuuviColor.dashboardIndicatorBigTextColor
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

    private lazy var moreIcon: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        iv.image = RuuviAssets.threeDotMoreImage
        iv.tintColor = RuuviColor.dashboardIndicatorBigTextColor
        return iv
    }()

    /// This is used as a touch target only, and we will keep it accessible from
    /// other class to be able to set it's actions.
    lazy var moreButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .clear
        button.showsMenuAsPrimaryAction = true
        return button
    }()

    private lazy var temperatureView = DashboardIndicatorView()
    private lazy var humidityView = DashboardIndicatorView()
    private lazy var pressureView = DashboardIndicatorView()
    private lazy var movementView = DashboardIndicatorView()

    private lazy var dataSourceIconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        iv.alpha = 0.7
        iv.tintColor = RuuviColor
            .dashboardIndicatorTextColor?
            .withAlphaComponent(0.8)
        return iv
    }()

    private lazy var updatedAtLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor
            .dashboardIndicatorTextColor?
            .withAlphaComponent(0.8)
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.Muli(.regular, size: 10)
        return label
    }()

    private lazy var batteryLevelView = BatteryLevelView()

    private var temperatureViewHeight: NSLayoutConstraint!
    private var humidityViewHeight: NSLayoutConstraint!
    private var pressureViewHeight: NSLayoutConstraint!
    private var emptyViewHeight: NSLayoutConstraint!
    private var movementViewHeight: NSLayoutConstraint!

    private var timer: Timer?
    private var viewModel: CardsViewModel?
    weak var delegate: DashboardCellDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // swiftlint:disable:next function_body_length
    fileprivate func setUpUI() {
        let container = UIView(color: RuuviColor.dashboardCardBGColor,
                               cornerRadius: 8)
        contentView.addSubview(container)
        container.fillSuperview()

        container.addSubview(ruuviTagNameLabel)
        ruuviTagNameLabel.anchor(top: container.topAnchor,
                                 leading: container.leadingAnchor,
                                 bottom: nil,
                                 trailing: nil,
                                 padding: .init(top: 8, left: 8,
                                                bottom: 0, right: 0))
        ruuviTagNameLabel.heightAnchor.constraint(
            greaterThanOrEqualToConstant: 14
        ).isActive = true

        container.addSubview(alertIcon)
        alertIcon.anchor(top: ruuviTagNameLabel.topAnchor,
                         leading: ruuviTagNameLabel.trailingAnchor,
                         bottom: nil,
                         trailing: nil,
                         padding: .init(top: 4, left: 12, bottom: 0, right: 0),
                         size: .init(width: 18, height: 18))

        container.addSubview(alertButton)
        alertButton.match(view: alertIcon)

        container.addSubview(moreIcon)
        moreIcon.anchor(top: alertIcon.topAnchor,
                        leading: alertIcon.trailingAnchor,
                        bottom: nil,
                        trailing: container.trailingAnchor,
                        padding: .init(top: 0, left: 10, bottom: 0, right: 14),
                        size: .init(width: 18, height: 18))

        container.addSubview(moreButton)
        moreButton.match(view: moreIcon)

        let leftContainerView = UIView()
        container.addSubview(leftContainerView)
        leftContainerView.anchor(top: nil,
                                 leading: ruuviTagNameLabel.leadingAnchor,
                                 bottom: nil,
                                 trailing: nil)
        leftContainerView
            .topAnchor
            .constraint(
                greaterThanOrEqualTo: ruuviTagNameLabel.bottomAnchor,
                        constant: 4)
            .isActive = true

        let emptySpacer = UIView()
        emptySpacer.backgroundColor = .clear
        leftContainerView.addSubview(emptySpacer)
        emptySpacer.anchor(top: leftContainerView.topAnchor,
                           leading: leftContainerView.leadingAnchor,
                           bottom: nil,
                           trailing: leftContainerView.trailingAnchor)
        emptyViewHeight = emptySpacer.heightAnchor.constraint(equalToConstant: 0)
        emptyViewHeight.isActive = true

        leftContainerView.addSubview(temperatureView)
        temperatureView.anchor(top: emptySpacer.bottomAnchor,
                            leading: leftContainerView.leadingAnchor,
                            bottom: nil,
                            trailing: leftContainerView.trailingAnchor)
        temperatureViewHeight = temperatureView
            .heightAnchor
            .constraint(equalToConstant: indicatorViewHeight())
        temperatureViewHeight.isActive = true

        leftContainerView.addSubview(humidityView)
        humidityView.anchor(top: temperatureView.bottomAnchor,
                            leading: leftContainerView.leadingAnchor,
                            bottom: leftContainerView.bottomAnchor,
                            trailing: leftContainerView.trailingAnchor)
        humidityViewHeight = humidityView.heightAnchor.constraint(equalToConstant: indicatorViewHeight())
        humidityViewHeight.isActive = true

        let rightContainerView = UIView()
        container.addSubview(rightContainerView)
        rightContainerView.anchor(top: nil,
                                  leading: leftContainerView.trailingAnchor,
                                  bottom: leftContainerView.bottomAnchor,
                                  trailing: container.trailingAnchor,
                                  padding: .init(top: 0,
                                                 left: 4,
                                                 bottom: 0,
                                                 right: 4))

        rightContainerView.addSubview(pressureView)
        pressureView.anchor(top: rightContainerView.topAnchor,
                            leading: rightContainerView.leadingAnchor,
                            bottom: nil,
                            trailing: rightContainerView.trailingAnchor)
        pressureViewHeight = pressureView.heightAnchor.constraint(equalToConstant: indicatorViewHeight())
        pressureViewHeight.isActive = true

        rightContainerView.addSubview(movementView)
        movementView.anchor(top: pressureView.bottomAnchor,
                            leading: rightContainerView.leadingAnchor,
                            bottom: rightContainerView.bottomAnchor,
                            trailing: rightContainerView.trailingAnchor)
        movementViewHeight = movementView.heightAnchor.constraint(equalToConstant: indicatorViewHeight())
        movementViewHeight.isActive = true

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
        dataSourceIconView.size(width: 22, height: 22)

        let footerStack = UIStackView(arrangedSubviews: [
            sourceAndUpdateStack, batteryLevelView
        ])
        footerStack.spacing = 4
        footerStack.axis = .horizontal
        footerStack.distribution = .fillEqually

        container.addSubview(footerStack)
        footerStack.anchor(top: leftContainerView.bottomAnchor,
                          leading: ruuviTagNameLabel.leadingAnchor,
                          bottom: container.bottomAnchor,
                          trailing: container.trailingAnchor,
                          padding: .init(top: 4,
                                         left: 0,
                                         bottom: 6,
                                         right: 12))
        batteryLevelView.isHidden = true
    }
}

extension DashboardPlainCell {
    override func prepareForReuse() {
        super.prepareForReuse()
        viewModel = nil
        ruuviTagNameLabel.text = nil
        temperatureView.clearValues()
        humidityView.clearValues()
        pressureView.clearValues()
        movementView.clearValues()
        updatedAtLabel.text = nil
        batteryLevelView.isHidden = true
        timer?.invalidate()
        alertIcon.image = nil
        alertIcon.layer.removeAllAnimations()
        alertButton.isUserInteractionEnabled = false
    }
}

extension DashboardPlainCell {

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func configure(with viewModel: CardsViewModel,
                   measurementService: RuuviServiceMeasurement?) {

        self.viewModel = viewModel

        // Name
        ruuviTagNameLabel.text = viewModel.name.value

        // Temp
        if let temp = measurementService?.stringWithoutSign(for: viewModel.temperature.value),
           let temperatureUnit = measurementService?.units.temperatureUnit {
            temperatureView.setValue(with: temp, unit: temperatureUnit.symbol)
        } else {
            temperatureView.setValue(with: "N/A".localized())
        }

        // Humidity
        if let humidity = viewModel.humidity.value,
            let measurementService = measurementService {
            hideHumidityView(hide: false)
            let humidityValue = measurementService.stringWithoutSign(
                for: humidity,
                temperature: viewModel.temperature.value
            )
            let humidityUnit = measurementService.units.humidityUnit
            let humidityUnitSymbol = humidityUnit.symbol
            let temperatureUnitSymbol = measurementService.units.temperatureUnit.symbol
            let unit =  humidityUnit == .dew ? temperatureUnitSymbol
                : humidityUnitSymbol
            humidityView.setValue(with: humidityValue,
                                  unit: unit)
        } else {
            hideHumidityView(hide: true)
        }

        // Pressure
        if let pressure = viewModel.pressure.value {
            hidePressureView(hide: false)
            let pressureValue = measurementService?.stringWithoutSign(for: pressure)
            pressureView.setValue(with: pressureValue,
                                  unit: measurementService?.units.pressureUnit.symbol)
        } else {
            hidePressureView(hide: true)
        }

        // Movement
        switch viewModel.type {
        case .ruuvi:
            if let movement = viewModel.movementCounter.value {
                hideMovementView(hide: false)
                movementView.setValue(with: "\(movement)",
                                      unit: "Cards.Movements.title".localized())
            } else {
                hideMovementView(hide: true)
            }
        case .web:
            let location = viewModel.location
            if let location = location.value {
                movementView.setValue(with: location.city ?? location.country)
            } else if let currentLocation = viewModel.currentLocation.value {
                movementView.setValue(with: currentLocation.description)
            } else {
                movementView.setValue(with: "N/A".localized())
            }
        }

        // Ago
        if let date = viewModel.date.value?.ruuviAgo() {
            updatedAtLabel.text = date
        } else {
            updatedAtLabel.text = "Cards.UpdatedLabel.NoData.message".localized()
        }

        startTimer(with: viewModel.date.value)

        // Source
        if let source = viewModel.source.value {
            switch source {
            case .unknown:
                dataSourceIconView.image = nil
            case .advertisement:
                dataSourceIconView.image = RuuviAssets.advertisementImage
            case .heartbeat:
                dataSourceIconView.image = RuuviAssets.heartbeatImage
            case .log:
                dataSourceIconView.image = RuuviAssets.heartbeatImage
            case .ruuviNetwork:
                dataSourceIconView.image = RuuviAssets.ruuviNetworkImage
            case .weatherProvider:
                dataSourceIconView.image = RuuviAssets.weatherProviderImage
            }
        } else {
            dataSourceIconView.image = nil
        }
        dataSourceIconView.image = dataSourceIconView
            .image?
            .withRenderingMode(.alwaysTemplate)

        // Battery stat
        if let batteryLow = viewModel.batteryNeedsReplacement.value,
           batteryLow {
            batteryLevelView.isHidden = false
        } else {
            batteryLevelView.isHidden = true
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func restartAlertAnimation(for viewModel: CardsViewModel) {

        // Alert
        let alertVisible = viewModel.isCloud.value ?? false ||
            viewModel.isConnected.value ?? false

        let mutedTills = [
            viewModel.temperatureAlertMutedTill.value,
            viewModel.relativeHumidityAlertMutedTill.value,
            viewModel.pressureAlertMutedTill.value,
            viewModel.signalAlertMutedTill.value,
            viewModel.movementAlertMutedTill.value,
            viewModel.connectionAlertMutedTill.value
        ]

        if mutedTills.first(where: { $0 != nil }) != nil || !alertVisible {
            alertIcon.image = nil
            alertButton.isUserInteractionEnabled = false
            removeAlertAnimations(alpha: 0)
            return
        }

        if let isOn = viewModel.isTemperatureAlertOn.value, isOn,
           let temperatureAlertState = viewModel.temperatureAlertState.value {
            temperatureView.changeColor(highlight: temperatureAlertState == .firing)
        } else {
            temperatureView.changeColor(highlight: false)
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
                if alertIcon.image != RuuviAssets.alertOnImage {
                    alertIcon.alpha = 1
                    alertIcon.image = RuuviAssets.alertOnImage
                    removeAlertAnimations()
                }
                alertIcon.tintColor = RuuviColor.logoTintColor
            case .firing:
                alertButton.isUserInteractionEnabled = true
                alertIcon.alpha = 1.0
                alertIcon.tintColor = RuuviColor.ruuviOrangeColor
                if alertIcon.image != RuuviAssets.alertActiveImage {
                    alertIcon.image = RuuviAssets.alertActiveImage
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                    UIView.animate(withDuration: 0.5,
                                   delay: 0,
                                   options: [.repeat,
                                             .autoreverse,
                                             .beginFromCurrentState],
                                   animations: { [weak self] in
                        self?.alertIcon.alpha = 0.0
                    })
                })
            }
        } else {
            alertIcon.image = nil
            alertButton.isUserInteractionEnabled = false
            removeAlertAnimations(alpha: 0)
        }
    }

    func removeAlertAnimations(alpha: Double = 1) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1,
                                      execute: { [weak self] in
            self?.alertIcon.layer.removeAllAnimations()
            self?.alertIcon.alpha = alpha
        })
    }
}

extension DashboardPlainCell {
    private func startTimer(with date: Date?) {
        timer?.invalidate()
        timer = nil

        timer = Timer.scheduledTimer(withTimeInterval: 1,
                                     repeats: true,
                                     block: { [weak self] (_) in
            if let date = date?.ruuviAgo() {
                self?.updatedAtLabel.text = date
            } else {
                self?.updatedAtLabel.text = date?.ruuviAgo() ?? "Cards.UpdatedLabel.NoData.message".localized()
            }
        })
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
        return GlobalHelpers.isDeviceTablet() ? 24 : 18
    }

    @objc private func alertButtonDidTap() {
        guard let viewModel = viewModel else {
            return
        }
        delegate?.didTapAlertButton(for: viewModel)
    }
}
