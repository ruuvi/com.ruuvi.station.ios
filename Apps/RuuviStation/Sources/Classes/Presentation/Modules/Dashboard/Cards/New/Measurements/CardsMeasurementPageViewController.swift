import UIKit
import RuuviOntology
import Combine
import RuuviLocalization

// MARK: - Single Page Delegate Protocol
protocol CardsMeasurementPageViewControllerDelegate: AnyObject {
//    func cardsPageDidSelectMeasurement(
//        _ type: MeasurementType,
//        in pageViewController: CardsMeasurementPageViewController
//    )

    func cardsPageDidSelectMeasurementIndicator(
        _ indicator: RuuviTagCardSnapshotIndicatorData,
        in pageViewController: CardsMeasurementPageViewController
    )
}

// MARK: - Single Measurement Page (Individual Sensor)
// swiftlint:disable:next type_body_length
class CardsMeasurementPageViewController: UIViewController {

    // MARK: - Properties
    var delegate: CardsMeasurementPageViewControllerDelegate?
    var pageIndex: Int = 0

    func configure(with snapshot: RuuviTagCardSnapshot) {
        let snapshotChanged = self.snapshot != snapshot
        self.snapshot = snapshot

        if snapshotChanged {
            setupSnapshotObservation()
            updateUI()
        }
    }

    // MARK: - Layout Constants
    private struct Constants {
        static let topPadding: CGFloat = 8
        static let prominentViewTopPadding: CGFloat = 20
        static let measurementGridSpacing: CGFloat = 6
        static let minimumSpacing: CGFloat = 40
        static let cardHeight: CGFloat = 48
        static let fadeTransitionHeight: CGFloat = 20
        static let contentBottomPadding: CGFloat = 20
        static let standardHorizontalPadding: CGFloat = 20

        static let iPadPortraitColumns: Int = 3
        static let iPadLandscapeColumns: Int = 4
        static let iPadPortraitHorizontalPadding: CGFloat = 60
        static let iPadLandscapeHorizontalPadding: CGFloat = 80
    }

