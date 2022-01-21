import UIKit
import Charts
import BTKit
import GestureInstructions

class TagChartsScrollViewController: UIViewController {
    var output: TagChartsViewOutput!

    var tagChartsDismissInteractiveTransition: UIViewControllerInteractiveTransitioning!

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var syncButton: UIButton!
    @IBOutlet weak var syncStatusLabel: UILabel!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var bacgroundImageViewOverlay: UIImageView!
    @IBOutlet weak var alertImageView: UIImageView!

    var viewModel: TagChartsViewModel = TagChartsViewModel(type: .ruuvi) {
        didSet {
            updateUIViewModel()
        }
    }
    private var chartViews: [TagChartView] = [] {
        didSet {
            oldValue.forEach({
                $0.removeFromSuperview()
            })
            addChartViews()
        }
    }
    private var appDidBecomeActiveToken: NSObjectProtocol?
    private let alertActiveImage = UIImage(named: "icon-alert-active")
    private let alertOffImage = UIImage(named: "icon-alert-off")
    private let alertOnImage = UIImage(named: "icon-alert-on")

    deinit {
        appDidBecomeActiveToken?.invalidate()
    }
// MARK: - Actions
    @IBAction func didTriggerCards(_ sender: Any) {
        output.viewDidTriggerCards(for: viewModel)
    }

    @IBAction func didTriggerSettings(_ sender: Any) {
        output.viewDidTriggerSettings(for: viewModel)
    }

    @IBAction func didTriggerClear(_ sender: Any) {
        output.viewDidTriggerClear(for: viewModel)
    }

    @IBAction func didTriggerSync(_ sender: Any) {
        output.viewDidTriggerSync(for: viewModel)
    }
}

// MARK: - TagChartsViewInput
extension TagChartsScrollViewController: TagChartsViewInput {
    var viewIsVisible: Bool {
        return self.isViewLoaded && self.view.window != nil
    }

    func setupChartViews(chartViews: [TagChartView]) {
        self.chartViews = chartViews
    }

    func localize() {
        clearButton.setTitle("TagCharts.Clear.title".localized(), for: .normal)
        syncButton.setTitle("TagCharts.Sync.title".localized(), for: .normal)
        output.viewDidLocalized()
    }

    func showBluetoothDisabled() {
        let title = "TagCharts.BluetoothDisabledAlert.title".localized()
        let message = "TagCharts.BluetoothDisabledAlert.message".localized()
        showAlert(title: title, message: message)
    }

    func showSyncConfirmationDialog(for viewModel: TagChartsViewModel) {
        let title = "TagCharts.SyncConfirmationDialog.title".localized()
        let message = "TagCharts.SyncConfirmationDialog.message".localized()
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        let fromTag = "OK".localized()
        alertVC.addAction(UIAlertAction(title: fromTag, style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmToSyncWithTag(for: viewModel)
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

    func setSync(progress: BTServiceProgress?, for viewModel: TagChartsViewModel) {
        if let progress = progress {
            syncStatusLabel.isHidden = false
            syncButton.isHidden = true
            clearButton.isHidden = true
            switch progress {
            case .connecting:
                syncStatusLabel.text = "TagCharts.Status.Connecting".localized()
            case .serving:
                syncStatusLabel.text = "TagCharts.Status.Serving".localized()
            case .disconnecting:
                syncStatusLabel.text = "TagCharts.Status.Disconnecting".localized()
            case .success:
                ///Show success message
                syncStatusLabel.text = "TagCharts.Status.Success".localized()
                /// Hide success message and show buttons after two seconds
                showUtilButtons()
            case .failure:
                ///Show success message
                syncStatusLabel.text = "TagCharts.Status.Error".localized()
                /// Hide success message and show buttons after two seconds
                showUtilButtons()
            }
        } else {
            /// Show buttons after two seconds if there's an unexpected error
            showUtilButtons()
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
        coordinator.animate(alongsideTransition: { _ in
        }, completion: { [weak self] (_) in
            self?.output.viewDidTransition()
        })
        super.viewWillTransition(to: size, with: coordinator)
        gestureInstructor.dismissThenResume()
    }
}

// MARK: - UIScrollViewDelegate
extension TagChartsScrollViewController: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    }
}

// MARK: - ChartViewDelegate
extension TagChartsScrollViewController: ChartViewDelegate {

}

// MARK: - UIGestureRecognizerDelegate
extension TagChartsScrollViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let pan = gestureRecognizer as? UIPanGestureRecognizer {
            let velocity = pan.velocity(in: scrollView)
            return abs(velocity.y) > abs(velocity.x) && UIWindow.isPortrait
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

}

// MARK: - Update UI
extension TagChartsScrollViewController {
    private func updateUI() {
        updateUIViewModel()
    }

    private func addChartViews() {
        chartViews.forEach({ chartView in
            scrollView.addSubview(chartView)
        })
        localize()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        var maxY: CGFloat = 0
        let height: CGFloat
        if UIWindow.isLandscape {
            height = scrollView.frame.height
        } else {
            height = scrollView.frame.height / 3
        }
        chartViews.forEach({ chartView in
            chartView.frame = CGRect(x: 0, y: maxY, width: scrollView.frame.width, height: height)
            maxY += height
        })
        scrollView.contentSize = CGSize(width: scrollView.frame.width, height: height * CGFloat(chartViews.count))
        scrollView.layoutSubviews()
    }

    private func bindViewModel() {
        nameLabel?.bind(viewModel.name, block: { $0.text = $1?.uppercased() ?? "N/A".localized() })
        backgroundImageView?.bind(viewModel.background) { $0.image = $1 }
        bacgroundImageViewOverlay?.bind(viewModel.background, block: {
            $0.isHidden = $1 == nil
        })
        alertImageView?.bind(viewModel.isConnected) { (view, isConnected) in
            view.isHidden = !isConnected.bound
        }
        alertImageView?.bind(viewModel.alertState) { [weak self] (imageView, state) in
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

    private func updateUIViewModel() {
        bindViewModel()
    }

    private func restartAnimations() {
        // restart blinking animation if needed
        if let state = viewModel.alertState.value {
            alertImageView.alpha = 1.0
            switch state {
            case .empty:
                alertImageView.image = alertOffImage
            case .registered:
                alertImageView.image = alertOnImage
            case .firing:
                alertImageView.image = alertActiveImage
                alertImageView.layer.removeAllAnimations()
                UIView.animate(withDuration: 0.5,
                               delay: 0,
                               options: [.repeat, .autoreverse],
                               animations: { [weak alertImageView] in
                                alertImageView?.alpha = 0.0
                            })
            }
        } else {
            alertImageView.image = nil
        }
    }
    
    /// This method helps present the clear and sync button after a successful or failed operation.
    /// However, the visibility changes after two seconds to make sure user have a noticeable time to see the operation response
    private func showUtilButtons() {
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2), execute: { [weak self] in
            self?.syncStatusLabel.isHidden = true
            self?.syncButton.isHidden = false
            self?.clearButton.isHidden = false
        })
    }
}
