// swiftlint:disable file_length
import DGCharts
import RuuviLocal
import RuuviLocalization
import RuuviOntology
import RuuviService
import UIKit

// swiftlint:disable:next type_body_length
final class MeasurementDetailsViewController: UIViewController {
    // MARK: - Constants

    private enum Layout {
        static let headerTopMargin: CGFloat = 24
        static let headerHeight: CGFloat = 30
        static let iconSize: CGFloat = 24
        static let iconTitleSpacing: CGFloat = 8
        static let valueTitleSpacing: CGFloat = 8
        static let valueUnitSpacing: CGFloat = 4
        static let headerDescriptionSpacing: CGFloat = 16
        static let unitBottomOffset: CGFloat = -1
        static let statusViewHeight: CGFloat = 16
        static let graphTopMargin: CGFloat = 8
        static let graphBottomPadding: CGFloat = 16
        static let graphHeight: CGFloat = 200
        static let aqiContentTopPadding: CGFloat = 16
        static let beaverAdviceTopPadding: CGFloat = 16
        static let durationLabelRightPadding: CGFloat = 8
        static let horizontalMargin: CGFloat = 16
        static let bottomMargin: CGFloat = -20
    }

    private enum Animation {
        static let fadeTransitionDuration: Double = 0.3
    }

    private enum Alpha {
        static let durationLabel: CGFloat = 0.5
        static let descriptionParagraph: CGFloat = 0.8
        static let hidden: CGFloat = 0
        static let visible: CGFloat = 1
    }

    // MARK: - Dependencies

    weak var output: MeasurementDetailsViewOutput?

    // MARK: - UI Components - Scroll Container

    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()

    private lazy var contentView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - UI Components - Header

    private lazy var headerContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicatorBig.color
        label.font = UIFont.ruuviCallout()
        label.textAlignment = .left
        label.numberOfLines = 2
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(
            .required,
            for: .vertical
        )
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var valueLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicatorBig.color
        label.font = UIFont.ruuviCallout()
        label.textAlignment = .right
        label.numberOfLines = 1
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(
            .required,
            for: .vertical
        )
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var unitLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicatorBig.color
        label.font = UIFont.ruuviHeadlineTiny()
        label.textAlignment = .right
        label.numberOfLines = 1
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(
            .required,
            for: .vertical
        )
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var statusView: MeasurementStatusView = {
        let view = MeasurementStatusView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - UI Components - Graph

    private lazy var graphContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.addSubview(graphView)
        graphView.anchor(
            top: view.topAnchor,
            leading: view.leadingAnchor,
            bottom: view.bottomAnchor,
            trailing: view.trailingAnchor,
            padding: .init(
                top: 0,
                left: 0,
                bottom: Layout.graphBottomPadding,
                right: 0
            )
        )

        view.addSubview(graphOverlayView)
        graphOverlayView.fillSuperview()

        view.addSubview(noDataLabel)
        noDataLabel.match(
            view: graphView,
            padding: .init(top: 8, left: 16, bottom: 8, right: 16)
        )

        view.addSubview(durationLabel)
        durationLabel.anchor(
            top: nil,
            leading: nil,
            bottom: view.bottomAnchor,
            trailing: view.trailingAnchor,
            padding: .init(
                top: 0,
                left: 0,
                bottom: 0,
                right: Layout.durationLabelRightPadding
            )
        )
        return view
    }()

