// swiftlint:disable file_length
import UIKit
import Localize_Swift
import GestureInstructions
import Humidity
import RuuviOntology
import RuuviLocal
import RuuviService

class CardsScrollViewController: UIViewController {
    var output: CardsViewOutput!
    var menuPresentInteractiveTransition: UIViewControllerInteractiveTransitioning!
    var menuDismissInteractiveTransition: UIViewControllerInteractiveTransitioning!
    var tagChartsPresentInteractiveTransition: UIViewControllerInteractiveTransitioning!
    var tagChartsDismissInteractiveTransition: UIViewControllerInteractiveTransitioning!

    var measurementService: RuuviServiceMeasurement! {
        didSet {
            measurementService?.add(self)
        }
    }
    @IBOutlet weak var scrollView: UIScrollView!

    var viewModels = [CardsViewModel]() {
        didSet {
            updateUIViewModels()
        }
    }

    private var appDidBecomeActiveToken: NSObjectProtocol?
    private let alertActiveImage = UIImage(named: "icon-alert-active")
    private let alertOffImage = UIImage(named: "icon-alert-off")
    private let alertOnImage = UIImage(named: "icon-alert-on")
    private let advertisementImage = UIImage(named: "icon-bluetooth")
    private let heartbeatImage = UIImage(named: "icon-bluetooth-connected")
    private let ruuviNetworkImage = UIImage(named: "icon-gateway")
    private let weatherProviderImage = UIImage(named: "icon-weatherstation")
    private var views = [CardView]()
    var currentPage: Int {
        if isViewLoaded {
            return Int(scrollView.contentOffset.x / scrollView.frame.size.width)
        } else {
            return 0
        }
    }
    private static var localizedCache: LocalizedCache = LocalizedCache()
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    deinit {
        appDidBecomeActiveToken?.invalidate()
    }
    // MacCatalyst arrows detect
    #if targetEnvironment(macCatalyst)
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var didHandleEvent = false
        for press in presses {
            guard let key = press.key else {
                continue
            }
            if key.charactersIgnoringModifiers == UIKeyCommand.inputLeftArrow {
                if currentPage == 0 {
                    didHandleEvent = false
                } else {
                    scroll(to: currentPage - 1,
                           immediately: true,
                           animated: true)
                    output.viewDidScroll(to: viewModels[currentPage - 1])
                    didHandleEvent = true
                }
            }
            if key.charactersIgnoringModifiers == UIKeyCommand.inputRightArrow {
                if currentPage + 1 < viewModels.count {
                    scroll(to: currentPage + 1,
                           immediately: true,
                           animated: true)
                    output.viewDidScroll(to: viewModels[currentPage + 1])
                    didHandleEvent = true
                } else {
                    didHandleEvent = false
                }
            }
        }
        if didHandleEvent == false {
            super.pressesBegan(presses, with: event)
        }
    }
    #endif
}

// MARK: - CardsViewInput
extension CardsScrollViewController: CardsViewInput {

    func localize() {
        CardsScrollViewController.localizedCache = LocalizedCache()
        for (i, viewModel) in viewModels.enumerated() where i < views.count {
            let view = views[i]
            let updatePressure = pressureUpdateBlock(for: viewModel)
            updatePressure(view.pressureLabel, viewModel.pressure.value)

            let updateTemperature = temperatureUpdateBlock(for: viewModel, in: view)
            updateTemperature(view.temperatureLabel, viewModel.temperature.value)

            let updateHumidity = humidityUpdateBlock(for: viewModel, in: view)
            updateHumidity(view.humidityLabel, viewModel.humidity.value)

            switch viewModel.type {
            case .ruuvi:
                let movementUpdate = movementUpdateBlock(for: viewModel)
                view.movementCityLabel.bind(viewModel.movementCounter, block: movementUpdate)
            case .web:
                let locationUpdate = locationUpdateBlock(for: viewModel)
                view.movementCityLabel.bind(viewModel.currentLocation, block: locationUpdate)
            }
        }
    }

    func showWebTagAPILimitExceededError() {
        let title = "Cards.WebTagAPILimitExcededError.Alert.title".localized()
        let message = "Cards.WebTagAPILimitExcededError.Alert.message".localized()
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "OK".localized(), style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }

    func showBluetoothDisabled() {
        let title = "Cards.BluetoothDisabledAlert.title".localized()
        let message = "Cards.BluetoothDisabledAlert.message".localized()
        showAlert(title: title, message: message)
    }

