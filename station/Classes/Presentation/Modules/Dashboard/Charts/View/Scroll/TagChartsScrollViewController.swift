// swiftlint:disable file_length
import UIKit
import Charts
import BTKit
import GestureInstructions

class TagChartsScrollViewController: UIViewController {
    var output: TagChartsViewOutput!

    var tagChartsDismissInteractiveTransition: UIViewControllerInteractiveTransitioning!

    @IBOutlet weak var scrollView: UIScrollView!

    var viewModels = [TagChartsViewModel]() {
        didSet {
            updateUIViewModels()
        }
    }

    private var appDidBecomeActiveToken: NSObjectProtocol?
    private let alertActiveImage = UIImage(named: "icon-alert-active")
    private let alertOffImage = UIImage(named: "icon-alert-off")
    private let alertOnImage = UIImage(named: "icon-alert-on")
    private var views = [TrippleChartView]()
    private var currentPage: Int {
        return Int(scrollView.contentOffset.x / scrollView.frame.size.width)
    }
    private let noChartDataText = "TagCharts.NoChartData.text"

    deinit {
        if let appDidBecomeActiveToken = appDidBecomeActiveToken {
            NotificationCenter.default.removeObserver(appDidBecomeActiveToken)
        }
    }
}

// MARK: - TagChartsViewInput
extension TagChartsScrollViewController: TagChartsViewInput {
    func localize() {
        views.forEach({
            $0.temperatureChart.noDataText = noChartDataText.localized()
            $0.temperatureChart.noDataTextColor = .white
            $0.temperatureChart.setNeedsDisplay()
            $0.humidityChart.noDataText = noChartDataText.localized()
            $0.humidityChart.noDataTextColor = .white
            $0.humidityChart.setNeedsDisplay()
            $0.pressureChart.noDataText = noChartDataText.localized()
            $0.pressureChart.noDataTextColor = .white
            $0.pressureChart.setNeedsDisplay()
        })
    }

