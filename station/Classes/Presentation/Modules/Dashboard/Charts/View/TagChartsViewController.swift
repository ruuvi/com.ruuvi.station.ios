// swiftlint:disable file_length
import Foundation
import UIKit
import Charts
import RuuviOntology
import RuuviStorage
import RuuviLocal
import BTKit
import GestureInstructions

// swiftlint:disable type_body_length
class TagChartsViewController: UIViewController {
    var output: TagChartsViewOutput!
    private var appDidBecomeActiveToken: NSObjectProtocol?
    private let alertActiveImage = UIImage(named: "icon-alert-active")
    private let alertOffImage = UIImage(named: "icon-alert-off")
    private let alertOnImage = UIImage(named: "icon-alert-on")
    private var chartModules: [MeasurementType] = []

    var viewModel: TagChartsViewModel = TagChartsViewModel(type: .ruuvi) {
        didSet {
            bindViewModel()
        }
    }

    // MARK: - CONSTANTS
    private let cellId: String = "CellId"

    // MARK: - UI COMPONENTS DECLARATION
    // Background
    lazy var staticBackground = UIImageView(image: UIImage(named: "bg9"),
                                            contentMode: .scaleAspectFill)
    lazy var backgroundImage = UIImageView(image: nil,
                                           contentMode: .scaleAspectFill)
    lazy var backgroundImageOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.alpha = 0.7
        return view
    }()

    // Header View
    // Ruuvi Logo
    lazy var headerView = UIView(color: .clear)
    lazy var ruuviLogoView = UIImageView(image: UIImage(named: "ruuvi_logo_"),
                                         contentMode: .scaleAspectFit)

    // Action Buttons
    lazy var menuButton: UIButton = {
        let button  = UIButton()
        button.tintColor = .white
        let menuImage = UIImage(named: "baseline_menu_white_48pt")
        button.setImage(menuImage, for: .normal)
        button.setImage(menuImage, for: .highlighted)
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(menuButtonDidTap), for: .touchUpInside)
        return button
    }()

    lazy var alertButton: UIImageView = {
        let iv = UIImageView(image: alertOffImage,
                             contentMode: .scaleAspectFit)
        iv.tintColor = .white
        iv.addGestureRecognizer(UITapGestureRecognizer(target: self,
                                                       action: #selector(alertButtonDidTap)))
        return iv
    }()

    lazy var chartButton: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "icon-cards-button"),
                             contentMode: .scaleAspectFit)
        iv.tintColor = .white
        iv.addGestureRecognizer(UITapGestureRecognizer(target: self,
                                                       action: #selector(chartButtonDidTap)))
        return iv
    }()

    lazy var settingsButton: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "baseline_settings_white_48pt"),
                             contentMode: .scaleAspectFit)
        iv.tintColor = .white
        iv.addGestureRecognizer(UITapGestureRecognizer(target: self,
                                                       action: #selector(settingsButtonDidTap)))
        return iv
    }()

    // Body
    lazy var ruuviTagNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        let font = UIFont(name: "Montserrat-Bold", size: 20)
        label.font = font ?? UIFont.systemFont(ofSize: 16, weight: .bold)
        return label
    }()

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

    // Footer
    lazy var footerView = UIView(color: .clear)
    private var footerViewHeight: NSLayoutConstraint!

    lazy var syncStatusLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 17)
        return label
    }()

    lazy var syncProgressView = UIView(color: .clear)

    lazy var syncProgressLabel: UILabel = {
        let label = UILabel()
        label.text = "Reading history..."
        label.textColor = .white
        label.textAlignment = .left
        label.font = UIFont.systemFont(ofSize: 17)
        return label
    }()

    lazy var syncCancelButton: UIButton = {
        let button  = UIButton()
        let title = "Cancel".localized()
        button.setTitle(title, for: .normal)
        button.setTitle(title, for: .highlighted)
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.white, for: .highlighted)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        button.backgroundColor = .normalButtonBackground
        button.layer.cornerRadius = 21
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(cancelButtonDidTap), for: .touchUpInside)
        return button
    }()

    lazy var syncActionView = UIView(color: .clear)

    lazy var syncButton: UIButton = {
        let button  = UIButton()
        let title = "TagCharts.Sync.title".localized()
        button.setTitle(title, for: .normal)
        button.setTitle(title, for: .highlighted)
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.white, for: .highlighted)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        button.backgroundColor = .normalButtonBackground
        button.layer.cornerRadius = 21
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(syncButtonDidTap), for: .touchUpInside)
        return button
    }()

    lazy var clearButton: UIButton = {
        let button  = UIButton()
        let title = "TagCharts.Clear.title".localized()
        button.setTitle(title, for: .normal)
        button.setTitle(title, for: .highlighted)
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.white, for: .highlighted)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        button.backgroundColor = .normalButtonBackground
        button.layer.cornerRadius = 21
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(clearButtonDidTap), for: .touchUpInside)
        return button
    }()

    // UI END

    // MARK: - LIFECYCLE
    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
        setupLocalization()
        setUpUI()
        output.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        restartAnimations()
        output.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        hideFooterView()
        output.viewWillDisappear()
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
        setUpBaseView()
        setUpHeaderView()
        setUpContentView()
        setUpFooterView()
    }

    fileprivate func setUpBaseView() {
        view.addSubview(staticBackground)
        staticBackground.fillSuperview()

        view.addSubview(backgroundImage)
        backgroundImage.fillSuperview()

        view.addSubview(backgroundImageOverlay)
        backgroundImageOverlay.fillSuperview()
    }

    // swiftlint:disable function_body_length
    fileprivate func setUpHeaderView() {
        view.addSubview(headerView)
        headerView.anchor(top: view.safeTopAnchor,
                          leading: view.safeLeftAnchor,
                          bottom: nil,
                          trailing: view.safeRightAnchor,
                          padding: .init(top: 8, left: 0, bottom: 0, right: 0),
                          size: .init(width: 0, height: 32))

        headerView.addSubview(menuButton)
        menuButton.anchor(top: headerView.topAnchor,
                          leading: headerView.leadingAnchor,
                          bottom: headerView.bottomAnchor,
                          trailing: nil,
                          padding: .init(top: 0, left: 16, bottom: 0, right: 0),
                          size: .init(width: 32, height: 0))

        headerView.addSubview(ruuviLogoView)
        ruuviLogoView.anchor(top: nil,
                             leading: menuButton.trailingAnchor,
                             bottom: nil,
                             trailing: nil,
                             padding: .init(top: 0, left: 20, bottom: 0, right: 0),
                             size: .init(width: 110, height: 22))
        ruuviLogoView.centerYInSuperview()

        // Right action buttons
        headerView.addSubview(alertButton)
        alertButton.anchor(top: nil,
                           leading: nil,
                           bottom: nil,
                           trailing: nil,
                           size: .init(width: 24, height: 24))
        alertButton.centerYInSuperview()

        headerView.addSubview(chartButton)
        chartButton.anchor(top: nil,
                           leading: alertButton.trailingAnchor,
                           bottom: nil,
                           trailing: nil,
                           padding: .init(top: 0, left: 28, bottom: 0, right: 0),
                           size: .init(width: 22, height: 22))
        chartButton.centerYInSuperview()

        headerView.addSubview(settingsButton)
        settingsButton.anchor(top: nil,
                              leading: chartButton.trailingAnchor,
                              bottom: nil,
                              trailing: headerView.trailingAnchor,
                              padding: .init(top: 0, left: 16, bottom: 0, right: 16),
                              size: .init(width: 26, height: 26))
        settingsButton.centerYInSuperview()
    }

    fileprivate func setUpContentView() {
        view.addSubview(ruuviTagNameLabel)
        ruuviTagNameLabel.anchor(top: headerView.bottomAnchor,
                                 leading: view.safeLeftAnchor,
                                 bottom: nil,
                                 trailing: view.safeRightAnchor,
                                 padding: .init(top: 18, left: 16, bottom: 0, right: 16))

        view.addSubview(scrollView)
        scrollView.anchor(top: ruuviTagNameLabel.bottomAnchor,
                          leading: view.safeLeftAnchor,
                          bottom: nil,
                          trailing: view.safeRightAnchor,
                          padding: .init(top: 12, left: 0, bottom: 0, right: 0))

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

    }

    fileprivate func setUpFooterView() {
        view.addSubview(footerView)
        footerView.anchor(top: scrollView.bottomAnchor,
                          leading: view.safeLeftAnchor,
                          bottom: view.safeBottomAnchor,
                          trailing: view.safeRightAnchor,
                          padding: .init(top: 8, left: 0, bottom: 4, right: 0))
        footerView.alpha = 0
        footerViewHeight = footerView.heightAnchor.constraint(equalToConstant: 0)
        footerViewHeight.isActive = true

        // Sync status
        footerView.addSubview(syncStatusLabel)
        syncStatusLabel.fillSuperview(padding: .init(top: 8, left: 16, bottom: 8, right: 16))
        syncStatusLabel.alpha = 0

        // Sync progress view
        footerView.addSubview(syncProgressView)
        syncProgressView.fillSuperview(padding: .init(top: 9,
                                                      left: 12,
                                                      bottom: 9,
                                                      right: 12))

        syncProgressView.addSubview(syncProgressLabel)
        syncProgressLabel.anchor(top: nil,
                                 leading: syncProgressView.leadingAnchor,
                                 bottom: nil,
                                 trailing: nil,
                                 padding: .init(top: 0, left: 16, bottom: 0, right: 0))
        syncProgressLabel.centerYInSuperview()

        syncProgressView.addSubview(syncCancelButton)
        syncCancelButton.anchor(top: syncProgressView.topAnchor,
                                leading: syncProgressLabel.trailingAnchor,
                                bottom: syncProgressView.bottomAnchor,
                                trailing: syncProgressView.trailingAnchor,
                                padding: .init(top: 0, left: 12, bottom: 0, right: 16),
                                size: .init(width: 120, height: 0))
        syncProgressView.alpha = 0

        // Sync action view
        footerView.addSubview(syncActionView)
        syncActionView.centerInSuperview()

        let buttonStackView = UIStackView(arrangedSubviews: [
            syncButton, clearButton
        ])
        syncButton.constrainHeight(constant: 42)
        syncButton.widthGreaterThanOrEqualTo(constant: 120)
        buttonStackView.distribution = .fillEqually
        buttonStackView.spacing = 8
        syncActionView.addSubview(buttonStackView)
        buttonStackView.fillSuperview()
        syncActionView.alpha = 0
    }

    @objc fileprivate func menuButtonDidTap() {
        output.viewDidTriggerMenu()
    }

    @objc fileprivate func alertButtonDidTap() {
        output.viewDidTriggerSettings(for: viewModel, scrollToAlert: true)
    }

    @objc fileprivate func chartButtonDidTap() {
        output.viewDidTriggerCards(for: viewModel)
    }

    @objc fileprivate func settingsButtonDidTap() {
        output.viewDidTriggerSettings(for: viewModel, scrollToAlert: false)
    }

    @objc fileprivate func clearButtonDidTap() {
        output.viewDidTriggerClear(for: viewModel)
    }

    @objc fileprivate func syncButtonDidTap() {
        output.viewDidTriggerSync(for: viewModel)
    }

    @objc fileprivate func cancelButtonDidTap() {
        output.viewDidTriggerStopSync(for: viewModel)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

extension TagChartsViewController: TagChartsViewDelegate {
    func chartDidTranslate(_ chartView: TagChartsView) {
        guard chartViews.count > 1 else {
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
            return
        }

        for data in chartViewData {
            switch data.chartType {
            case .temperature:
                populateChartView(from: data.chartData,
                                  type: "TagSettings.OffsetCorrection.Temperature".localized(),
                                  unit: settings.temperatureUnit.symbol,
                                  settings: settings,
                                  view: temperatureChartView)
            case .humidity:
                populateChartView(from: data.chartData,
                                  type: "TagSettings.OffsetCorrection.Humidity".localized(),
                                  unit: settings.humidityUnit.symbol,
                                  settings: settings,
                                  view: humidityChartView)
            case .pressure:
                populateChartView(from: data.chartData,
                                  type: "TagSettings.OffsetCorrection.Pressure".localized(),
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

    /// This method requires more context
    /// 1: Clear and Sync button should not be visible and
    /// the status should be visible if a sync progress is already running in the background
    /// 2: Clear and Sync button should be hidden for shared sensors
    /// 3: The only case these buttons are shown are when the last stored data is from the cloud
    /// no sync process running in the background
    func handleClearSyncButtons(connectable: Bool, isSyncing: Bool) {
        if isSyncing {
            showFooterView()
            handleSyncStatusLabelVisibility(show: true)
            syncStatusLabel.text = "TagCharts.Status.Serving".localized()
            return
        }
        if !connectable {
            hideFooterView()
            hideChartActionButtons()
            handleSyncStatusLabelVisibility(show: false)
        } else {
            showFooterView()
            showChartActionButtons()
        }
    }

    func localize() {
        clearButton.setTitle("TagCharts.Clear.title".localized(), for: .normal)
        syncButton.setTitle("TagCharts.Sync.title".localized(), for: .normal)
        syncCancelButton.setTitle("Cancel".localized(), for: .normal)
    }

    func showBluetoothDisabled() {
        let title = "TagCharts.BluetoothDisabledAlert.title".localized()
        let message = "TagCharts.BluetoothDisabledAlert.message".localized()
        showAlert(title: title, message: message)
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
            hideChartActionButtons()

            switch progress {
            case .connecting:
                handleSyncStatusLabelVisibility(show: true)
                syncStatusLabel.text = "TagCharts.Status.Connecting".localized()
            case .serving:
                handleSyncStatusLabelVisibility(show: true)
                syncStatusLabel.text = "TagCharts.Status.Serving".localized()
            case .reading(let points):
                handleSyncStatusLabelVisibility(show: false)
                if syncProgressView.alpha == 0 {
                    showSyncProgressView()
                }
                syncProgressLabel.text = "TagCharts.Status.ReadingHistory".localized() + "... \(points)"
            case .disconnecting:
                hideSyncProgressView()
                handleSyncStatusLabelVisibility(show: true)
                syncStatusLabel.text = "TagCharts.Status.Disconnecting".localized()
            case .success:
                hideSyncProgressView()
                handleSyncStatusLabelVisibility(show: true)
                // Show success message
                syncStatusLabel.text = "TagCharts.Status.Success".localized()
                // Hide success message and show buttons after two seconds
                showChartActionButtons(withDelay: true)
            case .failure:
                hideSyncProgressView()
                handleSyncStatusLabelVisibility(show: true)
                // Show error message
                syncStatusLabel.text = "TagCharts.Status.Error".localized()
                // Hide error message and show buttons after two seconds
                showChartActionButtons(withDelay: true)
            }
        } else {
            /// Show buttons after two seconds if there's an unexpected error
            showChartActionButtons(withDelay: true)
        }
    }

    func setSyncProgressViewHidden() {
        // Hide the sync progress view
        hideSyncProgressView()
        showChartActionButtons()
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
}

extension TagChartsViewController {

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

    private func bindViewModel() {
        ruuviTagNameLabel.bind(viewModel.name, block: { $0.text = $1?.uppercased() ?? "N/A".localized() })
        backgroundImage.bind(viewModel.background) { $0.image = $1 }
        // Cloud sensors will show the alert bell
        // If it's not cloud sensor check whether it's connected and show bell icon if connected only
        alertButton.bind(viewModel.isConnected) { [weak self] (view, isConnected) in
            if let isCloud = self?.viewModel.isCloud.value.bound, isCloud {
                view.isHidden = !isCloud
            } else {
                view.isHidden = !isConnected.bound
            }
        }
        // Cloud sensors will always show the alert bell
        // If it's not cloud sensor check whether it's connected and show bell icon if connected only
        alertButton.bind(viewModel.isCloud) { [weak self] (view, isCloud) in
            if isCloud.bound {
                view.isHidden = !isCloud.bound
            } else {
                if let isConnected = self?.viewModel.isConnected.value.bound {
                    view.isHidden = !isConnected
                }
            }
        }
        alertButton.bind(viewModel.alertState) { [weak self] (imageView, state) in
            if let state = state {
                switch state {
                case .empty:
                    imageView.alpha = 0.5
                    imageView.image = self?.alertOffImage
                    imageView.layer.removeAllAnimations()
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

    private func updateChartsCollectionConstaints(from: [MeasurementType], withAnimation: Bool = false) {
        chartViews.removeAll()
        view.setNeedsLayout()
        view.layoutIfNeeded()
        let scrollViewHeight = scrollView.frame.height
        guard viewIsVisible && scrollViewHeight > 0 && from.count > 0 else {
            return
        }

        if !from.contains(.humidity) {
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

    private func populateChartView(from data: LineChartData?,
                                   type: String,
                                   unit: String,
                                   settings: RuuviLocalSettings,
                                   view: TagChartsView) {
        view.setChartLabel(with: type, unit: unit)
        view.data = data
        view.setSettings(settings: settings)
        view.localize()
        view.setYAxisLimit(min: data?.yMin ?? 0, max: data?.yMax ?? 0)
        view.setXAxisRenderer()
    }

    private func clearChartData() {
        temperatureChartView.clearChartData()
        humidityChartView.clearChartData()
        pressureChartView.clearChartData()
    }

    // MARK: - UI RELATED METHODS

    private func restartAnimations() {
        // restart blinking animation if needed
        if let state = viewModel.alertState.value {
            switch state {
            case .empty:
                alertButton.alpha = 0.5
                alertButton.image = alertOffImage
            case .registered:
                alertButton.alpha = 1.0
                alertButton.image = alertOnImage
            case .firing:
                alertButton.alpha = 1.0
                alertButton.image = alertActiveImage
                alertButton.layer.removeAllAnimations()
                UIView.animate(withDuration: 0.5,
                               delay: 0,
                               options: [.repeat, .autoreverse],
                               animations: { [weak alertButton] in
                    alertButton?.alpha = 0.0
                            })
            }
        } else {
            alertButton.image = nil
        }
    }

    private func showFooterView() {
        guard footerView.alpha == 0 else {
            return
        }
        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            guard let self = self else { return }
            self.footerView.alpha = 1
            self.footerViewHeight.constant = 60
            self.updateChartsCollectionConstaints(from: self.chartModules,
                                                  withAnimation: true)
        })
    }

    private func hideFooterView() {
        guard footerView.alpha == 1 else {
            return
        }
        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            guard let self = self else { return }
            self.footerView.alpha = 0
            self.footerViewHeight.constant = 0
            self.updateChartsCollectionConstaints(from: self.chartModules,
                                                  withAnimation: true)
        })
    }

    private func showChartActionButtons(withDelay: Bool = false) {
        guard syncActionView.alpha == 0 else {
            return
        }
        handleSyncStatusLabelVisibility(show: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(withDelay ? 2 : 0),
                                      execute: { [weak self] in
            UIView.animate(withDuration: 0.2, animations: { [weak self] in
                self?.syncActionView.alpha = 1
            })
        })
    }

    private func hideChartActionButtons() {
        guard syncActionView.alpha == 1 else {
            return
        }
        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            self?.syncActionView.alpha = 0
        })
    }

    private func showSyncProgressView() {
        guard syncProgressView.alpha == 0 else {
            return
        }
        UIView.animate(withDuration: 0.1, animations: { [weak self] in
            self?.syncProgressView.alpha = 1
        })
    }

    private func hideSyncProgressView() {
        guard syncProgressView.alpha == 1 else {
            return
        }
        UIView.animate(withDuration: 0.1, animations: { [weak self] in
            self?.syncProgressView.alpha = 0
        })
    }

    private func handleSyncStatusLabelVisibility(show: Bool) {
        syncStatusLabel.alpha = show ? 1 : 0
    }
}