    func showSwipeLeftRightHint() {
        gestureInstructor.show(.swipeRight, after: 0.1)
    }

    func scroll(to index: Int, immediately: Bool = false, animated: Bool = false) {
        if immediately {
            view.layoutIfNeeded()
            scrollView.layoutIfNeeded()
            let x: CGFloat = scrollView.frame.size.width * CGFloat(index)
            scrollView.setContentOffset(CGPoint(x: x, y: 0), animated: animated)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let sSelf = self else { return }
                let x: CGFloat = sSelf.scrollView.frame.size.width * CGFloat(index)
                sSelf.scrollView.setContentOffset(CGPoint(x: x, y: 0), animated: animated)
            }
        }
    }

    func showKeepConnectionDialog(for viewModel: CardsViewModel) {
        let message = "Cards.KeepConnectionDialog.message".localized()
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = "Cards.KeepConnectionDialog.Dismiss.title".localized()
        alert.addAction(UIAlertAction(title: dismissTitle, style: .cancel, handler: { [weak self] _ in
            self?.output.viewDidDismissKeepConnectionDialog(for: viewModel)
        }))
        let keepTitle = "Cards.KeepConnectionDialog.KeepConnection.title".localized()
        alert.addAction(UIAlertAction(title: keepTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmToKeepConnection(to: viewModel)
        }))
        present(alert, animated: true)
    }

    func showReverseGeocodingFailed() {
        let message = "Cards.Error.ReverseGeocodingFailed.message".localized()
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK".localized(), style: .cancel, handler: nil))
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
        restartAnimations()
        output.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        output.viewWillDisappear()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        let page = CGFloat(currentPage)
        coordinator.animate(alongsideTransition: { [weak self] (_) in
            let width = coordinator.containerView.bounds.width
            self?.scrollView.contentOffset = CGPoint(x: page * width, y: 0)
        }, completion: { [weak self] (_) in
            let width = coordinator.containerView.bounds.width
            self?.scrollView.contentOffset = CGPoint(x: page * width, y: 0)
        })
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
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        guard let textFieldText = textField.text,
            let rangeOfTextToReplace = Range(range, in: textFieldText) else {
                return false
        }
        let substringToReplace = textFieldText[rangeOfTextToReplace]
        let count = textFieldText.count - substringToReplace.count + string.count
        return count <= 30
    }
}

// MARK: - Update Blocks
extension CardsScrollViewController {
    private func pressureUpdateBlock(for viewModel: CardsViewModel) -> (UILabel, Pressure?) -> Void {
        return { [weak self] label, pressure in
            label.text = self?.measurementService?.string(for: pressure)
        }
    }

    private func temperatureUpdateBlock(for viewModel: CardsViewModel,
                                        in view: CardView) -> (UILabel, Temperature?) -> Void {
        let temperatureUnitLabel = view.temperatureUnitLabel
        let temperatureBlock: ((UILabel, Temperature?) -> Void) = {
            [weak self,
            weak temperatureUnitLabel] label, _ in
            if let temp = self?.measurementService.stringWithoutSign(for: viewModel.temperature.value) {
                label.text = temp.components(separatedBy: String.nbsp).first
            } else {
                label.text = "N/A".localized()
            }
            if let temperatureUnit = self?.measurementService.units.temperatureUnit {
                temperatureUnitLabel?.text = temperatureUnit.symbol
            } else {
                temperatureUnitLabel?.text = CardsScrollViewController.localizedCache.notAvailable
            }
        }
        return temperatureBlock
    }

    private func humidityUpdateBlock(for viewModel: CardsViewModel, in view: CardView) -> (UILabel, Humidity?) -> Void {
        let humidityWarning = view.humidityWarningImageView
        let humidityBlock: ((UILabel, Humidity?) -> Void) = {
            [weak self,
            weak humidityWarning] label, value in
            let temperature = viewModel.temperature.value
            if self?.measurementService.units.humidityUnit == .percent,
                let temperature = temperature,
                let offsetedValue = self?.measurementService.double(for: value,
                                                                    temperature: temperature,
                                                                    isDecimal: true) {
                humidityWarning?.isHidden = offsetedValue < 1.0
            } else {
                humidityWarning?.isHidden = true
            }
            label.text = self?.measurementService.string(for: value, temperature: temperature)
        }
        return humidityBlock
    }