    func scroll(to index: Int, immediately: Bool = false) {
        if isViewLoaded {
            if immediately {
                view.layoutIfNeeded()
                scrollView.layoutIfNeeded()
                let x: CGFloat = scrollView.frame.size.width * CGFloat(index)
                scrollView.setContentOffset(CGPoint(x: x, y: 0), animated: false)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let sSelf = self else { return }
                    let x: CGFloat = sSelf.scrollView.frame.size.width * CGFloat(index)
                    sSelf.scrollView.setContentOffset(CGPoint(x: x, y: 0), animated: true)
                }
            }
        }
    }

    func showBluetoothDisabled() {
        let title = "TagCharts.BluetoothDisabledAlert.title".localized()
        let message = "TagCharts.BluetoothDisabledAlert.message".localized()
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "OK".localized(), style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }

    func showSyncConfirmationDialog(for viewModel: TagChartsViewModel) {
        let title = "TagCharts.SyncConfirmationDialog.title".localized()
        let message = "TagCharts.SyncConfirmationDialog.message".localized()
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        alertVC.addAction(UIAlertAction(title: "Confirm".localized(), style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmToSync(for: viewModel)
        }))
        present(alertVC, animated: true)
    }

    func showClearConfirmationDialog(for viewModel: TagChartsViewModel) {
        let title = "TagCharts.DeleteHistoryConfirmationDialog.title".localized()
        let message = "TagCharts.DeleteHistoryConfirmationDialog.message".localized()
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        let actionTitle = "TagCharts.DeleteHistoryConfirmationDialog.button.delete.title".localized()
        alertVC.addAction(UIAlertAction(title: actionTitle, style: .destructive, handler: { [weak self] _ in
            self?.output.viewDidConfirmToClear(for: viewModel)

        }))
        present(alertVC, animated: true)
    }

    func showExportSheet(with path: URL) {
        var shareItems = [Any]()
        #if targetEnvironment(macCatalyst)
        if let nsUrl = NSURL(string: path.absoluteString) {
            shareItems.append(nsUrl)
        }
        #else
        shareItems.append(path)
        #endif
        let vc = UIActivityViewController(activityItems: [path], applicationActivities: [])
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
        vc.popoverPresentationController?.sourceView = views[currentPage].exportButton
        vc.popoverPresentationController?.sourceRect = views[currentPage].exportButton.bounds
        present(vc, animated: true)
    }

    func setSync(progress: BTServiceProgress?, for viewModel: TagChartsViewModel) {
        if let index = viewModels.firstIndex(where: { $0.uuid.value == viewModel.uuid.value }), index < views.count {
            let view = views[index]
            if let progress = progress {
                view.syncStatusLabel.isHidden = false
                view.syncButton.isHidden = true
                view.clearButton.isHidden = true
                view.exportButton.isHidden = true
                switch progress {
                case .connecting:
                    view.syncStatusLabel.text = "TagCharts.Status.Connecting".localized()
                case .serving:
                    view.syncStatusLabel.text = "TagCharts.Status.Serving".localized()
                case .disconnecting:
                    view.syncStatusLabel.text = "TagCharts.Status.Disconnecting".localized()
                case .success:
                    view.syncStatusLabel.text = "TagCharts.Status.Success".localized()
                case .failure:
                    view.syncStatusLabel.text = "TagCharts.Status.Error".localized()
                }
            } else {
                view.syncStatusLabel.isHidden = true
                view.syncButton.isHidden = false
                view.clearButton.isHidden = false
                view.exportButton.isHidden = false
            }
        }
    }

    func showFailedToSyncIn(connectionTimeout: TimeInterval) {
        let message = String.localizedStringWithFormat("TagCharts.FailedToSyncDialog.message".localized(),
                                                       connectionTimeout)
        let alertVC = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "OK".localized(), style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }

    func showFailedToServeIn(serviceTimeout: TimeInterval) {
        let message = String.localizedStringWithFormat("TagCharts.FailedToServeDialog.message".localized(),
                                                       serviceTimeout)
        let alertVC = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "OK".localized(), style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }

    func showSwipeUpInstruction() {
        gestureInstructor.show(.swipeUp, after: 0.1)
    }
}

// MARK: - IBActions
extension TagChartsScrollViewController {
    @IBAction func menuButtonTouchUpInside(_ sender: Any) {
        output.viewDidTriggerMenu()
    }

}

// MARK: - View lifecycle
extension TagChartsScrollViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
        setupLocalization()
        updateUI()
        output.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        restartAnimations()
        output.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        output.viewWillDisappear()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        let page = CGFloat(currentPage)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            let width = coordinator.containerView.bounds.width
            self?.scrollView.contentOffset = CGPoint(x: page * width, y: 0)
        }, completion: { [weak self] (_) in
            let width = coordinator.containerView.bounds.width
            self?.scrollView.contentOffset = CGPoint(x: page * width, y: 0)
            self?.output.viewDidTransition()
        })
        super.viewWillTransition(to: size, with: coordinator)
        gestureInstructor.dismissThenResume()
    }
}

// MARK: - UIScrollViewDelegate
extension TagChartsScrollViewController: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        output.viewDidScroll(to: viewModels[currentPage])
    }
}

// MARK: - ChartViewDelegate
extension TagChartsScrollViewController: ChartViewDelegate {

}

// MARK: - TrippleChartViewDelegate
extension TagChartsScrollViewController: TrippleChartViewDelegate {
    func trippleChart(view: TrippleChartView, didTriggerCards sender: Any) {
        if let index = views.firstIndex(of: view),
            index < viewModels.count {
            output.viewDidTriggerCards(for: viewModels[index])
        }
    }

    func trippleChart(view: TrippleChartView, didTriggerSettings sender: Any) {
        if let index = views.firstIndex(of: view),
            index < viewModels.count {
            output.viewDidTriggerSettings(for: viewModels[index])
        }
    }

    func trippleChart(view: TrippleChartView, didTriggerClear sender: Any) {
        if let index = views.firstIndex(of: view),
            index < viewModels.count {
            output.viewDidTriggerClear(for: viewModels[index])
        }
    }

