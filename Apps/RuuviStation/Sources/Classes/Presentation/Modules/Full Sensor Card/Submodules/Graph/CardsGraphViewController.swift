import BTKit
import DGCharts
// swiftlint:disable file_length
import Foundation
import GestureInstructions
import RuuviLocal
import RuuviLocalization
import RuuviOntology
import Humidity
import RuuviService
import RuuviStorage
import UIKit

// swiftlint:disable type_body_length
class CardsGraphViewController: UIViewController {
    weak var output: CardsGraphViewOutput?

    init(output: CardsGraphViewOutput, settings: RuuviLocalSettings) {
        self.output = output
        self.settings = settings
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var chartModules: [MeasurementDisplayVariant] = [] {
        didSet {
            moreButton.updateMenu(
                with:
                    moreButtonOptions(
                        showChartStat: showChartStat
                    )
            )
        }
    }

    private var snapshot: RuuviTagCardSnapshot?

    var showAlertRangeInGraph: Bool = true

    var historyLengthInDay: Int = 1 {
        didSet {
            historySelectionButton.updateTitle(with: historyLengthInDay.days)
        }
    }

    var historyLengthInHours: Int = 1 {
        didSet {
            if historyLengthInHours >= 24 {
                historyLengthInDay = historyLengthInHours / 24
            } else {
                let unit = historyLengthInHours == 1 ? RuuviLocalization.hour : RuuviLocalization.hours
                historySelectionButton.updateTitle(
                    with: "\(historyLengthInHours) " + unit.lowercased()
                )
            }
            historySelectionButton.updateMenu(with: historyLengthOptions())
        }
    }

    var showChartStat: Bool = true {
        didSet {
            moreButton.updateMenu(
                with:
                    moreButtonOptions(
                        showChartStat: showChartStat
                    )
            )
        }
    }

    var chartsPerScreen: Int = 3 {
        didSet {
            updateChartsCollectionConstaints(from: self.chartModules)
            moreButton.updateMenu(
                with:
                    moreButtonOptions(
                        showChartStat: showChartStat
                    )
            )
        }
    }

    var showChartAll: Bool = true {
        didSet {
            historySelectionButton.updateMenu(with: historyLengthOptions())
            if showChartAll {
                historySelectionButton.updateTitle(
                    with: RuuviLocalization.all
                )
            }
        }
    }

    var measurementService: RuuviServiceMeasurement!

    // MARK: - UI COMPONENTS DECLARATION

    // Body
    lazy var noDataLabel: UILabel = {
        let label = UILabel()
        label.text = RuuviLocalization.emptyChartMessage
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.mulish(.bold, size: 14)
        return label
    }()

    // Chart toolbar
    private lazy var historySelectionButton: RuuviContextMenuButton =
        .init(
            menu: historyLengthOptions(),
            titleColor: .white,
            title: RuuviLocalization.day1,
            icon: RuuviAsset.arrowDropDown.image,
            iconTintColor: RuuviColor.logoTintColor.color,
            iconSize: .init(width: 14, height: 14),
            leadingPadding: 6,
            trailingPadding: 6,
            preccedingIcon: false
        )

    private lazy var moreButton: RuuviCustomButton =
        .init(
            menu: moreButtonOptions(),
            icon: RuuviAsset.more3dot.image,
            tintColor: .white,
            iconSize: .init(width: 24, height: 18),
            leadingPadding: 0,
            trailingPadding: 12
        )

    // Charts
    lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.backgroundColor = .clear
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.alwaysBounceHorizontal = false
        sv.contentInsetAdjustmentBehavior = .never
        sv.isScrollEnabled = false
        sv.indicatorStyle = .white
        sv.delegate = self
        return sv
    }()

    private var chartViews: [CardsGraphView] = []
    private var pendingScrollVariant: MeasurementDisplayVariant?
    private var needsDeferredLayoutUpdate = false
    private var isMarkerInteractionActive = false
    private var isSyncingHighlights = false

    /// What the chart heights, paging, fade and size menu were last applied for.
    private struct ChartLayout: Equatable {
        let isPaged: Bool
        let scrollViewHeight: CGFloat
    }

    /// The rule behind `usesPagedChartLayout`.
    private enum PagedChartLayoutRule {
        /// The most charts the stack shows on one screen (the largest `chartsPerScreen`). The rule
        /// uses it whatever the current setting, so the layout depends only on the space.
        static let maximumChartsPerScreen: CGFloat = 3
        /// A stacked chart may be at most this many times wider than tall.
        static let maximumChartAspectRatio: CGFloat = 4
    }

    /// The bottom fade of the scroll view, and the matching bottom content inset.
    private enum FadeTransitionHeight {
        static let stacked: CGFloat = 30
        static let paged: CGFloat = 10
    }

    /// See `applyChartLayoutIfNeeded()`.
    private var appliedChartLayout: ChartLayout?
    /// Size transitions (rotation) in flight; their completion does the remaining work.
    private var activeSizeTransitionCount = 0
    /// The page a size transition started on when it started in the paged layout; the transition keeps it.
    private var sizeTransitionStartPage: CGFloat?

    /// `true` for one full-height chart per page with paging (iPhone and iPad landscape), `false` for
    /// a stack of `chartsPerScreen` charts (iPhone and iPad portrait). Picked from the space the
    /// charts have, never from the orientation or the device: paged in a compact-height layout, and
    /// wherever stacking the maximum number of charts would make each one more than
    /// `maximumChartAspectRatio` times wider than tall (full-screen iPad landscape, iPhone Duo inner
    /// display in landscape, short wide windows). So a stacked chart is always at least a quarter of
    /// the width tall (80pt at 320pt), however short the window. Before the scroll view has a size,
    /// only the size class decides.
    var usesPagedChartLayout: Bool {
        guard isViewLoaded else { return false }
        if traitCollection.ruuviLayoutClass.isCompactHeight {
            return true
        }
        let size = scrollView.bounds.size
        guard size.width > 0, size.height > 0 else { return false }
        return size.height / PagedChartLayoutRule.maximumChartsPerScreen
            < size.width / PagedChartLayoutRule.maximumChartAspectRatio
    }