    private lazy var graphView: TagChartsViewInternal = {
        let view = TagChartsViewInternal(
            source: .mesurementDetails,
            graphType: currentMeasurementType
        )
        view.isUserInteractionEnabled = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var graphOverlayView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(handleGraphTap)
            )
        )
        return view
    }()

    private lazy var noDataLabel: UILabel = {
        let label = UILabel()
        label.text = RuuviLocalization.popupNoHistoryData
        label.textColor = RuuviColor.dashboardIndicator.color
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.ruuviCallout()
        return label
    }()

    private lazy var durationLabel: UILabel = {
        let label = UILabel()
        label.text = RuuviLocalization.day2
        label.textColor = RuuviColor.dashboardIndicator.color
            .withAlphaComponent(Alpha.durationLabel)
        label.textAlignment = .right
        label.numberOfLines = 0
        label.font = UIFont.ruuviCaption2()
        return label
    }()

    // MARK: - UI Components - AQI Content

    private lazy var aqiMeasurementsStack: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private lazy var beaverAdviceView: BeaverAdviceView = {
        let view = BeaverAdviceView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - UI Components - Description

    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicator.color
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .left
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(
            .required,
            for: .vertical
        )
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = true
        return label
    }()

    // MARK: - State Properties

    private var currentMeasurementType: MeasurementType
    private var tagSnapshot: RuuviTagCardSnapshot
    private var maximumSheetHeight: CGFloat

    private var shouldHideStatusView = false
    private var shouldHideGraph = false
    private var lastAQIQualityState: MeasurementQualityState?

    private var co2Card: CardsMeasurementIndicatorView?
    private var pm25Card: CardsMeasurementIndicatorView?

    // MARK: - Interaction Properties

    private var linkTapHandler: ((String) -> Void)?
    private var descriptionTapGesture: UITapGestureRecognizer!

    // MARK: - Constraint Properties

    private var statusViewHeightConstraint: NSLayoutConstraint!
    private var graphContainerHeightConstraint: NSLayoutConstraint!
    private var aqiMeasurementsTopConstraint: NSLayoutConstraint!
    private var aqiMeasurementsHeightConstraint: NSLayoutConstraint!
    private var beaverAdviceTopConstraint: NSLayoutConstraint!
    private var beaverAdviceHeightConstraint: NSLayoutConstraint!

    // MARK: - Initialization

    init(
        maximumSheetHeight: CGFloat,
        measurementType: MeasurementType,
        snapshot: RuuviTagCardSnapshot
    ) {
        self.maximumSheetHeight = maximumSheetHeight
        self.currentMeasurementType = measurementType
        self.tagSnapshot = snapshot
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        applyVisibilityStates()
        setupLinkTapGesture()
        output?.viewDidLoad()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updatePreferredContentSize()
    }

    // MARK: - Public Configuration

    func configure(
        measurementType: MeasurementType,
        value: String? = nil,
        unit: String? = nil,
        quality: MeasurementQualityState? = nil,
        description: NSAttributedString? = nil,
        linkHandler: ((String) -> Void)? = nil
    ) {
        configureContent(
            measurementType: measurementType,
            value: value,
            unit: unit,
            quality: quality,
            description: description
        )

        linkTapHandler = linkHandler

        DispatchQueue.main.async { [weak self] in
            self?.updatePreferredContentSize()
        }
    }
}

// MARK: - Setup Methods

private extension MeasurementDetailsViewController {
    func setupUI() {
        view.backgroundColor = RuuviColor.dashboardCardBG.color
        buildViewHierarchy()
        setupAllConstraints()
    }

    func buildViewHierarchy() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(headerContainerView)
        contentView.addSubview(statusView)
        contentView.addSubview(graphContainerView)
        contentView.addSubview(aqiMeasurementsStack)
        contentView.addSubview(beaverAdviceView)
        contentView.addSubview(descriptionLabel)

        headerContainerView.addSubview(iconImageView)
        headerContainerView.addSubview(titleLabel)
        headerContainerView.addSubview(valueLabel)
        headerContainerView.addSubview(unitLabel)

