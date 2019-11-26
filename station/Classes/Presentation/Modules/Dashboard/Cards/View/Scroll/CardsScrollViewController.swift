import UIKit
import Localize_Swift
import GestureInstructions

class CardsScrollViewController: UIViewController {
    var output: CardsViewOutput!
    var menuPresentInteractiveTransition: UIViewControllerInteractiveTransitioning!
    var menuDismissInteractiveTransition: UIViewControllerInteractiveTransitioning!
    var tagChartsPresentInteractiveTransition: UIViewControllerInteractiveTransitioning!
    var tagChartsDismissInteractiveTransition: UIViewControllerInteractiveTransitioning!
    
    @IBOutlet weak var scrollView: UIScrollView!
    
    var viewModels = [CardsViewModel]() { didSet { updateUIViewModels() }  }
    
    private var views = [CardView]()
    private var currentPage: Int {
        if isViewLoaded {
            return Int(scrollView.contentOffset.x / scrollView.frame.size.width)
        } else {
            return 0
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

// MARK: - CardsViewInput
extension CardsScrollViewController: CardsViewInput {

    func localize() {
        
    }
    
    func apply(theme: Theme) {
        
    }
    
    func showWebTagAPILimitExceededError() {
        let alertVC = UIAlertController(title: "Cards.WebTagAPILimitExcededError.Alert.title".localized(), message: "Cards.WebTagAPILimitExcededError.Alert.message".localized(), preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "OK".localized(), style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }

    func showBluetoothDisabled() {
        let alertVC = UIAlertController(title: "Cards.BluetoothDisabledAlert.title".localized(), message: "Cards.BluetoothDisabledAlert.message".localized(), preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "OK".localized(), style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }
    
    func showSwipeLeftRightHint() {
        gestureInstructor.show(.swipeRight, after: 0.1)
    }
    
    func scroll(to index: Int, immediately: Bool = false) {
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
    
    func showKeepConnectionDialog(for viewModel: CardsViewModel) {
        let alert = UIAlertController(title: nil, message: "Cards.KeepConnectionDialog.message".localized(), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cards.KeepConnectionDialog.Dismiss.title".localized(), style: .cancel, handler: { [weak self] _ in
            self?.output.viewDidDismissKeepConnectionDialog(for: viewModel)
        }))
        alert.addAction(UIAlertAction(title: "Cards.KeepConnectionDialog.KeepConnection.title".localized(), style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmToKeepConnection(to: viewModel)
        }))
        present(alert, animated: true)
    }
}

// MARK: - IBActions
extension CardsScrollViewController {
    @IBAction func menuButtonTouchUpInside(_ sender: Any) {
        output.viewDidTriggerMenu()
    }
}

// MARK: - View lifecycle
extension CardsScrollViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        updateUI()
        configureViews()
        setupLocalization()
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
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        let page = CGFloat(currentPage)
        coordinator.animate(alongsideTransition: { [weak self] (context) in
            let width = coordinator.containerView.bounds.width
            self?.scrollView.contentOffset = CGPoint(x: page * width, y: 0)
        }) { [weak self] (context) in
            let width = coordinator.containerView.bounds.width
            self?.scrollView.contentOffset = CGPoint(x: page * width, y: 0)
        }
        super.viewWillTransition(to: size, with: coordinator)
    }
}

// MARK: - UIScrollViewDelegate
extension CardsScrollViewController: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        output.viewDidScroll(to: viewModels[currentPage])
    }
}

// MARK: - CardViewDelegate
extension CardsScrollViewController: CardViewDelegate {
    func card(view: CardView, didTriggerCharts sender: Any) {
        if let index = views.firstIndex(of: view),
            index < viewModels.count {
            output.viewDidTriggerChart(for: viewModels[index])
        }
    }
    
    func card(view: CardView, didTriggerSettings sender: Any) {
        if let index = views.firstIndex(of: view),
            index < viewModels.count {
            output.viewDidTriggerSettings(for: viewModels[index])
        }
    }
}