    private lazy var chartsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.alignment = .fill
        stack.distribution = .fill
        return stack
    }()

    private var chartViewCache: [MeasurementDisplayVariant: CardsGraphView] = [:]
    private var chartHeightConstraints: [MeasurementDisplayVariant: NSLayoutConstraint] = [:]

    // Sync view
    lazy var syncProgressView = UIView(color: .clear)
    lazy var syncStatusLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .left
        label.font = UIFont.ruuviBody()
        return label
    }()

    private lazy var syncButton: RuuviContextMenuButton = {
        let button = RuuviContextMenuButton(
            menu: nil,
            titleColor: .white,
            title: RuuviLocalization.TagCharts.Sync.title,
            icon: RuuviAsset.iconSyncBt.image,
            iconTintColor: .white,
            iconSize: .init(width: 22, height: 22),
            leadingPadding: 12,
            preccedingIcon: true
        )
        button.button.showsMenuAsPrimaryAction = false
        button.button.addTarget(
            self,
            action: #selector(syncButtonDidTap),
            for: .touchUpInside
        )
        return button
    }()

    lazy var syncCancelButton: UIButton = {
        let button = UIButton()
        let closeImage = UIImage(systemName: "xmark")
        button.tintColor = .white
        button.setImage(closeImage, for: .normal)
        button.addTarget(self, action: #selector(cancelButtonDidTap), for: .touchUpInside)
        return button
    }()

    // UI END

    private let historyHoursOptions: [Int] = [1, 2, 3, 6, 12]
    private let minimumHistoryLimit: Int = 1 // Day
    private var maximumHistoryLimit: Int { max(0, settings.dataPruningOffsetHours / 24) }
    private let highlightAnimationDelay: TimeInterval = 0.3

    private var settings: RuuviLocalSettings
    private var shouldHighlightOnScroll = false
    private var hasChartData: Bool?
    private var shouldHideChartsForLoading = false

    // MARK: - LIFECYCLE

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        localize()
        applyHasChartDataState()
        registerLayoutClassObserver()
        output?.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        output?.viewWillAppear()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateScrollInsetsForFade()
        if needsDeferredLayoutUpdate,
           scrollView.frame.height > 0 {
            needsDeferredLayoutUpdate = false
            updateChartsCollectionConstaints(from: chartModules)
        } else if let variant = pendingScrollVariant,
                  !chartModules.isEmpty,
                  scrollView.frame.height > 0 {
            scroll(to: variant)
        }
        applyChartLayoutIfNeeded()
    }

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        if activeSizeTransitionCount == 0 {
            sizeTransitionStartPage = appliedChartLayout.flatMap { layout in
                layout.isPaged ? (scrollView.contentOffset.y / layout.scrollViewHeight).rounded() : nil
            }
        }
        activeSizeTransitionCount += 1
        let isCompletionQueued = coordinator.animate(alongsideTransition: { _ in
        }, completion: { [weak self] _ in
            guard let sSelf = self else { return }
            sSelf.activeSizeTransitionCount = max(sSelf.activeSizeTransitionCount - 1, 0)
            if sSelf.activeSizeTransitionCount == 0 {
                sSelf.sizeTransitionStartPage = nil
            }
            sSelf.updateScrollviewBehaviour()
            sSelf.updateChartsCollectionConstaints(
                from: sSelf.chartModules,
                withAnimation: true
            )
            sSelf.moreButton.updateMenu(
                with: sSelf.moreButtonOptions(
                    showChartStat: sSelf.showChartStat
                )
            )
            sSelf.updateScrollInsetsForFade()
            self?.output?.viewDidTransition()
        })
        if !isCompletionQueued {
            activeSizeTransitionCount = max(activeSizeTransitionCount - 1, 0)
            if activeSizeTransitionCount == 0 {
                sizeTransitionStartPage = nil
            }
        }
        super.viewWillTransition(to: size, with: coordinator)
        gestureInstructor.dismissThenResume()
    }

    /// Size-class changes come with a layout pass, where `applyChartLayoutIfNeeded()` picks up the
    /// new layout; this makes sure that pass happens. iOS 16 is full screen only, so there only
    /// rotation changes the size classes, and it always lays out again.
    private func registerLayoutClassObserver() {
        guard #available(iOS 17.0, *) else { return }
        registerForTraitChanges(RuuviLayoutClass.traitsAffectingLayoutClass) {
            (controller: CardsGraphViewController, _: UITraitCollection) in
            controller.view.setNeedsLayout()
        }
    }

    fileprivate func setUpUI() {
        setUpContentView()
        configureViews()
    }

    // swiftlint:disable:next function_body_length
    fileprivate func setUpContentView() {
        let chartToolbarView = UIView(color: .clear)
        view.addSubview(chartToolbarView)
        chartToolbarView.anchor(
            top: view.safeTopAnchor,
            leading: view.safeLeftAnchor,
            bottom: nil,
            trailing: view.safeRightAnchor,
            size: .init(width: 0, height: 36)
        )

        chartToolbarView.addSubview(moreButton)
        moreButton.anchor(
            top: nil,
            leading: nil,
            bottom: nil,
            trailing: chartToolbarView.trailingAnchor
        )
        moreButton.centerYInSuperview()

        chartToolbarView.addSubview(historySelectionButton)
        historySelectionButton.anchor(
            top: nil,
            leading: nil,
            bottom: nil,
            trailing: moreButton.leadingAnchor,
            padding: .init(
                top: 0,
                left: 0,
                bottom: 0,
                right: 4
            ),
            size: .init(
                width: 0,
                height: 28
            )
        )
        historySelectionButton.centerYInSuperview()

        chartToolbarView.addSubview(syncProgressView)
        syncProgressView.anchor(
            top: chartToolbarView.topAnchor,
            leading: chartToolbarView.leadingAnchor,
            bottom: chartToolbarView.bottomAnchor,
            trailing: historySelectionButton.leadingAnchor,
            padding: .init(
                top: 0,
                left: 0,
                bottom: 0,
                right: 8
            )
        )

        syncProgressView.addSubview(syncCancelButton)
        syncCancelButton.anchor(
            top: nil,
            leading: syncProgressView.leadingAnchor,
            bottom: nil,
            trailing: nil,
            padding: .init(top: 0, left: 12, bottom: 0, right: 0),
            size: .init(width: 32, height: 32)
        )
        syncCancelButton.centerYInSuperview()
        syncProgressView.alpha = 0

        syncProgressView.addSubview(syncStatusLabel)
        syncStatusLabel.anchor(
            top: nil,
            leading: syncCancelButton.trailingAnchor,
            bottom: nil,
            trailing: syncProgressView.trailingAnchor,
            padding: .init(top: 0, left: 6, bottom: 0, right: 0)
        )
        syncStatusLabel.centerYInSuperview()

        chartToolbarView.addSubview(syncButton)
        syncButton.anchor(
            top: nil,
            leading: chartToolbarView.leadingAnchor,
            bottom: nil,
            trailing: nil,
            padding: .init(top: 0, left: 8, bottom: 0, right: 0),
            size: .init(
                width: 0,
                height: 28
            )
        )
        syncButton.centerYInSuperview()
        syncButton.alpha = 1

        view.addSubview(scrollView)
        scrollView.anchor(
            top: chartToolbarView.bottomAnchor,
            leading: view.safeLeftAnchor,
            bottom: view.safeBottomAnchor,
            trailing: view.safeRightAnchor,
            padding: .init(top: 6, left: 0, bottom: 0, right: 0)
        )

        scrollView.addSubview(chartsStackView)
        chartsStackView.anchor(
            top: scrollView.topAnchor,
            leading: scrollView.leadingAnchor,
            bottom: scrollView.bottomAnchor,
            trailing: scrollView.trailingAnchor
        )
        chartsStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true

        view.addSubview(noDataLabel)
        noDataLabel.anchor(
            top: nil,
            leading: view.safeLeftAnchor,
            bottom: nil,
            trailing: view.safeRightAnchor
        )
        noDataLabel.centerYInSuperview()
        noDataLabel.alpha = hasChartData == false ? 1 : 0
    }

    private func configureViews() {
        var fadeConfiguration = ScrollViewEdgeFader.Configuration()
        fadeConfiguration.fadeTransitionHeight = currentFadeTransitionHeight()
        scrollView.enableEdgeFading(configuration: fadeConfiguration)
        updateScrollInsetsForFade()
    }

    @objc fileprivate func syncButtonDidTap() {
        output?.viewDidTriggerSync(for: snapshot)
    }

    @objc fileprivate func cancelButtonDidTap() {
        output?.viewDidTriggerStopSync(for: snapshot)
    }

    fileprivate func historyLengthOptions() -> UIMenu {
        var actions: [UIAction] = []

        // Add 'All' at the top
        let all_action = UIAction(title: RuuviLocalization.all) { [weak self] _ in
            self?.handleHistorySelectionAll()
        }
        all_action.state = showChartAll ? .on : .off
        actions.append(all_action)

        for hour in historyHoursOptions where hour <= max(0, settings.dataPruningOffsetHours) {
            let action = UIAction(
                title: "\(hour) \(hour == 1 ? RuuviLocalization.hour : RuuviLocalization.hours)".lowercased()
            ) { [weak self] _ in
                self?.handleHistoryLengthSelection(hours: hour)
            }
            if hour == historyLengthInHours, !showChartAll {
                action.state = .on
            } else {
                action.state = .off
            }
            actions.append(action)
        }

        for day in 0 ... maximumHistoryLimit where day >= minimumHistoryLimit {
            let action = UIAction(title: day.days) {
                [weak self] _ in
                self?.handleHistoryLengthSelection(hours: day * 24)
            }
            if day == historyLengthInHours / 24, !showChartAll {
                action.state = .on
            } else {
                action.state = .off
            }
            actions.append(action)
        }

        // Add more at the bottom
        let more_action = UIAction(title: RuuviLocalization.more) { [weak self] _ in
            self?.handleHistoryLengthSelection(hours: nil)
        }
        actions.append(more_action)

        return UIMenu(
            title: "",
            children: actions
        )
    }

    fileprivate func handleHistoryLengthSelection(hours: Int?) {
        if let hours {
            if hours >= 24 {
                historySelectionButton.updateTitle(with: "\((hours / 24).days)")
                historySelectionButton.updateMenu(with: historyLengthOptions())
            } else {
                let unit = hours == 1 ? RuuviLocalization.hour : RuuviLocalization.hours
                historySelectionButton.updateTitle(
                    with: "\(hours) " + unit.lowercased()
                )
            }
            output?.viewDidSelectChartHistoryLength(hours: hours)
            historySelectionButton.updateMenu(with: historyLengthOptions())
        } else {
            output?.viewDidSelectLongerHistory()
        }
    }

    fileprivate func handleHistorySelectionAll() {
        resetXAxisTimeline()
        output?.viewDidSelectAllChartHistory()
    }

    // swiftlint:disable:next function_body_length
    fileprivate func moreButtonOptions(
        showChartStat: Bool = true
    ) -> UIMenu {
        let exportHistoryCSVAction = UIAction(title: RuuviLocalization.exportHistory) {
            [weak self] _ in
            self?.output?.viewDidTapOnExportCSV()
        }

        let exportHistoryXLSXAction = UIAction(title: RuuviLocalization.exportHistoryXlsx) {
            [weak self] _ in
            self?.output?.viewDidTapOnExportXLSX()
        }

        let clearViewHistory = UIAction(title: RuuviLocalization.clearView) {
            [weak self] _ in
            guard let sSelf = self else { return }
            sSelf.output?.viewDidTriggerClear(for: sSelf.snapshot)
        }

        let minMaxAvgAction = UIAction(
            title: !showChartStat ? RuuviLocalization.chartStatShow : RuuviLocalization.chartStatHide
        ) {
            [weak self] _ in
            guard let sSelf = self else { return }
            sSelf.output?.viewDidSelectTriggerChartStat(show: !showChartStat)
            sSelf.chartViews.forEach { chartView in
                chartView.setChartStatVisible(show: !showChartStat)
            }
        }

        let increaseChartSizeAction = UIAction(
            title: RuuviLocalization.increaseGraphSize
        ) {
            [weak self] _ in
            guard let sSelf = self else { return }
            sSelf.output?.viewDidSelectChartsPerScreen(
                max(sSelf.chartsPerScreen - 1, 1)
            )
            sSelf.updateChartsCollectionConstaints(
                from: sSelf.chartModules,
                withAnimation: true
            )
        }

        let decreaseChartSizeAction = UIAction(
            title: RuuviLocalization.decreaseGraphSize
        ) {
            [weak self] _ in
            guard let sSelf = self else { return }
            sSelf.output?.viewDidSelectChartsPerScreen(
                min(sSelf.chartsPerScreen + 1, 3)
            )
            sSelf.updateChartsCollectionConstaints(
                from: sSelf.chartModules,
                withAnimation: true
            )
        }

        var actions: [UIAction] = [
            exportHistoryCSVAction,
            exportHistoryXLSXAction,
            clearViewHistory,
            minMaxAvgAction,
        ]

        if chartModules.count > 2, !usesPagedChartLayout {
            if chartsPerScreen > 1 {
                actions.append(increaseChartSizeAction)
            }
            if chartsPerScreen < 3 {
                actions.append(decreaseChartSizeAction)
            }
        }

        return UIMenu(
            title: "",
            children: actions
        )
    }
}

