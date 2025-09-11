// swiftlint:disable file_length

import UIKit
import RuuviOntology
import RuuviLocalization
import RuuviService
import DGCharts
import RuuviLocal

final class MeasurementDetailsViewController: UIViewController {

    // MARK: - Constants
    private enum Constants {
        enum Layout {
            static let graphTopMargin: CGFloat = 8
            static let graphHeight: CGFloat = 200
            static let headerTopMargin: CGFloat = 24
            static let horizontalMargin: CGFloat = 16
            static let headerHeight: CGFloat = 30
            static let iconSize: CGFloat = 24
            static let iconTitleSpacing: CGFloat = 8
            static let valueTitleSpacing: CGFloat = 8
            static let valueUnitSpacing: CGFloat = 4
            static let headerDescriptionSpacing: CGFloat = 12
            static let unitBottomOffset: CGFloat = -1
            static let bottomMargin: CGFloat = -20
            static let graphBottomPadding: CGFloat = 16
            static let dataDurationLabelRightPadding: CGFloat = 8
        }

        enum Animation {
            static let fadeTransitionDuration: Double = 0.3
        }

        enum Alpha {
            static let durationLabelAlpha: CGFloat = 0.5
            static let descriptionParagraphAlpha: CGFloat = 0.8
            static let hiddenAlpha: CGFloat = 0
            static let visibleAlpha: CGFloat = 1
        }
    }

    // MARK: - Internal
    weak var output: MeasurementDetailsViewOutput?

    // MARK: - UI Components
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
                bottom: Constants.Layout.graphBottomPadding,
                right: 0
            )
        )

        view.addSubview(graphViewOverlay)
        graphViewOverlay.fillSuperview()

        view.addSubview(noGraphDataLabel)
        noGraphDataLabel.match(view: graphView)

        view.addSubview(dataDurationLabel)
        dataDurationLabel
            .anchor(
                top: nil,
                leading: nil,
                bottom: view.bottomAnchor,
                trailing: view.trailingAnchor,
                padding: .init(
                    top: 0,
                    left: 0,
                    bottom: 0,
                    right: Constants.Layout.dataDurationLabelRightPadding
                )
            )
        return view
    }()

    private lazy var graphView: TagChartsViewInternal = {
        let view = TagChartsViewInternal(source: .mesurementDetails)
        view.isUserInteractionEnabled = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var graphViewOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(handleGraphTap))
        )
        return view
    }()

    private lazy var noGraphDataLabel: UILabel = {
        let label = UILabel()
        label.text = RuuviLocalization.emptyChartMessage
        label.textColor = RuuviColor.dashboardIndicator.color
        label.textAlignment = .center
        label.numberOfLines = 1
        label.font = UIFont.ruuviCallout()
        return label
    }()

    private lazy var dataDurationLabel: UILabel = {
        let label = UILabel()
        label.text = RuuviLocalization.day2
        label.textColor = RuuviColor.dashboardIndicator.color
            .withAlphaComponent(Constants.Alpha.durationLabelAlpha)
        label.textAlignment = .right
        label.numberOfLines = 0
        label.font = UIFont.ruuviCaption2()
        return label
    }()

    private lazy var headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var imgView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private lazy var lblTitle: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicatorBig.color
        label.font = UIFont.ruuviCallout()
        label.textAlignment = .left
        label.numberOfLines = 2
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
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
        label.setContentCompressionResistancePriority(.required, for: .vertical)
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
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var lblDescription: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicator.color
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .left
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = true
        return label
    }()

    // MARK: - Properties
    private var maximumSheetHeight: CGFloat
    private var shouldHideGraph = false
    private var linkTapHandler: ((String) -> Void)?
    private var tapGestureRecognizer: UITapGestureRecognizer!
    private var graphViewHeightConstraint: NSLayoutConstraint!

    // MARK: - Initialization
    init(maximumSheetHeight: CGFloat) {
        self.maximumSheetHeight = maximumSheetHeight
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func instantiate(maximumSheetHeight: CGFloat) -> MeasurementDetailsViewController {
        return MeasurementDetailsViewController(maximumSheetHeight: maximumSheetHeight)
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        applyGraphVisibility()
        setupLinkTapGesture()
        output?.viewDidLoad()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updatePreferredContentSize()
    }

    // MARK: - Public Configuration
    func configure(
        indicatorType: MeasurementType,
        value: String? = nil,
        unit: String? = nil,
        description: NSAttributedString? = nil,
        linkHandler: ((String) -> Void)? = nil
    ) {
        configureContent(
            indicatorType: indicatorType,
            value: value,
            unit: unit,
            description: description
        )

        self.linkTapHandler = linkHandler

        DispatchQueue.main.async { [weak self] in
            self?.updatePreferredContentSize()
        }
    }
}

