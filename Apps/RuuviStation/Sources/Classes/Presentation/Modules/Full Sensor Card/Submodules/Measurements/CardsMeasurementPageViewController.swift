// swiftlint:disable file_length

import UIKit
import RuuviOntology
import Combine
import RuuviLocalization

// MARK: - Delegate Protocol
// swiftlint:disable:next type_name
protocol CardsMeasurementPageViewControllerDelegate: AnyObject {
    func cardsPageDidSelectMeasurementIndicator(
        _ indicator: RuuviTagCardSnapshotIndicatorData,
        in pageViewController: CardsMeasurementPageViewController
    )
}

// MARK: - Main View Controller
class CardsMeasurementPageViewController: UIViewController {

    // MARK: - Constants
    private struct Constants {
        static let topPadding: CGFloat = 8
        static let prominentViewTopPadding: CGFloat = 20
        static let measurementGridSpacing: CGFloat = 6
        static let minimumSpacing: CGFloat = 40
        static let cardHeight: CGFloat = 48
        static let contentBottomPadding: CGFloat = 20
        static let standardHorizontalPadding: CGFloat = 20
        static let iPadPortraitColumns: Int = 3
        static let iPadLandscapeColumns: Int = 4
        static let iPadPortraitHorizontalPadding: CGFloat = 60
        static let iPadLandscapeHorizontalPadding: CGFloat = 80
        static let minimumItemWidth: CGFloat = 100
        static let constraintPriority: Float = 999
    }

    // MARK: - Column Configuration
    private struct ColumnConfig {
        let columns: Int
        let shouldCenter: Bool
        let itemWidth: CGFloat
        let spacing: CGFloat
        let horizontalPadding: CGFloat

        static func forCurrentDevice(containerWidth: CGFloat) -> ColumnConfig {
            let isIPad = UIDevice.current.userInterfaceIdiom == .pad
            let spacing = Constants.measurementGridSpacing

            let columns: Int
            let shouldCenter: Bool
            let horizontalPadding: CGFloat

            if isIPad {
                let isLandscape = containerWidth > UIScreen.main.bounds.height
                if isLandscape {
                    columns = Constants.iPadLandscapeColumns
                    horizontalPadding = Constants.iPadLandscapeHorizontalPadding
                } else {
                    columns = Constants.iPadPortraitColumns
                    horizontalPadding = Constants.iPadPortraitHorizontalPadding
                }
                shouldCenter = false
            } else {
                // iPhone - keep existing logic unchanged
                columns = UIDevice.current.orientation.isLandscape ? 3 : 2
                shouldCenter = false
                horizontalPadding = Constants.standardHorizontalPadding
            }

            let totalHorizontalPadding = horizontalPadding * 2
            let availableWidth = containerWidth - totalHorizontalPadding
            let totalSpacing = CGFloat(columns - 1) * spacing
            let itemWidth = (availableWidth - totalSpacing) / CGFloat(columns)

            return ColumnConfig(
                columns: columns,
                shouldCenter: shouldCenter,
                itemWidth: max(itemWidth, Constants.minimumItemWidth),
                spacing: spacing,
                horizontalPadding: horizontalPadding
            )
        }
    }

    // MARK: - Properties
    var delegate: CardsMeasurementPageViewControllerDelegate?
    var pageIndex: Int = 0

    private var snapshot: RuuviTagCardSnapshot?
    private var cancellables = Set<AnyCancellable>()
    private var lastGridIndicatorTypes: Set<MeasurementType> = []
    private var currentMeasurementCards: [MeasurementType: CardsMeasurementIndicatorView] = [:]

    // MARK: - Layout Constraints
    private var spacerHeightConstraint: NSLayoutConstraint!
    private var spacerMinHeightConstraint: NSLayoutConstraint!
    private var measurementsStackLeadingConstraint: NSLayoutConstraint!
    private var measurementsStackTrailingConstraint: NSLayoutConstraint!

    // MARK: - UI Components
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()

    private lazy var contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var prominentIndicatorView: CardsProminentIndicatorView = {
        let view = CardsProminentIndicatorView()
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var dynamicSpacerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()

    private lazy var measurementsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = Constants.measurementGridSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    // MARK: - Public Configuration
    func configure(with snapshot: RuuviTagCardSnapshot) {
        let snapshotChanged = self.snapshot != snapshot
        self.snapshot = snapshot

        if snapshotChanged {
            setupSnapshotObservation()
            updateUI()
        }
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        startObservingAppState()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateDynamicSpacing()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { _ in
            self.updateLayoutForRotation(containerWidth: size.width)
        }, completion: { _ in
            self.updateDynamicSpacing()
        })
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        restartAlertAnimations()
    }

