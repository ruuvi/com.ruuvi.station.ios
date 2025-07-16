// swiftlint:disable file_length

import UIKit
import Combine
import RuuviOntology
import RuuviLocalization

protocol DashboardCellDelegate: AnyObject {
    func didTapAlertButton(
        for snapshot: RuuviTagCardSnapshot
    )

    func didChangeMoreButtonMenuPresentationState(
        for snapshot: RuuviTagCardSnapshot,
        isPresented: Bool
    )
}

// MARK: - Layout Configuration
struct DashboardCellLayoutConstants {
    // Card padding
    static let topPadding: CGFloat = 12
    static let bottomPadding: CGFloat = 4
    static let leadingPadding: CGFloat = 16
    static let trailingPadding: CGFloat = 10

    // Header section
    static let alertIconSize = CGSize(
        width: 36,
        height: 36
    )
    static let moreIconTopPadding: CGFloat = 16
    static let moreIconSize: CGFloat = 36

    // Grid section
    static let headerToGridSpacing: CGFloat = 10
    static let gridRowHeight: CGFloat = 20
    static let gridRowSpacing: CGFloat = -2

    // Footer section
    static let gridToFooterSpacing: CGFloat = 4
    static let footerHeight: CGFloat = 24
    static let footerTrailingPadding: CGFloat = 14
    static let sourceIconToTextSpacing: CGFloat = 6
    static let sourceIconRegularWidth: CGFloat = 22
    static let sourceIconCompactWidth: CGFloat = 16

    // Image cell specific properties
    static let imageWidthRatio: CGFloat = 0.25
    static let nameToImageSpacing: CGFloat = 14
    static let groupSpacing: CGFloat = 10
    static let prominentViewHeight: CGFloat = 30
    static let progressViewHeight: CGFloat = 5
    static let progressViewTopSpacing: CGFloat = 3

    // Font configuration
    static let nameFont = UIFont.Montserrat(
        .bold,
        size: 14
    )
    static let timestampFont = UIFont.Muli(
        .regular,
        size: 10
    )
    static let maxNameLines: Int = 2

    // Derived calculations
    static var headerFixedWidth: CGFloat {
        return alertIconSize.width + moreIconSize
    }

    static var totalVerticalSpacing: CGFloat {
        return topPadding + headerToGridSpacing + gridToFooterSpacing + bottomPadding
    }

    static func availableNameWidth(
        containerWidth: CGFloat,
        dashboardType: DashboardType
    ) -> CGFloat {
        let reservedWidth: CGFloat
        if dashboardType == .image {
            let imageWidth = containerWidth * imageWidthRatio
            reservedWidth = imageWidth + nameToImageSpacing + headerFixedWidth
        } else {
            reservedWidth = leadingPadding + headerFixedWidth
        }
        return max(
            containerWidth - reservedWidth,
            80
        ) // Minimum 80pt width
    }

    static func gridHeight(
        indicatorCount: Int,
        dashboardType: DashboardType,
        hasAQI: Bool = false
    ) -> CGFloat {
        let actualIndicatorCount: Int

        if dashboardType == .image {
            // Filter out indicators shown prominently in image mode
            actualIndicatorCount = hasAQI ? max(
                0,
                indicatorCount - 1
            ) : max(
                0,
                indicatorCount - 1
            )
        } else {
            actualIndicatorCount = max(
                0,
                indicatorCount
            )
        }

        guard actualIndicatorCount > 0 else {
            return dashboardType == .simple ? gridRowHeight : 0
        }

        let numberOfRows: Int
        if actualIndicatorCount < 3 {
            numberOfRows = actualIndicatorCount
        } else {
            numberOfRows = Int(
                ceil(
                    Double(
                        actualIndicatorCount
                    ) / 2.0
                )
            )
        }

        let totalRowHeight = CGFloat(
            numberOfRows
        ) * gridRowHeight
        let totalSpacing = CGFloat(
            max(
                0,
                numberOfRows - 1
            )
        ) * gridRowSpacing
        return totalRowHeight + totalSpacing
    }
}

// swiftlint:disable:next type_body_length
class DashboardCell: UICollectionViewCell, TimestampUpdateable {

    // MARK: - Configuration
    private var dashboardType: DashboardType = .simple

