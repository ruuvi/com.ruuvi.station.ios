// swiftlint:disable file_length

import UIKit
import Combine
import RuuviOntology
import RuuviLocalization

protocol RuuviTagDashboardCellDelegate: AnyObject {
    func didTapAlertButton(for snapshot: RuuviTagCardSnapshot)
}

// MARK: - Layout Configuration
struct DashboardCellLayout {
    // Card padding
    static let topPadding: CGFloat = 10
    static let bottomPadding: CGFloat = 8
    static let leadingPadding: CGFloat = 16
    static let trailingPadding: CGFloat = 12

    // Header section
    static let nameToAlertSpacing: CGFloat = 10
    static let alertToMoreSpacing: CGFloat = 0
    static let alertIconSize = CGSize(width: 24, height: 22)
    static let alertIconTopOffset: CGFloat = 3 // Additional offset for alert icon alignment
    static let moreIconPadding: CGFloat = 8
    static let moreIconSize: CGFloat = 36

    // Grid section
    static let headerToGridSpacing: CGFloat = 10
    static let gridRowHeight: CGFloat = 20
    static let gridRowSpacing: CGFloat = 2

    // Footer section
    static let gridToFooterSpacing: CGFloat = 10
    static let footerHeight: CGFloat = 24
    static let sourceIconToTextSpacing: CGFloat = 6
    static let sourceIconRegularWidth: CGFloat = 22
    static let sourceIconCompactWidth: CGFloat = 16

    // Font configuration
    static let nameFont = UIFont.Montserrat(.bold, size: 14)
    static let timestampFont = UIFont.Muli(.regular, size: 10)
    static let maxNameLines: Int = 2

    // Derived calculations
    static var headerFixedWidth: CGFloat {
        return nameToAlertSpacing + alertIconSize.width + alertToMoreSpacing + moreIconSize
    }

    static var totalVerticalSpacing: CGFloat {
        return topPadding + headerToGridSpacing + gridToFooterSpacing + bottomPadding
    }

    static func availableNameWidth(containerWidth: CGFloat) -> CGFloat {
        let reservedWidth = leadingPadding + headerFixedWidth
        return max(containerWidth - reservedWidth, 80) // Minimum 80pt width
    }

    static func gridHeight(indicatorCount: Int) -> CGFloat {
        guard indicatorCount > 0 else { return gridRowHeight }

        let numberOfRows: Int
        if indicatorCount < 3 {
            numberOfRows = indicatorCount
        } else {
            numberOfRows = Int(ceil(Double(indicatorCount) / 2.0))
        }

        let totalRowHeight = CGFloat(numberOfRows) * gridRowHeight
        let totalSpacing = CGFloat(max(0, numberOfRows - 1)) * gridRowSpacing
        return totalRowHeight + totalSpacing
    }
}

// swiftlint:disable:next type_body_length
class RuuviTagDashboardCell: UICollectionViewCell, TimestampUpdateable {