    deinit {
        cancellables.removeAll()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Setup Methods
private extension CardsMeasurementPageViewController {

    func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(prominentIndicatorView)
        contentView.addSubview(dynamicSpacerView)
        contentView.addSubview(measurementsStackView)

        setupConstraints()

        scrollView.delaysContentTouches = false
        scrollView.canCancelContentTouches = true

        scrollView.enableEdgeFading()
    }

    // swiftlint:disable:next function_body_length
    func setupConstraints() {
        let initialColumnConfig = ColumnConfig.forCurrentDevice(containerWidth: UIScreen.main.bounds.width)
        let initialPadding = initialColumnConfig.horizontalPadding

        spacerHeightConstraint = dynamicSpacerView.heightAnchor.constraint(
            equalToConstant: Constants.minimumSpacing
        )
        spacerMinHeightConstraint = dynamicSpacerView.heightAnchor.constraint(
            greaterThanOrEqualToConstant: Constants.minimumSpacing
        )

        scrollView.anchor(
            top: view.safeAreaLayoutGuide.topAnchor,
            leading: view.leadingAnchor,
            bottom: view.safeAreaLayoutGuide.bottomAnchor,
            trailing: view.trailingAnchor,
            padding: UIEdgeInsets(
                top: Constants.topPadding,
                left: 0,
                bottom: 0,
                right: 0
            )
        )

        contentView.fillSuperview()
        contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true

        prominentIndicatorView.anchor(
            top: contentView.topAnchor,
            leading: contentView.leadingAnchor,
            bottom: nil,
            trailing: contentView.trailingAnchor,
            padding: UIEdgeInsets(
                top: Constants.prominentViewTopPadding,
                left: Constants.standardHorizontalPadding,
                bottom: 0,
                right: Constants.standardHorizontalPadding
            )
        )
        prominentIndicatorView.centerXInSuperview()

        dynamicSpacerView.anchor(
            top: prominentIndicatorView.bottomAnchor,
            leading: contentView.leadingAnchor,
            bottom: nil,
            trailing: contentView.trailingAnchor
        )

        measurementsStackView.anchor(
            top: dynamicSpacerView.bottomAnchor,
            leading: nil,
            bottom: contentView.bottomAnchor,
            trailing: nil,
            padding: UIEdgeInsets(top: 0, left: 0, bottom: Constants.contentBottomPadding, right: 0)
        )

        measurementsStackLeadingConstraint = measurementsStackView.leadingAnchor.constraint(
            equalTo: contentView.leadingAnchor,
            constant: initialPadding
        )
        measurementsStackTrailingConstraint = measurementsStackView.trailingAnchor.constraint(
            equalTo: contentView.trailingAnchor,
            constant: -initialPadding
        )

        spacerHeightConstraint.isActive = true
        spacerMinHeightConstraint.isActive = false
        measurementsStackLeadingConstraint.isActive = true
        measurementsStackTrailingConstraint.isActive = true
    }

    func startObservingAppState() {
        NotificationCenter
            .default
            .addObserver(
                self,
                selector: #selector(handleAppWillMoveToForeground),
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )
    }

    @objc func handleAppWillMoveToForeground() {
        restartAllAlertAnimations()
    }

    func setupSnapshotObservation() {
        guard let snapshot = snapshot else { return }

        cancellables.removeAll()

        snapshot.$displayData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] displayData in
                self?.handleDisplayDataUpdate(displayData)
            }
            .store(in: &cancellables)

        snapshot.$alertData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateIndicatorAlerts()
            }
            .store(in: &cancellables)

        snapshot.anyIndicatorAlertPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateIndicatorAlerts()
            }
            .store(in: &cancellables)

        snapshot.$metadata
            .receive(
                on: DispatchQueue.main
            )
            .sink { [weak self] _ in
                self?.updateIndicatorAlerts()
            }
            .store(
                in: &cancellables
            )
    }
}

// MARK: - Data Update Handling
private extension CardsMeasurementPageViewController {

