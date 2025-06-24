// swiftlint:disable file_length

import UIKit
import Combine
import RuuviOntology
import RuuviLocalization

// MARK: - Shared Layout Configuration
struct DashboardImageCellLayout {
    // Inherit from regular cell layout
    static let topPadding = DashboardCellLayout.topPadding
    static let bottomPadding = DashboardCellLayout.bottomPadding
    static let leadingPadding = DashboardCellLayout.leadingPadding
    static let trailingPadding = DashboardCellLayout.trailingPadding
    static let nameToAlertSpacing = DashboardCellLayout.nameToAlertSpacing
    static let alertToMoreSpacing = DashboardCellLayout.alertToMoreSpacing
    static let alertIconSize = DashboardCellLayout.alertIconSize
    static let alertIconTopOffset = DashboardCellLayout.alertIconTopOffset
    static let moreIconPadding = DashboardCellLayout.moreIconPadding
    static let moreIconSize = DashboardCellLayout.moreIconSize
    static let gridRowHeight = DashboardCellLayout.gridRowHeight
    static let gridRowSpacing = DashboardCellLayout.gridRowSpacing
    static let gridToFooterSpacing = DashboardCellLayout.gridToFooterSpacing
    static let footerHeight = DashboardCellLayout.footerHeight
    static let footerTrailingPadding = DashboardCellLayout.footerTrailingPadding
    static let sourceIconToTextSpacing = DashboardCellLayout.sourceIconToTextSpacing
    static let sourceIconRegularWidth = DashboardCellLayout.sourceIconRegularWidth
    static let sourceIconCompactWidth = DashboardCellLayout.sourceIconCompactWidth
    static let nameFont = DashboardCellLayout.nameFont
    static let timestampFont = DashboardCellLayout.timestampFont
    static let maxNameLines = DashboardCellLayout.maxNameLines

    // Image cell specific properties
    static let imageWidthRatio: CGFloat = 0.25
    static let nameToImageSpacing: CGFloat = 14

    // Fixed 10px spacing between groups
    static let groupSpacing: CGFloat = 10
    static let prominentViewHeight: CGFloat = 36
    static let progressViewHeight: CGFloat = 5
    static let progressViewTopSpacing: CGFloat = 3

    // Derived calculations
    static var headerFixedWidth: CGFloat {
        return nameToAlertSpacing + alertIconSize.width + alertToMoreSpacing + moreIconSize
    }

    static func availableNameWidth(containerWidth: CGFloat) -> CGFloat {
        let imageWidth = containerWidth * imageWidthRatio
        let reservedWidth = imageWidth + nameToImageSpacing + headerFixedWidth
        return max(containerWidth - reservedWidth, 80)
    }

    static func gridHeight(indicatorCount: Int, hasAQI: Bool) -> CGFloat {
        // Filter out indicators shown prominently
        let gridIndicatorCount = hasAQI ?
            max(0, indicatorCount - 1) : // Remove AQI
            max(0, indicatorCount - 1)   // Remove Temperature

        guard gridIndicatorCount > 0 else { return 0 }

        let numberOfRows: Int
        if gridIndicatorCount < 3 {
            numberOfRows = gridIndicatorCount
        } else {
            numberOfRows = Int(ceil(Double(gridIndicatorCount) / 2.0))
        }

        let totalRowHeight = CGFloat(numberOfRows) * gridRowHeight
        let totalSpacing = CGFloat(max(0, numberOfRows - 1)) * gridRowSpacing
        return totalRowHeight + totalSpacing
    }
}

// swiftlint:disable:next type_body_length
class RuuviTagDashboardImageCell: UICollectionViewCell, TimestampUpdateable {