        noDataLabel.alpha = Alpha.hidden
    }

    func setupAllConstraints() {
        createConstraintReferences()
        activateScrollViewConstraints()
        activateHeaderConstraints()
        activateStatusViewConstraints()
        activateGraphConstraints()
        activateAQIContentConstraints()
        activateBeaverAdviceConstraints()
        activateDescriptionConstraints()
    }

    func createConstraintReferences() {
        statusViewHeightConstraint = statusView.heightAnchor
            .constraint(equalToConstant: Layout.statusViewHeight)

        graphContainerHeightConstraint = graphContainerView.heightAnchor
            .constraint(equalToConstant: Layout.graphHeight)

        aqiMeasurementsTopConstraint = aqiMeasurementsStack.topAnchor
            .constraint(
                equalTo: graphContainerView.bottomAnchor,
                constant: Layout.aqiContentTopPadding
            )

        aqiMeasurementsHeightConstraint = aqiMeasurementsStack
            .heightAnchor.constraint(equalToConstant: 0)

        beaverAdviceTopConstraint = beaverAdviceView.topAnchor
            .constraint(
                equalTo: aqiMeasurementsStack.bottomAnchor,
                constant: Layout.beaverAdviceTopPadding
            )

        beaverAdviceHeightConstraint = beaverAdviceView.heightAnchor
            .constraint(equalToConstant: 0)
    }

    func activateScrollViewConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor
            ),
            scrollView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor
            ),
            scrollView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            ),
            scrollView.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor
            ),

            contentView.topAnchor.constraint(
                equalTo: scrollView.topAnchor
            ),
            contentView.leadingAnchor.constraint(
                equalTo: scrollView.leadingAnchor
            ),
            contentView.trailingAnchor.constraint(
                equalTo: scrollView.trailingAnchor
            ),
            contentView.bottomAnchor.constraint(
                equalTo: scrollView.bottomAnchor
            ),
            contentView.widthAnchor.constraint(
                equalTo: scrollView.widthAnchor
            ),
        ])
    }

    // swiftlint:disable:next function_body_length
    func activateHeaderConstraints() {
        NSLayoutConstraint.activate([
            headerContainerView.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: Layout.headerTopMargin
            ),
            headerContainerView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: Layout.horizontalMargin
            ),
            headerContainerView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -Layout.horizontalMargin
            ),
            headerContainerView.heightAnchor.constraint(
                equalToConstant: Layout.headerHeight
            ),

            iconImageView.leadingAnchor.constraint(
                equalTo: headerContainerView.leadingAnchor
            ),
            iconImageView.centerYAnchor.constraint(
                equalTo: headerContainerView.centerYAnchor
            ),
            iconImageView.widthAnchor.constraint(
                equalToConstant: Layout.iconSize
            ),
            iconImageView.heightAnchor.constraint(
                equalToConstant: Layout.iconSize
            ),

            titleLabel.leadingAnchor.constraint(
                equalTo: iconImageView.trailingAnchor,
                constant: Layout.iconTitleSpacing
            ),
            titleLabel.centerYAnchor.constraint(
                equalTo: headerContainerView.centerYAnchor
            ),

            valueLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: titleLabel.trailingAnchor,
                constant: Layout.valueTitleSpacing
            ),
            valueLabel.centerYAnchor.constraint(
                equalTo: headerContainerView.centerYAnchor
            ),

            unitLabel.leadingAnchor.constraint(
                equalTo: valueLabel.trailingAnchor,
                constant: Layout.valueUnitSpacing
            ),
            unitLabel.trailingAnchor.constraint(
                equalTo: headerContainerView.trailingAnchor
            ),
            unitLabel.bottomAnchor.constraint(
                equalTo: valueLabel.bottomAnchor,
                constant: Layout.unitBottomOffset
            ),
        ])
    }

    func activateStatusViewConstraints() {
        NSLayoutConstraint.activate([
            statusView.topAnchor.constraint(
                equalTo: headerContainerView.bottomAnchor
            ),
            statusView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: Layout.horizontalMargin
            ),
            statusView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -Layout.horizontalMargin
            ),
            statusViewHeightConstraint,
        ])
    }

    func activateGraphConstraints() {
        NSLayoutConstraint.activate([
            graphContainerView.topAnchor.constraint(
                equalTo: statusView.bottomAnchor,
                constant: Layout.graphTopMargin
            ),
            graphContainerView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor
            ),
            graphContainerView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -Layout.horizontalMargin
            ),
            graphContainerHeightConstraint,
        ])
    }

    func activateAQIContentConstraints() {
        NSLayoutConstraint.activate([
            aqiMeasurementsTopConstraint,
            aqiMeasurementsStack.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: Layout.horizontalMargin
            ),
            aqiMeasurementsStack.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -Layout.horizontalMargin
            ),
            aqiMeasurementsHeightConstraint,
        ])
    }

    func activateBeaverAdviceConstraints() {
        NSLayoutConstraint.activate([
            beaverAdviceTopConstraint,
            beaverAdviceView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: Layout.horizontalMargin
            ),
            beaverAdviceView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -Layout.horizontalMargin
            ),
            beaverAdviceHeightConstraint,
        ])
    }

    func activateDescriptionConstraints() {
        NSLayoutConstraint.activate([
            descriptionLabel.topAnchor.constraint(
                equalTo: beaverAdviceView.bottomAnchor,
                constant: Layout.headerDescriptionSpacing
            ),
            descriptionLabel.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: Layout.horizontalMargin
            ),
            descriptionLabel.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -Layout.horizontalMargin
            ),
            descriptionLabel.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: Layout.bottomMargin
            ),
        ])
    }
}

