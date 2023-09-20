// swiftlint:disable file_length
import Foundation
import UIKit
import Charts
import RuuviOntology
import RuuviStorage
import RuuviLocal
import BTKit
import RuuviService
import GestureInstructions

// swiftlint:disable type_body_length
class TagChartsViewController: UIViewController {
    var output: TagChartsViewOutput!
    private var chartModules: [MeasurementType] = []

    var viewModel: TagChartsViewModel = TagChartsViewModel(type: .ruuvi)

    var historyLengthInDay: Int = 1 {
        didSet {
            historySelectionButton.updateTitle(with: "day_\(historyLengthInDay)".localized())
        }
    }

    var historyLengthInHours: Int = 1 {
        didSet {
            if historyLengthInHours >= 24 {
                historyLengthInDay = historyLengthInHours / 24
            } else {
                let unit = historyLengthInHours == 1 ? "hour".localized() : "hours".localized()
                historySelectionButton.updateTitle(
                        with: "\(historyLengthInHours) " + unit.lowercased()
                )
            }
            historySelectionButton.updateMenu(with: historyLengthOptions())
        }
    }

    var showChartStat: Bool = true {
        didSet {
            moreButton.menu = moreButtonOptions(showChartStat: showChartStat)
        }
    }

    var measurementService: RuuviServiceMeasurement! {
        didSet {
            measurementService?.add(self)
        }
    }

    // MARK: - CONSTANTS
    private let cellId: String = "CellId"

    // MARK: - UI COMPONENTS DECLARATION
    // Body
    lazy var noDataLabel: UILabel = {
        let label = UILabel()
        label.text = "Cards.UpdatedLabel.NoData.message".localized()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.Montserrat(.bold, size: 14)
        return label
    }()

    // Chart toolbar
    private lazy var historySelectionButton: RuuviContextMenuButton =
        RuuviContextMenuButton(menu: historyLengthOptions(),
                               titleColor: .white,
                               title: "1 day".localized(),
                               icon: RuuviAssets.dropDownArrowImage,
                               iconTintColor: RuuviColor.logoTintColor,
                               iconSize: .init(width: 14, height: 14),
                               preccedingIcon: false)

    // Chart toolbar
    private lazy var moreButton: UIButton = {
        let button  = UIButton()
        button.tintColor = .white
        button.setImage(RuuviAssets.threeDotMoreImage, for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.showsMenuAsPrimaryAction = true
        button.menu = moreButtonOptions()
        return button
    }()

    // Charts
    lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.backgroundColor = .clear
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.alwaysBounceHorizontal = false
        sv.contentInsetAdjustmentBehavior = .never
        sv.isScrollEnabled = false
        return sv
    }()

    private var chartViews: [TagChartsView] = []

    lazy var temperatureChartView = TagChartsView()
    lazy var humidityChartView = TagChartsView()
    lazy var pressureChartView = TagChartsView()

    private var temperatureChartViewHeight: NSLayoutConstraint!
    private var humidityChartViewHeight: NSLayoutConstraint!
    private var pressureChartViewHeight: NSLayoutConstraint!

    // Sync view
    lazy var syncProgressView = UIView(color: .clear)
    lazy var syncStatusLabel: UILabel = {
        let label = UILabel()
        label.text = "Reading history..."
        label.textColor = .white
        label.textAlignment = .left
        label.font = UIFont.Muli(.regular, size: 16)
        return label
    }()

    private lazy var syncButton: RuuviContextMenuButton = {
        let button = RuuviContextMenuButton(
            menu: nil,
            titleColor: .white,
            title: "TagCharts.Sync.title".localized(),
            icon: UIImage(named: "icon_sync_bt"),
            iconTintColor: .white,
            iconSize: .init(width: 22, height: 22),
            preccedingIcon: true
        )
        button.button.showsMenuAsPrimaryAction = false
        button.button.addTarget(self, action: #selector(syncButtonDidTap),
                                for: .touchUpInside)
        return button
    }()

