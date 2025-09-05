import RuuviLocal
import RuuviLocalization
import RuuviOntology
import RuuviService
import UIKit

class LegacyCardsLargeImageCell: UICollectionViewCell {
    private lazy var temperatureLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 1
        label.font = UIFont.oswald(.bold, size: 76)
        return label
    }()

    private lazy var temperatureUnitLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = UIFont.oswald(.regular, size: 40)
        return label
    }()

    private lazy var humidityView = LegacyCardsIndicatorView(icon: RuuviAsset.iconMeasureHumidity.image)
    private lazy var pressureView = LegacyCardsIndicatorView(icon: RuuviAsset.iconMeasurePressure.image)
    private lazy var movementView = LegacyCardsIndicatorView(icon: RuuviAsset.iconMeasureMovement.image)

    private lazy var batteryLevelView = BatteryLevelView()

    private lazy var updatedAtLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white.withAlphaComponent(0.8)
        label.textAlignment = .right
        label.numberOfLines = 0
        label.font = UIFont.mulish(.regular, size: 10)
        return label
    }()

    private lazy var dataSourceIconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        iv.alpha = 0.7
        iv.tintColor = .white.withAlphaComponent(0.8)
        return iv
    }()

    private var humidityViewHeight: NSLayoutConstraint!
    private var pressureViewHeight: NSLayoutConstraint!
    private var movementViewHeight: NSLayoutConstraint!
    private var batteryLevelViewHeight: NSLayoutConstraint!

    private var viewModel: LegacyCardsViewModel?
    private var isSyncing: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
        TimestampUpdateService.shared.addSubscriber(self)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // swiftlint:disable:next function_body_length
    fileprivate func setUpUI() {
        let container = UIView()
        container.backgroundColor = .clear
        contentView.addSubview(container)
        container.fillSuperview()

        container.addSubview(temperatureLabel)
        temperatureLabel.anchor(
            top: container.topAnchor,
            leading: nil,
            bottom: nil,
            trailing: nil,
            padding: .init(
                top: 52,
                left: 0,
                bottom: 0,
                right: 0
            )
        )
        temperatureLabel.centerXInSuperview()

        container.addSubview(temperatureUnitLabel)
        temperatureUnitLabel.anchor(
            top: temperatureLabel.topAnchor,
            leading: temperatureLabel.trailingAnchor,
            bottom: nil,
            trailing: nil,
            padding: .init(
                top: 22,
                left: 0,
                bottom: 0,
                right: 0
            ),
            size: .init(width: 0, height: 44)
        )

        container.addSubview(humidityView)
        humidityView.anchor(
            top: nil,
            leading: container.leadingAnchor,
            bottom: nil,
            trailing: container.trailingAnchor,
            padding: .init(
                top: 0,
                left: 16,
                bottom: 0,
                right: 16
            )
        )
        humidityViewHeight = humidityView.heightAnchor.constraint(equalToConstant: 66)
        humidityViewHeight.isActive = true

        container.addSubview(pressureView)
        pressureView.anchor(
            top: humidityView.bottomAnchor,
            leading: container.leadingAnchor,
            bottom: nil,
            trailing: container.trailingAnchor,
            padding: .init(
                top: 0,
                left: 16,
                bottom: 0,
                right: 16
            )
        )
        pressureViewHeight = pressureView.heightAnchor.constraint(equalToConstant: 66)
        pressureViewHeight.isActive = true

        container.addSubview(movementView)
        movementView.anchor(
            top: pressureView.bottomAnchor,
            leading: container.leadingAnchor,
            bottom: nil,
            trailing: container.trailingAnchor,
            padding: .init(
                top: 0,
                left: 16,
                bottom: 0,
                right: 16
            )
        )
        movementViewHeight = movementView.heightAnchor.constraint(equalToConstant: 66)
        movementViewHeight.isActive = true

        container.addSubview(batteryLevelView)
        batteryLevelView.anchor(
            top: movementView.bottomAnchor,
            leading: nil,
            bottom: nil,
            trailing: container.trailingAnchor,
            padding: .init(
                top: 8,
                left: 0,
                bottom: 0,
                right: 12
            )
        )
        batteryLevelView.updateTextColor(with: .white.withAlphaComponent(0.8))
        batteryLevelViewHeight = batteryLevelView.heightAnchor.constraint(equalToConstant: 0)
        batteryLevelViewHeight.isActive = true
        batteryLevelView.isHidden = true

        let footerView = UIView(color: .clear)
        container.addSubview(footerView)
        footerView.anchor(
            top: batteryLevelView.bottomAnchor,
            leading: container.leadingAnchor,
            bottom: container.bottomAnchor,
            trailing: container.trailingAnchor,
            padding: .init(
                top: 4,
                left: 16,
                bottom: 0,
                right: 12
            ),
            size: .init(width: 0, height: 24)
        )

        footerView.addSubview(updatedAtLabel)
        updatedAtLabel.anchor(
            top: footerView.topAnchor,
            leading: nil,
            bottom: footerView.bottomAnchor,
            trailing: nil,
            padding: .init(
                top: 0,
                left: 12,
                bottom: 0,
                right: 0
            )
        )

        footerView.addSubview(dataSourceIconView)
        // TODO: - Use larger icon size for iPads
        dataSourceIconView.anchor(
            top: nil,
            leading: updatedAtLabel.trailingAnchor,
            bottom: nil,
            trailing: footerView.trailingAnchor,
            padding: .init(
                top: 0,
                left: 6,
                bottom: 0,
                right: 0
            ),
            size: .init(width: 16, height: 16)
        )
        dataSourceIconView.centerYInSuperview()
    }
}