// MARK: - Private Setup Methods
private extension MeasurementDetailsViewController {

    func setupUI() {
        view.backgroundColor = RuuviColor.dashboardCardBG.color
        addSubviews()
        setupConstraints()
    }

    func addSubviews() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(graphContainerView)
        noGraphDataLabel.alpha = Constants.Alpha.hiddenAlpha

        contentView.addSubview(headerView)
        contentView.addSubview(lblDescription)

        headerView.addSubview(imgView)
        headerView.addSubview(lblTitle)
        headerView.addSubview(valueLabel)
        headerView.addSubview(unitLabel)
    }

    // swiftlint:disable:next function_body_length
    func setupConstraints() {
        graphViewHeightConstraint = graphContainerView.heightAnchor
            .constraint(
                equalToConstant: Constants.Layout.graphHeight
            )

        NSLayoutConstraint.activate(
            [
                // Scroll view
                scrollView.topAnchor
                    .constraint(
                        equalTo: view.safeAreaLayoutGuide.topAnchor
                    ),
                scrollView.leadingAnchor
                    .constraint(
                        equalTo: view.leadingAnchor
                    ),
                scrollView.trailingAnchor
                    .constraint(
                        equalTo: view.trailingAnchor
                    ),
                scrollView.bottomAnchor
                    .constraint(
                        equalTo: view.safeAreaLayoutGuide.bottomAnchor
                    ),

                // Content view
                contentView.topAnchor
                    .constraint(
                        equalTo: scrollView.topAnchor
                    ),
                contentView.leadingAnchor
                    .constraint(
                        equalTo: scrollView.leadingAnchor
                    ),
                contentView.trailingAnchor
                    .constraint(
                        equalTo: scrollView.trailingAnchor
                    ),
                contentView.bottomAnchor
                    .constraint(
                        equalTo: scrollView.bottomAnchor
                    ),
                contentView.widthAnchor
                    .constraint(
                        equalTo: scrollView.widthAnchor
                    ),

                // Header view
                headerView.topAnchor
                    .constraint(
                        equalTo: contentView.topAnchor,
                        constant: Constants.Layout.headerTopMargin
                    ),
                headerView.leadingAnchor
                    .constraint(
                        equalTo: contentView.leadingAnchor,
                        constant: Constants.Layout.horizontalMargin
                    ),
                headerView.trailingAnchor
                    .constraint(
                        equalTo: contentView.trailingAnchor,
                        constant: -Constants.Layout.horizontalMargin
                    ),
                headerView.heightAnchor
                    .constraint(
                        equalToConstant: Constants.Layout.headerHeight
                    ),

                // Icon
                imgView.leadingAnchor
                    .constraint(
                        equalTo: headerView.leadingAnchor
                    ),
                imgView.centerYAnchor
                    .constraint(
                        equalTo: headerView.centerYAnchor
                    ),
                imgView.widthAnchor
                    .constraint(
                        equalToConstant: Constants.Layout.iconSize
                    ),
                imgView.heightAnchor
                    .constraint(
                        equalToConstant: Constants.Layout.iconSize
                    ),

                // Title
                lblTitle.leadingAnchor
                    .constraint(
                        equalTo: imgView.trailingAnchor,
                        constant: Constants.Layout.iconTitleSpacing
                    ),
                lblTitle.centerYAnchor
                    .constraint(
                        equalTo: headerView.centerYAnchor
                    ),

                // Value and unit
                valueLabel.leadingAnchor
                    .constraint(
                        greaterThanOrEqualTo: lblTitle.trailingAnchor,
                        constant: Constants.Layout.valueTitleSpacing
                    ),
                valueLabel.centerYAnchor
                    .constraint(
                        equalTo: headerView.centerYAnchor
                    ),
                unitLabel.leadingAnchor
                    .constraint(
                        equalTo: valueLabel.trailingAnchor,
                        constant: Constants.Layout.valueUnitSpacing
                    ),
                unitLabel.trailingAnchor
                    .constraint(
                        equalTo: headerView.trailingAnchor
                    ),
                unitLabel.bottomAnchor
                    .constraint(
                        equalTo: valueLabel.bottomAnchor,
                        constant: Constants.Layout.unitBottomOffset
                    ),

                // Graph view
                graphContainerView.topAnchor
                    .constraint(
                        equalTo: headerView.bottomAnchor,
                        constant: Constants.Layout.graphTopMargin
                    ),
                graphContainerView.leadingAnchor
                    .constraint(
                        equalTo: contentView.leadingAnchor
                    ),
                graphContainerView.trailingAnchor
                    .constraint(
                        equalTo: contentView.trailingAnchor
                    ),
                graphViewHeightConstraint,
                // Description
                lblDescription.topAnchor
                    .constraint(
                        equalTo: graphContainerView.bottomAnchor,
                        constant: Constants.Layout.headerDescriptionSpacing
                    ),
                lblDescription.leadingAnchor
                    .constraint(
                        equalTo: contentView.leadingAnchor,
                        constant: Constants.Layout.horizontalMargin
                    ),
                lblDescription.trailingAnchor
                    .constraint(
                        equalTo: contentView.trailingAnchor,
                        constant: -Constants.Layout.horizontalMargin
                    ),
                lblDescription.bottomAnchor
                    .constraint(
                        equalTo: contentView.bottomAnchor,
                        constant: Constants.Layout.bottomMargin
                    ),
            ]
        )
    }

    func configureContent(
        indicatorType: MeasurementType,
        value: String?,
        unit: String?,
        description: NSAttributedString?
    ) {
        lblTitle.text = indicatorType.fullName
        valueLabel.text = value
        unitLabel.text = unit
        lblDescription.attributedText = description

        imgView.image = indicatorType.icon.withRenderingMode(.alwaysOriginal)

        shouldHideGraph = (indicatorType == .movementCounter)

        if isViewLoaded {
            applyGraphVisibility()
        }
    }

    private func applyGraphVisibility() {
        if shouldHideGraph {
            graphViewHeightConstraint.constant = 0
            graphContainerView.isHidden = true
        } else {
            graphViewHeightConstraint.constant = Constants.Layout.graphHeight
            graphContainerView.isHidden = false
        }
    }

    @objc func handleGraphTap() {
        output?.didTapGraph()
    }
}