    lazy var syncCancelButton: UIButton = {
        let button  = UIButton()
        let closeImage = UIImage(systemName: "xmark")
        button.tintColor = .white
        button.setImage(closeImage, for: .normal)
        button.addTarget(self, action: #selector(cancelButtonDidTap), for: .touchUpInside)
        return button
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
        iv.tintColor = .white.withAlphaComponent(0.8)
        return iv
    }()
    // UI END

    private let historyHoursOptions: [Int] = [1, 2, 3, 12]
    private let minimumHistoryLimit: Int = 1 // Day
    private let maximumHistoryLimit: Int = 10 // Days
    private var timer: Timer?

    deinit {
        timer?.invalidate()
    }

    // MARK: - LIFECYCLE
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
        setUpUI()
        output.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hideNoDataLabel()
        output.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        hideNoDataLabel()
        output.viewWillDisappear()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateChartsCollectionConstaints(
            from: chartModules,
            withAnimation: false
        )
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: { _ in
        }, completion: { [weak self] (_) in
            self?.updateScrollviewBehaviour()
            self?.updateChartsCollectionConstaints(from: self?.chartModules ?? [],
                                                   withAnimation: true)
            self?.output.viewDidTransition()
        })
        super.viewWillTransition(to: size, with: coordinator)
        gestureInstructor.dismissThenResume()
    }

    fileprivate func setUpUI() {
        setUpContentView()
    }

    // swiftlint:disable:next function_body_length
    fileprivate func setUpContentView() {
        let chartToolbarView = UIView(color: .clear)
        view.addSubview(chartToolbarView)
        chartToolbarView.anchor(top: view.safeTopAnchor,
                                leading: view.safeLeftAnchor,
                                bottom: nil,
                                trailing: view.safeRightAnchor,
                                padding: .init(top: 8,
                                               left: 12,
                                               bottom: 0,
                                               right: 8),
                                size: .init(width: 0, height: 36))

        chartToolbarView.addSubview(moreButton)
        moreButton.anchor(top: nil,
                          leading: nil,
                          bottom: nil,
                          trailing: chartToolbarView.trailingAnchor,
                          padding: .init(top: 0,
                                         left: 0,
                                         bottom: 0,
                                         right: 8),
                          size: .init(width: 18, height: 18))
        moreButton.centerYInSuperview()

        chartToolbarView.addSubview(historySelectionButton)
        historySelectionButton.anchor(top: nil,
                                      leading: nil,
                                      bottom: nil,
                                      trailing: moreButton.leadingAnchor,
                                      padding: .init(top: 0,
                                                     left: 0,
                                                     bottom: 0,
                                                     right: 8),
                                      size: .init(width: 0,
                                                  height: 24))
        historySelectionButton.centerYInSuperview()

        chartToolbarView.addSubview(syncProgressView)
        syncProgressView.anchor(top: chartToolbarView.topAnchor,
                                leading: chartToolbarView.leadingAnchor,
                                bottom: chartToolbarView.bottomAnchor,
                                trailing: historySelectionButton.leadingAnchor,
                                padding: .init(top: 0,
                                               left: 0,
                                               bottom: 0,
                                               right: 8))

        syncProgressView.addSubview(syncCancelButton)
        syncCancelButton.anchor(top: nil,
                                leading: syncProgressView.leadingAnchor,
                                bottom: nil,
                                trailing: nil,
                                size: .init(width: 32, height: 32))
        syncCancelButton.centerYInSuperview()
        syncProgressView.alpha = 0

        syncProgressView.addSubview(syncStatusLabel)
        syncStatusLabel.anchor(top: nil,
                                 leading: syncCancelButton.trailingAnchor,
                                 bottom: nil,
                                 trailing: syncProgressView.trailingAnchor,
                                 padding: .init(top: 0, left: 6, bottom: 0, right: 0))
        syncStatusLabel.centerYInSuperview()

        chartToolbarView.addSubview(syncButton)
        syncButton.anchor(top: nil,
                          leading: chartToolbarView.leadingAnchor,
                          bottom: nil,
                          trailing: nil,
                          padding: .init(top: 0, left: 8, bottom: 0, right: 0),
                          size: .init(width: 0,
                                      height: 28))
        syncButton.centerYInSuperview()
        syncButton.alpha = 1

        view.addSubview(scrollView)
        scrollView.anchor(top: chartToolbarView.bottomAnchor,
                          leading: view.safeLeftAnchor,
                          bottom: view.safeBottomAnchor,
                          trailing: view.safeRightAnchor,
                          padding: .init(top: 6, left: 0, bottom: 28, right: 0))

        scrollView.addSubview(temperatureChartView)
        temperatureChartView.anchor(top: scrollView.topAnchor,
                                    leading: scrollView.leadingAnchor,
                                    bottom: nil,
                                    trailing: scrollView.trailingAnchor)
        temperatureChartView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
        temperatureChartViewHeight = temperatureChartView.heightAnchor.constraint(equalToConstant: 0)
        temperatureChartViewHeight.isActive = true
        temperatureChartView.chartDelegate = self

        scrollView.addSubview(humidityChartView)
        humidityChartView.anchor(top: temperatureChartView.bottomAnchor,
                                    leading: scrollView.leadingAnchor,
                                    bottom: nil,
                                    trailing: scrollView.trailingAnchor)
        humidityChartView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
        humidityChartViewHeight = humidityChartView.heightAnchor.constraint(equalToConstant: 0)
        humidityChartViewHeight.isActive = true
        humidityChartView.chartDelegate = self

        scrollView.addSubview(pressureChartView)
        pressureChartView.anchor(top: humidityChartView.bottomAnchor,
                                    leading: scrollView.leadingAnchor,
                                 bottom: scrollView.bottomAnchor,
                                    trailing: scrollView.trailingAnchor)
        pressureChartView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
        pressureChartViewHeight = pressureChartView.heightAnchor.constraint(equalToConstant: 0)
        pressureChartViewHeight.isActive = true
        pressureChartView.chartDelegate = self

        view.addSubview(noDataLabel)
        noDataLabel.anchor(top: nil,
                           leading: view.safeLeftAnchor,
                           bottom: nil,
                           trailing: view.safeRightAnchor)
        noDataLabel.centerYInSuperview()
        noDataLabel.alpha = 0

        let footerView = UIView(color: .clear)
        view.addSubview(footerView)
        footerView.anchor(top: scrollView.bottomAnchor,
                          leading: view.safeLeftAnchor,
                          bottom: view.safeBottomAnchor,
                          trailing: view.safeRightAnchor,
                          padding: .init(top: 4,
                                         left: 16,
                                         bottom: 8,
                                         right: 16),
                          size: .init(width: 0, height: 26))

        footerView.addSubview(updatedAtLabel)
        updatedAtLabel.anchor(top: footerView.topAnchor,
                              leading: nil,
                              bottom: footerView.bottomAnchor,
                              trailing: nil,
                              padding: .init(top: 0,
                                             left: 12,
                                             bottom: 0,
                                             right: 0))

        footerView.addSubview(dataSourceIconView)
        dataSourceIconView.anchor(top: nil,
                                  leading: updatedAtLabel.trailingAnchor,
                                  bottom: nil,
                                  trailing: footerView.trailingAnchor,
                                  padding: .init(top: 0,
                                                 left: 6,
                                                 bottom: 0,
                                                 right: 0),
                                  size: .init(width: 22, height: 22))
        dataSourceIconView.centerYInSuperview()

    }

    @objc fileprivate func syncButtonDidTap() {
        output.viewDidTriggerSync(for: viewModel)
    }

    @objc fileprivate func cancelButtonDidTap() {
        output.viewDidTriggerStopSync(for: viewModel)
    }

    fileprivate func historyLengthOptions() -> UIMenu {
        var actions: [UIAction] = []

        for hour in historyHoursOptions {
            let action = UIAction(
                title: "\(hour) \(hour == 1 ? "hour".localized() : "hours".localized())".lowercased()
            ) { [weak self] _ in
                self?.handleHistoryLengthSelection(hours: hour)
            }
             if hour == historyLengthInHours {
                action.state = .on
             } else {
                action.state = .off
             }
            actions.append(action)
        }

        for day in minimumHistoryLimit...maximumHistoryLimit {
            let action = UIAction(title: "day_\(day)".localized()) {
                [weak self] _ in
                self?.handleHistoryLengthSelection(hours: day*24)
            }
            if day == historyLengthInHours / 24 {
                action.state = .on
            } else {
                action.state = .off
            }
            actions.append(action)
        }

        // Add more at the bottom
        let more_action = UIAction(title: "more".localized()) { [weak self] _ in
            self?.handleHistoryLengthSelection(hours: nil)
        }
        actions.append(more_action)

        return UIMenu(title: "",
                      children: actions)
    }

    fileprivate func handleHistoryLengthSelection(hours: Int?) {
        if let hours = hours {
            if hours >= 24 {
                historySelectionButton.updateTitle(with: "day_\(hours/24)".localized())
                historySelectionButton.updateMenu(with: historyLengthOptions())
            } else {
                let unit = hours == 1 ? "hour".localized() : "hours".localized()
                historySelectionButton.updateTitle(
                        with: "\(hours) " + unit.lowercased()
                )
            }
            output.viewDidSelectChartHistoryLength(hours: hours)
            historySelectionButton.updateMenu(with: historyLengthOptions())
        } else {
            output.viewDidSelectLongerHistory()
        }
    }

    fileprivate func moreButtonOptions(showChartStat: Bool = true) -> UIMenu {
        let exportHistoryAction = UIAction(title: "export_history".localized()) {
            [weak self] _ in
            self?.output.viewDidTapOnExport()
        }

        let clearViewHistory = UIAction(title: "clear_view".localized()) {
            [weak self] _ in
            guard let sSelf = self else { return }
            sSelf.output.viewDidTriggerClear(for: sSelf.viewModel)
        }

        let minMaxAvgAction = UIAction(
            title: !showChartStat ? "chart_stat_show".localized() : "chart_stat_hide".localized()
        ) {
            [weak self] _ in
            guard let sSelf = self else { return }
            sSelf.output.viewDidSelectTriggerChartStat(show: !showChartStat)
            sSelf.chartViews.forEach({ chartView in
                chartView.setChartStatVisible(show: !showChartStat)
            })
        }

        return UIMenu(
            title: "",
            children: [
                exportHistoryAction,
                clearViewHistory,
                minMaxAvgAction
            ]
        )
    }
}