    // MARK: Column Configuration with Width Calculation
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
                itemWidth: max(itemWidth, 100),
                spacing: spacing,
                horizontalPadding: horizontalPadding
            )
        }
    }

    private var snapshot: RuuviTagCardSnapshot?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI Components
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = self
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

    // MARK: - Layout Properties
    private var spacerHeightConstraint: NSLayoutConstraint!
    private var spacerMinHeightConstraint: NSLayoutConstraint!
    private var measurementsStackLeadingConstraint: NSLayoutConstraint!
    private var measurementsStackTrailingConstraint: NSLayoutConstraint!
    private var isContentScrollable = false

    // MARK: - Alert Management
    private var currentMeasurementCards: [MeasurementType: CardsMeasurementIndicatorView] = [:]

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
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
    }

    // MARK: - Setup Methods
    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(prominentIndicatorView)
        contentView.addSubview(dynamicSpacerView)
        contentView.addSubview(measurementsStackView)

        setupConstraints()

        scrollView.delaysContentTouches = false
        scrollView.canCancelContentTouches = true
    }

    private func setupConstraints() {
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

    // MARK: - Snapshot Observation
    private func setupSnapshotObservation() {
        guard let snapshot = snapshot else { return }

        cancellables.removeAll()

        snapshot.$displayData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMeasurements()
                self?.updateProminentIndicator()
                self?.updateDynamicSpacing()
            }
            .store(in: &cancellables)

        snapshot.$alertData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] alertData in
                self?.updateAlertData(alertData)
            }
            .store(in: &cancellables)
    }

    // MARK: - Height Calculation Methods
    private func calculateAccurateProminentViewHeight() -> CGFloat {
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

    private func calculateAccurateMeasurementGridHeight() -> CGFloat {
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

    // MARK: - Dynamic Layout Methods
    private func updateDynamicSpacing() {
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

            isContentScrollable = false
        } else {
            spacerHeightConstraint.isActive = false
            spacerMinHeightConstraint.isActive = true

            isContentScrollable = true
        }

        view.layoutIfNeeded()

        DispatchQueue.main.async {
            self.updateContentFadeMask()
        }
    }

    // MARK: - Fixed Height Fade Methods
    private func updateContentFadeMask() {
        guard isContentScrollable else {
            scrollView.layer.mask = nil
            return
        }

        let contentOffset = max(0, scrollView.contentOffset.y)
        let contentHeight = scrollView.contentSize.height
        let scrollViewHeight = scrollView.bounds.height
        let maxScrollOffset = contentHeight - scrollViewHeight

        let hasContentAbove = contentOffset > 0
        let remainingContentBelow = maxScrollOffset - contentOffset
        let hasContentBelow = remainingContentBelow > 0

        guard hasContentAbove || hasContentBelow else {
            scrollView.layer.mask = nil
            return
        }

        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = scrollView.bounds

        var colors: [CGColor] = []
        var locations: [NSNumber] = []

        let fadeHeight: CGFloat = Constants.fadeTransitionHeight

        if hasContentAbove {
            let fadeProgress = min(contentOffset / fadeHeight, 1.0)
            let topFadeEnd = fadeHeight / scrollViewHeight

            colors.append(UIColor.clear.cgColor)
            colors.append(UIColor.black.withAlphaComponent(0.3 * fadeProgress).cgColor)
            colors.append(UIColor.black.cgColor)

            locations.append(0.0)
            locations.append(NSNumber(value: topFadeEnd * 0.6))
            locations.append(NSNumber(value: topFadeEnd))
        } else {
            colors.append(UIColor.black.cgColor)
            locations.append(0.0)
        }

        if hasContentBelow {
            let fadeProgress = min(remainingContentBelow / fadeHeight, 1.0)
            let bottomFadeStart = 1.0 - (fadeHeight / scrollViewHeight)

            if colors.count == 1 || locations.last!.doubleValue < bottomFadeStart {
                colors.append(UIColor.black.cgColor)
                locations.append(NSNumber(value: bottomFadeStart))
            }

            colors.append(UIColor.black.withAlphaComponent(0.3 * fadeProgress).cgColor)
            colors.append(UIColor.clear.cgColor)

            locations.append(NSNumber(value: bottomFadeStart + 0.04))
            locations.append(1.0)
        } else {
            colors.append(UIColor.black.cgColor)
            locations.append(1.0)
        }

        gradientLayer.colors = colors
        gradientLayer.locations = locations
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)

        scrollView.layer.mask = gradientLayer
    }

    private func updateLayoutForRotation(containerWidth: CGFloat) {
        let columnConfig = ColumnConfig.forCurrentDevice(containerWidth: containerWidth)

        // Update padding constraints
        measurementsStackLeadingConstraint.constant = columnConfig.horizontalPadding
        measurementsStackTrailingConstraint.constant = -columnConfig.horizontalPadding

        // Rebuild the measurement grid with new configuration
        updateMeasurements()

        view.layoutIfNeeded()
    }

    // MARK: - Data Update Methods
    private func updateUI() {
        updateProminentIndicator()
        updateMeasurements()

        DispatchQueue.main.async {
            self.updateDynamicSpacing()
        }
    }

    private func updateProminentIndicator() {
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

    private func getFilteredIndicators() -> [RuuviTagCardSnapshotIndicatorData]? {
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

    private func updateMeasurements() {
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

    private func updateAlertData(_ alertData: RuuviTagCardSnapshotAlertData?) {
        // Update alert states for all measurement cards
        updateIndicatorAlerts()

        // Restart animations if needed (with slight delay to ensure state is updated)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.restartAlertAnimations()
        }
    }

    private func updateIndicatorAlerts() {
        guard let snapshot = snapshot else { return }

        // Update alert states for each indicator
        snapshot.displayData.indicatorGrid?.indicators.forEach { indicatorData in
            // Update measurement cards only if they exist
            if let card = currentMeasurementCards[indicatorData.type] {
                card.configure(with: indicatorData)
            }
        }

        // The prominent indicator view updates itself when indicatorData is set
        updateProminentIndicator()
    }

    private func restartAlertAnimations() {
        // Only restart if we have a snapshot with alert data
        guard snapshot != nil else { return }

        // Restart animations for prominent indicator
        prominentIndicatorView.restartAlertAnimationIfNeeded()

        // Restart animations for all measurement cards
        currentMeasurementCards.values.forEach { card in
            card.restartAlertAnimationIfNeeded()
        }
    }

    // MARK: Grid Building with Proper Column Width Constraints
    private func buildGrid(with indicators: [RuuviTagCardSnapshotIndicatorData], columnConfig: ColumnConfig) {
        // FIXED: Always use grid layout to maintain consistent column widths
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

                // CRITICAL FIX: Set both width constraint AND content hugging/compression resistance
                let widthConstraint = card.widthAnchor.constraint(equalToConstant: columnConfig.itemWidth)
                widthConstraint.priority = UILayoutPriority(999) // High priority
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
                let placeholderWidthConstraint = placeholder.widthAnchor.constraint(equalToConstant: columnConfig.itemWidth)
                placeholderWidthConstraint.priority = UILayoutPriority(999)
                placeholderWidthConstraint.isActive = true

                placeholder.setContentHuggingPriority(.required, for: .horizontal)
                placeholder.setContentCompressionResistancePriority(.required, for: .horizontal)

                rowStackView.addArrangedSubview(placeholder)
                cardsInRow += 1
            }

            // FIXED: Handle centering for iPad landscape
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

    private func createMeasurementCard(
        for measurement: RuuviTagCardSnapshotIndicatorData
    ) -> CardsMeasurementIndicatorView {
        let card = CardsMeasurementIndicatorView()
        card.configure(with: measurement)
        card.onTap = { [weak self] in
            guard let self = self else { return }
            self.delegate?
                .cardsPageDidSelectMeasurementIndicator(measurement, in: self)
//            self.delegate?.cardsPageDidSelectMeasurement(measurement.type, in: self)
        }
        return card
    }
}

// MARK: - UIScrollViewDelegate
extension CardsMeasurementPageViewController: UIScrollViewDelegate {

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard isContentScrollable else { return }
        updateContentFadeMask()
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