    func handleDisplayDataUpdate(_ displayData: RuuviTagCardSnapshotDisplayData) {
        let needsGridRebuild = checkIfGridRebuildNeeded(for: displayData)

        if needsGridRebuild {
            rebuildMeasurementGrid()
            updateProminentIndicator()
        } else {
            updateExistingMeasurementValues()
            updateProminentIndicator()
        }

        updateDynamicSpacing()
    }

    func checkIfGridRebuildNeeded(for displayData: RuuviTagCardSnapshotDisplayData) -> Bool {
        guard let indicators = displayData.indicatorGrid?.indicators else {
            let needsRebuild = !lastGridIndicatorTypes.isEmpty
            if needsRebuild {
                lastGridIndicatorTypes.removeAll()
            }
            return needsRebuild
        }

        // Get filtered indicators (same logic as getFilteredIndicators)
        let hasAQI = indicators.contains { $0.type == .aqi }
        let filteredIndicators = indicators.filter { indicator in
            if hasAQI && indicator.type == .aqi {
                return false
            }
            if !hasAQI && indicator.type == .temperature {
                return false
            }
            return true
        }

        let currentTypes = Set(filteredIndicators.map { $0.type })
        let needsRebuild = currentTypes != lastGridIndicatorTypes

        if needsRebuild {
            lastGridIndicatorTypes = currentTypes
        }

        return needsRebuild
    }

    func updateExistingMeasurementValues() {
        guard let indicators = getFilteredIndicators() else {
            return
        }

        // Update existing cards with new values
        for indicator in indicators {
            if let existingCard = currentMeasurementCards[indicator.type] {
                existingCard.configure(with: indicator)
            }
        }
    }

    func rebuildMeasurementGrid() {
        // Clear existing cards tracking
        currentMeasurementCards.removeAll()

        // Remove existing views
        measurementsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard let measurements = getFilteredIndicators() else {
            return
        }

        let columnConfig = ColumnConfig.forCurrentDevice(containerWidth: view.bounds.width)
        buildGrid(with: measurements, columnConfig: columnConfig)
    }

    func forceRebuildMeasurements() {
        lastGridIndicatorTypes.removeAll() // Force rebuild detection
        rebuildMeasurementGrid()
    }

    func updateLayoutForRotation(containerWidth: CGFloat) {
        let columnConfig = ColumnConfig.forCurrentDevice(containerWidth: containerWidth)

        // Update padding constraints
        measurementsStackLeadingConstraint.constant = columnConfig.horizontalPadding
        measurementsStackTrailingConstraint.constant = -columnConfig.horizontalPadding

        // Force rebuild for orientation changes since column count might change
        forceRebuildMeasurements()

        view.layoutIfNeeded()
    }

    func updateUI() {
        updateProminentIndicator()
        forceRebuildMeasurements() // Force rebuild on initial setup

        DispatchQueue.main.async {
            self.updateDynamicSpacing()
        }
    }
}

// MARK: - Alert Management
private extension CardsMeasurementPageViewController {

    func updateIndicatorAlerts() {
        guard let snapshot = snapshot else { return }

        snapshot.displayData.indicatorGrid?.indicators.forEach { indicatorData in
            // Only update alert state for existing measurement cards
            if let card = currentMeasurementCards[indicatorData.type],
               let alertConfig = snapshot.getAlertConfig(
                   for: indicatorData.type
               ) {
                card
                    .updateAlertState(
                        isHighlighted: alertConfig.isHighlighted &&
                            snapshot.metadata.isAlertAvailable
                    )
            }
        }

        // Update prominent indicator alert
        updateProminentIndicatorAlert()
    }

    func updateProminentIndicatorAlert() {
        guard let indicators = snapshot?.displayData.indicatorGrid?.indicators else {
            prominentIndicatorView.indicatorData = nil
            return
        }

        let prominentIndicator: RuuviTagCardSnapshotIndicatorData?

        if let aqiIndicator = indicators.first(where: { $0.type == .aqi }) {
            prominentIndicator = aqiIndicator
        } else if let tempIndicator = indicators.first(where: { $0.type == .temperature }) {
            prominentIndicator = tempIndicator
        } else {
            prominentIndicator = indicators.first
        }

        if let type = prominentIndicator?.type,
            let alertConfig = snapshot?.getAlertConfig(for: type),
            let metadata = snapshot?.metadata {
            prominentIndicatorView
                .updateAlertState(
                    isHighlighted: alertConfig.isHighlighted && metadata.isAlertAvailable
                )
        }
    }