extension TagChartsViewController: TagChartsViewDelegate {
    func chartDidTranslate(_ chartView: TagChartsView) {
        guard chartViews.count > 1 else {
            calculateMinMaxForChart(for: chartView)
            return
        }
        let sourceMatrix = chartView.viewPortHandler.touchMatrix
        chartViews.filter({ $0 != chartView }).forEach { otherChart in
            var targetMatrix = otherChart.viewPortHandler.touchMatrix
            targetMatrix.a = sourceMatrix.a
            targetMatrix.tx = sourceMatrix.tx
            otherChart.viewPortHandler.refresh(
                newMatrix: targetMatrix,
                chart: otherChart,
                invalidate: true
            )
        }

        for view in chartViews {
            calculateMinMaxForChart(for: view)
        }
    }

    func chartValueDidSelect(_ chartView: TagChartsView,
                             entry: ChartDataEntry,
                             highlight: Highlight) {
        guard chartViews.count > 1 else {
            return
        }

        chartViews.filter({ $0 != chartView }).forEach { otherChart in
            otherChart.highlightValue(highlight)
        }
    }

    func chartValueDidDeselect(_ chartView: TagChartsView) {
        guard chartViews.count > 1 else {
            return
        }

        chartViews.forEach { chart in
            chart.highlightValue(nil)
        }
    }
}

