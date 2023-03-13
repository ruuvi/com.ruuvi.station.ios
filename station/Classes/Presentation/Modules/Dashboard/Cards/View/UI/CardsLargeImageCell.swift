// swiftlint:disable file_length
import UIKit
import RuuviService
import RuuviLocal
import RuuviOntology

class CardsLargeImageCell: UICollectionViewCell {

    private lazy var ruuviTagNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        let font = UIFont(name: "Montserrat-Bold", size: 20)
        label.font = font ?? UIFont.systemFont(ofSize: 16, weight: .bold)
        return label
    }()

    private lazy var temperatureLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 1
        let font = UIFont(name: "Oswald-Bold", size: 76)
        label.font = font ?? UIFont.systemFont(ofSize: 66, weight: .bold)
        return label
    }()

    private lazy var temperatureUnitLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .left
        label.numberOfLines = 1
        let font = UIFont(name: "Oswald-ExtraLight", size: 40)
        label.font = font ?? UIFont.systemFont(ofSize: 30, weight: .ultraLight)
        return label
    }()

    private lazy var humidityView = CardsIndicatorView(icon: RuuviAssets.humidityImage)
    private lazy var pressureView = CardsIndicatorView(icon: RuuviAssets.pressureImage)
    private lazy var movementView = CardsIndicatorView(icon: RuuviAssets.movementCounterImage)

    private lazy var batteryLevelView = BatteryLevelView()

    private lazy var syncStateLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white.withAlphaComponent(0.8)
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        return label
    }()

    private lazy var updatedAtLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white.withAlphaComponent(0.8)
        label.textAlignment = .right
        label.numberOfLines = 0
        label.font = UIFont.Muli(.regular, size: 14)
        return label
    }()

    private lazy var dataSourceIconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        iv.alpha = 0.7
        return iv
    }()

    private var humidityViewHeight: NSLayoutConstraint!
    private var pressureViewHeight: NSLayoutConstraint!
    private var movementViewHeight: NSLayoutConstraint!
    private var batteryLevelViewHeight: NSLayoutConstraint!

    private var timer: Timer?
    private var notificationToken: NSObjectProtocol?
    private var isSyncing: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // swiftlint:disable:next function_body_length
    fileprivate func setUpUI() {
        let container = UIView()
        container.backgroundColor = .clear
        contentView.addSubview(container)
        container.fillSuperview()

        container.addSubview(ruuviTagNameLabel)
        ruuviTagNameLabel.anchor(top: container.topAnchor,
                                 leading: container.leadingAnchor,
                                 bottom: nil,
                                 trailing: container.trailingAnchor,
                                 padding: .init(top: 14, left: 12, bottom: 0, right: 12))

        container.addSubview(temperatureLabel)
        temperatureLabel.anchor(top: ruuviTagNameLabel.bottomAnchor,
                                leading: nil,
                                bottom: nil,
                                trailing: nil,
                                padding: .init(top: 52,
                                               left: 0,
                                               bottom: 0,
                                               right: 0))
        temperatureLabel.centerXInSuperview()

        container.addSubview(temperatureUnitLabel)
        temperatureUnitLabel.anchor(top: temperatureLabel.topAnchor,
                                    leading: temperatureLabel.trailingAnchor,
                                    bottom: nil,
                                    trailing: nil,
                                    padding: .init(top: 22,
                                                   left: 0,
                                                   bottom: 0,
                                                   right: 0),
                                    size: .init(width: 0, height: 44))

        container.addSubview(humidityView)
        humidityView.anchor(top: nil,
                            leading: container.leadingAnchor,
                            bottom: nil,
                            trailing: container.trailingAnchor,
                            padding: .init(top: 0,
                                           left: 16,
                                           bottom: 0,
                                           right: 16))
        humidityViewHeight = humidityView.heightAnchor.constraint(equalToConstant: 66)
        humidityViewHeight.isActive = true

        container.addSubview(pressureView)
        pressureView.anchor(top: humidityView.bottomAnchor,
                            leading: container.leadingAnchor,
                            bottom: nil,
                            trailing: container.trailingAnchor,
                            padding: .init(top: 0,
                                           left: 16,
                                           bottom: 0,
                                           right: 16))
        pressureViewHeight = pressureView.heightAnchor.constraint(equalToConstant: 66)
        pressureViewHeight.isActive = true

        container.addSubview(movementView)
        movementView.anchor(top: pressureView.bottomAnchor,
                            leading: container.leadingAnchor,
                            bottom: nil,
                            trailing: container.trailingAnchor,
                            padding: .init(top: 0,
                                           left: 16,
                                           bottom: 0,
                                           right: 16))
        movementViewHeight = movementView.heightAnchor.constraint(equalToConstant: 66)
        movementViewHeight.isActive = true

        container.addSubview(batteryLevelView)
        batteryLevelView.anchor(top: movementView.bottomAnchor,
                                leading: nil,
                                bottom: nil,
                                trailing: container.trailingAnchor,
                                padding: .init(top: 8,
                                               left: 0,
                                               bottom: 0,
                                               right: 12))
        batteryLevelView.updateTextColor(with: .white.withAlphaComponent(0.8))
        batteryLevelViewHeight = batteryLevelView.heightAnchor.constraint(equalToConstant: 0)
        batteryLevelViewHeight.isActive = true
        batteryLevelView.isHidden = true

        let footerView = UIView(color: .clear)
        container.addSubview(footerView)
        footerView.anchor(top: batteryLevelView.bottomAnchor,
                          leading: container.leadingAnchor,
                          bottom: container.bottomAnchor,
                          trailing: container.trailingAnchor,
                          padding: .init(top: 4,
                                         left: 16,
                                         bottom: 0,
                                         right: 12),
                          size: .init(width: 0, height: 24))

        footerView.addSubview(syncStateLabel)
        syncStateLabel.anchor(top: footerView.topAnchor,
                              leading: footerView.leadingAnchor,
                              bottom: footerView.bottomAnchor,
                              trailing: nil)

        footerView.addSubview(updatedAtLabel)
        updatedAtLabel.anchor(top: footerView.topAnchor,
                              leading: syncStateLabel.trailingAnchor,
                              bottom: footerView.bottomAnchor,
                              trailing: nil,
                              padding: .init(top: 0,
                                             left: 12,
                                             bottom: 0,
                                             right: 0))

        footerView.addSubview(dataSourceIconView)
        // TODO: - Use larger icon size for iPads
        dataSourceIconView.anchor(top: nil,
                                  leading: updatedAtLabel.trailingAnchor,
                                  bottom: nil,
                                  trailing: footerView.trailingAnchor,
                                  padding: .init(top: 0,
                                                 left: 6,
                                                 bottom: 0,
                                                 right: 0),
                                  size: .init(width: 20, height: 20))
        dataSourceIconView.centerYInSuperview()
    }
}