extension CardsGraphViewController: CardsGraphViewDelegate {
    func chartDidTranslate(_ chartView: CardsGraphView) {
        guard chartViews.count > 1
        else {
            calculateMinMaxForChart(for: chartView)
            if showAlertRangeInGraph {
                calculateAlertFillIfNeeded(for: chartView)
            }
            return
        }
        let sourceMatrix = chartView.underlyingView.viewPortHandler.touchMatrix
        chartViews.filter { $0 != chartView }.forEach { otherChart in
            var targetMatrix = otherChart.underlyingView.viewPortHandler.touchMatrix
            targetMatrix.a = sourceMatrix.a
            targetMatrix.tx = sourceMatrix.tx
            otherChart.underlyingView.viewPortHandler.refresh(
                newMatrix: targetMatrix,
                chart: otherChart.underlyingView,
                invalidate: true
            )
        }

        for view in chartViews {
            calculateMinMaxForChart(for: view)
            if showAlertRangeInGraph {
                calculateAlertFillIfNeeded(for: view)
            }
        }
    }

    func chartDidSingleTap(
        _: CardsGraphView,
        location _: CGPoint
    ) {
        output?.viewDidAskGraphLongPressTutorialDialog()
    }

    func chartMarkerInteractionDidBegin(_: CardsGraphView) {
        isMarkerInteractionActive = true
        updateScrollviewBehaviour()
    }

    func chartMarkerInteractionDidEnd(_: CardsGraphView) {
        isMarkerInteractionActive = false
        updateScrollviewBehaviour()
    }