// MARK: - TagChartsViewInput
extension TagChartsViewController: TagChartsViewInput {
    var viewIsVisible: Bool {
        return self.isViewLoaded && self.view.window != nil
    }

    func clearChartHistory() {
        clearChartData()
    }

    func createChartViews(from: [MeasurementType]) {
        chartModules = from
        updateChartsCollectionConstaints(from: from)
    }

    func setChartViewData(from chartViewData: [TagChartViewData],
                          settings: RuuviLocalSettings) {
        if chartViewData.count == 0 {
            clearChartData()
            showNoDataLabel()
            hideChartViews()
            return
        }

        hideNoDataLabel()
        showChartViews()

        for data in chartViewData {
            switch data.chartType {
            case .temperature:
                populateChartView(from: data.chartData,
                                  title: "TagSettings.OffsetCorrection.Temperature".localized(),
                                  type: data.chartType,
                                  unit: settings.temperatureUnit.symbol,
                                  settings: settings,
                                  view: temperatureChartView)
            case .humidity:
                populateChartView(from: data.chartData,
                                  title: "TagSettings.OffsetCorrection.Humidity".localized(),
                                  type: data.chartType,
                                  unit: settings.humidityUnit.symbol,
                                  settings: settings,
                                  view: humidityChartView)
            case .pressure:
                populateChartView(from: data.chartData,
                                  title: "TagSettings.OffsetCorrection.Pressure".localized(),
                                  type: data.chartType,
                                  unit: settings.pressureUnit.symbol,
                                  settings: settings,
                                  view: pressureChartView)
            default:
                break
            }
        }
    }