// MARK: - Content Configuration

private extension MeasurementDetailsViewController {
    func configureContent(
        measurementType: MeasurementType,
        value: String?,
        unit: String?,
        quality: MeasurementQualityState?,
        description: NSAttributedString?
    ) {
        titleLabel.text = measurementType.fullName
        valueLabel.text = value
        unitLabel.text = unit
        descriptionLabel.attributedText = description

        if let quality = quality {
            statusView.configure(from: quality)
        }

        iconImageView.image = measurementType.icon
            .withRenderingMode(.alwaysOriginal)

        shouldHideStatusView = !(
            measurementType == .aqi ||
            measurementType == .co2 ||
            measurementType == .pm25
        )
        shouldHideGraph = (measurementType == .movementCounter)

        if isViewLoaded {
            applyVisibilityStates()
        }
    }

    func applyVisibilityStates() {
        applyStatusViewVisibility()
        applyGraphVisibility()
        applyAQIContentVisibility()
    }

    func applyStatusViewVisibility() {
        if shouldHideStatusView {
            statusViewHeightConstraint.constant = 0
            statusView.isHidden = true
        } else {
            statusViewHeightConstraint.constant = Layout.statusViewHeight
            statusView.isHidden = false
        }
    }

    func applyGraphVisibility() {
        if shouldHideGraph {
            graphContainerHeightConstraint.constant = 0
            graphContainerView.isHidden = true
        } else {
            graphContainerHeightConstraint.constant = Layout.graphHeight
            graphContainerView.isHidden = false
        }
    }

    func applyAQIContentVisibility() {
        let aqiQuality = tagSnapshot.displayData.indicatorGrid?.indicators
            .first(where: { $0.type == .aqi })?.qualityState
        switch aqiQuality {
        case .undefined:
            hideAQIContent()
        default:
            if currentMeasurementType == .aqi {
                setupAQIContent()
            } else {
                hideAQIContent()
            }
        }
    }

    func setupAQIContent() {
        let measurements = tagSnapshot.displayData.indicatorGrid?
            .indicators.filter { $0.type == .co2 || $0.type == .pm25 }

        for measurement in measurements ?? [] {
            let card = createMeasurementCard(for: measurement)
            aqiMeasurementsStack.addArrangedSubview(card)

            if measurement.type == .co2 {
                co2Card = card
            } else if measurement.type == .pm25 {
                pm25Card = card
            }
        }

        aqiMeasurementsTopConstraint.constant = Layout.aqiContentTopPadding
        aqiMeasurementsHeightConstraint.isActive = false
        aqiMeasurementsStack.isHidden = false

        configureBeaverAdvice(with: measurements)

        beaverAdviceTopConstraint.constant = Layout.beaverAdviceTopPadding
        beaverAdviceHeightConstraint.isActive = false
        beaverAdviceView.isHidden = false
    }