    // MARK: - UI Components
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = RuuviColor.dashboardCardBG.color
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
        return view
    }()

    // Image cell specific components
    private lazy var cardBackgroundView = CardsBackgroundView()
    private lazy var prominentGroupContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    private lazy var prominentView = DashboardIndicatorProminentView()
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
        progressView.trackTintColor = RuuviColor.dashboardIndicator.color
            .withAlphaComponent(
                0.3
            )
        progressView.layer.cornerRadius = 0
        progressView.clipsToBounds = false
        return progressView
    }()

    private lazy var ruuviTagNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicatorBig.color
        label.textAlignment = .left
        label.numberOfLines = DashboardCellLayoutConstants.maxNameLines
        label.font = DashboardCellLayoutConstants.nameFont
        label
            .setContentHuggingPriority(
                .required,
                for: .vertical
            )
        label
            .setContentCompressionResistancePriority(
                .required,
                for: .vertical
            )
        label.backgroundColor = .clear
        return label
    }()

    private lazy var alertIconView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view
            .addSubview(
                alertIcon
            )
        alertIcon
            .anchor(
                top: view.topAnchor,
                leading: view.leadingAnchor,
                bottom: view.bottomAnchor,
                trailing: view.trailingAnchor,
                padding: .init(
                    top: 4,
                    left: 16,
                    bottom: 13,
                    right: 0
                )
            )
        return view
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
        button
            .addTarget(
                self,
                action: #selector(
                    alertButtonTapped
                ),
                for: .touchUpInside
            )
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
        view
            .addSubview(
                iv
            )
        iv
            .anchor(
                top: view.topAnchor,
                leading: view.leadingAnchor,
                bottom: view.bottomAnchor,
                trailing: view.trailingAnchor,
                padding: .init(
                    top: DashboardCellLayoutConstants.moreIconTopPadding,
                    left: 8,
                    bottom: 2,
                    right: 8
                )
            )
        return view
    }()

    private lazy var moreButton: DashboardContextMenuButton = {
        let button = DashboardContextMenuButton()
        button.backgroundColor = .clear
        button.showsMenuAsPrimaryAction = true
        button.onMenuPresent = { [weak self] in
            if let currentSnapshot = self?.currentSnapshot {
                self?.delegate?
                    .didChangeMoreButtonMenuPresentationState(
                        for: currentSnapshot,
                        isPresented: true
                    )
            }
        }

        button.onMenuDismiss = { [weak self] in
            if let currentSnapshot = self?.currentSnapshot {
                self?.delegate?
                    .didChangeMoreButtonMenuPresentationState(
                        for: currentSnapshot,
                        isPresented: false
                    )
            }
        }
        return button
    }()

    // Stack view to hold grid rows (vertical)
    private lazy var rowsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = DashboardCellLayoutConstants.gridRowSpacing
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
            .withAlphaComponent(
                0.8
            )
        return iv
    }()

    private lazy var updatedAtLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor
            .dashboardIndicator.color
            .withAlphaComponent(
                0.8
            )
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = DashboardCellLayoutConstants.timestampFont
        return label
    }()

    private lazy var batteryLevelView = BatteryLevelView()
    private lazy var noDataView = NoDataView()

    // Constraints for layout switching
    private var dataSourceIconViewWidthConstraint: NSLayoutConstraint!
    private var nameLeadingConstraint: NSLayoutConstraint!
    private var gridTopConstraint: NSLayoutConstraint!
    private var noDataViewLeadingConstraint: NSLayoutConstraint!

    // MARK: - Properties
    private var currentSnapshot: RuuviTagCardSnapshot?
    private var cancellables = Set<AnyCancellable>()
    weak var delegate: DashboardCellDelegate?

    // Keep track of current indicators for efficient updates
    private var currentIndicators: [DashboardIndicatorView] = []

    // MARK: - Lifecycle
    override init(
        frame: CGRect
    ) {
        super.init(
            frame: frame
        )
        setupUI()
    }

    required init?(
        coder: NSCoder
    ) {
        fatalError(
            "init(coder:) has not been implemented"
        )
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        currentSnapshot = nil
        cancellables
            .removeAll()
        alertIcon.layer
            .removeAllAnimations()

        // Clear and reset all indicator views
        rowsStackView.arrangedSubviews
            .forEach {
                $0.removeFromSuperview()
            }
        currentIndicators
            .removeAll()

        [
            airQIndexView, temperatureView, humidityView, pressureView,
            movementView, co2View, pm25View, pm10View, noxView,
            vocView, luminosityView, soundView,
        ].forEach {
            $0
                .clearValues()
        }

        // Reset image-specific components
        prominentView
            .clearValues()
        progressViewContainer.isHidden = true

        noDataView.isHidden = true
        batteryLevelView.isHidden = true
        alertButton.isUserInteractionEnabled = false
        dataSourceIconViewWidthConstraint.constant = DashboardCellLayoutConstants.sourceIconCompactWidth
        TimestampUpdateService.shared
            .removeSubscriber(
                self
            )
    }

    deinit {
        TimestampUpdateService.shared
            .removeSubscriber(
                self
            )
    }

    // MARK: - Configuration

    // swiftlint:disable:next function_body_length
    func configure(
        with snapshot: RuuviTagCardSnapshot,
        dashboardType: DashboardType
    ) {
        let dashboardTypeChanged = self.dashboardType != dashboardType
        let snapshotChanged = currentSnapshot != snapshot

        // Set dashboard type and update layout if changed
        if dashboardTypeChanged {
            self.dashboardType = dashboardType
            updateLayoutForDashboardType()
        }

        // Only update data if the snapshot actually changed
        if snapshotChanged {
            currentSnapshot = snapshot
            cancellables
                .removeAll()

            // Subscribe to data changes
            snapshot.$displayData
                .receive(
                    on: DispatchQueue.main
                )
                .sink { [weak self] displayData in
                    self?.updateDisplayData(
                        displayData
                    )
                }
                .store(
                    in: &cancellables
                )

            snapshot.$alertData
                .receive(
                    on: DispatchQueue.main
                )
                .sink { [weak self] alertData in
                    self?.updateAlertData(
                        alertData
                    )
                }
                .store(
                    in: &cancellables
                )

            snapshot.$lastUpdated
                .receive(
                    on: DispatchQueue.main
                )
                .sink { [weak self] _ in
                    self?.updateTimestampLabel()
                }
                .store(
                    in: &cancellables
                )

            // Subscribe to timer updates
            TimestampUpdateService.shared
                .addSubscriber(
                    self
                )

            // Initial update
            updateDisplayData(
                snapshot.displayData
            )
            updateAlertData(
                snapshot.alertData
            )
            updateTimestampLabel()
        } else if dashboardTypeChanged {
            // If only dashboard type changed, rebuild the indicator grid
            if let configuration = currentSnapshot?.displayData.indicatorGrid {
                buildIndicatorGrid(
                    with: configuration
                )
            }
        }
    }

    func setMenu(
        _ menu: UIMenu
    ) {
        moreButton.menu = menu
    }

    func restartAlertAnimationIfNeeded() {
        guard let snapshot = currentSnapshot else {
            return
        }
        updateAlertData(
            snapshot.alertData
        )
    }

    // MARK: - Layout Management
    private func updateLayoutForDashboardType() {
        if dashboardType == .image {
            // Show image-specific views
            cardBackgroundView.isHidden = false
            prominentGroupContainer.isHidden = false

            // Update name label constraint to start after image
            nameLeadingConstraint.isActive = false
            nameLeadingConstraint = ruuviTagNameLabel.leadingAnchor
                .constraint(
                    equalTo: cardBackgroundView.trailingAnchor,
                    constant: DashboardCellLayoutConstants.nameToImageSpacing
                )
            nameLeadingConstraint.isActive = true

            // Update grid top constraint to start after prominent view
            gridTopConstraint.isActive = false
            gridTopConstraint = rowsStackView.topAnchor
                .constraint(
                    equalTo: prominentGroupContainer.bottomAnchor,
                    constant: DashboardCellLayoutConstants.groupSpacing
                )
            gridTopConstraint.isActive = true

            noDataViewLeadingConstraint.isActive = false
            noDataViewLeadingConstraint = noDataView.leadingAnchor
                .constraint(
                    equalTo: cardBackgroundView.trailingAnchor,
                    constant: DashboardCellLayoutConstants.nameToImageSpacing
                )
            noDataViewLeadingConstraint.isActive = true

        } else {
            // Hide image-specific views
            cardBackgroundView.isHidden = true
            prominentGroupContainer.isHidden = true
            progressViewContainer.isHidden = true

            // Update name label constraint to start from container edge
            nameLeadingConstraint.isActive = false
            nameLeadingConstraint = ruuviTagNameLabel.leadingAnchor
                .constraint(
                    equalTo: containerView.leadingAnchor,
                    constant: DashboardCellLayoutConstants.leadingPadding
                )
            nameLeadingConstraint.isActive = true

            // Update grid top constraint to start after name label
            gridTopConstraint.isActive = false
            gridTopConstraint = rowsStackView.topAnchor
                .constraint(
                    equalTo: ruuviTagNameLabel.bottomAnchor,
                    constant: DashboardCellLayoutConstants.headerToGridSpacing
                )
            gridTopConstraint.isActive = true

            // Update no data view constraints for simple mode
            noDataViewLeadingConstraint.isActive = false
            noDataViewLeadingConstraint = noDataView.leadingAnchor
                .constraint(
                    equalTo: containerView.leadingAnchor
                )
            noDataViewLeadingConstraint.isActive = true
        }
    }

    // MARK: - Private Update Methods
    private func updateDisplayData(
        _ displayData: RuuviTagCardSnapshotDisplayData
    ) {
        ruuviTagNameLabel.text = displayData.name

        // Update background image if in image mode
        if dashboardType == .image {
            updateBackgroundImage(
                from: displayData
            )
        }

        // Build indicator grid efficiently - only rebuild if structure changed
        buildIndicatorGrid(
            with: displayData.indicatorGrid
        )

        // Update source icon
        updateSourceIcon(
            for: displayData.source
        )

        // Update battery and no data states
        batteryLevelView.isHidden = !displayData.batteryNeedsReplacement
        noDataView.isHidden = !displayData.hasNoData
    }

    private func updateBackgroundImage(
        from displayData: RuuviTagCardSnapshotDisplayData
    ) {
        cardBackgroundView.contentMode = .scaleAspectFit
        cardBackgroundView
            .setBackgroundImage(
                with: displayData.background,
                withAnimation: true
            )
    }

    private func updateAlertData(
        _ alertData: RuuviTagCardSnapshotAlertData
    ) {
        updateAlertIcon(
            for: alertData.alertState
        )
        // Update individual indicator alerts
        updateIndicatorAlerts()
    }

    func updateTimestampLabel() {
        guard let snapshot = currentSnapshot else {
            return
        }

        if let date = snapshot.lastUpdated {
            updatedAtLabel.text = date
                .ruuviAgo()
        } else {
            updatedAtLabel.text = RuuviLocalization.Cards.UpdatedLabel.NoData.message
        }
    }

    // MARK: - Indicator Grid Building
    private func buildIndicatorGrid(
        with configuration: RuuviTagCardSnapshotIndicatorGridConfiguration?
    ) {
        guard let configuration = configuration else {
            // Clear grid and show no data
            rowsStackView.arrangedSubviews
                .forEach {
                    $0.removeFromSuperview()
                }
            currentIndicators
                .removeAll()
            if dashboardType == .image {
                prominentView
                    .clearValues()
                progressViewContainer.isHidden = true
                updateGridPosition(
                    hasAQI: false
                )
            }
            noDataView.isHidden = false
            return
        }

        // Update prominent view only if in image mode
        if dashboardType == .image {
            updateProminentView(
                with: configuration
            )
        } else {
            // Ensure progress view is hidden in simple mode
            progressViewContainer.isHidden = true
        }

        let indicators = createIndicatorViews(
            from: configuration.indicators
        )

        // Only rebuild if indicators changed
        guard !indicatorsEqual(
            currentIndicators,
            indicators
        ) else {
            // Just update values without rebuilding layout
            updateIndicatorValues(
                configuration.indicators
            )
            return
        }

        currentIndicators = indicators
        buildGrid(
            with: indicators
        )
        updateIndicatorValues(
            configuration.indicators
        )
    }

    // swiftlint:disable:next function_body_length
    private func updateProminentView(
        with configuration: RuuviTagCardSnapshotIndicatorGridConfiguration
    ) {
        let hasAQI = configuration.indicators.contains {
            $0.type == .aqi
        }

        if hasAQI {
            // E1/V6 version - show Air Quality Index as prominent
            if let airQualityIndicator = configuration.indicators.first(
                where: {
                    $0.type == .aqi
                }) {
                let components = airQualityIndicator.value.components(
                    separatedBy: "/"
                )
                let mainValue = components.first ?? airQualityIndicator.value
                let superscriptValue = components.count > 1 ? "/\(components[1])" : ""

                prominentView
                    .setValue(
                        with: mainValue,
                        superscriptValue: superscriptValue,
                        subscriptValue: airQualityIndicator.unit
                    )

                // Show progress view
                progressViewContainer.isHidden = false
                if let progress = Int(
                    mainValue
                ) {
                    progressView.progress = Float(
                        progress
                    ) / 100
                    progressView.progressTintColor =
                    airQualityIndicator.isHighlighted ?
                    RuuviColor.orangeColor.color : airQualityIndicator.tintColor
                }
            }
        } else {
            // V5 version - show Temperature as prominent
            if let temperatureIndicator = configuration.indicators.first(
                where: {
                    $0.type == .temperature
                }) {
                let tempComponents = temperatureIndicator.value.components(
                    separatedBy: "\u{00A0}"
                ) // Non-breaking space
                let tempValue = tempComponents.first ?? temperatureIndicator.value

                prominentView
                    .setValue(
                        with: tempValue,
                        superscriptValue: temperatureIndicator.unit,
                        subscriptValue: temperatureIndicator.showSubscript ?
                        RuuviLocalization.TagSettings.OffsetCorrection.temperature : " "
                    )
            }
            // Hide progress view
            progressViewContainer.isHidden = true
        }

        // Update grid position based on progress view visibility
        updateGridPosition(
            hasAQI: hasAQI
        )
    }

    private func updateGridPosition(
        hasAQI: Bool
    ) {
        guard dashboardType == .image else {
            return
        }

        gridTopConstraint.isActive = false

        if hasAQI && !progressViewContainer.isHidden {
            // Grid positioned after progress view
            gridTopConstraint = rowsStackView.topAnchor
                .constraint(
                    equalTo: progressViewContainer.bottomAnchor,
                    constant: DashboardCellLayoutConstants.groupSpacing
                )
        } else {
            // Grid positioned after prominent view
            gridTopConstraint = rowsStackView.topAnchor
                .constraint(
                    equalTo: prominentGroupContainer.bottomAnchor,
                    constant: DashboardCellLayoutConstants.groupSpacing
                )
        }
        gridTopConstraint.isActive = true
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func createIndicatorViews(
        from indicatorData: [RuuviTagCardSnapshotIndicatorData]
    ) -> [DashboardIndicatorView] {
        var indicators: [DashboardIndicatorView] = []
        let hasAdvancedSensors = indicatorData.contains {
            $0.type == .aqi
        }

        for data in indicatorData {
            // Skip indicators that are shown prominently in image mode
            if dashboardType == .image {
                if hasAdvancedSensors && data.type == .aqi {
                    continue
                }
                if !hasAdvancedSensors && data.type == .temperature {
                    continue
                }
            }

            switch data.type {
            case .aqi:
                indicators
                    .append(
                        airQIndexView
                    )
            case .temperature:
                indicators
                    .append(
                        temperatureView
                    )
            case .humidity:
                indicators
                    .append(
                        humidityView
                    )
            case .pressure:
                indicators
                    .append(
                        pressureView
                    )
            case .movementCounter:
                indicators
                    .append(
                        movementView
                    )
            case .co2:
                indicators
                    .append(
                        co2View
                    )
            case .pm25:
                indicators
                    .append(
                        pm25View
                    )
            case .pm10:
                indicators
                    .append(
                        pm10View
                    )
            case .nox:
                indicators
                    .append(
                        noxView
                    )
            case .voc:
                indicators
                    .append(
                        vocView
                    )
            case .luminosity:
                indicators
                    .append(
                        luminosityView
                    )
            case .soundInstant:
                indicators
                    .append(
                        soundView
                    )
            default:
                break
            }
        }

        return indicators
    }

    private func updateIndicatorValues(
        _ indicatorData: [RuuviTagCardSnapshotIndicatorData]
    ) {
        for data in indicatorData {
            let indicatorView = getIndicatorView(
                for: data.type
            )
            indicatorView?
                .setValue(
                    with: data.value,
                    unit: data.unit
                )
        }
    }

    private func updateIndicatorAlerts() {
        guard let snapshot = currentSnapshot else {
            return
        }

        // Update each indicator's alert state
        snapshot.displayData.indicatorGrid?.indicators
            .forEach { indicatorData in
                if dashboardType == .image && indicatorData.type == .temperature {
                    let hasAdvancedSensors = snapshot.displayData.indicatorGrid?.indicators.contains {
                        $0.type == .aqi
                    } ?? false

                    if hasAdvancedSensors {
                        temperatureView
                            .changeColor(
                                highlight: indicatorData.isHighlighted
                            )
                    } else {
                        prominentView
                            .changeColor(
                                highlight: indicatorData.isHighlighted
                            )
                    }
                } else {
                    let indicatorView = getIndicatorView(
                        for: indicatorData.type
                    )
                    indicatorView?
                        .changeColor(
                            highlight: indicatorData.isHighlighted
                        )
                }
            }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func getIndicatorView(
        for type: MeasurementType
    ) -> DashboardIndicatorView? {
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
        case .soundInstant: return soundView
        default: return nil
        }
    }

    private func indicatorsEqual(
        _ lhs: [DashboardIndicatorView],
        _ rhs: [DashboardIndicatorView]
    ) -> Bool {
        guard lhs.count == rhs.count else {
            return false
        }
        return zip(
            lhs,
            rhs
        )
        .allSatisfy {
            $0 === $1
        }
    }

    // Build grid with fixed row heights
    // swiftlint:disable:next function_body_length
    private func buildGrid(
        with indicators: [DashboardIndicatorView]
    ) {
        // Clear existing arranged subviews
        rowsStackView.arrangedSubviews
            .forEach {
                $0.removeFromSuperview()
            }

        // Configure the rowsStackView
        rowsStackView.axis = .vertical
        rowsStackView.spacing = DashboardCellLayoutConstants.gridRowSpacing
        rowsStackView.distribution = .fill

        if indicators.count < 3 {
            // Less than 3 indicators: arrange vertically
            for indicator in indicators {
                // Set fixed height for each indicator
                indicator
                    .constrainHeight(
                        constant: DashboardCellLayoutConstants.gridRowHeight
                    )
                rowsStackView
                    .addArrangedSubview(
                        indicator
                    )
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
                rowStackView
                    .constrainHeight(
                        constant: DashboardCellLayoutConstants.gridRowHeight
                    )

                // Add the first indicator
                rowStackView
                    .addArrangedSubview(
                        indicators[index]
                    )
                index += 1

                // Check if there's a second indicator to add
                if index < indicators.count {
                    rowStackView
                        .addArrangedSubview(
                            indicators[index]
                        )
                    index += 1
                } else {
                    // Add an empty view to fill the second column
                    let emptyView = UIView()
                    rowStackView
                        .addArrangedSubview(
                            emptyView
                        )
                }

                // Add the row to the vertical stack view
                rowsStackView
                    .addArrangedSubview(
                        rowStackView
                    )
            }
        }
    }

    private func updateSourceIcon(
        for source: RuuviTagSensorRecordSource?
    ) {
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
            dataSourceIconViewWidthConstraint.constant = DashboardCellLayoutConstants.sourceIconRegularWidth
        default:
            dataSourceIconViewWidthConstraint.constant = DashboardCellLayoutConstants.sourceIconCompactWidth
        }

        dataSourceIconView.image = dataSourceIconView.image?
            .withRenderingMode(
                .alwaysTemplate
            )
    }

    private func updateAlertIcon(
        for alertState: AlertState?
    ) {
        alertIcon.layer
            .removeAllAnimations()

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
                removeAlertAnimations(
                    alpha: 0
                )
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
        DispatchQueue.main
            .asyncAfter(
                deadline: .now() + 0.1
            ) {
                UIView
                    .animate(
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

    private func removeAlertAnimations(
        alpha: Double = 1
    ) {
        DispatchQueue.main
            .asyncAfter(
                deadline: .now() + 0.1
            ) { [weak self] in
                self?.alertIcon.layer
                    .removeAllAnimations()
                self?.alertIcon.alpha = alpha
            }
    }

    @objc private func alertButtonTapped() {
        guard let snapshot = currentSnapshot else {
            return
        }
        delegate?
            .didTapAlertButton(
                for: snapshot
            )
    }
}

// MARK: - UI Setup
extension DashboardCell {

    // swiftlint:disable:next function_body_length
    private func setupUI() {
        contentView
            .addSubview(
                containerView
            )
        containerView
            .fillSuperview()

        // Background image (initially hidden)
        containerView
            .addSubview(
                cardBackgroundView
            )
        cardBackgroundView
            .anchor(
                top: containerView.topAnchor,
                leading: containerView.leadingAnchor,
                bottom: containerView.bottomAnchor,
                trailing: nil
            )
        cardBackgroundView.widthAnchor
            .constraint(
                equalTo: containerView.widthAnchor,
                multiplier: DashboardCellLayoutConstants.imageWidthRatio
            ).isActive = true
        cardBackgroundView.isHidden = true

        // Header Section - More and Alert icons
        containerView
            .addSubview(
                moreIconView
            )
        moreIconView
            .anchor(
                top: containerView.topAnchor,
                leading: nil,
                bottom: nil,
                trailing: containerView.trailingAnchor,
                size: .init(
                    width: DashboardCellLayoutConstants.moreIconSize,
                    height: DashboardCellLayoutConstants.moreIconSize
                )
            )

        containerView
            .addSubview(
                moreButton
            )
        moreButton
            .match(
                view: moreIconView
            )

        containerView
            .addSubview(
                alertIconView
            )
        alertIconView
            .anchor(
                top: containerView.topAnchor,
                leading: nil,
                bottom: nil,
                trailing: moreIconView.leadingAnchor,
                padding: .init(
                    top: DashboardCellLayoutConstants.topPadding,
                    left: 0,
                    bottom: 0,
                    right: 0
                ),
                size: DashboardCellLayoutConstants.alertIconSize
            )

        containerView
            .addSubview(
                alertButton
            )
        alertButton
            .match(
                view: alertIconView
            )

        // Name label with initial simple layout constraints
        containerView
            .addSubview(
                ruuviTagNameLabel
            )
        ruuviTagNameLabel
            .anchor(
                top: containerView.topAnchor,
                leading: nil,
                // Will be set by nameLeadingConstraint
                bottom: nil,
                trailing: alertIconView.leadingAnchor,
                padding: .init(
                    top: DashboardCellLayoutConstants.topPadding,
                    left: 0,
                    bottom: 0,
                    right: 0
                )
            )

        // Initial name leading constraint for simple mode
        nameLeadingConstraint = ruuviTagNameLabel.leadingAnchor
            .constraint(
                equalTo: containerView.leadingAnchor,
                constant: DashboardCellLayoutConstants.leadingPadding
            )
        nameLeadingConstraint.isActive = true

        // Prominent view container (initially hidden)
        containerView
            .addSubview(
                prominentGroupContainer
            )
        prominentGroupContainer
            .anchor(
                top: ruuviTagNameLabel.bottomAnchor,
                leading: ruuviTagNameLabel.leadingAnchor,
                bottom: nil,
                trailing: containerView.trailingAnchor,
                padding: .init(
                    top: DashboardCellLayoutConstants.groupSpacing,
                    left: 0,
                    bottom: 0,
                    right: DashboardCellLayoutConstants.trailingPadding
                )
            )
        prominentGroupContainer
            .constrainHeight(
                constant: DashboardCellLayoutConstants.prominentViewHeight
            )
        prominentGroupContainer.isHidden = true

        prominentGroupContainer
            .addSubview(
                prominentView
            )
        prominentView
            .fillSuperview()

        // Progress view
        containerView
            .addSubview(
                progressViewContainer
            )
        progressViewContainer
            .anchor(
                top: prominentGroupContainer.bottomAnchor,
                leading: prominentGroupContainer.leadingAnchor,
                bottom: nil,
                trailing: nil,
                padding: .init(
                    top: DashboardCellLayoutConstants.progressViewTopSpacing,
                    left: 0,
                    bottom: 0,
                    right: 0
                ),
                size: .init(
                    width: 120,
                    height: DashboardCellLayoutConstants.progressViewHeight
                )
            )

        progressViewContainer
            .addSubview(
                progressView
            )
        progressView
            .fillSuperview()
        progressViewContainer.isHidden = true

        // Grid Section
        containerView
            .addSubview(
                rowsStackView
            )
        rowsStackView
            .anchor(
                top: nil,
                // Will be set by gridTopConstraint
                leading: ruuviTagNameLabel.leadingAnchor,
                bottom: nil,
                trailing: containerView.trailingAnchor,
                padding: .init(
                    top: 0,
                    left: 0,
                    bottom: 0,
                    right: DashboardCellLayoutConstants.trailingPadding
                )
            )

        // Initial grid top constraint for simple mode
        gridTopConstraint = rowsStackView.topAnchor
            .constraint(
                equalTo: ruuviTagNameLabel.bottomAnchor,
                constant: DashboardCellLayoutConstants.headerToGridSpacing
            )
        gridTopConstraint.isActive = true

        // Footer Section
        let sourceAndUpdateStack = UIStackView(
            arrangedSubviews: [
                dataSourceIconView,
                updatedAtLabel,
            ]
        )
        sourceAndUpdateStack.axis = .horizontal
        sourceAndUpdateStack.spacing = DashboardCellLayoutConstants.sourceIconToTextSpacing
        sourceAndUpdateStack.distribution = .fill

        dataSourceIconViewWidthConstraint = dataSourceIconView.widthAnchor
            .constraint(
                lessThanOrEqualToConstant: DashboardCellLayoutConstants.sourceIconRegularWidth
            )
        dataSourceIconViewWidthConstraint.isActive = true

        let footerStack = UIStackView(
            arrangedSubviews: [
                sourceAndUpdateStack,
                UIView
                    .flexibleSpacer(),
                batteryLevelView,
            ]
        )
        footerStack.spacing = 4
        footerStack.axis = .horizontal
        footerStack.distribution = .fillProportionally

        containerView
            .addSubview(
                footerStack
            )
        footerStack
            .anchor(
                top: rowsStackView.bottomAnchor,
                leading: ruuviTagNameLabel.leadingAnchor,
                bottom: containerView.bottomAnchor,
                trailing: containerView.trailingAnchor,
                padding: .init(
                    top: DashboardCellLayoutConstants.gridToFooterSpacing,
                    left: 0,
                    bottom: DashboardCellLayoutConstants.bottomPadding,
                    right: DashboardCellLayoutConstants.footerTrailingPadding
                )
            )

        // Set fixed height for footer
        footerStack
            .constrainHeight(
                constant: DashboardCellLayoutConstants.footerHeight
            )
        batteryLevelView.isHidden = true

        // No data view
        containerView.addSubview(noDataView)
        noDataView
            .anchor(
                top: moreIconView.bottomAnchor,
                leading: nil,
                // Will be set by noDataViewLeadingConstraint
                bottom: containerView.bottomAnchor,
                trailing: containerView.trailingAnchor
            )

        // Initial no data view constraints for simple mode
        noDataViewLeadingConstraint = noDataView.leadingAnchor
            .constraint(
                equalTo: containerView.leadingAnchor
            )
        noDataViewLeadingConstraint.isActive = true
        noDataView.isHidden = true
    }
}

// MARK: - Height Calculator
extension DashboardCell {

    static func calculateHeight(
        for snapshot: RuuviTagCardSnapshot,
        width: CGFloat,
        dashboardType: DashboardType,
        numberOfColumns: Int = 2
    ) -> CGFloat {
        if dashboardType == .image {
            return calculateImageHeight(
                for: snapshot,
                width: width,
                numberOfColumns: numberOfColumns
            )
        } else {
            return calculateSimpleHeight(
                for: snapshot,
                width: width
            )
        }
    }

    private static func calculateSimpleHeight(
        for snapshot: RuuviTagCardSnapshot,
        width: CGFloat
    ) -> CGFloat {
        // Calculate name label height
        let nameHeight = calculateNameLabelHeight(
            text: snapshot.displayData.name,
            containerWidth: width,
            dashboardType: .simple
        )

        // Calculate grid height
        let indicatorCount = snapshot.displayData.indicatorGrid?.indicators.count ?? 0
        let gridHeight = DashboardCellLayoutConstants.gridHeight(
            indicatorCount: indicatorCount,
            dashboardType: .simple
        )

        // Total height calculation
        let totalHeight = nameHeight +
                          DashboardCellLayoutConstants.totalVerticalSpacing +
                          gridHeight +
                          DashboardCellLayoutConstants.footerHeight

        return ceil(
            totalHeight
        )
    }

    private static func calculateImageHeight(
        for snapshot: RuuviTagCardSnapshot,
        width: CGFloat,
        numberOfColumns: Int
    ) -> CGFloat {
        let nameHeight = calculateNameLabelHeight(
            text: snapshot.displayData.name,
            containerWidth: width,
            dashboardType: .image
        )
        let hasAQI = snapshot.displayData.indicatorGrid?.indicators.contains {
            $0.type == .aqi
        } ?? false
        let prominentHeight = DashboardCellLayoutConstants.prominentViewHeight
        let progressHeight = hasAQI ? (
            DashboardCellLayoutConstants.progressViewTopSpacing +
            DashboardCellLayoutConstants.progressViewHeight
        ) : 0
        let indicatorCount = snapshot.displayData.indicatorGrid?.indicators.count ?? 0
        let gridHeight = DashboardCellLayoutConstants.gridHeight(
            indicatorCount: indicatorCount,
            dashboardType: .image,
            hasAQI: hasAQI
        )

        // Calculate total height with consistent 10px spacing between all groups
        let totalHeight = DashboardCellLayoutConstants.topPadding +
        nameHeight +
        DashboardCellLayoutConstants.groupSpacing +
        prominentHeight +
        progressHeight +
        DashboardCellLayoutConstants.groupSpacing +
        gridHeight +
        DashboardCellLayoutConstants.gridToFooterSpacing +
        DashboardCellLayoutConstants.footerHeight +
        DashboardCellLayoutConstants.bottomPadding

        return ceil(
            totalHeight
        )
    }

    private static func calculateNameLabelHeight(
        text: String,
        containerWidth: CGFloat,
        dashboardType: DashboardType
    ) -> CGFloat {
        let availableWidth = DashboardCellLayoutConstants.availableNameWidth(
            containerWidth: containerWidth,
            dashboardType: dashboardType
        )
        let maxSize = CGSize(
            width: availableWidth,
            height: CGFloat.greatestFiniteMagnitude
        )

        let textRect = (
            text as NSString
        ).boundingRect(
            with: maxSize,
            options: [.usesLineFragmentOrigin],
            attributes: [.font: DashboardCellLayoutConstants.nameFont],
            context: nil
        )

        let calculatedHeight = ceil(
            textRect.height
        )
        let singleLineHeight = ceil(
            DashboardCellLayoutConstants.nameFont.lineHeight
        )
        let maxHeight = singleLineHeight * CGFloat(
            DashboardCellLayoutConstants.maxNameLines
        )

        return max(
            min(
                calculatedHeight,
                maxHeight
            ),
            singleLineHeight
        )
    }
}
// swiftlint:enable file_length