    func updateChartViewData(temperatureEntries: [ChartDataEntry],
                             humidityEntries: [ChartDataEntry],
                             pressureEntries: [ChartDataEntry],
                             isFirstEntry: Bool,
                             settings: RuuviLocalSettings) {
        hideNoDataLabel()
        showChartViews()

        temperatureChartView.setSettings(settings: settings)
        temperatureChartView.updateDataSet(with: temperatureEntries,
                                           isFirstEntry: isFirstEntry)

        humidityChartView.setSettings(settings: settings)
        humidityChartView.updateDataSet(with: humidityEntries,
                                        isFirstEntry: isFirstEntry)

        pressureChartView.setSettings(settings: settings)
        pressureChartView.updateDataSet(with: pressureEntries,
                                        isFirstEntry: isFirstEntry)
    }

    func updateLatestMeasurement(temperature: ChartDataEntry?,
                                 humidity: ChartDataEntry?,
                                 pressure: ChartDataEntry?,
                                 settings: RuuviLocalSettings) {
        temperatureChartView.updateLatest(with: temperature,
                                          type: .temperature,
                                          measurementService: measurementService,
                                          unit: settings.temperatureUnit.symbol)
        humidityChartView.updateLatest(with: humidity,
                                       type: .humidity,
                                       measurementService: measurementService,
                                       unit: settings.humidityUnit == .dew ?
                                        settings.temperatureUnit.symbol :
                                        settings.humidityUnit.symbol)
        pressureChartView.updateLatest(with: pressure,
                                       type: .pressure,
                                       measurementService: measurementService,
                                       unit: settings.pressureUnit.symbol)
    }

    func updateLatestRecordStatus(with record: RuuviTagSensorRecord) {
        // Ago
        let date = record.date.ruuviAgo()
        updatedAtLabel.text = date
        startTimer(with: record.date)
        // Source
        switch record.source {
        case .unknown:
            dataSourceIconView.image = nil
        case .advertisement:
            dataSourceIconView.image = RuuviAssets.advertisementImage
        case .heartbeat:
            dataSourceIconView.image = RuuviAssets.heartbeatImage
        case .log:
            dataSourceIconView.image = RuuviAssets.heartbeatImage
        case .ruuviNetwork:
            dataSourceIconView.image = RuuviAssets.ruuviNetworkImage
        case .weatherProvider:
            dataSourceIconView.image = RuuviAssets.weatherProviderImage
        }
    }

    func localize() {
        syncButton.updateTitle(with: "TagCharts.Sync.title".localized())
    }