    func chartValueDidSelect(
        _ chartView: CardsGraphView,
        entry: ChartDataEntry,
        highlight: Highlight
    ) {
        guard chartViews.count > 1
        else {
            return
        }

        guard !isSyncingHighlights else { return }
        isSyncingHighlights = true
        defer { isSyncingHighlights = false }

        chartViews.filter { $0 != chartView }.forEach { otherChart in
            otherChart.underlyingView.highlightEntry(
                atX: highlight.x,
                closestToY: entry.y,
                dataSetIndex: highlight.dataSetIndex
            )
        }
    }

    func chartValueDidDeselect(_: CardsGraphView) {
        guard chartViews.count > 1
        else {
            return
        }

        guard !isSyncingHighlights else { return }
        isSyncingHighlights = true
        defer { isSyncingHighlights = false }

        chartViews.forEach { chart in
            chart.underlyingView.clearMarker()
        }
    }
}

// MARK: - TagChartsViewInput

extension CardsGraphViewController: CardsGraphViewInput {
    func setActiveSnapshot(_ snapshot: RuuviTagCardSnapshot?) {
        self.snapshot = snapshot
        pendingScrollVariant = nil
        shouldHighlightOnScroll = false
    }

    var viewIsVisible: Bool {
        isViewLoaded && view.window != nil
    }

    var graphIsVisibleForUser: Bool {
        viewIsVisible && !view.isHidden && view.alpha > 0.01
    }

    func clearChartHistory() {
        clearChartData()
    }

    func createChartViews(from variants: [MeasurementDisplayVariant]) {
        chartModules = variants
        updateChartsCollectionConstaints(from: variants)
    }

    func resetScrollPosition() {
        scrollView.setContentOffset(.zero, animated: false)
    }

    func scroll(to variant: MeasurementDisplayVariant) {
        shouldHighlightOnScroll = true
        guard !chartModules.isEmpty else {
            pendingScrollVariant = variant
            return
        }

        guard let targetView = visibleChartView(for: variant),
              !targetView.isHidden else {
            pendingScrollVariant = variant
            return
        }

        pendingScrollVariant = nil

        ensureLayoutComplete()

        let targetFrame = targetView.convert(targetView.bounds, to: scrollView)
        let visibleRect = scrollView.visibleRect

        if visibleRect.contains(targetFrame) {
            if shouldHighlightOnScroll {
                highlightTarget(targetView)
                shouldHighlightOnScroll = false
            }
        } else {
            scrollToTarget(targetFrame, targetView: targetView)
        }
    }

    func setChartViewData(
        from chartViewData: [RuuviGraphViewDataModel],
        settings: RuuviLocalSettings
    ) {
        self.settings = settings
        if chartViewData.isEmpty {
            clearChartData()
            hideChartViews()
            return
        }

        clearChartData()
        showChartViews()
        let timelineRange = resolveGlobalTimelineRange(from: chartViewData)

        for data in chartViewData {
            let view = chartView(for: data.variant)
            populateChartView(
                from: data,
                displayType: data.variant.type,
                unit: data.variant.type.unit(for: data.variant, settings: settings),
                settings: settings,
                view: view
            )
        }

        chartViews.forEach {
            $0.setSettings(settings: settings)
            $0.setXAxisRenderer(
                showAll: settings.chartShowAll,
                timelineRange: timelineRange
            )
        }

        DispatchQueue.main.async { [weak self] in
            self?.view.layoutIfNeeded()
            if let variant = self?.pendingScrollVariant {
                self?.pendingScrollVariant = nil
                self?.scroll(to: variant)
            }
        }
    }

    func updateChartViewData(
        _ entries: [MeasurementDisplayVariant: [ChartDataEntry]],
        isFirstEntry: Bool,
        firstEntry: RuuviMeasurement?,
        settings: RuuviLocalSettings
    ) {
        self.settings = settings
        showChartViews()

        entries.forEach { variant, dataEntries in
            let view = chartView(for: variant)
            view.setSettings(settings: settings)
            view.updateDataSet(
                with: dataEntries,
                isFirstEntry: isFirstEntry,
                firstEntry: firstEntry,
                showAlertRangeInGraph: settings.showAlertsRangeInGraph
            )
        }

        if settings.chartShowAll {
            let timelineRange = resolveGlobalTimelineRange(from: chartViews)
            chartViews.forEach {
                $0.setSettings(settings: settings)
                $0.setXAxisRenderer(
                    showAll: true,
                    timelineRange: timelineRange
                )
            }
        }
    }

    func updateLatestMeasurement(
        _ entries: [MeasurementDisplayVariant: ChartDataEntry?],
        alertStates: [MeasurementDisplayVariant: Bool],
        settings: RuuviLocalSettings
    ) {
        self.settings = settings
        entries.forEach { variant, entry in
            let view = chartView(for: variant)
            view.updateLatest(
                with: entry,
                isHighlighted: alertStates[variant] ?? false,
                type: variant.type,
                measurementService: measurementService
            )
        }
    }

    func updateLatestAlertStates(_ alertStates: [MeasurementDisplayVariant: Bool]) {
        alertStates.forEach { variant, isHighlighted in
            chartView(for: variant)
                .updateLatestAlertState(isHighlighted: isHighlighted)
        }
    }

    func setHasChartData(_ hasData: Bool) {
        hasChartData = hasData
        shouldHideChartsForLoading = false
        guard isViewLoaded else { return }
        applyHasChartDataState()
    }

    func setChartLoading(hideCharts: Bool) {
        hasChartData = nil
        hideNoDataLabel()
        if hideCharts {
            shouldHideChartsForLoading = true
            hideChartViews()
        } else {
            shouldHideChartsForLoading = false
        }
    }

    func localize() {
        syncButton.updateTitle(with: RuuviLocalization.TagCharts.Sync.title)
    }

