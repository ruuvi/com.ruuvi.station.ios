import UIKit
import Localize_Swift

class DashboardScrollViewController: UIViewController {
    var output: DashboardViewOutput!
    
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
    
    func reload(viewModel: DashboardRuuviTagViewModel) {
        if let view = ruuviTagViews[viewModel] {
            configure(view: view, with: viewModel)
        }
    }
    
    func showMenu(for viewModel: DashboardRuuviTagViewModel) {
        var infoText = String(format: "Dashboard.settings.dataFormat.format".localized(), viewModel.version)
        if let voltage = viewModel.voltage {
            infoText.append(String(format: "Dashboard.settings.voltage.format".localized(), voltage))
        }
        let controller = UIAlertController(title: nil, message: infoText, preferredStyle: .actionSheet)
        controller.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        controller.addAction(UIAlertAction(title: "Dashboard.settings.remove.title".localized(), style: .destructive, handler: { [weak self] (action) in
            self?.output.viewDidAskToRemove(viewModel: viewModel)
        }))
        controller.addAction(UIAlertAction(title: "Dashboard.settings.rename.title".localized(), style: .default, handler: { [weak self] (action) in
            self?.output.viewDidAskToRename(viewModel: viewModel)
        }))
        present(controller, animated: false)
    }
}

// MARK: - IBActions
extension DashboardScrollViewController {
    @IBAction func settingsButtonTouchUpInside(_ sender: UIButton) {
        if currentPage >= 0 && currentPage < viewModels.count {
            output.viewDidTriggerSettings(for: viewModels[currentPage])
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
        updateUI()
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

// MARK: - Configure view
extension DashboardScrollViewController {
    private func configure(view: DashboardRuuviTagView, with viewModel: DashboardRuuviTagViewModel) {
        view.nameLabel.text = viewModel.name.uppercased()
        configureTemperature(view: view, with: viewModel)
        view.humidityLabel.text = String(format: "%.2f", viewModel.humidity) + " %"
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
            view.temperatureUnitLabel.text = "°C"
        }
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