    func showBluetoothDisabled(userDeclined: Bool) {
        let title = "TagCharts.BluetoothDisabledAlert.title".localized()
        let message = "TagCharts.BluetoothDisabledAlert.message".localized()
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "PermissionPresenter.settings".localized(),
                                        style: .default, handler: { _ in
            guard let url = URL(string: userDeclined ?
                                UIApplication.openSettingsURLString : "App-prefs:Bluetooth"),
                  UIApplication.shared.canOpenURL(url) else {
                return
            }
            UIApplication.shared.open(url)
        }))
        alertVC.addAction(UIAlertAction(title: "OK".localized(), style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }

    func showClearConfirmationDialog(for viewModel: TagChartsViewModel) {
        let title = "clear_local_history".localized()
        let message = "clear_local_history_description".localized()
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        let actionTitle = "TagCharts.Clear.title".localized()
        alertVC.addAction(UIAlertAction(title: actionTitle, style: .destructive, handler: { [weak self] _ in
            self?.output.viewDidConfirmToClear(for: viewModel)

        }))
        present(alertVC, animated: true)
    }

    func setSync(progress: BTServiceProgress?, for viewModel: TagChartsViewModel) {
        if let progress = progress {
            showSyncStatusLabel(show: true)
            switch progress {
            case .connecting:
                syncStatusLabel.text = "TagCharts.Status.Connecting".localized()
            case .serving:
                syncStatusLabel.text = "TagCharts.Status.Serving".localized()
            case .reading(let points):
                let format = "reading_history_x".localized()
                syncStatusLabel.text = String(format: format, Float(points))
            case .disconnecting:
                syncStatusLabel.text = "TagCharts.Status.Disconnecting".localized()
            case .success:
                syncStatusLabel.text = "TagCharts.Status.Success".localized()
            case .failure:
                syncStatusLabel.text = "TagCharts.Status.Error".localized()
            }
        } else {
            showSyncStatusLabel(show: false)
        }
    }

    func setSyncProgressViewHidden() {
        showSyncStatusLabel(show: false)
    }

    func showFailedToSyncIn() {
        let message = "TagCharts.FailedToSyncDialog.message".localized()
        let alertVC = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "OK".localized(), style: .cancel, handler: nil))
        alertVC.addAction(UIAlertAction(title: "TagCharts.TryAgain.title".localized(),
                                        style: .default,
                                        handler: { [weak self] _ in
            guard let self = self else { return }
            self.output.viewDidTriggerSync(for: self.viewModel)
        }))
        present(alertVC, animated: true)
    }

    func showSwipeUpInstruction() {
        gestureInstructor.show(.swipeUp, after: 0.1)
    }

    func showSyncConfirmationDialog(for viewModel: TagChartsViewModel) {
        let title = "synchronisation".localized()
        let message = "gatt_sync_description".localized()
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "Close".localized(), style: .cancel, handler: nil))
        let actionTitle = "do_not_show_again".localized()
        alertVC.addAction(UIAlertAction(title: actionTitle,
                                        style: .default,
                                        handler: { [weak self] _ in
            self?.output.viewDidTriggerDoNotShowSyncDialog()

        }))
        present(alertVC, animated: true)
    }

    func showSyncAbortAlert(dismiss: Bool) {
        let title = "TagCharts.DeleteHistoryConfirmationDialog.title".localized()
        let message = dismiss ? "TagCharts.Dismiss.Alert.message".localized() :
                                "TagCharts.AbortSync.Alert.message".localized()
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "OK".localized(), style: .cancel, handler: nil))
        let actionTitle = "TagCharts.AbortSync.Button.title".localized()
        alertVC.addAction(UIAlertAction(title: actionTitle, style: .destructive, handler: { [weak self] _ in
            self?.output.viewDidConfirmAbortSync(dismiss: dismiss)
        }))
        present(alertVC, animated: true)
    }

    func showSyncAbortAlertForSwipe() {
        let title = "TagCharts.DeleteHistoryConfirmationDialog.title".localized()
        let message = "TagCharts.Dismiss.Alert.message".localized()
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "OK".localized(), style: .cancel, handler: nil))
        let actionTitle = "TagCharts.AbortSync.Button.title".localized()
        alertVC.addAction(UIAlertAction(title: actionTitle, style: .destructive, handler: { [weak self] _ in
            self?.output.viewDidConfirmAbortSync(dismiss: false)
        }))
        present(alertVC, animated: true)
    }

    func showExportSheet(with path: URL) {
        let vc = UIActivityViewController(activityItems: [path],
                                          applicationActivities: [])
        vc.excludedActivityTypes = [
            UIActivity.ActivityType.assignToContact,
            UIActivity.ActivityType.saveToCameraRoll,
            UIActivity.ActivityType.postToFlickr,
            UIActivity.ActivityType.postToVimeo,
            UIActivity.ActivityType.postToTencentWeibo,
            UIActivity.ActivityType.postToTwitter,
            UIActivity.ActivityType.postToFacebook,
            UIActivity.ActivityType.openInIBooks
        ]
        vc.popoverPresentationController?.permittedArrowDirections = .up
        vc.popoverPresentationController?.sourceView = moreButton
        present(vc, animated: true)
    }

    func showLongerHistoryDialog() {
        let title = "longer_history_title".localized()
        let message = "longer_history_message".localized()
        let controller = UIAlertController(title: title,
                                           message: message,
                                           preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "OK".localized(),
                                           style: .cancel,
                                           handler: nil))
        present(controller, animated: true)
    }
}