    func restartAllAlertAnimations() {
        guard snapshot != nil else { return }
        // Restart animations for all measurement cards
        currentMeasurementCards.values.forEach { card in
            card.restartAlertAnimationIfNeeded()
        }

        // Restart animation for prominent indicator
        prominentIndicatorView.restartAlertAnimationIfNeeded()
    }

    func restartAlertAnimations() {
        guard snapshot != nil else { return }

        // Only restart animations for cards that should be alerting but aren't animating
        currentMeasurementCards.values.forEach { card in
            card.restartAlertAnimationIfNeeded()
        }

        prominentIndicatorView.restartAlertAnimationIfNeeded()
    }
}

// MARK: - Height Calculations
private extension CardsMeasurementPageViewController {

    func calculateAccurateProminentViewHeight() -> CGFloat {
        guard let indicators = snapshot?.displayData.indicatorGrid?.indicators else {
            return CardsProminentIndicatorView.heightForMeasurementMode()
        }

        let hasAQI = indicators.contains { $0.type == .aqi }

        if hasAQI {
            return CardsProminentIndicatorView.heightForAQIMode()
        } else {
            return CardsProminentIndicatorView.heightForMeasurementMode()
        }
    }

    func calculateAccurateMeasurementGridHeight() -> CGFloat {
        guard let filteredIndicators = getFilteredIndicators() else {
            return 0
        }

        let indicatorCount = filteredIndicators.count
        guard indicatorCount > 0 else {
            return 0
        }

        let columnConfig = ColumnConfig.forCurrentDevice(containerWidth: view.bounds.width)
        let numberOfRows = Int(ceil(Double(indicatorCount) / Double(columnConfig.columns)))
        let totalCardHeight = CGFloat(numberOfRows) * Constants.cardHeight
        let totalSpacing = CGFloat(max(0, numberOfRows - 1)) * Constants.measurementGridSpacing

        return totalCardHeight + totalSpacing
    }
}

// MARK: - Dynamic Layout
private extension CardsMeasurementPageViewController {

    func updateDynamicSpacing() {
        let prominentViewHeight = calculateAccurateProminentViewHeight()
        let measurementGridHeight = calculateAccurateMeasurementGridHeight()

        let scrollViewHeight = scrollView.bounds.height
        guard scrollViewHeight > 0 else { return }

        let totalFixedHeight = Constants.prominentViewTopPadding +
                              prominentViewHeight +
                              Constants.contentBottomPadding

        let availableHeightForSpacing = scrollViewHeight - totalFixedHeight - measurementGridHeight

        if availableHeightForSpacing >= Constants.minimumSpacing {
            let optimalSpacing = max(Constants.minimumSpacing, availableHeightForSpacing)

            spacerMinHeightConstraint.isActive = false
            spacerHeightConstraint.constant = optimalSpacing
            spacerHeightConstraint.isActive = true
        } else {
            spacerHeightConstraint.isActive = false
            spacerMinHeightConstraint.isActive = true
        }

        view.layoutIfNeeded()
    }
}

// MARK: - Indicator Management
private extension CardsMeasurementPageViewController {

    func updateProminentIndicator() {
        guard let indicators = snapshot?.displayData.indicatorGrid?.indicators else {
            prominentIndicatorView.indicatorData = nil
            return
        }

        let prominentIndicator: RuuviTagCardSnapshotIndicatorData?

        if let aqiIndicator = indicators.first(where: { $0.type == .aqi }) {
            prominentIndicator = aqiIndicator
        } else if let tempIndicator = indicators.first(where: { $0.type == .temperature }) {
            prominentIndicator = tempIndicator
        } else {
            prominentIndicator = indicators.first
        }

        prominentIndicatorView.indicatorData = prominentIndicator
    }

    func getFilteredIndicators() -> [RuuviTagCardSnapshotIndicatorData]? {
        guard let indicators = snapshot?.displayData.indicatorGrid?.indicators else {
            return nil
        }

        let hasAQI = indicators.contains { $0.type == .aqi }

        return indicators.filter { indicator in
            if hasAQI && indicator.type == .aqi {
                return false
            }
            if !hasAQI && indicator.type == .temperature {
                return false
            }
            return true
        }
    }