    // MARK: - UI Components
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = RuuviColor.dashboardCardBG.color
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
        return view
    }()

    private lazy var cardBackgroundView = CardsBackgroundView()

    private lazy var ruuviTagNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicatorBig.color
        label.textAlignment = .left
        label.numberOfLines = DashboardImageCellLayout.maxNameLines
        label.font = DashboardImageCellLayout.nameFont
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

    private lazy var alertButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(alertButtonTapped), for: .touchUpInside)
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
        iv.fillSuperview(padding: .init(top: 4, left: 8, bottom: 8, right: 8))
        return view
    }()

    private lazy var moreButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .clear
        button.showsMenuAsPrimaryAction = true
        return button
    }()

    // Container for prominent view (fixed height)
    private lazy var prominentGroupContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    private lazy var rowsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = DashboardImageCellLayout.gridRowSpacing
        stackView.distribution = .fillEqually
        return stackView
    }()

    private lazy var prominentView = DashboardIndicatorProminentView()

    // Indicator views
    private lazy var temperatureView = DashboardIndicatorView()
    private lazy var humidityView = DashboardIndicatorView()
    private lazy var pressureView = DashboardIndicatorView()
    private lazy var movementView = DashboardIndicatorView()
    private lazy var co2View = DashboardIndicatorView()
    private lazy var pm25View = DashboardIndicatorView()
    private lazy var pm10View = DashboardIndicatorView()
    private lazy var noxView = DashboardIndicatorView()
    private lazy var vocView = DashboardIndicatorView()
    private lazy var luminosityView = DashboardIndicatorView()
    private lazy var soundView = DashboardIndicatorView()

    private lazy var dataSourceIconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        iv.alpha = 0.7
        iv.tintColor = RuuviColor.dashboardIndicator.color.withAlphaComponent(0.8)
        return iv
    }()

    private lazy var updatedAtLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicator.color.withAlphaComponent(0.8)
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = DashboardImageCellLayout.timestampFont
        return label
    }()

    private lazy var batteryLevelView = BatteryLevelView()
    private lazy var noDataView = NoDataView()

    private lazy var progressViewContainer: UIView = {
        let container = UIView()
        container.backgroundColor = .clear
        container.layer.cornerRadius = 2.5
        container.clipsToBounds = true
        return container
    }()

    private lazy var progressView: UIProgressView = {
        let progressView = UIProgressView()
        progressView.progressViewStyle = .bar
        progressView.trackTintColor = RuuviColor.dashboardIndicator.color.withAlphaComponent(0.3)
        progressView.layer.cornerRadius = 0
        progressView.clipsToBounds = false
        return progressView
    }()

    private var dataSourceIconViewWidthConstraint: NSLayoutConstraint!
    private var gridTopConstraint: NSLayoutConstraint!

    // MARK: - Properties
    private var currentSnapshot: RuuviTagCardSnapshot?
    private var cancellables = Set<AnyCancellable>()
    weak var delegate: RuuviTagDashboardCellDelegate?
    private var currentIndicators: [DashboardIndicatorView] = []

    // MARK: - Lifecycle
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        TimestampUpdateService.shared.removeSubscriber(self)
        currentSnapshot = nil
        cancellables.removeAll()
        alertIcon.layer.removeAllAnimations()

        rowsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        currentIndicators.removeAll()
        prominentView.clearValues()

        [
            temperatureView,
            humidityView,
            pressureView,
            movementView,
            co2View,
            pm25View,
            pm10View,
            noxView,
            vocView,
            luminosityView,
            soundView,
        ].forEach {
            $0.clearValues()
        }

        noDataView.isHidden = true
        batteryLevelView.isHidden = true
        alertButton.isUserInteractionEnabled = false
        dataSourceIconViewWidthConstraint.constant = DashboardImageCellLayout.sourceIconCompactWidth
        progressViewContainer.isHidden = true
        gridTopConstraint?.isActive = false
    }

    deinit {
        TimestampUpdateService.shared.removeSubscriber(self)
    }

    // MARK: - Configuration
    func configure(with snapshot: RuuviTagCardSnapshot) {
        guard currentSnapshot != snapshot else { return }

        currentSnapshot = snapshot
        cancellables.removeAll()

        snapshot.$displayData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] displayData in
                self?.updateDisplayData(displayData)
            }
            .store(in: &cancellables)

        snapshot.$alertData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] alertData in
                self?.updateAlertData(alertData)
            }
            .store(in: &cancellables)

        snapshot.$lastUpdated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateTimestampLabel()
            }
            .store(in: &cancellables)

        TimestampUpdateService.shared.addSubscriber(self)

        updateDisplayData(snapshot.displayData)
        updateAlertData(snapshot.alertData)
        updateTimestampLabel()
        setNeedsLayout()
        layoutIfNeeded()
    }

    func setMenu(_ menu: UIMenu) {
        moreButton.menu = menu
    }

    func updateTimestampLabel() {
        guard let snapshot = currentSnapshot else { return }

        if let date = snapshot.lastUpdated {
            updatedAtLabel.text = date.ruuviAgo()
        } else {
            updatedAtLabel.text = RuuviLocalization.Cards.UpdatedLabel.NoData.message
        }
    }

    func restartAlertAnimationIfNeeded() {
        guard let snapshot = currentSnapshot else { return }
        updateAlertData(snapshot.alertData)
    }

    // MARK: - Private Update Methods
    private func updateDisplayData(_ displayData: RuuviTagCardSnapshotDisplayData) {
        ruuviTagNameLabel.text = displayData.name
        updateBackgroundImage(from: displayData)
        buildIndicatorGrid(with: displayData.indicatorGrid)
        updateSourceIcon(for: displayData.source)
        batteryLevelView.isHidden = !displayData.batteryNeedsReplacement
        noDataView.isHidden = !displayData.hasNoData
    }

    private func updateAlertData(_ alertData: RuuviTagCardSnapshotAlertData) {
        updateAlertIcon(for: alertData.alertState)
        updateIndicatorAlerts()
    }

    private func updateBackgroundImage(from displayData: RuuviTagCardSnapshotDisplayData) {
        cardBackgroundView.contentMode = .scaleAspectFit
        cardBackgroundView.setBackgroundImage(with: displayData.background, withAnimation: true)
    }

    // MARK: - Indicator Grid Building
    private func buildIndicatorGrid(with configuration: RuuviTagCardSnapshotIndicatorGridConfiguration?) {
        guard let configuration = configuration else {
            rowsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            currentIndicators.removeAll()
            prominentView.clearValues()
            progressViewContainer.isHidden = true
            updateGridPosition(hasAQI: false)
            noDataView.isHidden = false
            return
        }

        updateProminentView(with: configuration)
        let indicators = createIndicatorViews(from: configuration.indicators)

        guard !indicatorsEqual(currentIndicators, indicators) else {
            updateIndicatorValues(configuration.indicators)
            return
        }

        currentIndicators = indicators
        buildGrid(with: indicators)
        updateIndicatorValues(configuration.indicators)
    }

    private func updateProminentView(with configuration: RuuviTagCardSnapshotIndicatorGridConfiguration) {
        let hasAQI = configuration.indicators.contains { $0.type == .aqi }

        if hasAQI {
            // E0/F0 version - show Air Quality Index as prominent
            if let airQualityIndicator = configuration.indicators.first(where: { $0.type == .aqi }) {
                let components = airQualityIndicator.value.components(separatedBy: "/")
                let mainValue = components.first ?? airQualityIndicator.value
                let superscriptValue = components.count > 1 ? "/\(components[1])" : ""

                prominentView.setValue(
                    with: mainValue,
                    superscriptValue: superscriptValue,
                    subscriptValue: airQualityIndicator.unit
                )

                // Show progress view
                progressViewContainer.isHidden = false
                if let progress = mainValue.intValue {
                    progressView.progress = Float(progress) / 100
                    progressView.progressTintColor =
                        airQualityIndicator.isHighlighted ?
                            RuuviColor.orangeColor.color : airQualityIndicator.tintColor
                }
            }
        } else {
            // V5 version - show Temperature as prominent
            if let temperatureIndicator = configuration.indicators.first(where: { $0.type == .temperature }) {
                let tempComponents = temperatureIndicator.value.components(separatedBy: String.nbsp)
                let tempValue = tempComponents.first ?? temperatureIndicator.value

                prominentView.setValue(
                    with: tempValue,
                    superscriptValue: temperatureIndicator.unit,
                    subscriptValue: temperatureIndicator.showSubscript ?
                        RuuviLocalization.TagSettings.OffsetCorrection.temperature : ""
                )
            }
            // Hide progress view
            progressViewContainer.isHidden = true
        }

        // Update grid position based on progress view visibility
        updateGridPosition(hasAQI: hasAQI)
    }

    private func updateGridPosition(hasAQI: Bool) {
        gridTopConstraint?.isActive = false

        if hasAQI && !progressViewContainer.isHidden {
            // Grid positioned 10px from progress view
            gridTopConstraint = rowsStackView.topAnchor.constraint(
                equalTo: progressViewContainer.bottomAnchor,
                constant: DashboardImageCellLayout.groupSpacing
            )
        } else {
            // Grid positioned 10px from prominent view
            gridTopConstraint = rowsStackView.topAnchor.constraint(
                equalTo: prominentGroupContainer.bottomAnchor,
                constant: DashboardImageCellLayout.groupSpacing
            )
        }
        gridTopConstraint.isActive = true
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func createIndicatorViews(
        from indicatorData: [RuuviTagCardSnapshotIndicatorData]
    ) -> [DashboardIndicatorView] {
        var indicators: [DashboardIndicatorView] = []
        let hasAdvancedSensors = indicatorData.contains { $0.type == .aqi }

        for data in indicatorData {
            // Skip indicators that are shown prominently
            if hasAdvancedSensors && data.type == .aqi { continue }
            if !hasAdvancedSensors && data.type == .temperature { continue }

            switch data.type {
            case .temperature: indicators.append(temperatureView)
            case .humidity: indicators.append(humidityView)
            case .pressure: indicators.append(pressureView)
            case .movementCounter: indicators.append(movementView)
            case .co2: indicators.append(co2View)
            case .pm25: indicators.append(pm25View)
            case .pm10: indicators.append(pm10View)
            case .nox: indicators.append(noxView)
            case .voc: indicators.append(vocView)
            case .luminosity: indicators.append(luminosityView)
            case .sound: indicators.append(soundView)
            default: break
            }
        }

        return indicators
    }

    private func updateIndicatorValues(_ indicatorData: [RuuviTagCardSnapshotIndicatorData]) {
        for data in indicatorData {
            let indicatorView = getIndicatorView(for: data.type)
            indicatorView?.setValue(with: data.value, unit: data.unit)
        }
    }

    private func updateIndicatorAlerts() {
        guard let snapshot = currentSnapshot else { return }

        snapshot.displayData.indicatorGrid?.indicators.forEach { indicatorData in
            if indicatorData.type == .temperature {
                let hasAdvancedSensors = snapshot.displayData.indicatorGrid?.indicators.contains {
                    $0.type == .aqi
                } ?? false

                if hasAdvancedSensors {
                    temperatureView.changeColor(highlight: indicatorData.isHighlighted)
                } else {
                    prominentView.changeColor(highlight: indicatorData.isHighlighted)
                }
            } else {
                let indicatorView = getIndicatorView(for: indicatorData.type)
                indicatorView?.changeColor(highlight: indicatorData.isHighlighted)
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func getIndicatorView(for type: MeasurementType) -> DashboardIndicatorView? {
        switch type {
        case .temperature: return temperatureView
        case .humidity: return humidityView
        case .pressure: return pressureView
        case .movementCounter: return movementView
        case .co2: return co2View
        case .pm25: return pm25View
        case .pm10: return pm10View
        case .nox: return noxView
        case .voc: return vocView
        case .luminosity: return luminosityView
        case .sound: return soundView
        default: return nil
        }
    }

    private func indicatorsEqual(
        _ lhs: [DashboardIndicatorView],
        _ rhs: [DashboardIndicatorView]
    ) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { $0 === $1 }
    }

    private func buildGrid(with indicators: [DashboardIndicatorView]) {
        rowsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        rowsStackView.axis = .vertical
        rowsStackView.spacing = DashboardImageCellLayout.gridRowSpacing
        rowsStackView.distribution = .fill

        if indicators.count < 3 {
            for indicator in indicators {
                indicator.constrainHeight(constant: DashboardImageCellLayout.gridRowHeight)
                rowsStackView.addArrangedSubview(indicator)
            }
        } else {
            var index = 0
            while index < indicators.count {
                let rowStackView = UIStackView()
                rowStackView.axis = .horizontal
                rowStackView.spacing = 0
                rowStackView.distribution = .fillEqually
                rowStackView.constrainHeight(constant: DashboardImageCellLayout.gridRowHeight)

                rowStackView.addArrangedSubview(indicators[index])
                index += 1

                if index < indicators.count {
                    rowStackView.addArrangedSubview(indicators[index])
                    index += 1
                } else {
                    let emptyView = UIView()
                    rowStackView.addArrangedSubview(emptyView)
                }

                rowsStackView.addArrangedSubview(rowStackView)
            }
        }
    }

    private func updateSourceIcon(for source: RuuviTagSensorRecordSource?) {
        guard let source = source else {
            dataSourceIconView.image = nil
            return
        }

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

        switch source {
        case .ruuviNetwork:
            dataSourceIconViewWidthConstraint.constant = DashboardImageCellLayout.sourceIconRegularWidth
        default:
            dataSourceIconViewWidthConstraint.constant = DashboardImageCellLayout.sourceIconCompactWidth
        }

        dataSourceIconView.image = dataSourceIconView.image?.withRenderingMode(.alwaysTemplate)
    }

    private func updateAlertIcon(for alertState: AlertState?) {
        alertIcon.layer.removeAllAnimations()

        guard let alertState = alertState else {
            alertIcon.alpha = 0
            alertIcon.image = nil
            alertButton.isUserInteractionEnabled = false
            return
        }

        switch alertState {
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
            startAlertAnimation()
        }
    }

    private func startAlertAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIView.animate(
                withDuration: 0.5,
                delay: 0,
                options: [.repeat, .autoreverse, .beginFromCurrentState],
                animations: { [weak self] in
                    self?.alertIcon.alpha = 0.0
                }
            )
        }
    }

    private func removeAlertAnimations(alpha: Double = 1) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.alertIcon.layer.removeAllAnimations()
            self?.alertIcon.alpha = alpha
        }
    }

    @objc private func alertButtonTapped() {
        guard let snapshot = currentSnapshot else { return }
        delegate?.didTapAlertButton(for: snapshot)
    }
}