extension TagChartsViewController {

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func updateChartsCollectionConstaints(from: [MeasurementType],
                                                  withAnimation: Bool = false) {
        if from.count == 0 {
            noDataLabel.alpha = 1
            return
        }

        noDataLabel.alpha = 0
        chartViews.removeAll()
        let scrollViewHeight = scrollView.frame.height
        guard viewIsVisible && scrollViewHeight > 0 && from.count > 0 else {
            return
        }
        updateScrollviewBehaviour()

        if !from.contains(.humidity) {
            humidityChartView.isHidden = true
            humidityChartView.hideChartNameLabel(hide: true)
            if humidityChartViewHeight.constant != 0 {
                humidityChartViewHeight.constant = 0
            }
        } else {
            humidityChartView.isHidden = false
            humidityChartView.hideChartNameLabel(hide: false)
        }

        if !from.contains(.pressure) {
            pressureChartView.isHidden = true
            pressureChartView.hideChartNameLabel(hide: true)
            if pressureChartViewHeight.constant != 0 {
                pressureChartViewHeight.constant = 0
            }
        } else {
            pressureChartView.isHidden = false
            pressureChartView.hideChartNameLabel(hide: false)
        }

        for item in from {
            switch item {
            case .temperature:
                chartViews.append(temperatureChartView)
                updateChartViewConstaints(constaint: temperatureChartViewHeight,
                                          totalHeight: scrollViewHeight,
                                          itemCount: from.count,
                                          withAnimation: withAnimation)
            case .humidity:
                chartViews.append(humidityChartView)
                updateChartViewConstaints(constaint: humidityChartViewHeight,
                                          totalHeight: scrollViewHeight,
                                          itemCount: from.count,
                                          withAnimation: withAnimation)
            case .pressure:
                chartViews.append(pressureChartView)
                updateChartViewConstaints(constaint: pressureChartViewHeight,
                                          totalHeight: scrollViewHeight,
                                          itemCount: from.count,
                                          withAnimation: withAnimation)
            default:
                break
            }
        }
    }

    private func getItemHeight(from totalHeight: CGFloat, count: CGFloat) -> CGFloat {
        if UIWindow.isLandscape {
            return totalHeight
        } else {
            if count == 1 {
                return totalHeight/2
            } else {
                return totalHeight/count
            }
        }
    }

    private func updateScrollviewBehaviour() {
        if UIWindow.isLandscape {
            scrollView.isPagingEnabled = true
            scrollView.isScrollEnabled = true
        } else {
            scrollView.isPagingEnabled = false
            scrollView.isScrollEnabled = false
        }
    }