    func hideAQIContent() {
        aqiMeasurementsStack.arrangedSubviews.forEach {
            $0.removeFromSuperview()
        }
        aqiMeasurementsStack.isHidden = true
        aqiMeasurementsTopConstraint.constant = 0
        aqiMeasurementsHeightConstraint.isActive = true

        co2Card = nil
        pm25Card = nil

        beaverAdviceView.isHidden = true
        beaverAdviceTopConstraint.constant = 0
        beaverAdviceHeightConstraint.isActive = true
    }

    func createMeasurementCard(
        for measurement: RuuviTagCardSnapshotIndicatorData
    ) -> CardsMeasurementIndicatorView {
        let card = CardsMeasurementIndicatorView(
            source: .measurementDetails
        )
        card.configure(with: measurement)
        card.onTap = { [weak self] in
            self?.handleMeasurementCardTap(measurement)
        }
        return card
    }

    func configureBeaverAdvice(
        with measurements: [RuuviTagCardSnapshotIndicatorData]?
    ) {
        let aqiQuality = tagSnapshot.displayData.indicatorGrid?.indicators
            .first(where: { $0.type == .aqi })?.qualityState
        let co2Quality = measurements?
            .first(where: { $0.type == .co2 })?.qualityState
        let pm25Quality = measurements?
            .first(where: { $0.type == .pm25 })?.qualityState

        guard let aqiQuality = aqiQuality,
              let co2Quality = co2Quality,
              let pm25Quality = pm25Quality else { return }

        lastAQIQualityState = aqiQuality
        let advice = BeaverAdviceHelper.getBeaverAdvice(
            aqiQuality: aqiQuality,
            co2Quality: co2Quality,
            pm25Quality: pm25Quality
        )
        beaverAdviceView.configure(with: advice)
    }

    func handleMeasurementCardTap(
        _ measurement: RuuviTagCardSnapshotIndicatorData
    ) {
        currentMeasurementType = measurement.type

        let processedValue = Self.processIndicatorValue(measurement)
        let processedUnit = Self.processIndicatorUnit(measurement)
        let attributedDescription = Self.createAttributedDescription(
            for: measurement.type
        )

        configure(
            measurementType: measurement.type,
            value: processedValue,
            unit: processedUnit,
            quality: measurement.qualityState,
            description: attributedDescription,
            linkHandler: Self.handleLinkTap
        )

        output?.didTapMeasurement(measurement)
    }

    @objc func handleGraphTap() {
        output?.didTapGraph()
    }
}

// MARK: - MeasurementDetailsViewInput

extension MeasurementDetailsViewController: MeasurementDetailsViewInput {
    func updateMeasurements(
        with indicatorData: RuuviTagCardSnapshotDisplayData?
    ) {
        guard let indicatorData = indicatorData else { return }

        updateHeaderValues(from: indicatorData)

        if currentMeasurementType == .aqi {
            updateAQIContent(from: indicatorData)
        }
    }

    func setChartData(
        _ data: TagChartViewData,
        settings: RuuviLocalSettings
    ) {
        graphView.graphType = data.chartType
        graphView.data = data.chartData
        graphView.lowerAlertValue = data.lowerAlertValue
        graphView.upperAlertValue = data.upperAlertValue
        graphView.setSettings(settings: settings)
        graphView.localize()
        graphView.setYAxisLimit(
            min: data.chartData?.yMin ?? 0,
            max: data.chartData?.yMax ?? 0
        )
        graphView.setXAxisRenderer(showAll: true)

        let hasData = data.chartData?.entryCount ?? 0 > 0
        setNoDataLabelVisibility(show: !hasData)

        let isWithin36Hours = TagChartsHelper.isFirstDataPointWithin36Hours(
            from: data.chartData
        )
        durationLabel.isHidden = !isWithin36Hours

        DispatchQueue.main.async { [weak self] in
            self?.updatePreferredContentSize()
        }
    }

    func updateChartData(
        _ entries: [ChartDataEntry],
        settings: RuuviLocalSettings
    ) {
        let isWithin36Hours = TagChartsHelper.isFirstDataPointWithin36Hours(
            from: entries
        )
        durationLabel.isHidden = !isWithin36Hours

        graphView.updateDataSet(
            with: entries,
            isFirstEntry: entries.count == 1,
            firstEntry: nil,
            showAlertRangeInGraph: false
        )
    }