    func trippleChart(view: TrippleChartView, didTriggerSync sender: Any) {
        if let index = views.firstIndex(of: view),
            index < viewModels.count {
            output.viewDidTriggerSync(for: viewModels[index])
        }
    }

    func trippleChart(view: TrippleChartView, didTriggerExport sender: Any) {
        if let index = views.firstIndex(of: view),
            index < viewModels.count {
            output.viewDidTriggerExport(for: viewModels[index])
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension TagChartsScrollViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let pan = gestureRecognizer as? UIPanGestureRecognizer {
            let velocity = pan.velocity(in: scrollView)
            return abs(velocity.y) > abs(velocity.x) && UIApplication.shared.statusBarOrientation.isPortrait
        } else {
            return true
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureRecognizer.view != otherGestureRecognizer.view
    }
}

// MARK: - View configuration
extension TagChartsScrollViewController {

    private func configureViews() {
        configurePanGestureRecognozer()
        configureGestureInstructor()
        configureRestartAnimationsOnAppDidBecomeActive()
    }

    private func configureRestartAnimationsOnAppDidBecomeActive() {
        appDidBecomeActiveToken = NotificationCenter
            .default
            .addObserver(forName: UIApplication.didBecomeActiveNotification,
                         object: nil,
                         queue: .main) { [weak self] _ in
                self?.restartAnimations()
        }
    }

    private func configureGestureInstructor() {
        GestureInstructor.appearance.tapImage = UIImage(named: "gesture-assistant-hand")
    }

    private func configurePanGestureRecognozer() {
        let gr = UIPanGestureRecognizer()
        gr.delegate = self
        gr.cancelsTouchesInView = true
        scrollView.addGestureRecognizer(gr)
        gr.addTarget(tagChartsDismissInteractiveTransition as Any,
                     action: #selector(TagChartsDismissTransitionAnimation.handleHidePan(_:)))
    }

    private func configure(_ chartView: LineChartView) {
        chartView.delegate = self

        chartView.chartDescription?.enabled = false

        chartView.dragEnabled = true
        chartView.setScaleEnabled(true)
        chartView.pinchZoomEnabled = false
        chartView.highlightPerDragEnabled = false

        chartView.backgroundColor = .clear

        chartView.legend.enabled = false

        let xAxis = chartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.labelFont = .systemFont(ofSize: 10, weight: .light)
        xAxis.labelTextColor = UIColor.white
        xAxis.drawAxisLineEnabled = false
        xAxis.drawGridLinesEnabled = true
        xAxis.centerAxisLabelsEnabled = false
        xAxis.granularity = 300
        xAxis.valueFormatter = DateValueFormatter()
        xAxis.granularityEnabled = true

        let leftAxis = chartView.leftAxis
        leftAxis.labelPosition = .outsideChart
        leftAxis.labelFont = .systemFont(ofSize: 10, weight: .light)
        leftAxis.drawGridLinesEnabled = true

        leftAxis.labelTextColor = UIColor.white

        chartView.rightAxis.enabled = false
        chartView.legend.form = .line

        chartView.noDataTextColor = UIColor.white
        chartView.noDataText = noChartDataText.localized()

        chartView.scaleXEnabled = true
        chartView.scaleYEnabled = true
    }

    private func configure(_ set: LineChartDataSet) {
        set.axisDependency = .left
        set.setColor(UIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1))
        set.lineWidth = 1.5
        set.drawCirclesEnabled = true
        if set.entries.count == 1 {
            set.circleRadius = 6
        } else {
            set.circleRadius = 2
        }
        set.drawValuesEnabled = false
        set.fillAlpha = 0.26
        set.fillColor = UIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1)
        set.highlightColor = UIColor(red: 244/255, green: 117/255, blue: 117/255, alpha: 1)
        set.drawCircleHoleEnabled = false
        set.drawFilledEnabled = true
        set.highlightEnabled = false
    }

    private func split(_ values: [TagChartsPoint]) -> [IChartDataSet]? {
        let interval: TimeInterval = 60 * 60
        var points = [ChartDataEntry]()
        var sets = [IChartDataSet]()
        var previousValue: TimeInterval
        if values.count > 0 {
            previousValue = values[0].date.timeIntervalSince1970
        } else {
            previousValue = Date.distantPast.timeIntervalSince1970
        }
        for value in values {
            if value.date.timeIntervalSince1970 - previousValue < interval {
                points.append(ChartDataEntry(x: value.date.timeIntervalSince1970, y: value.value))
            } else {
                let set = LineChartDataSet(entries: points, label: "Temperature")
                configure(set)
                sets.append(set)
                points = [ChartDataEntry]()
                points.append(ChartDataEntry(x: value.date.timeIntervalSince1970, y: value.value))
            }
            previousValue = value.date.timeIntervalSince1970
        }
        let set = LineChartDataSet(entries: points, label: "Temperature")
        configure(set)
        sets.append(set)
        return sets
    }

    private func zoomAndScrollToLast24h(_ values: [TagChartsPoint], _ chartView: LineChartView) {
        if let firstX = values.first?.date.timeIntervalSince1970,
            let lastX = values.last?.date.timeIntervalSince1970 {
            let scaleX = CGFloat((lastX - firstX) / (60 * 60 * 24))
            chartView.zoom(scaleX: 0, scaleY: 0, x: 0, y: 0)
            chartView.zoom(scaleX: scaleX, scaleY: 0, x: 0, y: 0)
            chartView.moveViewToX(lastX - (60 * 60 * 24))
        }
    }

    private func configureData(chartView: LineChartView, values: [TagChartsPoint]?) {
        if let values = values {
            configure(chartView)
            let data = LineChartData(dataSets: split(values))
            chartView.data = data
            zoomAndScrollToLast24h(values, chartView)
        }
    }

    private func bindTemperature(view: TrippleChartView, with viewModel: TagChartsViewModel) {
        let temperatureUnit = viewModel.temperatureUnit
        let fahrenheit = viewModel.fahrenheit
        let celsius = viewModel.celsius
        let kelvin = viewModel.kelvin
        let temperatureChart = view.temperatureChart

        let temperatureBlock: ((LineChartView, [TagChartsPoint]?) -> Void) = {
            [weak self,
            weak temperatureUnit,
            weak fahrenheit,
            weak celsius,
            weak kelvin] chartView, _ in
           if let temperatureUnit = temperatureUnit?.value {
               switch temperatureUnit {
               case .celsius:
                   self?.configureData(chartView: chartView, values: celsius?.value)
               case .fahrenheit:
                   self?.configureData(chartView: chartView, values: fahrenheit?.value)
               case .kelvin:
                   self?.configureData(chartView: chartView, values: kelvin?.value)
               }
           } else {
               self?.configureData(chartView: chartView, values: nil)
           }
        }

        view.temperatureChart.bind(viewModel.celsius, fire: false, block: temperatureBlock)
        view.temperatureChart.bind(viewModel.fahrenheit, fire: false, block: temperatureBlock)
        view.temperatureChart.bind(viewModel.kelvin, fire: false, block: temperatureBlock)

        view.temperatureUnitLabel.bind(viewModel.temperatureUnit) { [weak temperatureChart] label, temperatureUnit in
            if let temperatureUnit = temperatureUnit {
                switch temperatureUnit {
                case .celsius:
                    label.text = "°C".localized()
                case .fahrenheit:
                    label.text = "°F".localized()
                case .kelvin:
                    label.text = "K".localized()
                }
            } else {
                label.text = "N/A".localized()
            }
            if let temperatureChart = temperatureChart {
                temperatureBlock(temperatureChart, nil)
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func bindHumidity(view: TrippleChartView, with viewModel: TagChartsViewModel) {
        let hu = viewModel.humidityUnit
        let rh = viewModel.relativeHumidity
        let ah = viewModel.absoluteHumidity
        let tu = viewModel.temperatureUnit
        let dc = viewModel.dewPointCelsius
        let df = viewModel.dewPointFahrenheit
        let dk = viewModel.dewPointKelvin
        let humidityUnit = viewModel.humidityUnit
        let humidityChart = view.humidityChart

        let humidityBlock: ((LineChartView, [TagChartsPoint]?) -> Void) = {
            [weak self,
            weak hu,
            weak rh,
            weak ah,
            weak tu,
            weak dc,
            weak df,
            weak dk] chartView, _ in
            if let hu = hu?.value {
                switch hu {
                case .percent:
                    self?.configureData(chartView: chartView, values: rh?.value)
                case .gm3:
                    self?.configureData(chartView: chartView, values: ah?.value)
                case .dew:
                    if let tu = tu?.value {
                        switch tu {
                        case .celsius:
                            self?.configureData(chartView: chartView, values: dc?.value)
                        case .fahrenheit:
                            self?.configureData(chartView: chartView, values: df?.value)
                        case .kelvin:
                            self?.configureData(chartView: chartView, values: dk?.value)
                        }
                    }
                }
            }
        }

        view.humidityChart.bind(viewModel.relativeHumidity, fire: false, block: humidityBlock)
        view.humidityChart.bind(viewModel.absoluteHumidity, fire: false, block: humidityBlock)
        view.humidityChart.bind(viewModel.dewPointKelvin, fire: false, block: humidityBlock)
        view.humidityChart.bind(viewModel.dewPointCelsius, fire: false, block: humidityBlock)
        view.humidityChart.bind(viewModel.dewPointFahrenheit, fire: false, block: humidityBlock)
        view.humidityChart.bind(viewModel.humidityUnit, fire: false) { chartView, _ in
            humidityBlock(chartView, nil)
        }
        view.humidityChart.bind(viewModel.temperatureUnit, fire: false, block: { chartView, _ in
            humidityBlock(chartView, nil)
        })

        let temperatureUnit = viewModel.temperatureUnit
        let humidityUnitBlock: ((UILabel, Any) -> Void) = {
            [weak humidityChart,
            weak temperatureUnit,
            weak humidityUnit] label, _ in
            if let humidityUnit = humidityUnit?.value {
                switch humidityUnit {
                case .percent:
                    label.text = "%".localized()
                case .dew:
                    if let temperatureUnit = temperatureUnit?.value {
                        switch temperatureUnit {
                        case .celsius:
                            label.text = "°C".localized()
                        case .fahrenheit:
                            label.text = "°F".localized()
                        case .kelvin:
                            label.text = "K".localized()
                        }
                    } else {
                        label.text = "N/A".localized()
                    }
                case .gm3:
                    label.text = "g/m³".localized()
                }
            } else {
                label.text = "N/A".localized()
            }
            if let humidityChart = humidityChart {
                humidityBlock(humidityChart, nil)
            }
        }
        view.humidityUnitLabel.bind(viewModel.humidityUnit, fire: false, block: humidityUnitBlock)
        view.humidityUnitLabel.bind(viewModel.temperatureUnit, block: humidityUnitBlock)

    }

    private func bind(view: TrippleChartView, with viewModel: TagChartsViewModel) {

        view.nameLabel.bind(viewModel.name, block: { $0.text = $1?.uppercased() ?? "N/A".localized() })
        view.backgroundImageView.bind(viewModel.background) { $0.image = $1 }

        bindTemperature(view: view, with: viewModel)
        bindHumidity(view: view, with: viewModel)

        view.pressureChart.bind(viewModel.pressure) { [weak self] chartView, pressure in
            self?.configureData(chartView: chartView, values: pressure)
        }

        view.pressureUnitLabel.text = "hPa".localized()

        view.alertView.bind(viewModel.isConnected) { (view, isConnected) in
            view.isHidden = !isConnected.bound
        }

        view.alertImageView.bind(viewModel.alertState) { [weak self] (imageView, state) in
            if let state = state {
                switch state {
                case .empty:
                    imageView.alpha = 1.0
                    imageView.image = self?.alertOffImage
                case .registered:
                    imageView.alpha = 1.0
                    imageView.image = self?.alertOnImage
                case .firing:
                    if imageView.image != self?.alertActiveImage {
                        imageView.image = self?.alertActiveImage
                        UIView.animate(withDuration: 0.5,
                                      delay: 0,
                                      options: [.repeat, .autoreverse],
                                      animations: { [weak imageView] in
                                        imageView?.alpha = 0.0
                                    })
                    }
                }
            } else {
                imageView.image = nil
            }
       }
    }

}

// MARK: - Update UI
extension TagChartsScrollViewController {
    private func updateUI() {
        updateUIViewModels()
    }

    private func updateUIViewModels() {
        if isViewLoaded {
            views.forEach({ $0.removeFromSuperview() })
            views.removeAll()

            if viewModels.count > 0 {
                var leftView: UIView = scrollView
                for viewModel in viewModels {
                    let view = TrippleChartView()
                    view.delegate = self
                    view.translatesAutoresizingMaskIntoConstraints = false
                    scrollView.addSubview(view)
                    position(view, leftView)
                    bind(view: view, with: viewModel)
                    views.append(view)
                    leftView = view
                }
                scrollView.addConstraint(NSLayoutConstraint(item: leftView,
                                                            attribute: .trailing,
                                                            relatedBy: .equal,
                                                            toItem: scrollView,
                                                            attribute: .trailing,
                                                            multiplier: 1.0,
                                                            constant: 0.0))
                localize()
            }
        }
    }

    private func position(_ view: UIView, _ leftView: UIView) {
        scrollView.addConstraint(NSLayoutConstraint(item: view,
                                                    attribute: .leading,
                                                    relatedBy: .equal,
                                                    toItem: leftView,
                                                    attribute: leftView == scrollView ? .leading : .trailing,
                                                    multiplier: 1.0,
                                                    constant: 0.0))
        scrollView.addConstraint(NSLayoutConstraint(item: view,
                                                    attribute: .top,
                                                    relatedBy: .equal,
                                                    toItem: scrollView,
                                                    attribute: .top,
                                                    multiplier: 1.0,
                                                    constant: 0.0))
        scrollView.addConstraint(NSLayoutConstraint(item: view,
                                                    attribute: .bottom,
                                                    relatedBy: .equal,
                                                    toItem: scrollView,
                                                    attribute: .bottom,
                                                    multiplier: 1.0,
                                                    constant: 0.0))
        scrollView.addConstraint(NSLayoutConstraint(item: view,
                                                    attribute: .width,
                                                    relatedBy: .equal,
                                                    toItem: scrollView,
                                                    attribute: .width,
                                                    multiplier: 1.0,
                                                    constant: 0.0))
        scrollView.addConstraint(NSLayoutConstraint(item: view,
                                                    attribute: .height,
                                                    relatedBy: .equal,
                                                    toItem: scrollView,
                                                    attribute: .height,
                                                    multiplier: 1.0,
                                                    constant: 0.0))
    }

    private func restartAnimations() {
        // restart blinking animation if needed
        for i in 0..<viewModels.count where i < views.count {
            let viewModel = viewModels[i]
            let view = views[i]
            let imageView = view.alertImageView
            if let state = viewModel.alertState.value {
                imageView.alpha = 1.0
                switch state {
                case .empty:
                    imageView.image = alertOffImage
                case .registered:
                    imageView.image = alertOnImage
                case .firing:
                    imageView.image = alertActiveImage
                    imageView.layer.removeAllAnimations()
                    UIView.animate(withDuration: 0.5,
                                   delay: 0,
                                   options: [.repeat, .autoreverse],
                                   animations: { [weak imageView] in
                                    imageView?.alpha = 0.0
                                })
                }
            } else {
                imageView.image = nil
            }
        }
    }
}
// swiftlint:enable file_length