// MARK: - UITextFieldDelegate
extension CardsScrollViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let textFieldText = textField.text,
            let rangeOfTextToReplace = Range(range, in: textFieldText) else {
                return false
        }
        let substringToReplace = textFieldText[rangeOfTextToReplace]
        let count = textFieldText.count - substringToReplace.count + string.count
        return count <= 30
    }
}

// MARK: - Configure view
extension CardsScrollViewController {
    private func bind(view: CardView, with viewModel: CardsViewModel) {
        
        view.chartsButtonContainerView.bind(viewModel.isConnectable) { (view, isConnectable) in
            view.isHidden = !isConnectable.bound
        }
        
        view.alertView.bind(viewModel.isConnected) { (view, isConnected) in
            view.isHidden = !isConnected.bound
        }
        
        view.nameLabel.bind(viewModel.name, block: { $0.text = $1?.uppercased() ?? "N/A".localized() })
        
        let temperatureUnit = viewModel.temperatureUnit
        let fahrenheit = viewModel.fahrenheit
        let celsius = viewModel.celsius
        let kelvin = viewModel.kelvin
        
        let temperatureBlock: ((UILabel,Double?) -> Void) = { [weak temperatureUnit, weak fahrenheit, weak celsius, weak kelvin] label, _ in
            if let temperatureUnit = temperatureUnit?.value {
                switch temperatureUnit {
                case .celsius:
                    if let celsius = celsius?.value {
                        label.text = String.localizedStringWithFormat("%.2f", celsius)
                    } else {
                        label.text = "N/A".localized()
                    }
                case .fahrenheit:
                    if let fahrenheit = fahrenheit?.value {
                        label.text = String.localizedStringWithFormat("%.2f", fahrenheit)
                    } else {
                        label.text = "N/A".localized()
                    }
                case .kelvin:
                    if let kelvin = kelvin?.value {
                        label.text = String.localizedStringWithFormat("%.2f", kelvin)
                    } else {
                        label.text = "N/A".localized()
                    }
                }
            } else {
                label.text = "N/A".localized()
            }
        }
        
        if let temperatureLabel = view.temperatureLabel {
            temperatureLabel.bind(viewModel.celsius, fire: false, block: temperatureBlock)
            temperatureLabel.bind(viewModel.fahrenheit, fire: false, block: temperatureBlock)
            temperatureLabel.bind(viewModel.kelvin, fire: false, block: temperatureBlock)
            
            view.temperatureUnitLabel.bind(viewModel.temperatureUnit) { [unowned temperatureLabel] label, temperatureUnit in
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
                temperatureBlock(temperatureLabel, nil)
            }
        }
        
        let hu = viewModel.humidityUnit
        let rh = viewModel.relativeHumidity
        let ah = viewModel.absoluteHumidity
        let ho = viewModel.humidityOffset
        let tu = viewModel.temperatureUnit
        let dc = viewModel.dewPointCelsius
        let df = viewModel.dewPointFahrenheit
        let dk = viewModel.dewPointKelvin
        let humidityWarning = view.humidityWarningImageView
        let rhFormat: String
        switch viewModel.type {
        case .ruuvi:
            rhFormat = "%.2f"
        case .web:
            rhFormat = "%.0f"
        }
        let humidityBlock: ((UILabel, Double?) -> Void) = { [weak hu, weak rh, weak ah, weak ho, weak tu, weak dc, weak df, weak dk, weak humidityWarning] label, _ in
            if let hu = hu?.value {
                switch hu {
                case .percent:
                    if let rh = rh?.value, let ho = ho?.value {
                        let sh = rh + ho
                        if sh < 100.0 {
                            label.text = String.localizedStringWithFormat(rhFormat, rh + ho) + " " + "%".localized()
                            humidityWarning?.isHidden = true
                        } else {
                            label.text = String.localizedStringWithFormat(rhFormat, 100.0) + " " + "%".localized()
                            humidityWarning?.isHidden = false
                        }
                    } else if let rh = rh?.value {
                        if rh < 100.0 {
                            label.text = String.localizedStringWithFormat(rhFormat, rh) + " " + "%".localized()
                            humidityWarning?.isHidden = true
                        } else {
                            label.text = String.localizedStringWithFormat(rhFormat, 100.0) + " " + "%".localized()
                            humidityWarning?.isHidden = false
                        }
                    } else {
                        label.text = "N/A".localized()
                    }
                case .gm3:
                    if let ah = ah?.value {
                        label.text = String.localizedStringWithFormat("%.2f", ah) + " " + "g/m³".localized()
                    } else {
                        label.text = "N/A".localized()
                    }
                case .dew:
                    if let tu = tu?.value {
                        switch tu {
                        case .celsius:
                            if let dc = dc?.value {
                                label.text = String.localizedStringWithFormat("%.2f", dc) + " " + "°C".localized()
                            } else {
                                label.text = "N/A".localized()
                            }
                        case .fahrenheit:
                            if let df = df?.value {
                                label.text = String.localizedStringWithFormat("%.2f", df) + " " + "°F".localized()
                            } else {
                                label.text = "N/A".localized()
                            }
                        case .kelvin:
                            if let dk = dk?.value {
                                label.text = String.localizedStringWithFormat("%.2f", dk) + " " + "K".localized()
                            } else {
                                label.text = "N/A".localized()
                            }
                        }
                    } else {
                        label.text = "N/A".localized()
                    }
                }
            } else {
                label.text = "N/A".localized()
            }
        }
        
        view.humidityLabel.bind(viewModel.relativeHumidity, fire: false, block: humidityBlock)
        view.humidityLabel.bind(viewModel.absoluteHumidity, fire: false, block: humidityBlock)
        view.humidityLabel.bind(viewModel.dewPointCelsius, fire: false, block: humidityBlock)
        view.humidityLabel.bind(viewModel.dewPointFahrenheit, fire: false, block: humidityBlock)
        view.humidityLabel.bind(viewModel.dewPointKelvin, fire: false, block: humidityBlock)
        view.humidityLabel.bind(viewModel.humidityOffset, fire: false, block: humidityBlock)
        view.humidityLabel.bind(viewModel.humidityUnit, fire: false) { label, _ in
            humidityBlock(label, nil)
        }
        view.humidityLabel.bind(viewModel.temperatureUnit) { label, _ in
            humidityBlock(label, nil)
        }
        
        let pressureFormat: String
        switch viewModel.type {
        case .ruuvi:
            pressureFormat = "%.2f"
        case .web:
            pressureFormat = "%.0f"
        }
        view.pressureLabel.bind(viewModel.pressure) { label, pressure in
            if let pressure = pressure {
                label.text = String.localizedStringWithFormat(pressureFormat, pressure) + " " + "hPa".localized()
            } else {
                label.text = "N/A".localized()
            }
        }
        
        switch viewModel.type {
        case .ruuvi:
            let animated = viewModel.animateRSSI
            view.rssiCityLabel.bind(viewModel.rssi) { [weak animated] label, rssi in
                if let rssi = rssi {
                    label.text = "\(rssi)" + " " + "dBm".localized()
                    if let animated = animated?.value, animated {
                        label.alpha = 0.0
                        UIView.animate(withDuration: 1.0, animations: {
                            label.alpha = 1.0
                        })
                    }
                } else {
                    label.text = "N/A".localized()
                }
            }
        case .web:
            let location = viewModel.location
            view.rssiCityLabel.bind(viewModel.currentLocation) { [weak location] (label, currentLocation) in
                if let location = location?.value {
                    label.text = location.city ?? location.country
                } else if let currentLocation = currentLocation {
                    label.text = currentLocation.city ?? currentLocation.country
                } else {
                    label.text = "N/A".localized()
                }
            }
        }
        
        let isConnected = viewModel.isConnected
        let date = viewModel.date
        
        view.updatedLabel.bind(viewModel.isConnected) { [weak view, weak date] (label, isConnected) in
            if let isConnected = isConnected, isConnected, let date = date?.value {
                label.text = "Cards.Connected.title".localized() + " " + "|" + " " + date.ruuviAgo
            } else {
                if let date = date?.value {
                    label.text = date.ruuviAgo
                } else {
                    label.text = "N/A".localized()
                }
            }
            view?.updatedAt = date?.value
            view?.isConnected = isConnected
        }
        
        view.updatedLabel.bind(viewModel.date) { [weak view, weak isConnected] (label, date) in
            if let isConnected = isConnected, isConnected.value.bound, let date = date {
                label.text = "Cards.Connected.title".localized() + " " + "|" + " " + date.ruuviAgo
            } else {
                if let date = date {
                    label.text = date.ruuviAgo
                } else {
                    label.text = "N/A".localized()
                }
            }
            view?.updatedAt = date
            view?.isConnected = isConnected?.value
        }
        
        view.backgroundImage.bind(viewModel.background) { $0.image = $1 }
        
        view.alertImageView.bind(viewModel.alertState) { (imageView, state) in
            if let state = state {
                switch state {
                case .empty:
                    imageView.image = UIImage(named: "icon-alert-off")
                case .registered:
                    imageView.image = UIImage(named: "icon-alert-on")
                case .firing:
                    imageView.image = UIImage(named: "icon-alert-active")
                }
            } else {
                imageView.image = nil
            }
        }
        
        switch viewModel.type {
        case .ruuvi:
            view.rssiCityImageView.image = UIImage(named: "icon-measure-signal")
        case .web:
            view.rssiCityImageView.image = UIImage(named: "icon-measure-location")
        }
    }
    
}