    func setNoDataLabelVisibility(show: Bool) {
        UIView.animate(withDuration: Animation.fadeTransitionDuration) {
            [weak self] in
            self?.noDataLabel.alpha = show ? Alpha.visible : Alpha.hidden
            self?.durationLabel.alpha = show ? Alpha.hidden : Alpha.visible
            self?.graphView.isHidden = show
        }
    }
}

// MARK: - Update Methods

private extension MeasurementDetailsViewController {
    func updateHeaderValues(
        from indicatorData: RuuviTagCardSnapshotDisplayData
    ) {
        guard let currentIndicator = indicatorData.indicatorGrid?.indicators
            .first(where: { $0.type == currentMeasurementType })
        else { return }

        let processedValue = Self.processIndicatorValue(currentIndicator)
        let processedUnit = Self.processIndicatorUnit(currentIndicator)

        valueLabel.text = processedValue
        unitLabel.text = processedUnit

        if let quality = currentIndicator.qualityState {
            statusView.configure(from: quality)
        }
    }

    func updateAQIContent(
        from indicatorData: RuuviTagCardSnapshotDisplayData
    ) {
        let measurements = indicatorData.indicatorGrid?.indicators
            .filter { $0.type == .co2 || $0.type == .pm25 }

        for measurement in measurements ?? [] {
            if measurement.type == .co2 {
                co2Card?.configure(with: measurement)
            } else if measurement.type == .pm25 {
                pm25Card?.configure(with: measurement)
            }
        }

        updateBeaverAdviceIfNeeded(
            indicatorData: indicatorData,
            measurements: measurements
        )
    }

    func updateBeaverAdviceIfNeeded(
        indicatorData: RuuviTagCardSnapshotDisplayData,
        measurements: [RuuviTagCardSnapshotIndicatorData]?
    ) {
        let aqiQuality = indicatorData.indicatorGrid?.indicators
            .first(where: { $0.type == .aqi })?.qualityState
        let co2Quality = measurements?
            .first(where: { $0.type == .co2 })?.qualityState
        let pm25Quality = measurements?
            .first(where: { $0.type == .pm25 })?.qualityState

        guard let aqiQuality = aqiQuality,
              let lastQuality = lastAQIQualityState,
              !lastQuality.isSameQualityLevel(as: aqiQuality)
        else { return }

        let advice = BeaverAdviceHelper.getBeaverAdvice(
            aqiQuality: aqiQuality,
            co2Quality: co2Quality,
            pm25Quality: pm25Quality
        )
        beaverAdviceView.configure(with: advice)
        lastAQIQualityState = aqiQuality
    }
}

// MARK: - Link Handling

private extension MeasurementDetailsViewController {
    func setupLinkTapGesture() {
        descriptionTapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(handleDescriptionTap(_:))
        )
        descriptionTapGesture.cancelsTouchesInView = false
        descriptionLabel.addGestureRecognizer(descriptionTapGesture)
    }

    @objc func handleDescriptionTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }

        let location = gesture.location(in: descriptionLabel)

        if let tappedLinkURL = getLinkAtLocation(
            location,
            in: descriptionLabel
        ) {
            linkTapHandler?(tappedLinkURL)
        }
    }

    func getLinkAtLocation(
        _ location: CGPoint,
        in label: UILabel
    ) -> String? {
        guard let attributedText = label.attributedText,
              attributedText.length > 0
        else { return nil }

        let textContainer = NSTextContainer(size: label.bounds.size)
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = label.numberOfLines
        textContainer.lineBreakMode = label.lineBreakMode

        let layoutManager = NSLayoutManager()
        let textStorage = NSTextStorage(attributedString: attributedText)

        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        let characterIndex = layoutManager.characterIndex(
            for: location,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )

        if characterIndex < attributedText.length {
            let linkURL = attributedText.attribute(
                .init("CustomLinkURL"),
                at: characterIndex,
                effectiveRange: nil
            ) as? String

            return linkURL
        }

        return nil
    }
}