    private func movementUpdateBlock(for viewModel: CardsViewModel) -> (UILabel, Int?) -> Void {
        return { label, movementCounter in
            if let movementCounter = movementCounter {
                label.text = "\(movementCounter)"
            } else {
                label.text = CardsScrollViewController.localizedCache.notAvailable
            }

        }
    }

    // TODO: @rinat not used, may be removed
    private func rssiUpdateBlock(for viewModel: CardsViewModel) -> (UILabel, Int?) -> Void {
        let animated = viewModel.animateRSSI
        return {
            [weak self,
            weak animated] label, rssi in
            if let rssi = rssi {
                label.text = "\(rssi)" + " " + CardsScrollViewController.localizedCache.dBm
                if let animated = animated?.value,
                    animated,
                    self?.pageIsVisible(for: viewModel) == true {
                    label.layer.removeAllAnimations()
                    label.alpha = 0.0
                    UIView.animate(withDuration: 1.0, animations: {
                        label.alpha = 1.0
                    })
                }
            } else {
                label.text = CardsScrollViewController.localizedCache.notAvailable
            }
        }
    }

    private func locationUpdateBlock(for viewModel: CardsViewModel) -> (UILabel, Location?) -> Void {
        let location = viewModel.location
        return { [weak location] (label, currentLocation) in
            if let location = location?.value {
                label.text = location.city ?? location.country
            } else if let currentLocation = currentLocation {
                label.text = currentLocation.city ?? currentLocation.country
            } else {
                label.text = CardsScrollViewController.localizedCache.notAvailable
            }
        }
    }
}

// MARK: - Configure view
extension CardsScrollViewController {

    private func bindTemperature(view: CardView, with viewModel: CardsViewModel) {
        let temperatureBlock = temperatureUpdateBlock(for: viewModel, in: view)
        view.temperatureLabel.bind(viewModel.temperature, fire: false, block: temperatureBlock)
    }

    private func bindHumidity(view: CardView, with viewModel: CardsViewModel) {
        let humidityBlock = humidityUpdateBlock(for: viewModel, in: view)
        view.humidityLabel.bind(viewModel.humidity, fire: false, block: humidityBlock)
    }

    private func bindConnectionRelated(view: CardView, with viewModel: CardsViewModel) {
        view.chartsButtonContainerView.bind(viewModel.isConnectable) {(view, isConnectable) in
            view.isHidden = !isConnectable.bound
        }

        let type = viewModel.type
        view.alertView.bind(viewModel.isConnected) { (view, isConnected) in
            switch type {
            case .ruuvi:
                view.isHidden = !isConnected.bound
            case .web:
                view.isHidden = false
            }
        }
    }

    private func bindUpdated(view: CardView, with viewModel: CardsViewModel) {
        view.bind(viewModel.isConnected) { view, isConnected in
            view.isConnected = isConnected
        }
        view.updatedLabel.bind(viewModel.date) { label, date in
            if let date = date {
                label.text = date.ruuviAgo()
            } else {
                label.text = CardsScrollViewController.localizedCache.notAvailable
            }
        }
        view.bind(viewModel.date) { view, date in
            view.updatedAt = date
        }
        view.dataSourceImageView.bind(viewModel.source) { [weak self] imageView, source in
            if let source = source {
                switch source {
                case .unknown:
                    imageView.image = nil
                case .advertisement:
                    imageView.image = self?.advertisementImage
                case .heartbeat:
                    imageView.image = self?.heartbeatImage
                case .log:
                    imageView.image = self?.heartbeatImage
                case .ruuviNetwork:
                    imageView.image = self?.ruuviNetworkImage
                case .weatherProvider:
                    imageView.image = self?.weatherProviderImage
                }
            } else {
                imageView.image = nil
            }
        }
    }