    func showBluetoothDisabled(userDeclined: Bool) {
        // The simulator has no Bluetooth: don't show this alert on every launch there.
        guard !UIDevice.isSimulator else { return }
        let title = RuuviLocalization.TagCharts.BluetoothDisabledAlert.title
        let message = RuuviLocalization.TagCharts.BluetoothDisabledAlert.message
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(
            title: RuuviLocalization.PermissionPresenter.settings,
            style: .default,
            handler: { _ in
                guard let url = URL(string: userDeclined ?
                                    UIApplication.openSettingsURLString : "App-prefs:Bluetooth"),
                      UIApplication.shared.canOpenURL(url)
                else {
                    return
                }
                UIApplication.shared.open(url)
            }
        ))
        alertVC.addAction(UIAlertAction(title: RuuviLocalization.ok, style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }

    func showClearConfirmationDialog(for snapshot: RuuviTagCardSnapshot) {
        let title = RuuviLocalization.clearLocalHistory
        let message = RuuviLocalization.clearLocalHistoryDescription
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: RuuviLocalization.cancel, style: .cancel, handler: nil))
        let actionTitle = RuuviLocalization.TagCharts.Clear.title
        alertVC.addAction(UIAlertAction(title: actionTitle, style: .destructive, handler: { [weak self] _ in
            self?.output?.viewDidConfirmToClear(for: snapshot)

        }))
        present(alertVC, animated: true)
    }

    func setSync(status: GraphGattSyncStatus?, for snapshot: RuuviTagCardSnapshot) {
        guard self.snapshot?.id == snapshot.id else { return }
        if let status {
            showSyncStatusLabel(show: true)
            switch status {
            case .queued:
                syncStatusLabel.text = RuuviLocalization.TagCharts.Status.queued
            case .progress(let progress):
                switch progress {
                case .connecting:
                    syncStatusLabel.text = RuuviLocalization.TagCharts.Status.connecting
                case .serving:
                    syncStatusLabel.text = RuuviLocalization.TagCharts.Status.serving
                case let .reading(points):
                    let format = RuuviLocalization.readingHistoryX
                    syncStatusLabel.text = format(Float(points))
                case .disconnecting:
                    syncStatusLabel.text = RuuviLocalization.TagCharts.Status.disconnecting
                case .success:
                    syncStatusLabel.text = RuuviLocalization.TagCharts.Status.success
                case .failure:
                    syncStatusLabel.text = RuuviLocalization.TagCharts.Status.error
                }
            }
        } else {
            showSyncStatusLabel(show: false)
        }
    }

    func setSyncProgressViewHidden() {
        showSyncStatusLabel(show: false)
    }

    func showSyncInProgressDialog() {
        let alertVC = UIAlertController(
            title: RuuviLocalization.synchronisation,
            message: RuuviLocalization.TagCharts.Dismiss.Alert.message,
            preferredStyle: .alert
        )
        alertVC.addAction(UIAlertAction(title: RuuviLocalization.ok, style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }

    func showFailedToSyncIn() {
        let title = RuuviLocalization.TagCharts.FailedToSyncDialog.title
        let message = RuuviLocalization.TagCharts.FailedToSyncDialog.message
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: RuuviLocalization.ok, style: .cancel, handler: nil))
        alertVC.addAction(UIAlertAction(
            title: RuuviLocalization.TagCharts.TryAgain.title,
            style: .default,
            handler: { [weak self] _ in
                guard let self else { return }
                self.output?.viewDidTriggerSync(for: self.snapshot)
            }
        ))
        present(alertVC, animated: true)
    }

    func showSwipeUpInstruction() {
        gestureInstructor.show(.swipeUp, after: 0.1)
    }

    func showSyncConfirmationDialog(for snapshot: RuuviTagCardSnapshot) {
        let title = RuuviLocalization.synchronisation
        let message = RuuviLocalization.gattSyncDescription
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: RuuviLocalization.close, style: .cancel, handler: nil))
        let actionTitle = RuuviLocalization.doNotShowAgain
        alertVC.addAction(UIAlertAction(
            title: actionTitle,
            style: .default,
            handler: { [weak self] _ in
                self?.output?.viewDidTriggerDoNotShowSyncDialog()
            }
        ))
        present(alertVC, animated: true)
    }

    func showSyncAbortAlert(source: GraphHistoryAbortSyncSource) {
        let title = RuuviLocalization.TagCharts.DeleteHistoryConfirmationDialog.title
        var showAbortSyncMessage: Bool = false
        if case .inPageCancel = source {
            showAbortSyncMessage = true
        }
        let message = showAbortSyncMessage ? RuuviLocalization.TagCharts.AbortSync.Alert.message :
            RuuviLocalization.TagCharts.Dismiss.Alert.message

        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: RuuviLocalization.ok, style: .cancel, handler: nil))
        let actionTitle = RuuviLocalization.TagCharts.AbortSync.Button.title
        alertVC.addAction(UIAlertAction(title: actionTitle, style: .destructive, handler: { [weak self] _ in
            self?.output?.viewDidConfirmAbortSync(source: source)
        }))
        present(alertVC, animated: true)
    }

    func showSyncAbortAlertForSwipe(to index: Int) {
        let title = RuuviLocalization.TagCharts.DeleteHistoryConfirmationDialog.title
        let message = RuuviLocalization.TagCharts.Dismiss.Alert.message
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: RuuviLocalization.ok, style: .cancel, handler: nil))
        let actionTitle = RuuviLocalization.TagCharts.AbortSync.Button.title
        alertVC.addAction(UIAlertAction(title: actionTitle, style: .destructive, handler: { [weak self] _ in
            self?.output?
                .viewDidConfirmAbortSync(source: .rootNavigationButton(index))
        }))
        present(alertVC, animated: true)
    }

    func showExportSheet(with path: URL) {
        let vc = UIActivityViewController(
            activityItems: [path],
            applicationActivities: []
        )
        vc.excludedActivityTypes = [
            UIActivity.ActivityType.assignToContact,
            UIActivity.ActivityType.saveToCameraRoll,
            UIActivity.ActivityType.postToFlickr,
            UIActivity.ActivityType.postToVimeo,
            UIActivity.ActivityType.postToTencentWeibo,
            UIActivity.ActivityType.postToTwitter,
            UIActivity.ActivityType.postToFacebook,
            UIActivity.ActivityType.openInIBooks,
        ]
        vc.popoverPresentationController?.permittedArrowDirections = .up
        vc.popoverPresentationController?.sourceView = moreButton
        present(vc, animated: true)
    }

    func showLongerHistoryDialog() {
        let title = RuuviLocalization.longerHistoryTitle
        let message = RuuviLocalization.longerHistoryMessage
        let controller = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        controller.addAction(UIAlertAction(
            title: RuuviLocalization.ok,
            style: .cancel,
            handler: nil
        ))
        present(controller, animated: true)
    }

    func showGraphLongPressTutorialDialog() {
        let message = RuuviLocalization.tutorialChartLongTap
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC
            .addAction(
                UIAlertAction(
                    title: RuuviLocalization.ok,
                    style: .cancel,
                    handler: nil
                )
            )
        alertVC.addAction(UIAlertAction(
            title: RuuviLocalization.doNotShowAgain,
            style: .default,
            handler: { [weak self] _ in
                self?.output?.viewDidTriggerDoNotShowGraphLongPressTutorialDialog()
            }
        ))
        present(alertVC, animated: true)
    }
}

extension CardsGraphViewController {
    private func updateChartsCollectionConstaints(
        from variants: [MeasurementDisplayVariant],
        withAnimation: Bool = false
    ) {
        if variants.isEmpty {
            chartViews.removeAll()
            hideChartViews()
            return
        }

        guard viewIsVisible, scrollView.frame.height > 0 else {
            needsDeferredLayoutUpdate = true
            pendingScrollVariant = pendingScrollVariant ?? variants.first
            return
        }
        needsDeferredLayoutUpdate = false
        updateScrollviewBehaviour()

        chartViews = variants.map { chartView(for: $0) }
        rebuildChartsStack(with: variants)

        let scrollViewHeight = scrollView.frame.height
        let itemCount = variants.count

        let shouldShowCharts = !shouldHideChartsForLoading && (hasChartData ?? true)
        variants.forEach { variant in
            let view = chartView(for: variant)
            view.isHidden = !shouldShowCharts
            updateChartViewHeight(
                for: variant,
                totalHeight: scrollViewHeight,
                itemCount: itemCount,
                animated: withAnimation
            )
        }

        let hiddenVariants = Set(chartViewCache.keys).subtracting(variants)
        hiddenVariants.forEach { variant in
            chartViewCache[variant]?.isHidden = true
            chartHeightConstraints[variant]?.constant = 0
        }

        DispatchQueue.main.async { [weak self] in
            self?.view.layoutIfNeeded()
            self?.scrollView.layoutIfNeeded()
            if let variant = self?.pendingScrollVariant {
                self?.pendingScrollVariant = nil
                self?.scroll(to: variant)
            }
        }
    }

