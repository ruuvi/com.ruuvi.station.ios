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
        static let compactWidthColumns: Int = 2
        static let compactHeightColumns: Int = 3
        static let regularColumns: Int = 3
        static let regularWideColumns: Int = 4
        static let regularHorizontalPadding: CGFloat = 60
        static let regularWideHorizontalPadding: CGFloat = 80
        static let minimumItemWidth: CGFloat = 100
        /// `.regular` layout: 3 columns while they are at most this wide, 4 beyond. With the page's
        /// own width this keeps the full-screen iPad grids: 3 columns in portrait (744-1032pt wide,
        /// columns up to 300pt) and 4 in landscape (1080-1376pt wide, where 3 would be 316pt+). 308
        /// sits midway between the two.
        static let regularMaximumItemWidth: CGFloat = 308
    }

    // MARK: - Column Configuration
    /// The measurement grid's column count and side padding, from the page's own size classes and
    /// width (never the device type or the orientation), so the grid follows the space the page
    /// has: full screen, a resized iPad window or either iPhone Duo display. Card widths are not
    /// part of it: each row shares its real width equally between its columns.
    private struct ColumnConfig: Equatable {
        let columns: Int
        let spacing: CGFloat
        let horizontalPadding: CGFloat

        /// - `.compactWidth` (iPhone portrait): 2 columns, 20pt side padding.
        /// - `.compactHeight` (iPhone landscape): 3 columns, 20pt side padding.
        /// - `.regular` (iPad, iPhone Duo inner display): 3 columns with 60pt side padding, or 4
        ///   with 80pt once 3 would be wider than `regularMaximumItemWidth`. Where a vertical fold
        ///   runs through the page (iPhone Duo inner display in landscape) the count is made even,
        ///   so the fold falls between two columns.
        static func make(
            for layoutClass: RuuviLayoutClass,
            containerWidth: CGFloat,
            hasVerticalFold: () -> Bool
        ) -> ColumnConfig {
            let spacing = Constants.measurementGridSpacing

            switch layoutClass {
            case .compactWidth:
                return ColumnConfig(
                    columns: Constants.compactWidthColumns,
                    spacing: spacing,
                    horizontalPadding: Constants.standardHorizontalPadding
                )
            case .compactHeight:
                return ColumnConfig(
                    columns: Constants.compactHeightColumns,
                    spacing: spacing,
                    horizontalPadding: Constants.standardHorizontalPadding
                )
            case .regular:
                var columns = RuuviGridFit.columns(
                    in: containerWidth,
                    counts: [Constants.regularColumns, Constants.regularWideColumns],
                    spacing: spacing,
                    padding: { 2 * regularHorizontalPadding(columns: $0) },
                    minimumColumnWidth: Constants.minimumItemWidth,
                    maximumColumnWidth: Constants.regularMaximumItemWidth
                )
                if !columns.isMultiple(of: 2), hasVerticalFold() {
                    columns += 1
                }
                return ColumnConfig(
                    columns: columns,
                    spacing: spacing,
                    horizontalPadding: regularHorizontalPadding(columns: columns)
                )
            }
        }

        /// 60pt side padding for 3 columns, 80pt for 4 (today's iPad portrait and landscape grids).
        private static func regularHorizontalPadding(columns: Int) -> CGFloat {
            columns >= Constants.regularWideColumns
                ? Constants.regularWideHorizontalPadding
                : Constants.regularHorizontalPadding
        }
    }

    // MARK: - Properties
    var delegate: CardsMeasurementPageViewControllerDelegate?
    var pageIndex: Int = 0

    private var snapshot: RuuviTagCardSnapshot?
    private var cancellables = Set<AnyCancellable>()
    private var lastGridIndicatorVariants: Set<MeasurementDisplayVariant> = []
    private var currentMeasurementCards: [MeasurementDisplayVariant: CardsMeasurementIndicatorView] = [:]

    // MARK: - Layout Constraints
    private var spacerHeightConstraint: NSLayoutConstraint!
    private var spacerMinHeightConstraint: NSLayoutConstraint!
    private var measurementsStackLeadingConstraint: NSLayoutConstraint!
    private var measurementsStackTrailingConstraint: NSLayoutConstraint!

    /// The configuration the grid was last built and padded with; `nil` until the first build.
    private var appliedColumnConfig: ColumnConfig?

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

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        // The grid is first built before the page is in a window, where the size classes aren't
        // known yet: correct it now that they are (normally already done by the first layout).
        updateColumnConfigIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateColumnConfigIfNeeded()
        updateDynamicSpacing()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { _ in
            self.updateColumnConfigIfNeeded()
            self.view.layoutIfNeeded()
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
        // Replaced by the grid's real padding when it is built and on every layout pass
        // (`applyColumnConfig(_:)`); the size classes aren't known yet here.
        let initialPadding = Constants.standardHorizontalPadding

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
        let currentVariants = Set(displayData.secondaryIndicators.map { $0.variant })
        let needsRebuild = currentVariants != lastGridIndicatorVariants

        if needsRebuild {
            lastGridIndicatorVariants = currentVariants
        }

        return needsRebuild
    }

    func updateExistingMeasurementValues() {
        guard let indicators = getFilteredIndicators() else {
            return
        }

        // Update existing cards with new values
        for indicator in indicators {
            if let existingCard = currentMeasurementCards[indicator.variant] {
                existingCard.configure(with: indicator)
            }
        }
    }

    private func rebuildMeasurementGrid(with columnConfig: ColumnConfig? = nil) {
        // First, as it may load the view (the first build happens before the page is shown).
        let columnConfig = columnConfig ?? currentColumnConfig()

        // Clear existing cards tracking
        currentMeasurementCards.removeAll()

        // Remove existing views
        measurementsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        applyColumnConfig(columnConfig)

        guard let measurements = getFilteredIndicators() else {
            return
        }

        buildGrid(with: measurements, columnConfig: columnConfig)
    }

    func forceRebuildMeasurements() {
        lastGridIndicatorVariants.removeAll() // Force rebuild detection
        rebuildMeasurementGrid()
    }

    /// The grid configuration for the page's current size classes and width.
    private func currentColumnConfig() -> ColumnConfig {
        ColumnConfig.make(
            for: view.traitCollection.ruuviLayoutClass,
            containerWidth: view.bounds.width,
            hasVerticalFold: {
                // Checked on the page view controller's view, which stays put while pages scroll,
                // so a neighbouring page laid out off screen sees the fold as well.
                RuuviDuoLayout.hasVerticalFold(in: parent?.view ?? view)
            }
        )
    }

    /// Sets the grid's side padding and remembers `columnConfig` as the applied configuration.
    private func applyColumnConfig(_ columnConfig: ColumnConfig) {
        appliedColumnConfig = columnConfig
        guard measurementsStackLeadingConstraint.constant != columnConfig.horizontalPadding else { return }
        measurementsStackLeadingConstraint.constant = columnConfig.horizontalPadding
        measurementsStackTrailingConstraint.constant = -columnConfig.horizontalPadding
    }

    /// Re-evaluates the grid for the page's current size classes and width. Runs on every layout
    /// pass (rotation, window resizing, the page joining a window), so it is cheap and idempotent:
    /// the cards are rebuilt only when the column count changes and the padding is set only when
    /// it changes. Card widths need nothing, the rows share their width equally.
    func updateColumnConfigIfNeeded() {
        let columnConfig = currentColumnConfig()
        guard columnConfig != appliedColumnConfig else { return }
        if columnConfig.columns != appliedColumnConfig?.columns {
            rebuildMeasurementGrid(with: columnConfig)
        } else {
            applyColumnConfig(columnConfig)
        }
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

        if let gridIndicators = getFilteredIndicators() {
            gridIndicators.forEach { indicatorData in
                guard let card = currentMeasurementCards[indicatorData.variant] else { return }
                let alertConfig = snapshot.getIndicatorAlertConfig(for: indicatorData)
                card.updateAlertState(
                    isHighlighted: alertConfig.isHighlighted && snapshot.metadata.isAlertAvailable
                )
            }
        }

        // Update prominent indicator alert
        updateProminentIndicatorAlert()
    }

    func updateProminentIndicatorAlert() {
        guard let snapshot,
              let primaryIndicator = snapshot.displayData.primaryIndicator else {
            prominentIndicatorView.indicatorData = nil
            return
        }

        let alertConfig = snapshot.getIndicatorAlertConfig(for: primaryIndicator)
        prominentIndicatorView
            .updateAlertState(
                isHighlighted: alertConfig.isHighlighted && snapshot.metadata.isAlertAvailable
            )
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
        guard let type = snapshot?.displayData.primaryIndicator?.type else {
            return CardsProminentIndicatorView.heightForMeasurementMode()
        }

        if type == .aqi {
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

        // The column count the grid is built with.
        let columns = (appliedColumnConfig ?? currentColumnConfig()).columns
        let numberOfRows = Int(ceil(Double(indicatorCount) / Double(columns)))
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
        prominentIndicatorView.indicatorData = snapshot?.displayData.primaryIndicator
    }

    func getFilteredIndicators() -> [RuuviTagCardSnapshotIndicatorData]? {
        let secondary = snapshot?.displayData.secondaryIndicators ?? []
        return secondary.isEmpty ? nil : secondary
    }
}