// MARK: - MeasurementDetailsViewInput

extension MeasurementDetailsViewController: MeasurementDetailsViewInput {

    func setChartData(_ data: TagChartViewData, settings: RuuviLocalSettings) {
        graphView.data = data.chartData
        graphView.lowerAlertValue = data.lowerAlertValue
        graphView.upperAlertValue = data.upperAlertValue
        graphView.setSettings(settings: settings)
        graphView.localize()
        graphView.setYAxisLimit(min: data.chartData?.yMin ?? 0, max: data.chartData?.yMax ?? 0)
        graphView.setXAxisRenderer()

        let hasData = data.chartData?.entryCount ?? 0 > 0
        setNoDataLabelVisibility(show: !hasData)

        // Force layout update for sheet height
        DispatchQueue.main.async { [weak self] in
            self?.updatePreferredContentSize()
        }
    }

    func updateChartData(_ entries: [ChartDataEntry], settings: RuuviLocalSettings) {
        graphView.updateDataSet(
            with: entries,
            isFirstEntry: entries.count == 1,
            firstEntry: nil,
            showAlertRangeInGraph: false
        )
    }

    func setNoDataLabelVisibility(show: Bool) {
        UIView
            .animate(
                withDuration: Constants.Animation.fadeTransitionDuration
            ) { [weak self] in
            self?.noGraphDataLabel.alpha = show ?
                Constants.Alpha.visibleAlpha : Constants.Alpha.hiddenAlpha
            self?.graphView.isHidden = show
        }
    }
}