    func updateMeasurements() {
        // Clear existing cards tracking
        currentMeasurementCards.removeAll()

        // Remove existing views
        measurementsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard let measurements = getFilteredIndicators() else {
            return
        }

        let columnConfig = ColumnConfig.forCurrentDevice(containerWidth: view.bounds.width)
        buildGrid(with: measurements, columnConfig: columnConfig)
    }
}

// MARK: - Grid Building
private extension CardsMeasurementPageViewController {

    // swiftlint:disable:next function_body_length
    private func buildGrid(
        with indicators: [RuuviTagCardSnapshotIndicatorData],
        columnConfig: ColumnConfig
    ) {
        var index = 0
        while index < indicators.count {
            let rowStackView = UIStackView()
            rowStackView.axis = .horizontal
            rowStackView.spacing = columnConfig.spacing
            rowStackView.distribution = .fill
            rowStackView.alignment = .fill

            var cardsInRow = 0

            // Add actual measurement cards with fixed widths
            while cardsInRow < columnConfig.columns && index < indicators.count {
                let card = createMeasurementCard(for: indicators[index])

                // Track the card for alert updates
                currentMeasurementCards[indicators[index].type] = card

                // Set both width constraint AND content hugging/compression resistance
                let widthConstraint = card.widthAnchor.constraint(equalToConstant: columnConfig.itemWidth)
                widthConstraint.priority = UILayoutPriority(Constants.constraintPriority) // High priority
                widthConstraint.isActive = true

                // Prevent the card from expanding beyond its intended width
                card.setContentHuggingPriority(.required, for: .horizontal)
                card.setContentCompressionResistancePriority(.required, for: .horizontal)

                rowStackView.addArrangedSubview(card)
                cardsInRow += 1
                index += 1
            }

            // Add invisible placeholder views for remaining columns to maintain layout
            while cardsInRow < columnConfig.columns {
                let placeholder = UIView()
                placeholder.backgroundColor = .clear
                placeholder.isHidden = false // Keep visible for layout but transparent

                // Set same width as cards to maintain proper spacing
                let placeholderWidthConstraint = placeholder.widthAnchor.constraint(
                    equalToConstant: columnConfig.itemWidth
                )
                placeholderWidthConstraint.priority = UILayoutPriority(Constants.constraintPriority)
                placeholderWidthConstraint.isActive = true

                placeholder.setContentHuggingPriority(.required, for: .horizontal)
                placeholder.setContentCompressionResistancePriority(.required, for: .horizontal)

                rowStackView.addArrangedSubview(placeholder)
                cardsInRow += 1
            }

            // Handle centering for iPad landscape
            if columnConfig.shouldCenter {
                let containerStack = UIStackView()
                containerStack.axis = .horizontal
                containerStack.distribution = .fill
                containerStack.alignment = .center

                let leadingSpacer = UIView()
                let trailingSpacer = UIView()

                leadingSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
                trailingSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

                containerStack.addArrangedSubview(leadingSpacer)
                containerStack.addArrangedSubview(rowStackView)
                containerStack.addArrangedSubview(trailingSpacer)

                leadingSpacer.widthAnchor.constraint(equalTo: trailingSpacer.widthAnchor).isActive = true

                measurementsStackView.addArrangedSubview(containerStack)
            } else {
                measurementsStackView.addArrangedSubview(rowStackView)
            }
        }
    }

    func createMeasurementCard(
        for measurement: RuuviTagCardSnapshotIndicatorData
    ) -> CardsMeasurementIndicatorView {
        let card = CardsMeasurementIndicatorView()

        // Configure the card with initial data
        card.configure(with: measurement)

        // Set up tap handler
        card.onTap = { [weak self] in
            guard let self = self else { return }
            self.delegate?.cardsPageDidSelectMeasurementIndicator(measurement, in: self)
        }

        return card
    }
}

// MARK: - CardsProminentIndicatorViewDelegate
extension CardsMeasurementPageViewController: CardsProminentIndicatorViewDelegate {
    func cardsProminentIndicatorViewDidTap(
        for indicator: RuuviTagCardSnapshotIndicatorData,
        sender: CardsProminentIndicatorView
    ) {
        delegate?.cardsPageDidSelectMeasurementIndicator(indicator, in: self)
    }
}

// swiftlint:enable file_length