extension LegacyCardsLargeImageCell {
    override func prepareForReuse() {
        super.prepareForReuse()
        temperatureLabel.text = nil
        temperatureUnitLabel.text = nil
        humidityView.clearValues()
        pressureView.clearValues()
        movementView.clearValues()
        updatedAtLabel.text = nil
        dataSourceIconView.image = nil
        batteryLevelView.isHidden = true
        batteryLevelViewHeight.constant = 0
        TimestampUpdateService.shared.removeSubscriber(self)
    }
}

extension LegacyCardsLargeImageCell {
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func configure(
        with viewModel: LegacyCardsViewModel,
        measurementService: RuuviServiceMeasurement?
    ) {
        self.viewModel = viewModel

        // Temp
        if let temp = measurementService?.stringWithoutSign(for: viewModel.temperature) {
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
        if let humidity = viewModel.humidity,
           let measurementService {
            hideHumidityView(hide: false)
            let humidityValue = measurementService.stringWithoutSign(
                for: humidity,
                temperature: viewModel.temperature
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
        if let pressure = viewModel.pressure {
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
            if let movement = viewModel.movementCounter {
                hideMovementView(hide: false)
                movementView.setValue(
                    with: "\(movement)",
                    unit: RuuviLocalization.movements
                )
            } else {
                hideMovementView(hide: true)
            }
        }

        // Ago
        updateTimestampLabel()

        // Source
        if let source = viewModel.source {
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

        // Battery stat
        if let batteryLow = viewModel.batteryNeedsReplacement,
           batteryLow {
            batteryLevelView.isHidden = false
            batteryLevelViewHeight.constant = 24
        } else {
            batteryLevelView.isHidden = true
            batteryLevelViewHeight.constant = 0
        }
    }
}

extension LegacyCardsLargeImageCell: TimestampUpdateable {
    func updateTimestampLabel() {
        if let ago = viewModel?.date?.ruuviAgo() {
            updatedAtLabel.text = ago
        } else {
            updatedAtLabel.text = RuuviLocalization.Cards.UpdatedLabel.NoData.message
        }
    }
}

extension LegacyCardsLargeImageCell {

    private func hideHumidityView(hide: Bool) {
        if hide {
            humidityView.isHidden = true
            humidityViewHeight.constant = 0
        } else {
            humidityView.isHidden = false
            humidityViewHeight.constant = 66
        }
    }

    private func hidePressureView(hide: Bool) {
        if hide {
            pressureView.isHidden = true
            pressureViewHeight.constant = 0
        } else {
            pressureView.isHidden = false
            pressureViewHeight.constant = 66
        }
    }

    private func hideMovementView(hide: Bool) {
        if hide {
            movementView.isHidden = true
            movementViewHeight.constant = 0
        } else {
            movementView.isHidden = false
            movementViewHeight.constant = 66
        }
    }
}
