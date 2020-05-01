// swiftlint:disable file_length
import UIKit
import Charts
import BTKit
import GestureInstructions

class TagChartsScrollViewController: UIViewController {
    var output: (TagChartsViewOutput & TagChartViewOutput)!

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
    private var currentTrippleView: TrippleChartView {
        return views[currentPage]
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
    var viewIsVisible: Bool {
        return self.isViewLoaded && self.view.window != nil
    }

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
        let fromTag = "TagCharts.SyncConfirmationDialog.WithTag.title".localized()
        alertVC.addAction(UIAlertAction(title: fromTag, style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmToSyncWithTag(for: viewModel)
        }))
        let fromWeb = "TagCharts.SyncConfirmationDialog.WithWeb.title".localized()
        alertVC.addAction(UIAlertAction(title: fromWeb, style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmToSyncWithWeb(for: viewModel)
        }))
        let fromKaltiot = "TagCharts.SyncConfirmationDialog.WithWebKaltiot.title".localized()
        alertVC.addAction(UIAlertAction(title: fromKaltiot, style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmToSyncWithWebKaltiot(for: viewModel)
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

    private func bindTemperature(view: TrippleChartView, with viewModel: TagChartsViewModel) {
        view.temperatureUnitLabel.bind(viewModel.temperatureUnit) { label, temperatureUnit in
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
        }
    }

    private func bindHumidity(view: TrippleChartView, with viewModel: TagChartsViewModel) {
        let humidityUnit = viewModel.humidityUnit
        let temperatureUnit = viewModel.temperatureUnit
        let humidityUnitBlock: ((UILabel, Any) -> Void) = {
            [weak temperatureUnit,
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
        }
        view.humidityUnitLabel.bind(viewModel.humidityUnit, fire: false, block: humidityUnitBlock)
        view.humidityUnitLabel.bind(viewModel.temperatureUnit, block: humidityUnitBlock)
    }

    private func bindCharts(view: TrippleChartView, with viewModel: TagChartsViewModel) {
        view.temperatureChart.tagUuid = viewModel.uuid.value
        viewModel.temperatureChart.value = view.temperatureChart
        view.temperatureChart.bind(viewModel.temperatureChartData) {
            [weak self] (view, dataSet) in
            view.data = dataSet
            view.output = self?.output
        }
        view.humidityChart.tagUuid = viewModel.uuid.value
        viewModel.humidityChart.value = view.humidityChart
        view.humidityChart.bind(viewModel.humidityChartData) {
            [weak self] (view, dataSet) in
            view.data = dataSet
            view.output = self?.output
        }
        view.pressureChart.tagUuid = viewModel.uuid.value
        viewModel.pressureChart.value = view.pressureChart
        view.pressureChart.bind(viewModel.pressureChartData) {
            [weak self] (view, dataSet) in
            view.data = dataSet
            view.output = self?.output
        }
    }
    private func bind(view: TrippleChartView, with viewModel: TagChartsViewModel) {

        view.nameLabel.bind(viewModel.name, block: { $0.text = $1?.uppercased() ?? "N/A".localized() })
        view.backgroundImageView.bind(viewModel.background) { $0.image = $1 }
        bindTemperature(view: view, with: viewModel)
        bindHumidity(view: view, with: viewModel)
        bindCharts(view: view, with: viewModel)

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

    private func addChartViews() {
        var leftView: UIView = scrollView
        for viewModel in viewModels {
            let view = TrippleChartView()
            view.delegate = self
            view.translatesAutoresizingMaskIntoConstraints = false
            scrollView.addSubview(view)
            position(view, leftView)
            bind(view: view, with: viewModel)
            bindCharts(view: view, with: viewModel)
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

    private func bindViewModels() {
        viewModels.enumerated().forEach { (index, viewModel) in
            if scrollView.bounds.contains(views[index].frame) {
                bind(view: views[index], with: viewModel)
            }
        }
    }

    private func updateUIViewModels() {
        if isViewLoaded && views.isEmpty {
            if viewModels.count > 0 {
                addChartViews()
            }
        } else {
            if viewModels.count == views.count {
                bindViewModels()
            } else if viewModels.count > 0 {
                views.forEach({ $0.removeFromSuperview() })
                views.removeAll()
                addChartViews()
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