// MARK: - Grid Building
private extension CardsMeasurementPageViewController {

    private func buildGrid(
        with indicators: [RuuviTagCardSnapshotIndicatorData],
        columnConfig: ColumnConfig
    ) {
        var index = 0
        while index < indicators.count {
            let rowStackView = UIStackView()
            rowStackView.axis = .horizontal
            rowStackView.spacing = columnConfig.spacing
            // Equal columns that always follow the row's real width (rotation, window resizing),
            // with no fixed card widths that could go stale.
            rowStackView.distribution = .fillEqually
            rowStackView.alignment = .fill

            var cardsInRow = 0

            // Add actual measurement cards
            while cardsInRow < columnConfig.columns && index < indicators.count {
                let card = createMeasurementCard(for: indicators[index])

                // Track the card for alert updates
                currentMeasurementCards[indicators[index].variant] = card

                rowStackView.addArrangedSubview(card)
                cardsInRow += 1
                index += 1
            }

            // Invisible placeholders fill the remaining columns, so the cards of a short last row
            // keep the same width as the cards above them.
            while cardsInRow < columnConfig.columns {
                let placeholder = UIView()
                placeholder.backgroundColor = .clear
                rowStackView.addArrangedSubview(placeholder)
                cardsInRow += 1
            }

            measurementsStackView.addArrangedSubview(rowStackView)
        }
    }

    func createMeasurementCard(
        for measurement: RuuviTagCardSnapshotIndicatorData
    ) -> CardsMeasurementIndicatorView {
        let card = CardsMeasurementIndicatorView(source: .cards)

        // Configure the card with initial data
        card.configure(with: measurement)

        // Rebuilt cards need the current alert state before another snapshot update arrives.
        if let snapshot {
            let alertConfig = snapshot.getIndicatorAlertConfig(for: measurement)
            card.updateAlertState(
                isHighlighted: alertConfig.isHighlighted && snapshot.metadata.isAlertAvailable
            )
        }

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