//MARK: - UIGestureRecognizerDelegate
extension CardsScrollViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let pan = gestureRecognizer as? UIPanGestureRecognizer {
            let velocity = pan.velocity(in: scrollView)
            return abs(velocity.y) > abs(velocity.x) && viewModels[currentPage].isConnectable.value.bound
        } else {
            return true
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureRecognizer.view != otherGestureRecognizer.view
    }
}


// MARK: - View configuration
extension CardsScrollViewController {
    private func configureViews() {
        configureEdgeGestureRecognozer()
        configurePanGestureRecognozer()
        configureGestureInstructor()
    }
    
    private func configureGestureInstructor() {
        GestureInstructor.appearance.tapImage = UIImage(named: "gesture-assistant-hand")
    }
    
     private func configurePanGestureRecognozer() {
         let gr = UIPanGestureRecognizer()
         gr.delegate = self
         gr.cancelsTouchesInView = true
         scrollView.addGestureRecognizer(gr)
         gr.addTarget(tagChartsPresentInteractiveTransition as Any, action:#selector(TagChartsPresentTransitionAnimation.handlePresentPan(_:)))
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
extension CardsScrollViewController {
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
                    let view = Bundle.main.loadNibNamed("CardView", owner: self, options: nil)?.first as! CardView
                    view.translatesAutoresizingMaskIntoConstraints = false
                    scrollView.addSubview(view)
                    position(view, leftView)
                    bind(view: view, with: viewModel)
                    view.delegate = self
                    views.append(view)
                    leftView = view
                }
                localize()
                scrollView.addConstraint(NSLayoutConstraint(item: leftView, attribute: .trailing, relatedBy: .equal
                    , toItem: scrollView, attribute: .trailing, multiplier: 1.0, constant: 0.0))
            }
        }
    }
    
    private func position(_ view: CardView, _ leftView: UIView) {
        scrollView.addConstraint(NSLayoutConstraint(item: view, attribute: .leading, relatedBy: .equal, toItem: leftView, attribute: leftView == scrollView ? .leading : .trailing, multiplier: 1.0, constant: 0.0))
        scrollView.addConstraint(NSLayoutConstraint(item: view, attribute: .top, relatedBy: .equal, toItem: scrollView, attribute: .top, multiplier: 1.0, constant: 0.0))
        scrollView.addConstraint(NSLayoutConstraint(item: view, attribute: .bottom, relatedBy: .equal, toItem: scrollView, attribute: .bottom, multiplier: 1.0, constant: 0.0))
        scrollView.addConstraint(NSLayoutConstraint(item: view, attribute: .width, relatedBy: .equal, toItem: scrollView, attribute: .width, multiplier: 1.0, constant: 0.0))
        scrollView.addConstraint(NSLayoutConstraint(item: view, attribute: .height, relatedBy: .equal, toItem: scrollView, attribute: .height, multiplier: 1.0, constant: 0.0))
    }
}