    // MARK: - UI Components
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = RuuviColor.dashboardCardBG.color
        view.layer.cornerRadius = 8
        return view
    }()

    private lazy var ruuviTagNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicatorBig.color
        label.textAlignment = .left
        label.numberOfLines = DashboardCellLayout.maxNameLines
        label.font = DashboardCellLayout.nameFont
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
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
        iv.anchor(
            top: view.topAnchor,
            leading: view.leadingAnchor,
            bottom: view.bottomAnchor,
            trailing: view.trailingAnchor,
            padding: .init(top: 2, left: 8, bottom: 8, right: 8)
        )
        return view
    }()

    private lazy var moreButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .clear
        button.showsMenuAsPrimaryAction = true
        return button
    }()

    // Stack view to hold grid rows (vertical)
    private lazy var rowsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = DashboardCellLayout.gridRowSpacing
        stackView.distribution = .fillEqually
        return stackView
    }()

    // Indicator views for all possible values
    private lazy var airQIndexView = DashboardIndicatorView()
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
        label.font = DashboardCellLayout.timestampFont
        return label
    }()

    private lazy var batteryLevelView = BatteryLevelView()
    private lazy var noDataView = NoDataView()

    private var dataSourceIconViewWidthConstraint: NSLayoutConstraint!

    // MARK: - Properties
    private var currentSnapshot: RuuviTagCardSnapshot?
    private var cancellables = Set<AnyCancellable>()
    weak var delegate: RuuviTagDashboardCellDelegate?

    // Keep track of current indicators for efficient updates
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
        currentSnapshot = nil
        cancellables.removeAll()
        alertIcon.layer.removeAllAnimations()

        // Clear and reset all indicator views
        rowsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        currentIndicators.removeAll()

        [
            airQIndexView, temperatureView, humidityView, pressureView,
            movementView, co2View, pm25View, pm10View, noxView,
            vocView, luminosityView, soundView,
        ].forEach {
            $0.clearValues()
        }

        noDataView.isHidden = true
        batteryLevelView.isHidden = true
        alertButton.isUserInteractionEnabled = false
        dataSourceIconViewWidthConstraint.constant = DashboardCellLayout.sourceIconCompactWidth
        TimestampUpdateService.shared.removeSubscriber(self)
    }

    deinit {
        TimestampUpdateService.shared.removeSubscriber(self)
    }

    // MARK: - Configuration
    func configure(with snapshot: RuuviTagCardSnapshot) {
        // Only update if the snapshot actually changed
        guard currentSnapshot != snapshot else { return }

        currentSnapshot = snapshot
        cancellables.removeAll()

        // Subscribe to data changes
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

        // Subscribe to timer updates
        TimestampUpdateService.shared.addSubscriber(self)

        // Initial update
        updateDisplayData(snapshot.displayData)
        updateAlertData(snapshot.alertData)
        updateTimestampLabel()
    }

    func setMenu(_ menu: UIMenu) {
        moreButton.menu = menu
    }

    // MARK: - Private Update Methods
    private func updateDisplayData(_ displayData: RuuviTagCardSnapshotDisplayData) {
        ruuviTagNameLabel.text = displayData.name

        // Build indicator grid efficiently - only rebuild if structure changed
        buildIndicatorGrid(with: displayData.indicatorGrid)

        // Update source icon
        updateSourceIcon(for: displayData.source)

        // Update battery and no data states
        batteryLevelView.isHidden = !displayData.batteryNeedsReplacement
        noDataView.isHidden = !displayData.hasNoData
    }

    private func updateAlertData(_ alertData: RuuviTagCardSnapshotAlertData) {
        updateAlertIcon(for: alertData.alertState)
        // Update individual indicator alerts
        updateIndicatorAlerts()
    }

    func updateTimestampLabel() {
        guard let snapshot = currentSnapshot else { return }

        if let date = snapshot.lastUpdated {
            updatedAtLabel.text = date.ruuviAgo()
        } else {
            updatedAtLabel.text = RuuviLocalization.Cards.UpdatedLabel.NoData.message
        }
    }

    // MARK: - Indicator Grid Building
    private func buildIndicatorGrid(with configuration: RuuviTagCardSnapshotIndicatorGridConfiguration?) {
        guard let configuration = configuration else {
            // Clear grid and show no data
            rowsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            currentIndicators.removeAll()
            noDataView.isHidden = false
            return
        }

        let indicators = createIndicatorViews(from: configuration.indicators)

        // Only rebuild if indicators changed
        guard !indicatorsEqual(currentIndicators, indicators) else {
            // Just update values without rebuilding layout
            updateIndicatorValues(configuration.indicators)
            return
        }

        currentIndicators = indicators
        buildGrid(with: indicators)
        updateIndicatorValues(configuration.indicators)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func createIndicatorViews(
        from indicatorData: [RuuviTagCardSnapshotIndicatorData]
    ) -> [DashboardIndicatorView] {
        var indicators: [DashboardIndicatorView] = []

        for data in indicatorData {
            switch data.type {
            case .aqi:
                indicators.append(airQIndexView)
            case .temperature:
                indicators.append(temperatureView)
            case .humidity:
                indicators.append(humidityView)
            case .pressure:
                indicators.append(pressureView)
            case .movementCounter:
                indicators.append(movementView)
            case .co2:
                indicators.append(co2View)
            case .pm25:
                indicators.append(pm25View)
            case .pm10:
                indicators.append(pm10View)
            case .nox:
                indicators.append(noxView)
            case .voc:
                indicators.append(vocView)
            case .luminosity:
                indicators.append(luminosityView)
            case .sound:
                indicators.append(soundView)
            default:
                break
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

        // Update each indicator's alert state
        snapshot.displayData.indicatorGrid?.indicators.forEach { indicatorData in
            let indicatorView = getIndicatorView(for: indicatorData.type)
            indicatorView?.changeColor(highlight: indicatorData.isHighlighted)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func getIndicatorView(for type: MeasurementType) -> DashboardIndicatorView? {
        switch type {
        case .aqi: return airQIndexView
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

    private func indicatorsEqual(_ lhs: [DashboardIndicatorView], _ rhs: [DashboardIndicatorView]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { $0 === $1 }
    }

    // Build grid with fixed row heights
    private func buildGrid(with indicators: [DashboardIndicatorView]) {
        // Clear existing arranged subviews
        rowsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Configure the rowsStackView
        rowsStackView.axis = .vertical
        rowsStackView.spacing = DashboardCellLayout.gridRowSpacing
        rowsStackView.distribution = .fill

        if indicators.count < 3 {
            // Less than 3 indicators: arrange vertically
            for indicator in indicators {
                // Set fixed height for each indicator
                indicator.constrainHeight(constant: DashboardCellLayout.gridRowHeight)
                rowsStackView.addArrangedSubview(indicator)
            }
        } else {
            // 3 or more indicators: arrange in rows of two
            var index = 0
            while index < indicators.count {
                // Create a horizontal stack view for each row
                let rowStackView = UIStackView()
                rowStackView.axis = .horizontal
                rowStackView.spacing = 0
                rowStackView.distribution = .fillEqually

                // Set fixed height for the row
                rowStackView.constrainHeight(constant: DashboardCellLayout.gridRowHeight)

                // Add the first indicator
                rowStackView.addArrangedSubview(indicators[index])
                index += 1

                // Check if there's a second indicator to add
                if index < indicators.count {
                    rowStackView.addArrangedSubview(indicators[index])
                    index += 1
                } else {
                    // Add an empty view to fill the second column
                    let emptyView = UIView()
                    rowStackView.addArrangedSubview(emptyView)
                }

                // Add the row to the vertical stack view
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
            dataSourceIconViewWidthConstraint.constant = DashboardCellLayout.sourceIconRegularWidth
        default:
            dataSourceIconViewWidthConstraint.constant = DashboardCellLayout.sourceIconCompactWidth
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
                options: [
                    .repeat,
                    .autoreverse,
                    .beginFromCurrentState,
                ],
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
extension RuuviTagDashboardCell {

    // swiftlint:disable:next function_body_length
    private func setupUI() {
        contentView.addSubview(containerView)
        containerView.fillSuperview()

        // Header Section - Name, Alert, More (top aligned)
        containerView.addSubview(moreIconView)
        moreIconView.anchor(
            top: containerView.topAnchor,
            leading: nil,
            bottom: nil,
            trailing: containerView.trailingAnchor,
            padding: .init(
                top: DashboardCellLayout.moreIconPadding,
                left: 0,
                bottom: 0,
                right: 0
            ),
            size: .init(
                width: DashboardCellLayout.moreIconSize,
                height: DashboardCellLayout.moreIconSize
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
                top: DashboardCellLayout.topPadding + DashboardCellLayout.alertIconTopOffset,
                left: 0,
                bottom: 0,
                right: DashboardCellLayout.alertToMoreSpacing
            ),
            size: DashboardCellLayout.alertIconSize
        )

        containerView.addSubview(alertButton)
        alertButton.match(view: alertIcon)

        containerView.addSubview(ruuviTagNameLabel)
        ruuviTagNameLabel.anchor(
            top: containerView.topAnchor,
            leading: containerView.leadingAnchor,
            bottom: nil,
            trailing: alertIcon.leadingAnchor,
            padding: .init(
                top: DashboardCellLayout.topPadding,
                left: DashboardCellLayout.leadingPadding,
                bottom: 0,
                right: DashboardCellLayout.nameToAlertSpacing
            )
        )

        // Grid Section
        containerView.addSubview(rowsStackView)
        rowsStackView.anchor(
            top: ruuviTagNameLabel.bottomAnchor,
            leading: ruuviTagNameLabel.leadingAnchor,
            bottom: nil,
            trailing: containerView.trailingAnchor,
            padding: .init(
                top: DashboardCellLayout.headerToGridSpacing,
                left: 0,
                bottom: 0,
                right: DashboardCellLayout.trailingPadding
            )
        )

        // Footer Section
        let sourceAndUpdateStack = UIStackView(arrangedSubviews: [
            dataSourceIconView, updatedAtLabel
        ])
        sourceAndUpdateStack.axis = .horizontal
        sourceAndUpdateStack.spacing = DashboardCellLayout.sourceIconToTextSpacing
        sourceAndUpdateStack.distribution = .fill

        dataSourceIconViewWidthConstraint = dataSourceIconView.widthAnchor
            .constraint(lessThanOrEqualToConstant: DashboardCellLayout.sourceIconRegularWidth)
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
                top: DashboardCellLayout.gridToFooterSpacing,
                left: 0,
                bottom: DashboardCellLayout.bottomPadding,
                right: DashboardCellLayout.trailingPadding
            )
        )

        // Set fixed height for footer
        footerStack.constrainHeight(constant: DashboardCellLayout.footerHeight)
        batteryLevelView.isHidden = true

        // No data view
        containerView.insertSubview(noDataView, belowSubview: moreIconView)
        noDataView.anchor(
            top: ruuviTagNameLabel.bottomAnchor,
            leading: containerView.leadingAnchor,
            bottom: containerView.bottomAnchor,
            trailing: containerView.trailingAnchor,
            padding: .init(
                top: DashboardCellLayout.headerToGridSpacing,
                left: 0,
                bottom: 0,
                right: 0
            )
        )
        noDataView.isHidden = true
    }
}

// MARK: - Height Calculator
extension RuuviTagDashboardCell {

    static func calculateHeight(
        for snapshot: RuuviTagCardSnapshot,
        width: CGFloat,
        numberOfColumns: Int = 2
    ) -> CGFloat {
        // Calculate name label height
        let nameHeight = calculateNameLabelHeight(
            text: snapshot.displayData.name,
            containerWidth: width
        )

        // Calculate grid height
        let indicatorCount = snapshot.displayData.indicatorGrid?.indicators.count ?? 0
        let gridHeight = DashboardCellLayout.gridHeight(indicatorCount: indicatorCount)

        // Total height calculation
        let totalHeight = nameHeight +                              // Dynamic header height
                         DashboardCellLayout.totalVerticalSpacing +  // All fixed spacings
                         gridHeight +                               // Dynamic grid height
                         DashboardCellLayout.footerHeight           // Fixed footer height

        return ceil(totalHeight)
    }

    private static func calculateNameLabelHeight(
        text: String,
        containerWidth: CGFloat
    ) -> CGFloat {
        let availableWidth = DashboardCellLayout.availableNameWidth(containerWidth: containerWidth)
        let maxSize = CGSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude)

        let textRect = (text as NSString).boundingRect(
            with: maxSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: DashboardCellLayout.nameFont],
            context: nil
        )

        let calculatedHeight = ceil(textRect.height)
        let singleLineHeight = ceil(DashboardCellLayout.nameFont.lineHeight)
        let maxHeight = singleLineHeight * CGFloat(DashboardCellLayout.maxNameLines)

        return max(min(calculatedHeight, maxHeight), singleLineHeight)
    }
}
// swiftlint:enable file_length