    // swiftlint:disable:next function_body_length
    private func bind(view: CardView, with viewModel: CardsViewModel) {
        view.nameLabel.bind(viewModel.name,
                            block: {
            $0.text = $1?.uppercased() ?? CardsScrollViewController.localizedCache.notAvailable
        })
        bindConnectionRelated(view: view, with: viewModel)
        bindTemperature(view: view, with: viewModel)
        bindHumidity(view: view, with: viewModel)
        let pressureUpdate = pressureUpdateBlock(for: viewModel)
        view.pressureLabel.bind(viewModel.pressure, block: pressureUpdate)

        switch viewModel.type {
        case .ruuvi:
            let movementUpdate = movementUpdateBlock(for: viewModel)
            view.movementCityLabel.bind(viewModel.movementCounter, block: movementUpdate)
            if let macId = viewModel.mac.value {
                view.networkTagMacId = macId
                view.bind(viewModel.networkSyncStatus) { view, syncStatus in
                    view.syncStatus = syncStatus ?? NetworkSyncStatus.none
                }
            }
        case .web:
            let locationUpdate = locationUpdateBlock(for: viewModel)
            view.movementCityLabel.bind(viewModel.currentLocation, block: locationUpdate)
        }
        bindUpdated(view: view, with: viewModel)
        view.backgroundImage.bind(viewModel.background) { $0.image = $1 }
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

        switch viewModel.type {
        case .ruuvi:
            view.movementCityImageView.image = UIImage(named: "icon-measure-movement")
        case .web:
            view.movementCityImageView.image = UIImage(named: "icon-measure-location")
        }
    }

}

// MARK: - UIGestureRecognizerDelegate
extension CardsScrollViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let pan = gestureRecognizer as? UIPanGestureRecognizer,
            !viewModels.isEmpty {
            let velocity = pan.velocity(in: scrollView)
            return abs(velocity.y) > abs(velocity.x) && viewModels[currentPage].isConnectable.value.bound
        } else {
            return false
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureRecognizer.view != otherGestureRecognizer.view
    }
}

// MARK: - View configuration
extension CardsScrollViewController {
    private func configureViews() {
        configureEdgeGestureRecognozer()
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
         gr.addTarget(tagChartsPresentInteractiveTransition as Any,
                      action: #selector(TagChartsPresentTransitionAnimation.handlePresentPan(_:)))
     }

    private func configureEdgeGestureRecognozer() {
        let leftScreenEdgeGestureRecognizer = UIScreenEdgePanGestureRecognizer()
        leftScreenEdgeGestureRecognizer.cancelsTouchesInView = true
        scrollView.addGestureRecognizer(leftScreenEdgeGestureRecognizer)
        leftScreenEdgeGestureRecognizer
            .addTarget(menuPresentInteractiveTransition as Any,
                       action: #selector(MenuTablePresentTransitionAnimation.handlePresentMenuLeftScreenEdge(_:)))
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
                    // swiftlint:disable force_cast
                    let view = Bundle.main.loadNibNamed("CardView", owner: self, options: nil)?.first as! CardView
                    // swiftlint:enable force_cast
                    switch viewModel.type {
                    case .ruuvi:
                        view.chartsButtonWidth.constant = 44
                    case .web:
                        view.chartsButtonWidth.constant = 4
                    }
                    view.translatesAutoresizingMaskIntoConstraints = false
                    scrollView.addSubview(view)
                    position(view, leftView)
                    bind(view: view, with: viewModel)
                    view.delegate = self
                    views.append(view)
                    leftView = view
                }
                localize()
                scrollView.addConstraint(NSLayoutConstraint(item: leftView,
                                                            attribute: .trailing,
                                                            relatedBy: .equal,
                                                            toItem: scrollView,
                                                            attribute: .trailing,
                                                            multiplier: 1.0,
                                                            constant: 0.0))
            }
        }
    }

    private func position(_ view: CardView, _ leftView: UIView) {
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
                imageView?.alpha = 1.0
                switch state {
                case .empty:
                    imageView?.image = alertOffImage
                case .registered:
                    imageView?.image = alertOnImage
                case .firing:
                    imageView?.image = alertActiveImage
                    imageView?.layer.removeAllAnimations()
                    UIView.animate(withDuration: 0.5,
                                  delay: 0,
                                  options: [.repeat, .autoreverse],
                                  animations: { [weak imageView] in
                                    imageView?.alpha = 0.0
                                })
                }
            } else {
                imageView?.image = nil
            }
        }
    }

    private func pageIsVisible(for viewModel: CardsViewModel) -> Bool {
        return viewModels[currentPage].id.value != nil &&
            viewModel.id.value != nil
            && viewModels[currentPage].id.value == viewModel.id.value
    }
}
extension CardsScrollViewController: RuuviServiceMeasurementDelegate {
    func measurementServiceDidUpdateUnit() {
        guard isViewLoaded else {
            return
        }
        updateUI()
    }
}
// swiftlint:enable file_length