    private func chartView(for variant: MeasurementDisplayVariant) -> CardsGraphView {
        if let cached = chartViewCache[variant] {
            return cached
        }

        let view = CardsGraphView(variant: variant)
        view.chartDelegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        chartViewCache[variant] = view
        ensureHeightConstraint(for: view, variant: variant)
        return view
    }

    private func visibleChartView(
        for variant: MeasurementDisplayVariant
    ) -> CardsGraphView? {
        chartViewCache[variant]
    }

    private func ensureHeightConstraint(
        for view: CardsGraphView,
        variant: MeasurementDisplayVariant
    ) {
        if chartHeightConstraints[variant] != nil {
            return
        }
        let constraint = view.heightAnchor.constraint(equalToConstant: 0)
        constraint.isActive = true
        chartHeightConstraints[variant] = constraint
    }

    private func rebuildChartsStack(
        with variants: [MeasurementDisplayVariant]
    ) {
        // Re-adding every chart is only needed when the charts change, not when only their
        // heights do (rotation, window resizing, the size menu).
        let views = variants.map { chartView(for: $0) }
        guard !chartsStackView.arrangedSubviews.elementsEqual(views, by: { $0 === $1 }) else {
            return
        }

        chartsStackView.arrangedSubviews.forEach {
            chartsStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        variants.forEach { variant in
            let view = chartView(for: variant)
            chartsStackView.addArrangedSubview(view)
        }
    }

    private func variant(for view: CardsGraphView) -> MeasurementDisplayVariant? {
        return chartViewCache.first(where: { $0.value === view })?.key
    }

    private func getItemHeight(
        from totalHeight: CGFloat,
        count: CGFloat
    ) -> CGFloat {
        if usesPagedChartLayout {
            return totalHeight
        } else {
            let effectiveChartsPerScreen = count > 2 ? CGFloat(max(chartsPerScreen, 1)) : count
            return totalHeight / effectiveChartsPerScreen
        }
    }

    /// Follows the scroll view's size and the size classes on every layout pass (rotation, window
    /// resizing, the sensor name wrapping, the footer collapsing). Cheap when nothing changed: a new
    /// height only updates the chart height constants, and only a switch between the paged and the
    /// stacked layout re-applies paging, the fade and the size menu. The charts are never rebuilt.
    private func applyChartLayoutIfNeeded() {
        let scrollViewHeight = scrollView.bounds.height
        guard scrollViewHeight > 0 else { return }
        let layout = ChartLayout(isPaged: usesPagedChartLayout, scrollViewHeight: scrollViewHeight)
        guard layout != appliedChartLayout else { return }
        let previousLayout = appliedChartLayout
        appliedChartLayout = layout

        let hasChartStack = !needsDeferredLayoutUpdate && !chartViews.isEmpty
        if hasChartStack {
            chartModules.forEach { variant in
                updateChartViewHeight(
                    for: variant,
                    totalHeight: scrollViewHeight,
                    itemCount: chartModules.count,
                    animated: false
                )
            }
        }

        if layout.isPaged != previousLayout?.isPaged {
            updateScrollviewBehaviour()
            moreButton.updateMenu(with: moreButtonOptions(showChartStat: showChartStat))
            // A rotation tells the presenter from its completion, as before.
            if activeSizeTransitionCount == 0, graphIsVisibleForUser {
                output?.viewDidTransition()
            }
        } else if layout.isPaged, hasChartStack, let previousLayout {
            if activeSizeTransitionCount == 0 {
                keepCurrentPage(previousPageHeight: previousLayout.scrollViewHeight)
            } else if let sizeTransitionStartPage {
                // The offset may already be clamped to the new size here, so a size transition
                // (a window resize, a Duo display move) keeps the page it started on instead.
                showPage(sizeTransitionStartPage)
            }
        }
    }

    /// Keeps the chart that was on screen when the page height changes in the paged layout (a window
    /// resize, the sensor name wrapping), instead of leaving a page boundary in the middle of a chart.
    private func keepCurrentPage(previousPageHeight: CGFloat) {
        guard previousPageHeight > 0 else { return }
        showPage((scrollView.contentOffset.y / previousPageHeight).rounded())
    }

    /// Scrolls the paged layout to `page` at the current page height, unless the user is scrolling.
    private func showPage(_ page: CGFloat) {
        guard !chartModules.isEmpty,
              !scrollView.isDragging,
              !scrollView.isDecelerating else {
            return
        }
        let pageIndex = min(max(page, 0), CGFloat(chartModules.count - 1))
        let offsetY = pageIndex * scrollView.bounds.height
        guard offsetY != scrollView.contentOffset.y else { return }
        scrollView.setContentOffset(
            CGPoint(x: scrollView.contentOffset.x, y: offsetY),
            animated: false
        )
    }

    private func updateScrollviewBehaviour() {
        if isMarkerInteractionActive {
            scrollView.isScrollEnabled = false
            scrollView.showsVerticalScrollIndicator = false
            updateScrollInsetsForFade()
            scrollView.edgeFader?.updateFadeMask()
            return
        }
        if usesPagedChartLayout {
            scrollView.isPagingEnabled = true
            scrollView.isScrollEnabled = true
            scrollView.showsVerticalScrollIndicator = true
        } else {
            let effectiveChartsPerScreen = chartModules.count > 2 ?
                chartsPerScreen : chartModules.count
            let needsScrolling = chartModules.count > effectiveChartsPerScreen
            scrollView.isPagingEnabled = false
            scrollView.isScrollEnabled = needsScrolling
            scrollView.showsVerticalScrollIndicator = needsScrolling
        }
        updateScrollInsetsForFade()
        scrollView.edgeFader?.updateFadeMask()
    }

    private func updateScrollInsetsForFade() {
        let fadeTransitionHeight = currentFadeTransitionHeight()
        if let edgeFader = scrollView.edgeFader,
           edgeFader.configuration.fadeTransitionHeight != fadeTransitionHeight {
            // Setting the configuration re-applies the fade mask.
            edgeFader.configuration.fadeTransitionHeight = fadeTransitionHeight
        }
        let insetHeight = scrollView.isScrollEnabled ? fadeTransitionHeight : 0
        var inset = scrollView.contentInset
        inset.bottom = insetHeight
        scrollView.contentInset = inset
        scrollView.scrollIndicatorInsets = inset
    }

    /// The edge fader and the bottom inset use the same height, which follows the chart layout.
    private func currentFadeTransitionHeight() -> CGFloat {
        usesPagedChartLayout ? FadeTransitionHeight.paged : FadeTransitionHeight.stacked
    }

    private func updateChartViewHeight(
        for variant: MeasurementDisplayVariant,
        totalHeight: CGFloat,
        itemCount: Int,
        animated: Bool
    ) {
        guard let constraint = chartHeightConstraints[variant], itemCount > 0 else {
            return
        }

        let targetHeight = getItemHeight(
            from: totalHeight,
            count: CGFloat(itemCount)
        )

        if animated {
            UIView.animate(withDuration: 0.2, animations: { [weak self] in
                constraint.constant = targetHeight
                self?.view.layoutIfNeeded()
            })
        } else {
            constraint.constant = targetHeight
        }
    }

    private func populateChartView(
        from data: RuuviGraphViewDataModel,
        displayType: MeasurementType,
        unit: String,
        settings: RuuviLocalSettings,
        view: CardsGraphView
    ) {
        view.setChartLabel(
            type: displayType,
            measurementService: measurementService,
            unit: unit
        )
        view.underlyingView.data = data.chartData
        view.underlyingView.lowerAlertValue = data.lowerAlertValue
        view.underlyingView.upperAlertValue = data.upperAlertValue
        view.setSettings(settings: settings)
        view.localize()
        view.setYAxisLimit(min: data.chartData?.yMin ?? 0, max: data.chartData?.yMax ?? 0)
        view.setChartStatVisible(show: showChartStat)

        // Calculation of min/max depends on the chart
        // internal viewport state. Give it a chance to
        // redraw itself before calculation.
        // Fixes https://github.com/ruuvi/com.ruuvi.station.ios/issues/1758
        DispatchQueue.main.async { [weak self] in
            guard let sSelf = self else { return }
            sSelf.calculateMinMaxForChart(for: view)
            if sSelf.showAlertRangeInGraph {
                sSelf.calculateAlertFillIfNeeded(for: view)
            }
        }
        if showAlertRangeInGraph {
            calculateAlertFillIfNeeded(for: view)
        }
    }

    private func clearChartData() {
        chartViewCache.values.forEach {
            $0.clearChartData()
            $0.underlyingView.highlightValue(nil)
        }
    }

    private func resetXAxisTimeline() {
        chartViewCache.values.forEach {
            $0.resetCustomAxisMinMax()
        }
    }

    private func resolveGlobalTimelineRange(
        from chartViewData: [RuuviGraphViewDataModel]
    ) -> ClosedRange<Double>? {
        let ranges = chartViewData.compactMap { model -> ClosedRange<Double>? in
            guard let dataSet = model.chartData?.dataSets.first as? LineChartDataSet,
                  !dataSet.entries.isEmpty else {
                return nil
            }
            return resolveTimelineRange(from: dataSet.entries)
        }

        return mergeTimelineRanges(ranges)
    }

    private func resolveGlobalTimelineRange(
        from chartViews: [CardsGraphView]
    ) -> ClosedRange<Double>? {
        let ranges = chartViews.compactMap { view -> ClosedRange<Double>? in
            guard let dataSet = view.underlyingView.data?.dataSets.first as? LineChartDataSet,
                  !dataSet.entries.isEmpty else {
                return nil
            }
            return resolveTimelineRange(from: dataSet.entries)
        }

        return mergeTimelineRanges(ranges)
    }

    private func resolveTimelineRange(
        from entries: [ChartDataEntry]
    ) -> ClosedRange<Double>? {
        let xValues = entries.map(\.x)
        guard let minX = xValues.min(),
              let maxX = xValues.max(),
              minX.isFinite,
              maxX.isFinite else {
            return nil
        }
        return minX...maxX
    }

    private func mergeTimelineRanges(
        _ ranges: [ClosedRange<Double>]
    ) -> ClosedRange<Double>? {
        guard let minX = ranges.map(\.lowerBound).min(),
              let maxX = ranges.map(\.upperBound).max() else {
            return nil
        }
        return minX...maxX
    }

    // MARK: - UI RELATED METHODS

    private func showSyncStatusLabel(show: Bool) {
        syncProgressView.alpha = show ? 1 : 0
        syncButton.alpha = show ? 0 : 1
    }

    private func hideChartViews() {
        chartViewCache.values.forEach {
            $0.isHidden = true
        }
    }

    private func showChartViews() {
        chartViews.forEach {
            $0.isHidden = false
        }
    }

    private func applyHasChartDataState() {
        guard let hasData = hasChartData else { return }
        if hasData {
            hideNoDataLabel()
            showChartViews()
        } else {
            showNoDataLabel()
            hideChartViews()
        }
    }

    private func hideNoDataLabel() {
        if noDataLabel.alpha != 0 {
            noDataLabel.alpha = 0
        }
    }

    private func showNoDataLabel() {
        if noDataLabel.alpha != 1 {
            noDataLabel.alpha = 1
        }
    }

    private func calculateAlertFillIfNeeded(for view: CardsGraphView) {
        guard let data = view.underlyingView.data,
              let dataSet = data.dataSets.first as? LineChartDataSet else {
            return
        }

        let upperAlertValue = view.underlyingView.upperAlertValue
        let lowerAlertValue = view.underlyingView.lowerAlertValue
        guard upperAlertValue != nil || lowerAlertValue != nil else {
            dataSet.hasAlertRange = false
            return
        }

        let shouldKeepAlertRangeVisible = dataSet.hasAlertRange

        // Update limits without changing whether the current alert range is visible.
        dataSet.lowerAlertLimit = lowerAlertValue.map { CGFloat($0) } ?? .nan
        dataSet.upperAlertLimit = upperAlertValue.map { CGFloat($0) } ?? .nan
        dataSet.alertColor = RuuviColor.graphAlertColor.color
        dataSet.hasAlertRange = shouldKeepAlertRangeVisible
    }

    private func calculateMinMaxForChart(for view: CardsGraphView) {
        guard let data = view.underlyingView.data,
              let dataSet = data.dataSets.first as? LineChartDataSet else {
            return
        }

        let lowestVisibleX = view.underlyingView.lowestVisibleX
        let highestVisibleX = view.underlyingView.highestVisibleX

        var minVisibleYValue = Double.greatestFiniteMagnitude
        var maxVisibleYValue = -Double.greatestFiniteMagnitude

        dataSet.entries.forEach { entry in
            if entry.x >= lowestVisibleX, entry.x <= highestVisibleX {
                minVisibleYValue = min(minVisibleYValue, entry.y)
                maxVisibleYValue = max(maxVisibleYValue, entry.y)
            }
        }

        if minVisibleYValue == Double.greatestFiniteMagnitude {
            minVisibleYValue = 0
        }
        if maxVisibleYValue == -Double.greatestFiniteMagnitude {
            maxVisibleYValue = 0
        }

        let averageYValue = calculateVisibleAverage(
            chartView: view.underlyingView,
            dataSet: dataSet
        )

        let measurementType = variant(for: view).map { $0.type } ?? view.measurementType

        view.setChartStat(
            min: minVisibleYValue,
            max: maxVisibleYValue,
            avg: averageYValue,
            type: measurementType,
            measurementService: measurementService
        )
    }

    /**
     Calculate the average value of visible data points on a `LineChartView`.
     This function computes the average by considering the area under the curve
     formed by the visible data points and then divides it by the width of the visible x-range.
     The area under the curve is approximated using the trapezoidal rule.

     - Parameters:
     - chartView: The `LineChartView` instance whose visible range's average needs to be calculated.
     - dataSet: The `LineChartDataSet` containing data points to be considered.

     - Returns: The average value of visible data points.

     - Note:
     The function uses the trapezoidal rule for approximation. The formula for the trapezoidal rule is:
     A = (b - a) * (f(a) + f(b)) / 2
     Where:
     - A is the area of the trapezium.
     - a and b are the x-coordinates of the two data points.
     - f(a) and f(b) are the y-coordinates (or values) of the two data points.

     The average is then computed as the total area divided by the width of the visible x-range.
     */
    private func calculateVisibleAverage(chartView: LineChartView, dataSet: LineChartDataSet) -> Double {
        // Get the x-values defining the visible range of the chart.
        let lowestVisibleX = chartView.lowestVisibleX
        let highestVisibleX = chartView.highestVisibleX

        // Filter out the entries that lie within the visible range.
        let visibleEntries = dataSet.entries.filter { $0.x >= lowestVisibleX && $0.x <= highestVisibleX }

        // If there are no visible entries, return an average of 0.
        guard !visibleEntries.isEmpty else { return 0.0 }

        var totalArea = 0.0
        // Compute the area under the curve for each pair of consecutive points.
        for i in 1 ..< visibleEntries.count {
            let x1 = visibleEntries[i - 1].x
            let y1 = visibleEntries[i - 1].y
            let x2 = visibleEntries[i].x
            let y2 = visibleEntries[i].y

            // Calculate the area of the trapezium formed by two consecutive data points.
            let area = (x2 - x1) * (y1 + y2) / 2.0
            totalArea += area
        }

        // Calculate the width of the visible x-range.
        let timeSpan = visibleEntries.last!.x - visibleEntries.first!.x

        // If all visible data points have the same x-value, simply return the average of their y-values.
        if timeSpan == 0 {
            return visibleEntries.map(\.y).reduce(0, +) / Double(visibleEntries.count)
        }

        // Compute the average using the trapezoidal rule.
        return totalArea / timeSpan
    }

    private func ensureLayoutComplete() {
        view.layoutIfNeeded()
        scrollView.layoutIfNeeded()
    }

    private func scrollToTarget(
        _ targetFrame: CGRect,
        targetView: CardsGraphView
    ) {
        let newOffset = calculateNewOffset(for: targetFrame)
        let clampedOffset = clampOffset(newOffset)
        scrollView.setContentOffset(clampedOffset, animated: false)
        if shouldHighlightOnScroll {
            scheduleHighlightAnimation(for: targetView)
            shouldHighlightOnScroll = false
        }
    }

    private func calculateNewOffset(for targetFrame: CGRect) -> CGPoint {
        var newOffset = scrollView.contentOffset

        if scrollView.isPagingEnabled {
            newOffset.y = calculatePageOffset(for: targetFrame)
        } else {
            newOffset.y = calculateRegularOffset(for: targetFrame)
        }

        return newOffset
    }

    private func calculatePageOffset(for targetFrame: CGRect) -> CGFloat {
        let pageHeight = scrollView.bounds.height
        let maxOffset = max(0, scrollView.contentSize.height - pageHeight)
        let targetPageIndex = floor(targetFrame.minY / pageHeight)
        return min(targetPageIndex * pageHeight, maxOffset)
    }

    private func calculateRegularOffset(for targetFrame: CGRect) -> CGFloat {
        let visibleRect = scrollView.visibleRect
        let currentOffset = scrollView.contentOffset.y

        if targetFrame.minY < visibleRect.minY {
            // Target is above - scroll up to show top
            return targetFrame.minY
        } else if targetFrame.maxY > visibleRect.maxY {
            // Target is below - scroll down
            let idealOffset = targetFrame.maxY - scrollView.bounds.height
            let maxOffset = scrollView.contentSize.height - scrollView.bounds.height
            let calculatedOffset = min(idealOffset, maxOffset)

            // If target is taller than visible area, prioritize showing the top
            return targetFrame.height > scrollView.bounds.height ? targetFrame.minY : calculatedOffset
        }

        return currentOffset
    }

    private func clampOffset(_ offset: CGPoint) -> CGPoint {
        let maxY = scrollView.contentSize.height - scrollView.bounds.height
        return CGPoint(
            x: offset.x,
            y: max(0, min(offset.y, maxY))
        )
    }

    private func scheduleHighlightAnimation(for targetView: CardsGraphView) {
        DispatchQueue.main.asyncAfter(deadline: .now() + highlightAnimationDelay) { [weak self] in
            self?.highlightTarget(targetView)
        }
    }

    private func highlightTarget(_ targetView: CardsGraphView) {
        addHighlightAnimation(to: targetView)
    }

    private func addHighlightAnimation(to chartView: CardsGraphView) {
        // Create a highlight overlay
        let highlightView = UIView()
        highlightView.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        highlightView.alpha = 0
        highlightView.translatesAutoresizingMaskIntoConstraints = false

        chartView.addSubview(highlightView)
        NSLayoutConstraint.activate([
            highlightView.topAnchor.constraint(equalTo: chartView.topAnchor),
            highlightView.leadingAnchor.constraint(equalTo: chartView.leadingAnchor),
            highlightView.trailingAnchor.constraint(equalTo: chartView.trailingAnchor),
            highlightView.bottomAnchor.constraint(equalTo: chartView.bottomAnchor),
        ])

        // Animate the highlight
        UIView.animate(withDuration: 0.4, animations: {
            highlightView.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 0.1, options: [], animations: {
                highlightView.alpha = 0
            }) { _ in
                highlightView.removeFromSuperview()
            }
        }

        // Add a subtle scale animation to the chart
        let originalTransform = chartView.transform
        UIView.animate(withDuration: 0.15, animations: {
            chartView.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
        }) { _ in
            UIView.animate(withDuration: 0.15, animations: {
                chartView.transform = originalTransform
            })
        }
    }
}

// MARK: - UIScrollViewDelegate
extension CardsGraphViewController: UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_: UIScrollView) {
        output?.viewDidStartScrolling()
    }

    func scrollViewDidEndDragging(_: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            output?.viewDidEndScrolling()
        }
    }

    func scrollViewDidEndDecelerating(_: UIScrollView) {
        output?.viewDidEndScrolling()
    }
}

private extension Int {
    var days: String {
        switch self {
        case 1:
            RuuviLocalization.day1
        case 2:
            RuuviLocalization.day2
        case 3:
            RuuviLocalization.day3
        case 4:
            RuuviLocalization.day4
        case 5:
            RuuviLocalization.day5
        case 6:
            RuuviLocalization.day6
        case 7:
            RuuviLocalization.day7
        case 8:
            RuuviLocalization.day8
        case 9:
            RuuviLocalization.day9
        case 10:
            RuuviLocalization.day10
        default:
            RuuviLocalization.dayX(Float(self))
        }
    }
}

private extension UIScrollView {
    var visibleRect: CGRect {
        CGRect(
            x: contentOffset.x,
            y: contentOffset.y,
            width: bounds.width,
            height: bounds.height
        )
    }
}

// swiftlint:enable type_body_length