    private func updateChartViewConstaints(constaint: NSLayoutConstraint,
                                           totalHeight: CGFloat,
                                           itemCount: Int,
                                           withAnimation: Bool) {
        if withAnimation {
            UIView.animate(withDuration: 0.2, animations: { [weak self] in
                guard let sSelf = self else { return }
                constaint.constant = sSelf.getItemHeight(from: totalHeight,
                                                         count: CGFloat(itemCount))
                sSelf.view.layoutIfNeeded()
            })
        } else {
            constaint.constant = getItemHeight(from: totalHeight,
                                               count: CGFloat(itemCount))
        }
    }

    // swiftlint:disable:next function_parameter_count
    private func populateChartView(from data: LineChartData?,
                                   title: String,
                                   type: MeasurementType,
                                   unit: String,
                                   settings: RuuviLocalSettings,
                                   view: TagChartsView) {
        view.setChartLabel(with: title,
                           type: type,
                           measurementService: measurementService,
                           unit: unit)
        view.data = data
        view.setSettings(settings: settings)
        view.localize()
        view.setYAxisLimit(min: data?.yMin ?? 0, max: data?.yMax ?? 0)
        view.setXAxisRenderer()
        view.setChartStatVisible(show: showChartStat)

        calculateMinMaxForChart(for: view)
    }

    private func clearChartData() {
        temperatureChartView.clearChartData()
        temperatureChartView.highlightValue(nil)
        temperatureChartView.clearChartStat()
        humidityChartView.clearChartData()
        humidityChartView.highlightValue(nil)
        humidityChartView.clearChartStat()
        pressureChartView.clearChartData()
        pressureChartView.highlightValue(nil)
        pressureChartView.clearChartStat()
    }

    // MARK: - UI RELATED METHODS
    private func showSyncStatusLabel(show: Bool) {
        syncProgressView.alpha = show ? 1 : 0
        syncButton.alpha = show ? 0 : 1
    }

    private func hideChartViews() {
        temperatureChartView.isHidden = true
        humidityChartView.isHidden = true
        pressureChartView.isHidden = true
    }

    private func showChartViews() {
        temperatureChartView.isHidden = false
        humidityChartView.isHidden = false
        pressureChartView.isHidden = false
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

    private func startTimer(with date: Date?) {
        timer?.invalidate()
        timer = nil

        timer = Timer.scheduledTimer(withTimeInterval: 1,
                                     repeats: true,
                                     block: { [weak self] (_) in
            self?.updatedAtLabel.text = date?.ruuviAgo() ?? "Cards.UpdatedLabel.NoData.message".localized()
        })
    }

    private func calculateMinMaxForChart(for view: TagChartsView) {
        if let data = view.data,
           let dataSet = data.dataSets.first as? LineChartDataSet {

            let lowestVisibleX = view.lowestVisibleX
            let highestVisibleX = view.highestVisibleX

            var minVisibleYValue = Double.greatestFiniteMagnitude
            var maxVisibleYValue = -Double.greatestFiniteMagnitude

            dataSet.entries.forEach { entry in
                if entry.x >= lowestVisibleX && entry.x <= highestVisibleX {
                    minVisibleYValue = min(minVisibleYValue, entry.y)
                    maxVisibleYValue = max(maxVisibleYValue, entry.y)
                }
            }

            let averageYValue = calculateVisibleAverage(chartView: view, dataSet: dataSet)
            var type: MeasurementType = .temperature
            if view == temperatureChartView {
                type = .temperature
            } else if view == humidityChartView {
                type = .humidity
            } else if view == pressureChartView {
                type = .pressure
            }

            view.setChartStat(
                min: minVisibleYValue,
                max: maxVisibleYValue,
                avg: averageYValue,
                type: type
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
        for i in 1..<visibleEntries.count {
            let x1 = visibleEntries[i-1].x
            let y1 = visibleEntries[i-1].y
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
            return visibleEntries.map { $0.y }.reduce(0, +) / Double(visibleEntries.count)
        }

        // Compute the average using the trapezoidal rule.
        return totalArea / timeSpan
    }
}

extension TagChartsViewController: RuuviServiceMeasurementDelegate {
    func measurementServiceDidUpdateUnit() {}
}
// swiftlint:enable type_body_length