extension CardsLargeImageCell {
    override func prepareForReuse() {
        super.prepareForReuse()
        ruuviTagNameLabel.text = nil
        temperatureLabel.text = nil
        temperatureUnitLabel.text = nil
        humidityView.setValue(with: nil)
        pressureView.setValue(with: nil)
        movementView.setValue(with: nil)
        updatedAtLabel.text = nil
        dataSourceIconView.image = nil
        syncStateLabel.text = nil
        timer?.invalidate()
        notificationToken?.invalidate()
        batteryLevelView.isHidden = true
        batteryLevelViewHeight.constant = 0
    }
}

extension CardsLargeImageCell {

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func configure(with viewModel: CardsViewModel,
                   measurementService: RuuviServiceMeasurement?) {

        ruuviTagNameLabel.bind(viewModel.name) { (label, name) in
            label.text = name
        }

        // Temp
        temperatureLabel.bind(viewModel.temperature) { (label, temperature) in
            if let temp = measurementService?.stringWithoutSign(for: temperature) {
                label.text = temp.components(separatedBy: String.nbsp).first
            } else {
                label.text = "N/A".localized()
            }
        }

        temperatureUnitLabel.bind(viewModel.temperature) { (label, _) in
            if let temperatureUnit = measurementService?.units.temperatureUnit {
                label.text = temperatureUnit.symbol
            } else {
                label.text = "N/A".localized()
            }
        }

        // Humidity
        humidityView.bind(viewModel.humidity) { [weak self] (view, humidity) in
            if let humidity = humidity {
                self?.hideHumidityView(hide: false)
                let humidityValue = measurementService?.string(
                    for: humidity,
                    temperature: viewModel.temperature.value,
                    allowSettings: true
                )
                view.setValue(with: humidityValue)
            } else {
                self?.hideHumidityView(hide: true)
            }
        }

        // Pressure
        pressureView.bind(viewModel.pressure) { [weak self] (view, pressure) in
            if let pressure = pressure {
                self?.hidePressureView(hide: false)
                let pressureValue = measurementService?.string(
                    for: pressure,
                    allowSettings: true
                )
                view.setValue(with: pressureValue)
            } else {
                self?.hidePressureView(hide: true)
            }
        }

        // Movement
        switch viewModel.type {
        case .ruuvi:
            movementView.bind(viewModel.movementCounter) {
                [weak self] (view, movement) in
                if let movement = movement {
                    self?.hideMovementView(hide: false)
                    let movementValue = "\(movement) " + "Cards.Movements.title".localized()
                    view.setValue(with: movementValue)
                } else {
                    self?.hideMovementView(hide: true)
                }
                view.setIcon(with: RuuviAssets.movementCounterImage)
            }
        case .web:
            movementView.bind(viewModel.location) { (view, location) in
                if let location = location {
                    view.setValue(with: location.city ?? location.country)
                } else if let currentLocation = viewModel.currentLocation.value {
                    view.setValue(with: currentLocation.description)
                } else {
                    view.setValue(with: "N/A".localized())
                }
                view.setIcon(with: RuuviAssets.locationImage)
            }
        }

        // Ago
        updatedAtLabel.bind(viewModel.date) { [weak self] (label, date) in
            label.text = date?.ruuviAgo() ?? "Cards.UpdatedLabel.NoData.message".localized()
            self?.startTimer(with: date)
        }

        // Source
        dataSourceIconView.bind(viewModel.source) { (iv, source) in
            guard let source = source else {
                iv.image = nil
                return
            }
            switch source {
            case .unknown:
                iv.image = nil
            case .advertisement:
                iv.image = RuuviAssets.advertisementImage
            case .heartbeat, .log:
                iv.image = RuuviAssets.heartbeatImage
            case .ruuviNetwork:
                iv.image = RuuviAssets.ruuviNetworkImage
            case .weatherProvider:
                iv.image = RuuviAssets.weatherProviderImage
            }
        }

        // Battery stat
        batteryLevelView.bind(viewModel.batteryNeedsReplacement) {
            [weak self] (view, batteryLow) in
            if let batteryLow = batteryLow, batteryLow {
                view.isHidden = false
                self?.batteryLevelViewHeight.constant = 24
            } else {
                view.isHidden = true
                self?.batteryLevelViewHeight.constant = 0
            }
        }
    }