// MARK: - UI Setup
extension RuuviTagDashboardImageCell {

    // swiftlint:disable:next function_body_length
    private func setupUI() {
        contentView.addSubview(containerView)
        containerView.fillSuperview()

        // Background image (25% width, full height)
        containerView.addSubview(cardBackgroundView)
        cardBackgroundView.anchor(
            top: containerView.topAnchor,
            leading: containerView.leadingAnchor,
            bottom: containerView.bottomAnchor,
            trailing: nil
        )
        cardBackgroundView.widthAnchor.constraint(
            equalTo: containerView.widthAnchor,
            multiplier: DashboardImageCellLayout.imageWidthRatio
        ).isActive = true

        // Header Section - More and Alert icons (don't change their positioning)
        containerView.addSubview(moreIconView)
        moreIconView.anchor(
            top: containerView.topAnchor,
            leading: nil,
            bottom: nil,
            trailing: containerView.trailingAnchor,
            padding: .init(
                top: DashboardImageCellLayout.moreIconPadding,
                left: 0,
                bottom: 0,
                right: 0
            ),
            size: .init(
                width: DashboardImageCellLayout.moreIconSize,
                height: DashboardImageCellLayout.moreIconSize
            )
        )

        containerView.addSubview(moreButton)
        moreButton.match(view: moreIconView)

        containerView.addSubview(alertIcon)
        alertIcon.anchor(
            top: containerView.topAnchor,
            leading: nil,
            bottom: nil,
            trailing: moreIconView.leadingAnchor,
            padding: .init(
                top: DashboardImageCellLayout.topPadding + DashboardImageCellLayout.alertIconTopOffset,
                left: 0,
                bottom: 0,
                right: DashboardImageCellLayout.alertToMoreSpacing
            ),
            size: DashboardImageCellLayout.alertIconSize
        )

        containerView.addSubview(alertButton)
        alertButton.match(view: alertIcon)

        // Group 1: Name with 10px top padding
        containerView.addSubview(ruuviTagNameLabel)
        ruuviTagNameLabel.anchor(
            top: containerView.topAnchor,
            leading: cardBackgroundView.trailingAnchor,
            bottom: nil,
            trailing: alertIcon.leadingAnchor,
            padding: .init(
                top: DashboardImageCellLayout.groupSpacing, // 10px top padding
                left: DashboardImageCellLayout.nameToImageSpacing,
                bottom: 0,
                right: DashboardImageCellLayout.nameToAlertSpacing
            )
        )

        // Group 2: Prominent view container
        containerView.addSubview(prominentGroupContainer)
        prominentGroupContainer.anchor(
            top: ruuviTagNameLabel.bottomAnchor,
            leading: ruuviTagNameLabel.leadingAnchor,
            bottom: nil,
            trailing: containerView.trailingAnchor,
            padding: .init(
                top: DashboardImageCellLayout.groupSpacing, // 10px from name
                left: 0,
                bottom: 0,
                right: DashboardImageCellLayout.trailingPadding
            )
        )
        prominentGroupContainer.constrainHeight(constant: DashboardImageCellLayout.prominentViewHeight)

        // Prominent view fills the container
        prominentGroupContainer.addSubview(prominentView)
        prominentView.fillSuperview()

        // Progress view positioned separately OUTSIDE the container
        containerView.addSubview(progressViewContainer)
        progressViewContainer.anchor(
            top: prominentGroupContainer.bottomAnchor,
            leading: prominentGroupContainer.leadingAnchor,
            bottom: nil,
            trailing: nil,
            padding: .init(top: DashboardImageCellLayout.progressViewTopSpacing, left: 0, bottom: 0, right: 0),
            size: .init(width: 120, height: DashboardImageCellLayout.progressViewHeight)
        )

        progressViewContainer.addSubview(progressView)
        progressView.fillSuperview()
        progressViewContainer.isHidden = true

        // Group 3: Grid Section - positioned dynamically
        containerView.addSubview(rowsStackView)
        rowsStackView.anchor(
            top: nil, // Will be set dynamically
            leading: ruuviTagNameLabel.leadingAnchor,
            bottom: nil,
            trailing: containerView.trailingAnchor,
            padding: .init(
                top: 0, // Will be set dynamically
                left: 0,
                bottom: 0,
                right: DashboardImageCellLayout.trailingPadding
            )
        )

        // Initial grid position (will be updated based on progress view visibility)
        gridTopConstraint = rowsStackView.topAnchor.constraint(
            equalTo: prominentGroupContainer.bottomAnchor,
            constant: DashboardImageCellLayout.groupSpacing
        )
        gridTopConstraint.isActive = true

        // Group 4: Footer Section - 10px from grid, 10px bottom padding
        let sourceAndUpdateStack = UIStackView(arrangedSubviews: [dataSourceIconView, updatedAtLabel])
        sourceAndUpdateStack.axis = .horizontal
        sourceAndUpdateStack.spacing = DashboardImageCellLayout.sourceIconToTextSpacing
        sourceAndUpdateStack.distribution = .fill

        dataSourceIconViewWidthConstraint = dataSourceIconView.widthAnchor
            .constraint(lessThanOrEqualToConstant: DashboardImageCellLayout.sourceIconRegularWidth)
        dataSourceIconViewWidthConstraint.isActive = true

        let footerStack = UIStackView(
            arrangedSubviews: [
                sourceAndUpdateStack,
                UIView.flexibleSpacer(),
                batteryLevelView,
            ]
        )
        footerStack.spacing = 4
        footerStack.axis = .horizontal
        footerStack.distribution = .fillProportionally

        containerView.addSubview(footerStack)
        footerStack.anchor(
            top: rowsStackView.bottomAnchor,
            leading: ruuviTagNameLabel.leadingAnchor,
            bottom: containerView.bottomAnchor,
            trailing: containerView.trailingAnchor,
            padding: .init(
                top: DashboardImageCellLayout.gridToFooterSpacing, // 10px from grid
                left: 0,
                bottom: DashboardImageCellLayout.bottomPadding, // 10px bottom padding
                right: DashboardImageCellLayout.footerTrailingPadding
            )
        )

        footerStack.constrainHeight(constant: DashboardImageCellLayout.footerHeight)
        batteryLevelView.isHidden = true

        // No data view
        containerView.insertSubview(noDataView, belowSubview: moreIconView)
        noDataView.anchor(
            top: prominentGroupContainer.bottomAnchor,
            leading: cardBackgroundView.trailingAnchor,
            bottom: footerStack.topAnchor,
            trailing: containerView.trailingAnchor,
            padding: .init(
                top: DashboardImageCellLayout.groupSpacing,
                left: DashboardImageCellLayout.nameToImageSpacing,
                bottom: DashboardImageCellLayout.groupSpacing,
                right: DashboardImageCellLayout.trailingPadding
            )
        )
        noDataView.isHidden = true
    }
}

