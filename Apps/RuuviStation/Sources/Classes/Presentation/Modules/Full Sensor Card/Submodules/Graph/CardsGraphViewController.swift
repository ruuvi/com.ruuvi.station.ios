import BTKit
import DGCharts
// swiftlint:disable file_length
import Foundation
import GestureInstructions
import RuuviLocal
import RuuviLocalization
import RuuviOntology
import RuuviService
import RuuviStorage
import UIKit

// swiftlint:disable type_body_length
class CardsGraphViewController: UIViewController {
    weak var output: CardsGraphViewOutput?

    init(output: CardsGraphViewOutput) {
        self.output = output
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var chartModules: [MeasurementType] = [] {
        didSet {
            moreButton.updateMenu(
                with:
                    moreButtonOptions(
                        showChartStat: showChartStat,
                        compactChartView: compactChartView
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
                        showChartStat: showChartStat,
                        compactChartView: compactChartView
                    )
            )
        }
    }

    var compactChartView: Bool = true {
        didSet {
            updateChartsCollectionConstaints(from: self.chartModules)
            moreButton.updateMenu(
                with:
                    moreButtonOptions(
                        showChartStat: showChartStat,
                        compactChartView: compactChartView
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

    private var chartViews: [TagChartsView] = []
    private var pendingScrollToMeasurement: MeasurementType?

    private var isLandscapeLayout: Bool {
        if let interfaceOrientation = view.window?.windowScene?.interfaceOrientation {
            return interfaceOrientation.isLandscape
        }
        if view.bounds.width > 0, view.bounds.height > 0 {
            return view.bounds.width > view.bounds.height
        }
        return UIScreen.main.bounds.width > UIScreen.main.bounds.height
    }

    private lazy var graphScrollEdgeFadeConfiguration: ScrollViewEdgeFader.Configuration = {
        var configuration = ScrollViewEdgeFader.Configuration()
        configuration.fadeTransitionHeight = 30
        configuration.landscapeFadeTransitionHeight = 10
        return configuration
    }()

    lazy var temperatureChartView = TagChartsView(graphType: .temperature)
    lazy var humidityChartView = TagChartsView(graphType: .anyHumidity)
    lazy var pressureChartView = TagChartsView(graphType: .pressure)
    lazy var aqiChartView = TagChartsView(graphType: .aqi)
    lazy var co2ChartView = TagChartsView(graphType: .co2)
    lazy var pm25ChartView = TagChartsView(graphType: .pm25)
    lazy var vocChartView = TagChartsView(graphType: .voc)
    lazy var noxChartView = TagChartsView(graphType: .nox)
    lazy var luminosityChartView = TagChartsView(graphType: .luminosity)
    lazy var soundChartView = TagChartsView(graphType: .soundInstant)

    private var temperatureChartViewHeight: NSLayoutConstraint!
    private var humidityChartViewHeight: NSLayoutConstraint!
    private var pressureChartViewHeight: NSLayoutConstraint!
    private var aqiChartViewHeight: NSLayoutConstraint!
    private var co2ChartViewHeight: NSLayoutConstraint!
    private var pm25ChartViewHeight: NSLayoutConstraint!
    private var vocChartViewHeight: NSLayoutConstraint!
    private var noxChartViewHeight: NSLayoutConstraint!
    private var luminosityChartViewHeight: NSLayoutConstraint!
    private var soundChartViewHeight: NSLayoutConstraint!

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
    private let maximumHistoryLimit: Int = 10 // Days
    private let highlightAnimationDelay: TimeInterval = 0.3

    private var chartViewData: [TagChartViewData] = []
    private var settings: RuuviLocalSettings!

    // MARK: - LIFECYCLE

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        localize()
        output?.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hideNoDataLabel()
        output?.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        hideNoDataLabel()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateChartsCollectionConstaints(
            from: chartModules,
            withAnimation: false
        )
    }

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        coordinator.animate(alongsideTransition: { _ in
        }, completion: { [weak self] _ in
            guard let sSelf = self else { return }
            sSelf.updateScrollviewBehaviour()
            sSelf.updateChartsCollectionConstaints(
                from: sSelf.chartModules,
                withAnimation: true
            )
            self?.output?.viewDidTransition()
        })
        super.viewWillTransition(to: size, with: coordinator)
        gestureInstructor.dismissThenResume()
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

        scrollView.addSubview(aqiChartView)
        aqiChartView.anchor(
            top: scrollView.topAnchor,
            leading: scrollView.leadingAnchor,
            bottom: nil,
            trailing: scrollView.trailingAnchor
        )
        aqiChartView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
        aqiChartViewHeight = aqiChartView.heightAnchor.constraint(equalToConstant: 0)
        aqiChartViewHeight.isActive = true
        aqiChartView.chartDelegate = self

        scrollView.addSubview(co2ChartView)
        co2ChartView.anchor(
            top: aqiChartView.bottomAnchor,
            leading: scrollView.leadingAnchor,
            bottom: nil,
            trailing: scrollView.trailingAnchor
        )
        co2ChartView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
        co2ChartViewHeight = co2ChartView.heightAnchor.constraint(equalToConstant: 0)
        co2ChartViewHeight.isActive = true
        co2ChartView.chartDelegate = self

        scrollView.addSubview(pm25ChartView)
        pm25ChartView.anchor(
            top: co2ChartView.bottomAnchor,
            leading: scrollView.leadingAnchor,
            bottom: nil,
            trailing: scrollView.trailingAnchor
        )
        pm25ChartView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
        pm25ChartViewHeight = pm25ChartView.heightAnchor.constraint(equalToConstant: 0)
        pm25ChartViewHeight.isActive = true
        pm25ChartView.chartDelegate = self

        scrollView.addSubview(vocChartView)
        vocChartView.anchor(
            top: pm25ChartView.bottomAnchor,
            leading: scrollView.leadingAnchor,
            bottom: nil,
            trailing: scrollView.trailingAnchor
        )
        vocChartView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
        vocChartViewHeight = vocChartView.heightAnchor.constraint(equalToConstant: 0)
        vocChartViewHeight.isActive = true
        vocChartView.chartDelegate = self

        scrollView.addSubview(noxChartView)
        noxChartView.anchor(
            top: vocChartView.bottomAnchor,
            leading: scrollView.leadingAnchor,
            bottom: nil,
            trailing: scrollView.trailingAnchor
        )
        noxChartView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
        noxChartViewHeight = noxChartView.heightAnchor.constraint(equalToConstant: 0)
        noxChartViewHeight.isActive = true
        noxChartView.chartDelegate = self

        scrollView.addSubview(temperatureChartView)
        temperatureChartView.anchor(
            top: noxChartView.bottomAnchor,
            leading: scrollView.leadingAnchor,
            bottom: nil,
            trailing: scrollView.trailingAnchor
        )
        temperatureChartView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
        temperatureChartViewHeight = temperatureChartView.heightAnchor.constraint(equalToConstant: 0)
        temperatureChartViewHeight.isActive = true
        temperatureChartView.chartDelegate = self

        scrollView.addSubview(humidityChartView)
        humidityChartView.anchor(
            top: temperatureChartView.bottomAnchor,
            leading: scrollView.leadingAnchor,
            bottom: nil,
            trailing: scrollView.trailingAnchor
        )
        humidityChartView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
        humidityChartViewHeight = humidityChartView.heightAnchor.constraint(equalToConstant: 0)
        humidityChartViewHeight.isActive = true
        humidityChartView.chartDelegate = self

        scrollView.addSubview(pressureChartView)
        pressureChartView.anchor(
            top: humidityChartView.bottomAnchor,
            leading: scrollView.leadingAnchor,
            bottom: nil,
            trailing: scrollView.trailingAnchor
        )
        pressureChartView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
        pressureChartViewHeight = pressureChartView.heightAnchor.constraint(equalToConstant: 0)
        pressureChartViewHeight.isActive = true
        pressureChartView.chartDelegate = self

        scrollView.addSubview(luminosityChartView)
        luminosityChartView.anchor(
            top: pressureChartView.bottomAnchor,
            leading: scrollView.leadingAnchor,
            bottom: nil,
            trailing: scrollView.trailingAnchor
        )
        luminosityChartView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
        luminosityChartViewHeight = luminosityChartView.heightAnchor.constraint(equalToConstant: 0)
        luminosityChartViewHeight.isActive = true
        luminosityChartView.chartDelegate = self

        scrollView.addSubview(soundChartView)
        soundChartView.anchor(
            top: luminosityChartView.bottomAnchor,
            leading: scrollView.leadingAnchor,
            bottom: scrollView.bottomAnchor,
            trailing: scrollView.trailingAnchor
        )
        soundChartView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
        soundChartViewHeight = soundChartView.heightAnchor.constraint(equalToConstant: 0)
        soundChartViewHeight.isActive = true
        soundChartView.chartDelegate = self

        view.addSubview(noDataLabel)
        noDataLabel.anchor(
            top: nil,
            leading: view.safeLeftAnchor,
            bottom: nil,
            trailing: view.safeRightAnchor
        )
        noDataLabel.centerYInSuperview()
        noDataLabel.alpha = 0
    }

    private func configureViews() {
        scrollView.enableEdgeFading(configuration: graphScrollEdgeFadeConfiguration)
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

        for hour in historyHoursOptions {
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

        for day in minimumHistoryLimit ... maximumHistoryLimit {
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
        showChartStat: Bool = true,
        compactChartView: Bool = true
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

        let chartCompactExpandAction = UIAction(
            title: compactChartView ?
            RuuviLocalization.increaseGraphSize :
                RuuviLocalization.decreaseGraphSize
        ) {
            [weak self] _ in
            guard let sSelf = self else { return }
            sSelf.output?.viewDidSelectTriggerCompactChart(
                showCompactChartView: !compactChartView
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

        if chartModules.count > 2 {
            actions.append(chartCompactExpandAction)
        }

        return UIMenu(
            title: "",
            children: actions
        )
    }
}

extension CardsGraphViewController: TagChartsViewDelegate {
    func chartDidTranslate(_ chartView: TagChartsView) {
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
                calculateAlertFillIfNeeded(for: chartView)
            }
        }
    }

    func chartValueDidSelect(
        _ chartView: TagChartsView,
        entry _: ChartDataEntry,
        highlight: Highlight
    ) {
        guard chartViews.count > 1
        else {
            return
        }

        chartViews.filter { $0 != chartView }.forEach { otherChart in
            otherChart.underlyingView.highlightValue(highlight)
        }
    }

    func chartValueDidDeselect(_: TagChartsView) {
        guard chartViews.count > 1
        else {
            return
        }

        chartViews.forEach { chart in
            chart.underlyingView.highlightValue(nil)
        }
    }
}

// MARK: - TagChartsViewInput

extension CardsGraphViewController: CardsGraphViewInput {
    func setActiveSnapshot(_ snapshot: RuuviTagCardSnapshot?) {
        self.snapshot = snapshot
    }

    var viewIsVisible: Bool {
        isViewLoaded && view.window != nil
    }

    func clearChartHistory() {
        clearChartData()
    }

    func createChartViews(from: [MeasurementType]) {
        chartModules = from
        updateChartsCollectionConstaints(from: from)
    }

    func resetScrollPosition() {
        scrollView.setContentOffset(.zero, animated: false)
    }

    func scroll(to measurementType: MeasurementType) {
        guard !chartModules.isEmpty else {
            pendingScrollToMeasurement = measurementType
            return
        }

        pendingScrollToMeasurement = nil

        guard let targetView = getChartView(for: measurementType),
              !targetView.isHidden else {
            return
        }

        ensureLayoutComplete()

        let targetFrame = targetView.convert(targetView.bounds, to: scrollView)
        let visibleRect = scrollView.visibleRect

        if visibleRect.contains(targetFrame) {
            highlightTarget(targetView)
        } else {
            scrollToTarget(targetFrame, measurementType: measurementType, targetView: targetView)
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func setChartViewData(
        from chartViewData: [TagChartViewData],
        settings: RuuviLocalSettings
    ) {
        if chartViewData.count == 0 {
            clearChartData()
            showNoDataLabel()
            hideChartViews()
            return
        }

        clearChartData()
        hideNoDataLabel()
        showChartViews()

        for data in chartViewData {
            switch data.chartType {
            case .temperature:
                populateChartView(
                    from: data,
                    unit: settings.temperatureUnit.symbol,
                    settings: settings,
                    view: temperatureChartView
                )
            case .humidity:
                populateChartView(
                    from: data,
                    unit: settings.humidityUnit.symbol,
                    settings: settings,
                    view: humidityChartView
                )
            case .pressure:
                populateChartView(
                    from: data,
                    unit: settings.pressureUnit.symbol,
                    settings: settings,
                    view: pressureChartView
                )
            case .aqi:
                populateChartView(
                    from: data,
                    unit: "",
                    settings: settings,
                    view: aqiChartView
                )
            case .co2:
                populateChartView(
                    from: data,
                    unit: RuuviLocalization.unitCo2,
                    settings: settings,
                    view: co2ChartView
                )
            case .pm25:
                populateChartView(
                    from: data,
                    unit: RuuviLocalization.unitPm25,
                    settings: settings,
                    view: pm25ChartView
                )
            case .voc:
                populateChartView(
                    from: data,
                    unit: RuuviLocalization.unitVoc,
                    settings: settings,
                    view: vocChartView
                )
            case .nox:
                populateChartView(
                    from: data,
                    unit: RuuviLocalization.unitNox,
                    settings: settings,
                    view: noxChartView
                )
            case .luminosity:
                populateChartView(
                    from: data,
                    unit: RuuviLocalization.unitLuminosity,
                    settings: settings,
                    view: luminosityChartView
                )
            case .soundInstant:
                populateChartView(
                    from: data,
                    unit: RuuviLocalization.unitSound,
                    settings: settings,
                    view: soundChartView
                )
            default:
                break
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.view.layoutIfNeeded()
            if let m = self?.pendingScrollToMeasurement {
                self?.pendingScrollToMeasurement = nil
                self?.scroll(to: m)
            }
        }
    }

    // swiftlint:disable:next function_parameter_count function_body_length
    func updateChartViewData(
        temperatureEntries: [ChartDataEntry],
        humidityEntries: [ChartDataEntry],
        pressureEntries: [ChartDataEntry],
        aqiEntries: [ChartDataEntry],
        co2Entries: [ChartDataEntry],
        pm10Entries: [ChartDataEntry],
        pm25Entries: [ChartDataEntry],
        vocEntries: [ChartDataEntry],
        noxEntries: [ChartDataEntry],
        luminosityEntries: [ChartDataEntry],
        soundEntries: [ChartDataEntry],
        isFirstEntry: Bool,
        firstEntry: RuuviMeasurement?,
        settings: RuuviLocalSettings
    ) {
        hideNoDataLabel()
        showChartViews()

        temperatureChartView.setSettings(settings: settings)
        temperatureChartView.updateDataSet(
            with: temperatureEntries,
            isFirstEntry: isFirstEntry,
            firstEntry: firstEntry,
            showAlertRangeInGraph: settings.showAlertsRangeInGraph
        )

        humidityChartView.setSettings(settings: settings)
        humidityChartView.updateDataSet(
            with: humidityEntries,
            isFirstEntry: isFirstEntry,
            firstEntry: firstEntry,
            showAlertRangeInGraph: settings.showAlertsRangeInGraph
        )

        pressureChartView.setSettings(settings: settings)
        pressureChartView.updateDataSet(
            with: pressureEntries,
            isFirstEntry: isFirstEntry,
            firstEntry: firstEntry,
            showAlertRangeInGraph: settings.showAlertsRangeInGraph
        )

        aqiChartView.setSettings(settings: settings)
        aqiChartView.updateDataSet(
            with: aqiEntries,
            isFirstEntry: isFirstEntry,
            firstEntry: firstEntry,
            showAlertRangeInGraph: settings.showAlertsRangeInGraph
        )

        co2ChartView.setSettings(settings: settings)
        co2ChartView.updateDataSet(
            with: co2Entries,
            isFirstEntry: isFirstEntry,
            firstEntry: firstEntry,
            showAlertRangeInGraph: settings.showAlertsRangeInGraph
        )

        pm25ChartView.setSettings(settings: settings)
        pm25ChartView.updateDataSet(
            with: pm25Entries,
            isFirstEntry: isFirstEntry,
            firstEntry: firstEntry,
            showAlertRangeInGraph: settings.showAlertsRangeInGraph
        )

        vocChartView.setSettings(settings: settings)
        vocChartView.updateDataSet(
            with: vocEntries,
            isFirstEntry: isFirstEntry,
            firstEntry: firstEntry,
            showAlertRangeInGraph: settings.showAlertsRangeInGraph
        )

        noxChartView.setSettings(settings: settings)
        noxChartView.updateDataSet(
            with: noxEntries,
            isFirstEntry: isFirstEntry,
            firstEntry: firstEntry,
            showAlertRangeInGraph: settings.showAlertsRangeInGraph
        )

        luminosityChartView.setSettings(settings: settings)
        luminosityChartView.updateDataSet(
            with: luminosityEntries,
            isFirstEntry: isFirstEntry,
            firstEntry: firstEntry,
            showAlertRangeInGraph: settings.showAlertsRangeInGraph
        )

        soundChartView.setSettings(settings: settings)
        soundChartView.updateDataSet(
            with: soundEntries,
            isFirstEntry: isFirstEntry,
            firstEntry: firstEntry,
            showAlertRangeInGraph: settings.showAlertsRangeInGraph
        )
    }

    // swiftlint:disable:next function_parameter_count
    func updateLatestMeasurement(
        temperature: ChartDataEntry?,
        humidity: ChartDataEntry?,
        pressure: ChartDataEntry?,
        aqi: ChartDataEntry?,
        co2: ChartDataEntry?,
        pm10: ChartDataEntry?,
        pm25: ChartDataEntry?,
        voc: ChartDataEntry?,
        nox: ChartDataEntry?,
        luminosity: ChartDataEntry?,
        sound: ChartDataEntry?,
        settings: RuuviLocalSettings
    ) {
        temperatureChartView.updateLatest(
            with: temperature,
            type: .temperature,
            measurementService: measurementService
        )
        humidityChartView.updateLatest(
            with: humidity,
            type: .humidity(settings.humidityUnit),
            measurementService: measurementService
        )
        pressureChartView.updateLatest(
            with: pressure,
            type: .pressure,
            measurementService: measurementService
        )
        aqiChartView.updateLatest(
            with: aqi,
            type: .aqi,
            measurementService: measurementService
        )
        co2ChartView.updateLatest(
            with: co2,
            type: .co2,
            measurementService: measurementService
        )
        pm25ChartView.updateLatest(
            with: pm25,
            type: .pm25,
            measurementService: measurementService
        )
        vocChartView.updateLatest(
            with: voc,
            type: .voc,
            measurementService: measurementService
        )
        noxChartView.updateLatest(
            with: nox,
            type: .nox,
            measurementService: measurementService
        )
        luminosityChartView.updateLatest(
            with: luminosity,
            type: .luminosity,
            measurementService: measurementService
        )
        soundChartView.updateLatest(
            with: sound,
            type: .soundInstant,
            measurementService: measurementService
        )
    }

    func localize() {
        syncButton.updateTitle(with: RuuviLocalization.TagCharts.Sync.title)
    }

    func showBluetoothDisabled(userDeclined: Bool) {
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

    func setSync(progress: BTServiceProgress?, for snapshot: RuuviTagCardSnapshot) {
        if let progress {
            showSyncStatusLabel(show: true)
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
        } else {
            showSyncStatusLabel(show: false)
        }
    }

    func setSyncProgressViewHidden() {
        showSyncStatusLabel(show: false)
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
}

extension CardsGraphViewController {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func updateChartsCollectionConstaints(
        from: [MeasurementType],
        withAnimation: Bool = false
    ) {
        if from.count == 0 {
            noDataLabel.alpha = 1
            return
        }

        noDataLabel.alpha = 0
        chartViews.removeAll()
        let scrollViewHeight = scrollView.frame.height
        guard viewIsVisible, scrollViewHeight > 0, from.count > 0
        else {
            return
        }
        updateScrollviewBehaviour()

        if !from.contains(.anyHumidity) {
            humidityChartView.isHidden = true
            if humidityChartViewHeight.constant != 0 {
                humidityChartViewHeight.constant = 0
            }
        } else {
            humidityChartView.isHidden = false
        }

        if !from.contains(.pressure) {
            pressureChartView.isHidden = true
            if pressureChartViewHeight.constant != 0 {
                pressureChartViewHeight.constant = 0
            }
        } else {
            pressureChartView.isHidden = false
        }

        if !from.contains(.aqi) {
            aqiChartView.isHidden = true
            if aqiChartViewHeight.constant != 0 {
                aqiChartViewHeight.constant = 0
            }
        } else {
            aqiChartView.isHidden = false
        }

        if !from.contains(.co2) {
            co2ChartView.isHidden = true
            if co2ChartViewHeight.constant != 0 {
                co2ChartViewHeight.constant = 0
            }
        } else {
            co2ChartView.isHidden = false
        }

        if !from.contains(.pm25) {
            pm25ChartView.isHidden = true
            if pm25ChartViewHeight.constant != 0 {
                pm25ChartViewHeight.constant = 0
            }
        } else {
            pm25ChartView.isHidden = false
        }

        if !from.contains(.voc) {
            vocChartView.isHidden = true
            if vocChartViewHeight.constant != 0 {
                vocChartViewHeight.constant = 0
            }
        } else {
            vocChartView.isHidden = false
        }

        if !from.contains(.nox) {
            noxChartView.isHidden = true
            if noxChartViewHeight.constant != 0 {
                noxChartViewHeight.constant = 0
            }
        } else {
            noxChartView.isHidden = false
        }

        if !from.contains(.luminosity) {
            luminosityChartView.isHidden = true
            if luminosityChartViewHeight.constant != 0 {
                luminosityChartViewHeight.constant = 0
            }
        } else {
            luminosityChartView.isHidden = false
        }

        if !from.contains(.soundInstant) {
            soundChartView.isHidden = true
            if soundChartViewHeight.constant != 0 {
                soundChartViewHeight.constant = 0
            }
        } else {
            soundChartView.isHidden = false
        }

        for item in from {
            switch item {
            case .temperature:
                chartViews.append(temperatureChartView)
                updateChartViewConstaints(
                    constaint: temperatureChartViewHeight,
                    totalHeight: scrollViewHeight,
                    itemCount: from.count,
                    withAnimation: withAnimation
                )
            case .humidity:
                chartViews.append(humidityChartView)
                updateChartViewConstaints(
                    constaint: humidityChartViewHeight,
                    totalHeight: scrollViewHeight,
                    itemCount: from.count,
                    withAnimation: withAnimation
                )
            case .pressure:
                chartViews.append(pressureChartView)
                updateChartViewConstaints(
                    constaint: pressureChartViewHeight,
                    totalHeight: scrollViewHeight,
                    itemCount: from.count,
                    withAnimation: withAnimation
                )
            case .aqi:
                chartViews.append(aqiChartView)
                updateChartViewConstaints(
                    constaint: aqiChartViewHeight,
                    totalHeight: scrollViewHeight,
                    itemCount: from.count,
                    withAnimation: withAnimation
                )
            case .co2:
                chartViews.append(co2ChartView)
                updateChartViewConstaints(
                    constaint: co2ChartViewHeight,
                    totalHeight: scrollViewHeight,
                    itemCount: from.count,
                    withAnimation: withAnimation
                )
            case .pm25:
                chartViews.append(pm25ChartView)
                updateChartViewConstaints(
                    constaint: pm25ChartViewHeight,
                    totalHeight: scrollViewHeight,
                    itemCount: from.count,
                    withAnimation: withAnimation
                )
            case .voc:
                chartViews.append(vocChartView)
                updateChartViewConstaints(
                    constaint: vocChartViewHeight,
                    totalHeight: scrollViewHeight,
                    itemCount: from.count,
                    withAnimation: withAnimation
                )
            case .nox:
                chartViews.append(noxChartView)
                updateChartViewConstaints(
                    constaint: noxChartViewHeight,
                    totalHeight: scrollViewHeight,
                    itemCount: from.count,
                    withAnimation: withAnimation
                )
            case .luminosity:
                chartViews.append(luminosityChartView)
                updateChartViewConstaints(
                    constaint: luminosityChartViewHeight,
                    totalHeight: scrollViewHeight,
                    itemCount: from.count,
                    withAnimation: withAnimation
                )
            case .soundInstant:
                chartViews.append(soundChartView)
                updateChartViewConstaints(
                    constaint: soundChartViewHeight,
                    totalHeight: scrollViewHeight,
                    itemCount: from.count,
                    withAnimation: withAnimation
                )
            default:
                break
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.view.layoutIfNeeded()
            self?.scrollView.layoutIfNeeded()
            if let m = self?.pendingScrollToMeasurement {
                self?.pendingScrollToMeasurement = nil
                self?.scroll(to: m)
            }
        }
    }

    private func getItemHeight(
        from totalHeight: CGFloat,
        count: CGFloat
    ) -> CGFloat {
        if isLandscapeLayout {
            totalHeight
        } else {
            if !compactChartView {
                totalHeight / 2
            } else {
                if count >= 3 {
                    totalHeight / 3
                } else {
                    totalHeight / count
                }
            }
        }
    }

    private func updateScrollviewBehaviour() {
        if compactChartView {
            if isLandscapeLayout || chartModules.count > 3 {
                scrollView.isPagingEnabled = isLandscapeLayout
                scrollView.isScrollEnabled = true
                scrollView.showsVerticalScrollIndicator = true
            } else {
                scrollView.isPagingEnabled = false
                scrollView.isScrollEnabled = false
                scrollView.showsVerticalScrollIndicator = false
            }
        } else {
            if isLandscapeLayout {
                scrollView.isPagingEnabled = true
            } else {
                scrollView.isPagingEnabled = false
            }
            scrollView.isScrollEnabled = true
            scrollView.showsVerticalScrollIndicator = true
        }
        scrollView.edgeFader?.updateFadeMask()
    }

    private func updateChartViewConstaints(
        constaint: NSLayoutConstraint,
        totalHeight: CGFloat,
        itemCount: Int,
        withAnimation: Bool
    ) {
        if withAnimation {
            UIView.animate(withDuration: 0.2, animations: { [weak self] in
                guard let sSelf = self else { return }
                constaint.constant = sSelf.getItemHeight(
                    from: totalHeight,
                    count: CGFloat(itemCount)
                )
                sSelf.view.layoutIfNeeded()
            })
        } else {
            constaint.constant = getItemHeight(
                from: totalHeight,
                count: CGFloat(itemCount)
            )
        }
    }

    private func populateChartView(
        from data: TagChartViewData,
        unit: String,
        settings: RuuviLocalSettings,
        view: TagChartsView
    ) {
        view.setChartLabel(
            type: data.chartType,
            measurementService: measurementService,
            unit: unit
        )
        view.underlyingView.data = data.chartData
        view.underlyingView.lowerAlertValue = data.lowerAlertValue
        view.underlyingView.upperAlertValue = data.upperAlertValue
        view.setSettings(settings: settings)
        view.localize()
        view.setYAxisLimit(min: data.chartData?.yMin ?? 0, max: data.chartData?.yMax ?? 0)
        view.setXAxisRenderer(showAll: settings.chartShowAll)
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
        [temperatureChartView,
         humidityChartView,
         pressureChartView,
         aqiChartView,
         co2ChartView,
         pm25ChartView,
         vocChartView,
         noxChartView,
         luminosityChartView,
         soundChartView,
        ].forEach {
            $0.clearChartData()
        }

        [temperatureChartView,
         humidityChartView,
         pressureChartView,
         aqiChartView,
         co2ChartView,
         pm25ChartView,
         vocChartView,
         noxChartView,
         luminosityChartView,
         soundChartView,
        ].forEach {
            $0.underlyingView.highlightValue(nil)
        }
    }

    private func resetXAxisTimeline() {
        [temperatureChartView,
         humidityChartView,
         pressureChartView,
         aqiChartView,
         co2ChartView,
         pm25ChartView,
         vocChartView,
         noxChartView,
         luminosityChartView,
         soundChartView,
        ].forEach {
            $0.resetCustomAxisMinMax()
        }
    }

    // MARK: - UI RELATED METHODS

    private func showSyncStatusLabel(show: Bool) {
        syncProgressView.alpha = show ? 1 : 0
        syncButton.alpha = show ? 0 : 1
    }

    private func hideChartViews() {
        [temperatureChartView,
         humidityChartView,
         pressureChartView,
         aqiChartView,
         co2ChartView,
         pm25ChartView,
         vocChartView,
         noxChartView,
         luminosityChartView,
         soundChartView,
        ].forEach {
            $0.isHidden = true
        }
    }

    private func showChartViews() {
        [temperatureChartView,
         humidityChartView,
         pressureChartView,
         aqiChartView,
         co2ChartView,
         pm25ChartView,
         vocChartView,
         noxChartView,
         luminosityChartView,
         soundChartView,
        ].forEach {
            $0.isHidden = false
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

    private func calculateAlertFillIfNeeded(for view: TagChartsView) {
        guard let data = view.underlyingView.data,
              let dataSet = data.dataSets.first as? LineChartDataSet,
              let upperAlertValue = view.underlyingView.upperAlertValue,
              let lowerAlertValue = view.underlyingView.lowerAlertValue else {
            // Ensure alert range is disabled if thresholds aren't available
            if let dataSet = view.underlyingView.data?.dataSets.first as? LineChartDataSet {
                dataSet.hasAlertRange = false
            }
            return
        }

        // Always reset alert state first
        dataSet.hasAlertRange = false

        // Set the alert range if the thresholds are valid
        dataSet.lowerAlertLimit = lowerAlertValue
        dataSet.upperAlertLimit = upperAlertValue
        dataSet.alertColor = RuuviColor.graphAlertColor.color
        dataSet.hasAlertRange = true
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func calculateMinMaxForChart(for view: TagChartsView) {
        if let data = view.underlyingView.data,
           let dataSet = data.dataSets.first as? LineChartDataSet {
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

            let averageYValue = calculateVisibleAverage(
                chartView: view.underlyingView,
                dataSet: dataSet
            )
            var type: MeasurementType = .temperature
            if view == temperatureChartView {
                type = .temperature
            } else if view == humidityChartView {
                type = .anyHumidity
            } else if view == pressureChartView {
                type = .pressure
            } else if view == aqiChartView {
                type = .aqi
            } else if view == co2ChartView {
                type = .co2
            } else if view == pm25ChartView {
                type = .pm25
            } else if view == vocChartView {
                type = .voc
            } else if view == noxChartView {
                type = .nox
            } else if view == luminosityChartView {
                type = .luminosity
            } else if view == soundChartView {
                type = .soundInstant
            }

            if minVisibleYValue == Double.greatestFiniteMagnitude {
                minVisibleYValue = 0
            }
            if maxVisibleYValue == -Double.greatestFiniteMagnitude {
                maxVisibleYValue = 0
            }

            view.setChartStat(
                min: minVisibleYValue,
                max: maxVisibleYValue,
                avg: averageYValue,
                type: type,
                measurementService: measurementService
            )
        }
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
        measurementType: MeasurementType,
        targetView: TagChartsView
    ) {
        let newOffset = calculateNewOffset(for: targetFrame)
        let clampedOffset = clampOffset(newOffset)
        scrollView.setContentOffset(clampedOffset, animated: false)
        scheduleHighlightAnimation(for: targetView)
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

    private func scheduleHighlightAnimation(for targetView: TagChartsView) {
        DispatchQueue.main.asyncAfter(deadline: .now() + highlightAnimationDelay) { [weak self] in
            self?.highlightTarget(targetView)
        }
    }

    private func highlightTarget(_ targetView: TagChartsView) {
        addHighlightAnimation(to: targetView)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func getChartView(for measurementType: MeasurementType) -> TagChartsView? {
        switch measurementType {
        case .temperature: return temperatureChartView
        case .humidity: return humidityChartView
        case .pressure: return pressureChartView
        case .aqi: return aqiChartView
        case .co2: return co2ChartView
        case .pm25: return pm25ChartView
        case .voc: return vocChartView
        case .nox: return noxChartView
        case .luminosity: return luminosityChartView
        case .soundInstant: return soundChartView
        default: return nil
        }
    }

    private func addHighlightAnimation(to chartView: TagChartsView) {
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