    func startObservingNetworkSyncNotification(for macId: AnyMACIdentifier) {
        notificationToken?.invalidate()
        notificationToken = nil

        notificationToken = NotificationCenter
            .default
            .addObserver(forName: .NetworkSyncDidChangeStatus,
                         object: nil,
                         queue: .main,
                         using: { [weak self] notification in
                guard let mac = notification.userInfo?[NetworkSyncStatusKey.mac] as? MACIdentifier,
                      let status = notification.userInfo?[NetworkSyncStatusKey.status] as? NetworkSyncStatus,
                      mac.any == macId else {
                    return
                }
                self?.updateSyncLabel(with: status)
            })
    }
}

extension CardsLargeImageCell {
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

    private func updateSyncLabel(with status: NetworkSyncStatus) {
        switch status {
        case .none:
            isSyncing = false
        case .syncing:
            isSyncing = true
            syncStateLabel.text = "TagCharts.Status.Serving".localized()
        case .complete:
            syncStateLabel.text = "Synchronized".localized()
            hideSyncStatusLabel()
        case .onError:
            syncStateLabel.text = "ErrorPresenterAlert.Error".localized()
            hideSyncStatusLabel()
        }
    }

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

    private func hideSyncStatusLabel() {
        UIView.animate(withDuration: 0, delay: 0.2, animations: { [weak self] in
            self?.syncStateLabel.text = nil
        })
    }
}