// MARK: - Height Calculator
extension RuuviTagDashboardImageCell {
    static func calculateHeight(
        for snapshot: RuuviTagCardSnapshot,
        width: CGFloat,
        numberOfColumns: Int = 2
    ) -> CGFloat {
        let nameHeight = calculateNameLabelHeight(
            text: snapshot.displayData.name,
            containerWidth: width
        )
        let hasAQI = snapshot.displayData.indicatorGrid?.indicators.contains { $0.type == .aqi } ?? false
        let prominentHeight = DashboardImageCellLayout.prominentViewHeight
        let progressHeight = hasAQI ? (
            DashboardImageCellLayout.progressViewTopSpacing +
            DashboardImageCellLayout.progressViewHeight
        ) : 0
        let indicatorCount = snapshot.displayData.indicatorGrid?.indicators.count ?? 0
        let gridHeight = DashboardImageCellLayout.gridHeight(indicatorCount: indicatorCount, hasAQI: hasAQI)

        // Calculate total height with consistent 10px spacing between all groups
        let totalHeight = DashboardImageCellLayout.groupSpacing + // Top padding
                         nameHeight +
                         DashboardImageCellLayout.groupSpacing + // Name to prominent
                         prominentHeight +
                         progressHeight + // Progress view space (0 when not visible)
                         DashboardImageCellLayout.groupSpacing + // To grid (always 10px from last element)
                         gridHeight +
                         DashboardImageCellLayout.groupSpacing + // Grid to footer
                         DashboardImageCellLayout.footerHeight +
                         DashboardImageCellLayout.groupSpacing   // Bottom padding

        return ceil(totalHeight)
    }

    private static func calculateNameLabelHeight(
        text: String,
        containerWidth: CGFloat
    ) -> CGFloat {
        let availableWidth = DashboardImageCellLayout.availableNameWidth(
            containerWidth: containerWidth
        )
        let maxSize = CGSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude)

        let textRect = (text as NSString).boundingRect(
            with: maxSize,
            options: [.usesLineFragmentOrigin],
            attributes: [.font: DashboardImageCellLayout.nameFont],
            context: nil
        )

        let calculatedHeight = ceil(textRect.height)
        let singleLineHeight = ceil(DashboardImageCellLayout.nameFont.lineHeight)
        let maxHeight =
        singleLineHeight * CGFloat(DashboardImageCellLayout.maxNameLines)

        return max(min(calculatedHeight, maxHeight), singleLineHeight)
    }
}
// swiftlint:enable file_length