// MARK: - Link Handling
private extension MeasurementDetailsViewController {

    func setupLinkTapGesture() {
        tapGestureRecognizer = UITapGestureRecognizer(
            target: self, action: #selector(handleLabelTap(_:))
        )
        tapGestureRecognizer.cancelsTouchesInView = false
        lblDescription.addGestureRecognizer(tapGestureRecognizer)
    }

    @objc func handleLabelTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }

        let location = gesture.location(in: lblDescription)

        if let tappedLinkURL = getLinkAtLocation(location, in: lblDescription) {
            linkTapHandler?(tappedLinkURL)
        }
    }

    func getLinkAtLocation(_ location: CGPoint, in label: UILabel) -> String? {
        guard let attributedText = label.attributedText,
              attributedText.length > 0 else {
            return nil
        }

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

    private func updatePreferredContentSize() {
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
            preferredContentSize = CGSize(width: view.bounds.width, height: finalHeight)
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
        if #available(iOS 15.0, *) {
            if let sheetController = presentingViewController?.presentedViewController?.sheetPresentationController {
                if #available(
                    iOS 16.0,
                    *
                ) {
                    sheetController.invalidateDetents()
                }
            }
        }
    }
}

extension MeasurementDetailsViewController {

    static func createSheet(
        from indicator: RuuviTagCardSnapshotIndicatorData,
        maximumSheetHeight: CGFloat
    ) -> MeasurementDetailsViewController {
        let viewController = MeasurementDetailsViewController.instantiate(
            maximumSheetHeight: maximumSheetHeight
        )

        let processedValue = processIndicatorValue(
            indicator
        )
        let processedUnit = processIndicatorUnit(indicator)
        let attributedDescription = createAttributedDescription(for: indicator.type)

        viewController.configure(
            indicatorType: indicator.type,
            value: processedValue,
            unit: processedUnit,
            description: attributedDescription,
            linkHandler: handleLinkTap
        )

        return viewController
    }
}

// MARK: - Private Factory Methods
private extension MeasurementDetailsViewController {

    static func processIndicatorValue(
        _ indicator: RuuviTagCardSnapshotIndicatorData
    ) -> String {
        var value = indicator.value

        if indicator.type == .aqi {
            let components = indicator.value.components(separatedBy: "/")
            value = components.first ?? indicator.value
        }

        return value
    }

    static func processIndicatorUnit(
        _ indicator: RuuviTagCardSnapshotIndicatorData
    ) -> String {
        var unit = indicator.unit

        // Some units gets special treatment because some don't need units
        // and some requires formatting.
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

    static func createAttributedDescription(for type: MeasurementType) -> NSAttributedString {
        return NSAttributedString.fromFormattedDescription(
            type.descriptionText,
            titleFont: UIFont.ruuviBody(),
            paragraphFont: UIFont.ruuviSubheadline(),
            titleColor: RuuviColor.dashboardIndicator.color,
            paragraphColor: RuuviColor.dashboardIndicator.color
                .withAlphaComponent(
                    Constants.Alpha.descriptionParagraphAlpha
                ),
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