// MARK: - Content Size Management

private extension MeasurementDetailsViewController {
    func updatePreferredContentSize() {
        view.layoutIfNeeded()
        contentView.layoutIfNeeded()

        let contentHeight = contentView.systemLayoutSizeFitting(
            CGSize(
                width: view.bounds.width,
                height: UIView.layoutFittingCompressedSize.height
            ),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height

        let safeAreaHeight = view.safeAreaInsets.top
        let totalHeight = contentHeight + safeAreaHeight
        let finalHeight = min(totalHeight, maximumSheetHeight)

        if preferredContentSize.height != finalHeight {
            preferredContentSize = CGSize(
                width: view.bounds.width,
                height: finalHeight
            )
            updateSheetPresentationIfNeeded()
        }

        scrollView.isScrollEnabled = true

        if scrollView.bounds.width > 0 && scrollView.bounds.height > 0 {
            if scrollView.edgeFader == nil {
                scrollView.enableEdgeFading()
            } else {
                scrollView.updateEdgeFading()
            }
        }
    }

    func updateSheetPresentationIfNeeded() {
        if let sheetController = presentingViewController?
            .presentedViewController?.sheetPresentationController {
            sheetController
                .invalidateDetents()
        }
    }
}

// MARK: - Factory

extension MeasurementDetailsViewController {
    static func createSheet(
        from indicator: RuuviTagCardSnapshotIndicatorData,
        for snapshot: RuuviTagCardSnapshot,
        maximumSheetHeight: CGFloat
    ) -> MeasurementDetailsViewController {
        let viewController = MeasurementDetailsViewController(
            maximumSheetHeight: maximumSheetHeight,
            measurementType: indicator.type,
            snapshot: snapshot
        )

        let processedValue = processIndicatorValue(indicator)
        let processedUnit = processIndicatorUnit(indicator)
        let attributedDescription = createAttributedDescription(
            for: indicator.type
        )

        viewController.configure(
            measurementType: indicator.type,
            value: processedValue,
            unit: processedUnit,
            quality: indicator.qualityState,
            description: attributedDescription,
            linkHandler: handleLinkTap
        )

        return viewController
    }
}

// MARK: - Processing Helpers

private extension MeasurementDetailsViewController {
    static func processIndicatorValue(
        _ indicator: RuuviTagCardSnapshotIndicatorData
    ) -> String {
        var value = indicator.value

        if indicator.type == .aqi {
            let components = indicator.value.components(separatedBy: "/")
            value = components.first ?? indicator.value
            switch indicator.qualityState {
            case .undefined:
                value = RuuviLocalization.na
            default:
                break
            }
        }

        return value
    }

    static func processIndicatorUnit(
        _ indicator: RuuviTagCardSnapshotIndicatorData
    ) -> String {
        var unit = indicator.unit

        switch indicator.type {
        case .aqi:
            let components = indicator.value.components(separatedBy: "/")
            if let indicatorUnit = components.last {
                unit = "/\(indicatorUnit)"
            } else {
                unit = indicator.unit
            }
        case .voc, .nox, .movementCounter:
            unit = ""
        default:
            break
        }

        return unit
    }

    static func createAttributedDescription(
        for type: MeasurementType
    ) -> NSAttributedString {
        NSAttributedString.fromFormattedDescription(
            type.descriptionText,
            titleFont: UIFont.ruuviBody(),
            paragraphFont: UIFont.ruuviSubheadline(),
            boldFont: UIFont.ruuviSubheadlineBold(),
            titleColor: RuuviColor.dashboardIndicator.color,
            paragraphColor: RuuviColor.dashboardIndicator.color
                .withAlphaComponent(Alpha.descriptionParagraph),
            linkColor: RuuviColor.tintColor.color,
            linkFont: .ruuviCallout()
        )
    }

    static func handleLinkTap(url: String) {
        guard let linkURL = URL(string: url) else { return }

        DispatchQueue.main.async {
            UIApplication.shared.open(linkURL)
        }
    }
}

// swiftlint:enable file_length
