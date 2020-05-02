// swiftlint:disable file_length
import UIKit
import Charts

protocol TrippleChartViewDelegate: class {
    func trippleChart(view: TrippleChartView, didTriggerCards sender: Any)
    func trippleChart(view: TrippleChartView, didTriggerSettings sender: Any)
    func trippleChart(view: TrippleChartView, didTriggerClear sender: Any)
    func trippleChart(view: TrippleChartView, didTriggerSync sender: Any)
    func trippleChart(view: TrippleChartView, didTriggerExport sender: Any)
}

// swiftlint:disable:next type_body_length
class TrippleChartView: UIView, Localizable, UIScrollViewDelegate {

    weak var delegate: TrippleChartViewDelegate?

    private lazy var landscapeConstraints: [NSLayoutConstraint] = {
        let dummyLogoViewWidthConstraint = NSLayoutConstraint(item: dummyLogoView,
                                                              attribute: .width,
                                                              relatedBy: .equal,
                                                              toItem: nil,
                                                              attribute: .notAnAttribute,
                                                              multiplier: 1.0,
                                                              constant: 180)
        dummyLogoViewWidthConstraint.priority = .defaultLow
        return [dummyLogoViewWidthConstraint,
                NSLayoutConstraint(item: scrollContainer,
                                   attribute: .height,
                                   relatedBy: .equal,
                                   toItem: scrollView,
                                   attribute: .height,
                                   multiplier: 3.0,
                                   constant: 0.0),
                NSLayoutConstraint(item: nameLabel,
                                   attribute: .leading,
                                   relatedBy: .equal,
                                   toItem: dummyLogoView,
                                   attribute: .trailing,
                                   multiplier: 1.0,
                                   constant: 8),
                NSLayoutConstraint(item: nameLabel,
                                   attribute: .centerY,
                                   relatedBy: .equal,
                                   toItem: settingsButton,
                                   attribute: .centerY,
                                   multiplier: 1.0,
                                   constant: 0),
                NSLayoutConstraint(item: alertView,
                                   attribute: .leading,
                                   relatedBy: .greaterThanOrEqual,
                                   toItem: nameLabel,
                                   attribute: .trailing,
                                   multiplier: 1.0,
                                   constant: 8)]
    }()
    private lazy var portraitConstraints: [NSLayoutConstraint] = {
        var topNameLabelConstraint: NSLayoutConstraint
        if #available(iOS 11.0, *) {
            let guide = safeAreaLayoutGuide
             topNameLabelConstraint = nameLabel.topAnchor.constraint(equalTo: guide.topAnchor, constant: 60)

        } else {
            topNameLabelConstraint = NSLayoutConstraint(item: nameLabel,
                                                        attribute: .top,
                                                        relatedBy: .equal,
                                                        toItem: self,
                                                        attribute: .top,
                                                        multiplier: 1.0,
                                                        constant: 60)
        }
        return [topNameLabelConstraint,
                NSLayoutConstraint(item: scrollView,
                                   attribute: .centerY,
                                   relatedBy: .equal,
                                   toItem: scrollContainer,
                                   attribute: .centerY,
                                   multiplier: 1.0,
                                   constant: 0.0),
                NSLayoutConstraint(item: nameLabel,
                                   attribute: .width,
                                   relatedBy: .equal,
                                   toItem: nil,
                                   attribute: .notAnAttribute,
                                   multiplier: 1.0,
                                   constant: 271),
                NSLayoutConstraint(item: nameLabel,
                                   attribute: .centerX,
                                   relatedBy: .equal,
                                   toItem: self,
                                   attribute: .centerX,
                                   multiplier: 1.0,
                                   constant: 0),
                NSLayoutConstraint(item: dummyLogoView,
                                   attribute: .width,
                                   relatedBy: .equal,
                                   toItem: nil,
                                   attribute: .notAnAttribute,
                                   multiplier: 1.0,
                                   constant: 50)]
    }()

    lazy var alertView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var alertButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .clear
        return button
    }()

    private lazy var alertImage = UIImage(named: "icon-alert-off", in: dynamicBundle, compatibleWith: nil)
    lazy var alertImageView: UIImageView = {
        let imageView = UIImageView(image: alertImage)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = .white
        return imageView
    }()

    private lazy var dummyLogoView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()

    private lazy var backgroundImage = UIImage(named: "bg1", in: dynamicBundle, compatibleWith: nil)
    lazy var backgroundImageView: UIImageView = {
        let imageView = UIImageView(image: backgroundImage)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()

    private lazy var settingsButtonImage = UIImage(named: "baseline_settings_white_48pt",
                                                   in: dynamicBundle,
                                                   compatibleWith: nil)
    lazy var settingsButton: UIButton = {
        let button = UIButton(type: .custom)
        button.tintColor = .white
        button.setImage(settingsButtonImage, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(TrippleChartView.settingsButtonTouchUpInside(_:)), for: .touchUpInside)
        return button
    }()

    @objc private func settingsButtonTouchUpInside(_ sender: Any) {
        delegate?.trippleChart(view: self, didTriggerSettings: sender)
    }

    private lazy var backgroundOverlayImage = UIImage(named: "tag_bg_layer", in: dynamicBundle, compatibleWith: nil)
    private lazy var backgroundOverlayImageView: UIImageView = {
        let imageView = UIImageView(image: backgroundOverlayImage)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleToFill
        imageView.clipsToBounds = true
        return imageView
    }()

    private lazy var cardsContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()

    private lazy var cardsImage = UIImage(named: "icon-cards-button", in: dynamicBundle, compatibleWith: nil)
    private lazy var cardsImageView: UIImageView = {
        let imageView = UIImageView(image: cardsImage)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = .white
        return imageView
    }()

    private lazy var cardsButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(TrippleChartView.cardsButtonTouchUpInside(_:)), for: .touchUpInside)
        return button
    }()

    @objc private func cardsButtonTouchUpInside(_ sender: Any) {
        delegate?.trippleChart(view: self, didTriggerCards: sender)
    }

    lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont(name: montserratBoldFontName, size: 20)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Name".localized()
        return label
    }()

    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.isPagingEnabled = true
        scrollView.delegate = self
        return scrollView
    }()

    private lazy var scrollContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    lazy var temperatureChart: TagChartView = {
        let chart = TagChartView(frame: .zero, dataType: .temperature)
        chart.translatesAutoresizingMaskIntoConstraints = false
        return chart
    }()

    lazy var humidityChart: TagChartView = {
        let chart = TagChartView(frame: .zero, dataType: .humidity)
        chart.translatesAutoresizingMaskIntoConstraints = false
        return chart
    }()

    lazy var pressureChart: TagChartView = {
        let chart = TagChartView(frame: .zero, dataType: .pressure)
        chart.translatesAutoresizingMaskIntoConstraints = false
        return chart
    }()

    private lazy var bottomButtonContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()

    lazy var temperatureUnitLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.text = "Temperature unit".localized()
        label.font = UIFont.systemFont(ofSize: 11)
        return label
    }()

    lazy var humidityUnitLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.text = "Humidity unit".localized()
        label.font = UIFont.systemFont(ofSize: 11)
        return label
    }()

    lazy var pressureUnitLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.text = "Pressure unit".localized()
        label.font = UIFont.systemFont(ofSize: 11)
        return label
    }()

    lazy var temperatureProgressView: ProgressBarView = {
        let progressView = ProgressBarView(frame: .zero)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.layer.cornerRadius = 12
        return progressView
    }()

    lazy var humidityProgressView: ProgressBarView = {
        let progressView = ProgressBarView(frame: .zero)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.layer.cornerRadius = 12
        return progressView
    }()

    lazy var pressureProgressView: ProgressBarView = {
        let progressView = ProgressBarView(frame: .zero)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.layer.cornerRadius = 12
        return progressView
    }()

    lazy var syncButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle("SYNC".localized(), for: .normal)
        button.titleLabel?.font = UIFont(name: montserratBoldFontName, size: 15)
        button.backgroundColor = UIColor(red: 21.0/255.0, green: 141.0/255.0, blue: 165.0/255.0, alpha: 1.0)
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.cornerRadius = 22
        button.addTarget(self, action: #selector(TrippleChartView.syncButtonTouchUpInside(_:)), for: .touchUpInside)
        return button
    }()

    @objc private func syncButtonTouchUpInside(_ sender: Any) {
        delegate?.trippleChart(view: self, didTriggerSync: sender)
    }

    lazy var clearButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle("CLEAR".localized(), for: .normal)
        button.titleLabel?.font = UIFont(name: montserratBoldFontName, size: 15)
        button.backgroundColor = UIColor(red: 21.0/255.0, green: 141.0/255.0, blue: 165.0/255.0, alpha: 1.0)
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.cornerRadius = 22
        button.addTarget(self, action: #selector(TrippleChartView.clearButtonTouchUpInside(_:)), for: .touchUpInside)
        return button
    }()

    @objc private func clearButtonTouchUpInside(_ sender: Any) {
        delegate?.trippleChart(view: self, didTriggerClear: sender)
    }

    lazy var exportButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle("EXPORT".localized(), for: .normal)
        button.titleLabel?.font = UIFont(name: montserratBoldFontName, size: 15)
        button.backgroundColor = UIColor(red: 21.0/255.0, green: 141.0/255.0, blue: 165.0/255.0, alpha: 1.0)
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.cornerRadius = 22
        button.addTarget(self, action: #selector(TrippleChartView.exportButtonTouchUpInside(_:)), for: .touchUpInside)
        return button
    }()

    @objc private func exportButtonTouchUpInside(_ sender: Any) {
        delegate?.trippleChart(view: self, didTriggerExport: sender)
    }

    lazy var syncStatusLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Status...".localized()
        label.isHidden = true
        return label
    }()

    private let dynamicBundle = Bundle(for: TrippleChartView.self)
    private var contentOffset: CGPoint = .zero
    private let montserratBoldFontName = "Montserrat-Bold"

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
        setupLocalization()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
        setupLocalization()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Localizable
    func localize() {
        clearButton.setTitle("TagCharts.Clear.title".localized(), for: .normal)
        syncButton.setTitle("TagCharts.Sync.title".localized(), for: .normal)
        exportButton.setTitle("TagCharts.Export.title".localized(), for: .normal)
        pressureUnitLabel.text = "hPa".localized()
    }

    // MARK: - UIScrollViewDelegate
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        contentOffset = scrollView.contentOffset
    }

    private func commonInit() {
        addSubview(backgroundImageView)
        wrap(view: backgroundImageView, into: self)
        addSubview(backgroundOverlayImageView)
        wrap(view: backgroundOverlayImageView, into: self)
        addSubview(settingsButton)
        positionSettings(button: settingsButton)
        addSubview(cardsContainer)
        setupCardsContainer()
        positionCards(container: cardsContainer)
        addSubview(alertView)
        setupAlertView()
        position(alertView: alertView)
        addSubview(nameLabel)
        positionName(label: nameLabel)
        addSubview(scrollView)
        setupScrollView()
        position(scrollView: scrollView)
        addSubview(bottomButtonContainer)
        setupBottomButtonsContainer()
        position(bottomButtonContainer: bottomButtonContainer)
        addSubview(dummyLogoView)
        position(dummyLogoView: dummyLogoView)

        handleRotation()
        NotificationCenter
            .default
            .addObserver(self,
                         selector: #selector(TrippleChartView.handleRotation),
                         name: UIDevice.orientationDidChangeNotification,
                         object: nil)
        NotificationCenter
            .default
            .addObserver(self,
                         selector: #selector(TrippleChartView.recoverContentOffset),
                         name: UIDevice.orientationDidChangeNotification,
                         object: nil)
    }

    @objc private func recoverContentOffset() {
        let isLandscape = UIApplication.shared.statusBarOrientation.isLandscape
        if isLandscape {
            scrollView.setContentOffset(contentOffset, animated: true)
        }
    }

    @objc private func handleRotation() {
        let isLandscape = UIApplication.shared.statusBarOrientation.isLandscape
        if isLandscape {
            NSLayoutConstraint.deactivate(portraitConstraints)
            NSLayoutConstraint.activate(landscapeConstraints)
        } else {
            NSLayoutConstraint.deactivate(landscapeConstraints)
            NSLayoutConstraint.activate(portraitConstraints)
        }
    }

    private func position(alertView: UIView) {
        addConstraint(NSLayoutConstraint(item: alertView,
                                         attribute: .trailing,
                                         relatedBy: .equal,
                                         toItem: cardsContainer,
                                         attribute: .leading,
                                         multiplier: 1.0,
                                         constant: 0.0))
        addConstraint(NSLayoutConstraint(item: alertView,
                                         attribute: .centerY,
                                         relatedBy: .equal,
                                         toItem: settingsButton,
                                         attribute: .centerY,
                                         multiplier: 1.0,
                                         constant: 0.0))
    }

    // swiftlint:disable:next function_body_length
    private func setupAlertView() {
        alertView.addSubview(alertImageView)
        alertView.addSubview(alertButton)
        alertButton.addConstraint(NSLayoutConstraint(item: alertButton,
                                                     attribute: .width,
                                                     relatedBy: .equal,
                                                     toItem: nil,
                                                     attribute: .notAnAttribute,
                                                     multiplier: 1.0,
                                                     constant: 32))
        alertButton.addConstraint(NSLayoutConstraint(item: alertButton,
                                                     attribute: .height,
                                                     relatedBy: .equal,
                                                     toItem: nil,
                                                     attribute: .notAnAttribute,
                                                     multiplier: 1.0,
                                                     constant: 44))
        wrap(view: alertButton, into: alertView)

        alertImageView.addConstraint(NSLayoutConstraint(item: alertImageView,
                                                        attribute: .width,
                                                        relatedBy: .equal,
                                                        toItem: nil,
                                                        attribute: .notAnAttribute,
                                                        multiplier: 1.0,
                                                        constant: 28))
        alertImageView.addConstraint(NSLayoutConstraint(item: alertImageView,
                                                        attribute: .height,
                                                        relatedBy: .equal,
                                                        toItem: nil,
                                                        attribute: .notAnAttribute,
                                                        multiplier: 1.0,
                                                        constant: 28))

        alertView.addConstraint(NSLayoutConstraint(item: alertImageView,
                                                   attribute: .centerX,
                                                   relatedBy: .equal,
                                                   toItem: alertButton,
                                                   attribute: .centerX,
                                                   multiplier: 1.0,
                                                   constant: 0.0))
        alertView.addConstraint(NSLayoutConstraint(item: alertImageView,
                                                   attribute: .centerY,
                                                   relatedBy: .equal,
                                                   toItem: alertButton,
                                                   attribute: .centerY,
                                                   multiplier: 1.0,
                                                   constant: 0.0))
    }

    private func position(dummyLogoView: UIView) {
        dummyLogoView.addConstraint(NSLayoutConstraint(item: dummyLogoView,
                                                       attribute: .height,
                                                       relatedBy: .equal,
                                                       toItem: nil,
                                                       attribute: .notAnAttribute,
                                                       multiplier: 1.0,
                                                       constant: 36))

        if #available(iOS 11.0, *) {
            let guide = safeAreaLayoutGuide
            addConstraint(dummyLogoView.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 8))
            addConstraint(dummyLogoView.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8))

        } else {
            addConstraint(NSLayoutConstraint(item: dummyLogoView,
                                             attribute: .leading,
                                             relatedBy: .equal,
                                             toItem: self,
                                             attribute: .leading,
                                             multiplier: 1.0,
                                             constant: 8))

            addConstraint(NSLayoutConstraint(item: dummyLogoView,
                                             attribute: .top,
                                             relatedBy: .equal,
                                             toItem: self,
                                             attribute: .top,
                                             multiplier: 1.0,
                                             constant: 28))
        }
    }

    // swiftlint:disable:next function_body_length
    private func setupBottomButtonsContainer() {
        bottomButtonContainer.addSubview(syncButton)
        bottomButtonContainer.addConstraint(NSLayoutConstraint(item: bottomButtonContainer,
                                                               attribute: .centerX,
                                                               relatedBy: .equal,
                                                               toItem: syncButton,
                                                               attribute: .centerX,
                                                               multiplier: 1.0,
                                                               constant: 0.0))
        bottomButtonContainer.addConstraint(NSLayoutConstraint(item: bottomButtonContainer,
                                                               attribute: .centerY,
                                                               relatedBy: .equal,
                                                               toItem: syncButton,
                                                               attribute: .centerY,
                                                               multiplier: 1.0,
                                                               constant: 0.0))

        bottomButtonContainer.addSubview(clearButton)
        bottomButtonContainer.addConstraint(NSLayoutConstraint(item: clearButton,
                                                               attribute: .centerY,
                                                               relatedBy: .equal,
                                                               toItem: syncButton,
                                                               attribute: .centerY,
                                                               multiplier: 1.0,
                                                               constant: 0))
        bottomButtonContainer.addConstraint(NSLayoutConstraint(item: clearButton,
                                                               attribute: .trailing,
                                                               relatedBy: .equal,
                                                               toItem: syncButton,
                                                               attribute: .leading,
                                                               multiplier: 1.0,
                                                               constant: -8))

        bottomButtonContainer.addSubview(exportButton)
        bottomButtonContainer.addConstraint(NSLayoutConstraint(item: exportButton,
                                                               attribute: .centerY,
                                                               relatedBy: .equal,
                                                               toItem: syncButton,
                                                               attribute: .centerY,
                                                               multiplier: 1.0,
                                                               constant: 0))
        bottomButtonContainer.addConstraint(NSLayoutConstraint(item: syncButton,
                                                               attribute: .trailing,
                                                               relatedBy: .equal,
                                                               toItem: exportButton,
                                                               attribute: .leading,
                                                               multiplier: 1.0,
                                                               constant: -8))

        bottomButtonContainer.addSubview(syncStatusLabel)
        bottomButtonContainer.addConstraint(NSLayoutConstraint(item: bottomButtonContainer,
                                                               attribute: .centerX,
                                                               relatedBy: .equal,
                                                               toItem: syncStatusLabel,
                                                               attribute: .centerX,
                                                               multiplier: 1.0,
                                                               constant: 0.0))
        bottomButtonContainer.addConstraint(NSLayoutConstraint(item: bottomButtonContainer,
                                                               attribute: .centerY,
                                                               relatedBy: .equal,
                                                               toItem: syncStatusLabel,
                                                               attribute: .centerY,
                                                               multiplier: 1.0,
                                                               constant: 0.0))
    }

    // swiftlint:disable:next function_body_length
    private func position(bottomButtonContainer: UIView) {

        bottomButtonContainer.addConstraint(NSLayoutConstraint(item: bottomButtonContainer,
                                                               attribute: .height,
                                                               relatedBy: .equal,
                                                               toItem: nil,
                                                               attribute: .notAnAttribute,
                                                               multiplier: 1.0,
                                                               constant: 60))
        if #available(iOS 11.0, *) {
            let guide = safeAreaLayoutGuide
            addConstraint(bottomButtonContainer.trailingAnchor.constraint(equalTo: guide.trailingAnchor))
            addConstraint(bottomButtonContainer.leadingAnchor.constraint(equalTo: guide.leadingAnchor))
            addConstraint(bottomButtonContainer.bottomAnchor.constraint(equalTo: guide.bottomAnchor))

        } else {
            addConstraint(NSLayoutConstraint(item: bottomButtonContainer,
                                             attribute: .trailing,
                                             relatedBy: .equal,
                                             toItem: self,
                                             attribute: .trailing,
                                             multiplier: 1.0,
                                             constant: 0))
            addConstraint(NSLayoutConstraint(item: bottomButtonContainer,
                                             attribute: .leading,
                                             relatedBy: .equal,
                                             toItem: self,
                                             attribute: .leading,
                                             multiplier: 1.0,
                                             constant: 0))
            addConstraint(NSLayoutConstraint(item: bottomButtonContainer,
                                             attribute: .bottom,
                                             relatedBy: .equal,
                                             toItem: self,
                                             attribute: .bottom,
                                             multiplier: 1.0,
                                             constant: 0))
        }

        addConstraint(NSLayoutConstraint(item: scrollView,
                                         attribute: .bottom,
                                         relatedBy: .equal,
                                         toItem: bottomButtonContainer,
                                         attribute: .top,
                                         multiplier: 1.0,
                                         constant: 0))
    }

    private func position(scrollView: UIScrollView) {
        if #available(iOS 11.0, *) {
            let guide = safeAreaLayoutGuide
            addConstraint(scrollView.trailingAnchor.constraint(equalTo: guide.trailingAnchor))
            addConstraint(scrollView.leadingAnchor.constraint(equalTo: guide.leadingAnchor))

        } else {
            addConstraint(NSLayoutConstraint(item: scrollView,
                                             attribute: .trailing,
                                             relatedBy: .equal,
                                             toItem: self,
                                             attribute: .trailing,
                                             multiplier: 1.0,
                                             constant: 0))
            addConstraint(NSLayoutConstraint(item: scrollView,
                                             attribute: .leading,
                                             relatedBy: .equal,
                                             toItem: self,
                                             attribute: .leading,
                                             multiplier: 1.0,
                                             constant: 0))
        }

        addConstraint(NSLayoutConstraint(item: scrollView,
                                         attribute: .top,
                                         relatedBy: .equal,
                                         toItem: nameLabel,
                                         attribute: .bottom,
                                         multiplier: 1.0,
                                         constant: 8))
    }

    private func setupScrollView() {
        scrollView.addSubview(scrollContainer)
        wrap(view: scrollContainer, into: scrollView)
        scrollView.addConstraint(NSLayoutConstraint(item: scrollView,
                                                    attribute: .centerX,
                                                    relatedBy: .equal,
                                                    toItem: scrollContainer,
                                                    attribute: .centerX,
                                                    multiplier: 1.0,
                                                    constant: 0.0))
        setupScrollContainer()
        setupUnitLabels()
        setupProgressBars()
    }

    // swiftlint:disable:next function_body_length
    private func setupUnitLabels() {
        temperatureChart.addSubview(temperatureUnitLabel)
        temperatureChart.addConstraint(NSLayoutConstraint(item: temperatureUnitLabel,
                                                          attribute: .trailing,
                                                          relatedBy: .equal,
                                                          toItem: temperatureChart,
                                                          attribute: .trailing,
                                                          multiplier: 1.0,
                                                          constant: -8))
        temperatureChart.addConstraint(NSLayoutConstraint(item: temperatureUnitLabel,
                                                          attribute: .top,
                                                          relatedBy: .equal,
                                                          toItem: temperatureChart,
                                                          attribute: .top,
                                                          multiplier: 1.0,
                                                          constant: 8))

        humidityChart.addSubview(humidityUnitLabel)
        humidityChart.addConstraint(NSLayoutConstraint(item: humidityUnitLabel,
                                                       attribute: .trailing,
                                                       relatedBy: .equal,
                                                       toItem: humidityChart,
                                                       attribute: .trailing,
                                                       multiplier: 1.0,
                                                       constant: -8))
        humidityChart.addConstraint(NSLayoutConstraint(item: humidityUnitLabel,
                                                       attribute: .top,
                                                       relatedBy: .equal,
                                                       toItem: humidityChart,
                                                       attribute: .top,
                                                       multiplier: 1.0,
                                                       constant: 8))

        pressureChart.addSubview(pressureUnitLabel)
        pressureChart.addConstraint(NSLayoutConstraint(item: pressureUnitLabel,
                                                       attribute: .trailing,
                                                       relatedBy: .equal,
                                                       toItem: pressureChart,
                                                       attribute: .trailing,
                                                       multiplier: 1.0,
                                                       constant: -8))
        pressureChart.addConstraint(NSLayoutConstraint(item: pressureUnitLabel,
                                                       attribute: .top,
                                                       relatedBy: .equal,
                                                       toItem: pressureChart,
                                                       attribute: .top,
                                                       multiplier: 1.0,
                                                       constant: 8))
    }

    private func setupProgressBars() {
        temperatureChart.addSubview(temperatureProgressView)
        addConstraints(for: temperatureChart, progressView: temperatureProgressView)
        humidityChart.addSubview(humidityProgressView)
        addConstraints(for: humidityChart, progressView: humidityProgressView)
        pressureChart.addSubview(pressureProgressView)
        addConstraints(for: pressureChart, progressView: pressureProgressView)
    }

    private func addConstraints(for chartView: TagChartView, progressView: ProgressBarView) {
        chartView.addConstraint(NSLayoutConstraint(item: progressView,
                                                   attribute: .centerX,
                                                   relatedBy: .equal,
                                                   toItem: chartView,
                                                   attribute: .centerX,
                                                   multiplier: 1.0,
                                                   constant: 0.0))
        chartView.addConstraint(NSLayoutConstraint(item: progressView,
                                                   attribute: .centerY,
                                                   relatedBy: .equal,
                                                   toItem: chartView,
                                                   attribute: .centerY,
                                                   multiplier: 1.0,
                                                   constant: 44.0))
        chartView.addConstraint(NSLayoutConstraint(item: progressView,
                                                   attribute: .height,
                                                   relatedBy: .equal,
                                                   toItem: nil,
                                                   attribute: .notAnAttribute,
                                                   multiplier: 1.0,
                                                   constant: 24.0))
        chartView.addConstraint(NSLayoutConstraint(item: progressView,
                                                   attribute: .width,
                                                   relatedBy: .equal,
                                                   toItem: chartView,
                                                   attribute: .width,
                                                   multiplier: 0.5,
                                                   constant: 0.0))
    }

    // swiftlint:disable:next function_body_length
    private func setupScrollContainer() {
        scrollContainer.addSubview(temperatureChart)
        scrollContainer.addSubview(humidityChart)
        scrollContainer.addSubview(pressureChart)

        // bind top leading and trailing of temperature chart
        scrollContainer.addConstraint(NSLayoutConstraint(item: temperatureChart,
                                                         attribute: .leading,
                                                         relatedBy: .equal,
                                                         toItem: scrollContainer,
                                                         attribute: .leading,
                                                         multiplier: 1.0,
                                                         constant: 0.0))
        scrollContainer.addConstraint(NSLayoutConstraint(item: temperatureChart,
                                                         attribute: .trailing,
                                                         relatedBy: .equal,
                                                         toItem: scrollContainer,
                                                         attribute: .trailing,
                                                         multiplier: 1.0,
                                                         constant: 0.0))
        scrollContainer.addConstraint(NSLayoutConstraint(item: temperatureChart,
                                                         attribute: .top,
                                                         relatedBy: .equal,
                                                         toItem: scrollContainer,
                                                         attribute: .top,
                                                         multiplier: 1.0,
                                                         constant: 0.0))

        // bind temperature and humidity charts
        scrollContainer.addConstraint(NSLayoutConstraint(item: temperatureChart,
                                                         attribute: .bottom,
                                                         relatedBy: .equal,
                                                         toItem: humidityChart,
                                                         attribute: .top,
                                                         multiplier: 1.0,
                                                         constant: 0.0))

        // bind leading and trailing of humidity chart
        scrollContainer.addConstraint(NSLayoutConstraint(item: humidityChart,
                                                         attribute: .leading,
                                                         relatedBy: .equal,
                                                         toItem: scrollContainer,
                                                         attribute: .leading,
                                                         multiplier: 1.0,
                                                         constant: 0.0))
        scrollContainer.addConstraint(NSLayoutConstraint(item: humidityChart,
                                                         attribute: .trailing,
                                                         relatedBy: .equal,
                                                         toItem: scrollContainer,
                                                         attribute: .trailing,
                                                         multiplier: 1.0,
                                                         constant: 0.0))

        // bind humidity and pressure charts
        scrollContainer.addConstraint(NSLayoutConstraint(item: humidityChart,
                                                         attribute: .bottom,
                                                         relatedBy: .equal,
                                                         toItem: pressureChart,
                                                         attribute: .top,
                                                         multiplier: 1.0,
                                                         constant: 0.0))

        // bind bottom leading and trailing of temperature chart
        scrollContainer.addConstraint(NSLayoutConstraint(item: pressureChart,
                                                         attribute: .leading,
                                                         relatedBy: .equal,
                                                         toItem: scrollContainer,
                                                         attribute: .leading,
                                                         multiplier: 1.0,
                                                         constant: 0.0))
        scrollContainer.addConstraint(NSLayoutConstraint(item: pressureChart,
                                                         attribute: .trailing,
                                                         relatedBy: .equal,
                                                         toItem: scrollContainer,
                                                         attribute: .trailing,
                                                         multiplier: 1.0,
                                                         constant: 0.0))
        scrollContainer.addConstraint(NSLayoutConstraint(item: pressureChart,
                                                         attribute: .bottom,
                                                         relatedBy: .equal,
                                                         toItem: scrollContainer,
                                                         attribute: .bottom,
                                                         multiplier: 1.0,
                                                         constant: 0.0))

        // bind equal heights for charts
        scrollContainer.addConstraint(NSLayoutConstraint(item: temperatureChart,
                                                         attribute: .height,
                                                         relatedBy: .equal,
                                                         toItem: humidityChart,
                                                         attribute: .height,
                                                         multiplier: 1.0,
                                                         constant: 0.0))
        scrollContainer.addConstraint(NSLayoutConstraint(item: humidityChart,
                                                         attribute: .height,
                                                         relatedBy: .equal,
                                                         toItem: pressureChart,
                                                         attribute: .height,
                                                         multiplier: 1.0,
                                                         constant: 0.0))
    }

    private func positionName(label: UILabel) {
        label.addConstraint(NSLayoutConstraint(item: label,
                                               attribute: .height,
                                               relatedBy: .equal,
                                               toItem: nil,
                                               attribute: .notAnAttribute,
                                               multiplier: 1.0,
                                               constant: 21))
    }

    private func positionCards(container: UIView) {
        addConstraint(NSLayoutConstraint(item: container,
                                         attribute: .trailing,
                                         relatedBy: .equal,
                                         toItem: settingsButton,
                                         attribute: .leading,
                                         multiplier: 1.0,
                                         constant: 0.0))
        addConstraint(NSLayoutConstraint(item: container,
                                         attribute: .centerY,
                                         relatedBy: .equal,
                                         toItem: settingsButton,
                                         attribute: .centerY,
                                         multiplier: 1.0,
                                         constant: 0.0))
    }

    // swiftlint:disable:next function_body_length
    private func setupCardsContainer() {
        cardsContainer.addSubview(cardsImageView)
        cardsContainer.addSubview(cardsButton)
        cardsButton.addConstraint(NSLayoutConstraint(item: cardsButton,
                                                     attribute: .width,
                                                     relatedBy: .equal,
                                                     toItem: nil,
                                                     attribute: .notAnAttribute,
                                                     multiplier: 1.0,
                                                     constant: 44))
        cardsButton.addConstraint(NSLayoutConstraint(item: cardsButton,
                                                     attribute: .height,
                                                     relatedBy: .equal,
                                                     toItem: nil,
                                                     attribute: .notAnAttribute,
                                                     multiplier: 1.0,
                                                     constant: 44))
        wrap(view: cardsButton, into: cardsContainer)

        cardsImageView.addConstraint(NSLayoutConstraint(item: cardsImageView,
                                                        attribute: .width,
                                                        relatedBy: .equal,
                                                        toItem: nil,
                                                        attribute: .notAnAttribute,
                                                        multiplier: 1.0,
                                                        constant: 26))
        cardsImageView.addConstraint(NSLayoutConstraint(item: cardsImageView,
                                                        attribute: .height,
                                                        relatedBy: .equal,
                                                        toItem: nil,
                                                        attribute: .notAnAttribute,
                                                        multiplier: 1.0,
                                                        constant: 26))

        cardsContainer.addConstraint(NSLayoutConstraint(item: cardsImageView,
                                                        attribute: .centerX,
                                                        relatedBy: .equal,
                                                        toItem: cardsButton,
                                                        attribute: .centerX,
                                                        multiplier: 1.0,
                                                        constant: 4.0))
        cardsContainer.addConstraint(NSLayoutConstraint(item: cardsImageView,
                                                        attribute: .centerY,
                                                        relatedBy: .equal,
                                                        toItem: cardsButton,
                                                        attribute: .centerY,
                                                        multiplier: 1.0,
                                                        constant: 0.0))
    }

    private func positionSettings(button: UIButton) {
        button.addConstraint(NSLayoutConstraint(item: button,
                                                attribute: .width,
                                                relatedBy: .equal,
                                                toItem: nil,
                                                attribute: .notAnAttribute,
                                                multiplier: 1.0,
                                                constant: 36))
        button.addConstraint(NSLayoutConstraint(item: button,
                                                attribute: .height,
                                                relatedBy: .equal,
                                                toItem: nil,
                                                attribute: .notAnAttribute,
                                                multiplier: 1.0,
                                                constant: 36))
        if #available(iOS 11.0, *) {
            let guide = safeAreaLayoutGuide
            addConstraint(button.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -8))
            addConstraint(button.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8))

        } else {
            addConstraint(NSLayoutConstraint(item: button,
                                             attribute: .top,
                                             relatedBy: .equal,
                                             toItem: self,
                                             attribute: .top,
                                             multiplier: 1.0,
                                             constant: 28))
            addConstraint(NSLayoutConstraint(item: button,
                                             attribute: .trailing,
                                             relatedBy: .equal,
                                             toItem: self,
                                             attribute: .trailing,
                                             multiplier: 1.0,
                                             constant: -8))
        }
    }

    private func wrap(view: UIView, into container: UIView) {
        addConstraint(NSLayoutConstraint(item: view,
                                         attribute: .leading,
                                         relatedBy: .equal,
                                         toItem: container,
                                         attribute: .leading,
                                         multiplier: 1.0,
                                         constant: 0.0))
        addConstraint(NSLayoutConstraint(item: view,
                                         attribute: .trailing,
                                         relatedBy: .equal,
                                         toItem: container,
                                         attribute: .trailing,
                                         multiplier: 1.0,
                                         constant: 0.0))
        addConstraint(NSLayoutConstraint(item: view,
                                         attribute: .top,
                                         relatedBy: .equal,
                                         toItem: container,
                                         attribute: .top,
                                         multiplier: 1.0,
                                         constant: 0.0))
        addConstraint(NSLayoutConstraint(item: view,
                                         attribute: .bottom,
                                         relatedBy: .equal,
                                         toItem: container,
                                         attribute: .bottom,
                                         multiplier: 1.0,
                                         constant: 0.0))
    }
}
// swiftlint:enable file_length
