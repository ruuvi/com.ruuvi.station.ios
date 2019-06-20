import UIKit
import Localize_Swift
import DateToolsSwift

class DashboardScrollViewController: UIViewController {
    var output: DashboardViewOutput!
    var menuPresentInteractiveTransition: UIViewControllerInteractiveTransitioning!
    var menuDismissInteractiveTransition: UIViewControllerInteractiveTransitioning!
    
    @IBOutlet weak var settingsButton: UIBarButtonItem!
    @IBOutlet weak var scrollView: UIScrollView!
    
    var temperatureUnit: TemperatureUnit = .celsius { didSet { updateUITemperatureUnit() } }
    var viewModels = [DashboardRuuviTagViewModel]() { didSet { updateUIRuuviTags() }  }
    
    private var ruuviTagViews = [DashboardRuuviTagViewModel: DashboardRuuviTagView]()
    private var currentPage: Int {
        return Int(scrollView.contentOffset.x / scrollView.frame.size.width)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

// MARK: - DashboardViewInput
extension DashboardScrollViewController: DashboardViewInput {

    func localize() {
        
    }
    
    func apply(theme: Theme) {
        
    }

    func showBluetoothDisabled() {
        let alertVC = UIAlertController(title: "Dashboard.BluetoothDisabledAlert.title".localized(), message: "Dashboard.BluetoothDisabledAlert.message".localized(), preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "OK".localized(), style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }
    
    func reload(viewModel: DashboardRuuviTagViewModel) {
        if let view = ruuviTagViews[viewModel] {
            configure(view: view, with: viewModel)
            ruuviTagViews.removeValue(forKey: viewModel)
            ruuviTagViews[viewModel] = view
        }
    }
    
    func showMenu(for viewModel: DashboardRuuviTagViewModel) {
        var infoText = String(format: "Dashboard.settings.dataFormat.format".localized(), viewModel.version)
        if let voltage = viewModel.voltage {
            infoText.append(String(format: "Dashboard.settings.voltage.format".localized(), voltage))
        }
        if let humidityOffsetDate = viewModel.humidityOffsetDate {
            let df = DateFormatter()
            df.dateFormat = "dd MMMM yyyy"
            infoText.append(String(format: "Dashboard.settings.humidityOffsetDate.format".localized(), df.string(from: humidityOffsetDate)))
        }
        let controller = UIAlertController(title: nil, message: infoText, preferredStyle: .actionSheet)
        controller.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        controller.addAction(UIAlertAction(title: "Dashboard.settings.calibrateHumidity.title".localized(), style: .destructive, handler: { [weak self] (action) in
            self?.output.viewDidAskToCalibrateHumidity(viewModel: viewModel)
        }))
        controller.addAction(UIAlertAction(title: "Dashboard.settings.remove.title".localized(), style: .destructive, handler: { [weak self] (action) in
            self?.output.viewDidAskToRemove(viewModel: viewModel)
        }))
        controller.addAction(UIAlertAction(title: "Dashboard.settings.rename.title".localized(), style: .default, handler: { [weak self] (action) in
            self?.output.viewDidAskToRename(viewModel: viewModel)
        }))
        present(controller, animated: true)
    }
    
    func showRenameDialog(for viewModel: DashboardRuuviTagViewModel) {
        let alert = UIAlertController(title: "Dashboard.settings.rename.title.EnterAName".localized(), message: nil, preferredStyle: .alert)
        alert.addTextField { (textField) in
            textField.autocapitalizationType = UITextAutocapitalizationType.sentences
            if viewModel.name == viewModel.uuid || viewModel.name == viewModel.mac {
                textField.text = nil
            } else {
                textField.text = viewModel.name
            }
        }
        alert.addAction(UIAlertAction(title: "OK".localized(), style: .default, handler: { [weak alert, weak self] (action) in
            let textField = alert?.textFields![0]
            self?.output.viewDidChangeName(of: viewModel, to: textField?.text ?? "")
        }))
        present(alert, animated: true)
    }
    
    func scroll(to index: Int) {
        let key = "DashboardScrollViewController.hasShownSwipeAlert"
        if viewModels.count > 1 && !UserDefaults.standard.bool(forKey: key) {
            UserDefaults.standard.set(true, forKey: key)
            let alert = UIAlertController(title: "Dashboard.SwipeAlert.title".localized(), message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK".localized(), style: .cancel, handler: nil))
            present(alert, animated: true)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let sSelf = self else { return }
            let x: CGFloat = sSelf.scrollView.frame.size.width * CGFloat(index)
            sSelf.scrollView.setContentOffset(CGPoint(x: x, y: 0), animated: true)
        }
    }
}

// MARK: - IBActions
extension DashboardScrollViewController {
    @IBAction func settingsButtonTouchUpInside(_ sender: UIButton) {
        if currentPage >= 0 && currentPage < viewModels.count {
            let viewModel = viewModels[currentPage]
            if let viewModel = ruuviTagViews.keys.first(where: { $0.uuid == viewModel.uuid }) {
                output.viewDidTriggerSettings(for: viewModel)
            }
        }
    }
    
    @IBAction func menuButtonTouchUpInside(_ sender: Any) {
        output.viewDidTriggerMenu()
    }
}

// MARK: - View lifecycle
extension DashboardScrollViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
        updateUI()
        configureViews()
        output.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        output.viewWillAppear()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        output.viewWillDisappear()
    }
}

// MARK: - DashboardRuuviTagViewDelegate
extension DashboardScrollViewController: DashboardRuuviTagViewDelegate {
    func dashboardRuuviTag(view: DashboardRuuviTagView, didTapOnRSSI sender: Any?) {
        if currentPage >= 0 && currentPage < viewModels.count {
            let viewModel = viewModels[currentPage]
            if let viewModel = ruuviTagViews.keys.first(where: { $0.uuid == viewModel.uuid }) {
                output.viewDidTapOnRSSI(for: viewModel)
            }
        }
    }
}

// MARK: - Configure view
extension DashboardScrollViewController {
    private func configure(view: DashboardRuuviTagView, with viewModel: DashboardRuuviTagViewModel) {
        view.nameLabel.text = viewModel.name.uppercased()
        configureTemperature(view: view, with: viewModel)
        view.humidityLabel.text = String(format: "%.2f", viewModel.humidity + viewModel.humidityOffset) + " %"
        view.pressureLabel.text = "\(viewModel.pressure) hPa"
        view.rssiLabel.text = "\(viewModel.rssi) dBm"
        view.updatedAt = Date()
        view.backgroundImage.image = viewModel.background
    }
    
    private func configureTemperature(view: DashboardRuuviTagView, with viewModel: DashboardRuuviTagViewModel) {
        switch temperatureUnit {
        case .celsius:
            view.temperatureLabel.text = String(format: "%.2f", viewModel.celsius)
            view.temperatureUnitLabel.text = "°C"
        case .fahrenheit:
            view.temperatureLabel.text = String(format: "%.2f", viewModel.fahrenheit)
            view.temperatureUnitLabel.text = "°F"
        }
    }
}

// MARK: - View configuration
extension DashboardScrollViewController {
    private func configureViews() {
        configureEdgeGestureRecognozer()
    }
    
    private func configureEdgeGestureRecognozer() {
        let leftScreenEdgeGestureRecognizer = UIScreenEdgePanGestureRecognizer()
        leftScreenEdgeGestureRecognizer.cancelsTouchesInView = true
        scrollView.addGestureRecognizer(leftScreenEdgeGestureRecognizer)
        leftScreenEdgeGestureRecognizer.addTarget(menuPresentInteractiveTransition as Any, action:#selector(MenuTablePresentTransitionAnimation.handlePresentMenuLeftScreenEdge(_:)))
        leftScreenEdgeGestureRecognizer.edges = .left
    }
}

// MARK: - Update UI
extension DashboardScrollViewController {
    private func updateUI() {
        updateUITemperatureUnit()
        updateUIRuuviTags()
    }
    
    private func updateUITemperatureUnit() {
        if isViewLoaded {
            ruuviTagViews.forEach({ configureTemperature(view: $1, with: $0) })
        }
    }
    
    private func updateUIRuuviTags() {
        if isViewLoaded {
            ruuviTagViews.values.forEach({ $0.removeFromSuperview() })
            
            if viewModels.count > 0 {
                var leftView: UIView = scrollView
                for viewModel in viewModels {
                    let view = Bundle.main.loadNibNamed("DashboardRuuviTagView", owner: self, options: nil)?.first as! DashboardRuuviTagView
                    view.delegate = self
                    view.translatesAutoresizingMaskIntoConstraints = false
                    scrollView.addSubview(view)
                    position(view, leftView)
                    configure(view: view, with: viewModel)
                    ruuviTagViews[viewModel] = view
                    leftView = view
                }
                scrollView.addConstraint(NSLayoutConstraint(item: leftView, attribute: .trailing, relatedBy: .equal
                    , toItem: scrollView, attribute: .trailing, multiplier: 1.0, constant: 0.0))
            }
        }
    }
    
    private func position(_ view: DashboardRuuviTagView, _ leftView: UIView) {
        scrollView.addConstraint(NSLayoutConstraint(item: view, attribute: .leading, relatedBy: .equal, toItem: leftView, attribute: leftView == scrollView ? .leading : .trailing, multiplier: 1.0, constant: 0.0))
        scrollView.addConstraint(NSLayoutConstraint(item: view, attribute: .top, relatedBy: .equal, toItem: scrollView, attribute: .top, multiplier: 1.0, constant: 0.0))
        scrollView.addConstraint(NSLayoutConstraint(item: view, attribute: .bottom, relatedBy: .equal, toItem: scrollView, attribute: .bottom, multiplier: 1.0, constant: 0.0))
        scrollView.addConstraint(NSLayoutConstraint(item: view, attribute: .width, relatedBy: .equal, toItem: scrollView, attribute: .width, multiplier: 1.0, constant: 0.0))
        scrollView.addConstraint(NSLayoutConstraint(item: view, attribute: .height, relatedBy: .equal, toItem: scrollView, attribute: .height, multiplier: 1.0, constant: 0.0))
    }
}
