// swiftlint:disable file_length

import UIKit
import RuuviOntology
import RuuviLocalization
import RuuviService

final class CardsMeasurementDetailsView: UIViewController {

    // MARK: - Constants
    private enum Constants {
        static let headerTopMargin: CGFloat = 24
        static let horizontalMargin: CGFloat = 16
        static let headerHeight: CGFloat = 30
        static let iconSize: CGFloat = 24
        static let iconTitleSpacing: CGFloat = 8
        static let valueTitleSpacing: CGFloat = 8
        static let valueUnitSpacing: CGFloat = 4
        static let headerDescriptionSpacing: CGFloat = 12
        static let unitBottomOffset: CGFloat = -1
        static let maxSheetHeight: CGFloat = 200
        static let iPadBottomMargin: CGFloat = -20
    }

    // MARK: - Factories
    private enum UIScrollViewFactory {
        static func create() -> UIScrollView {
            let scrollView = UIScrollView()
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            scrollView.showsVerticalScrollIndicator = false
            return scrollView
        }
    }

    private enum ContentViewFactory {
        static func create() -> UIView {
            let view = UIView()
            view.backgroundColor = .clear
            view.translatesAutoresizingMaskIntoConstraints = false
            return view
        }
    }

    private enum HeaderViewFactory {
        static func create() -> UIView {
            let view = UIView()
            view.backgroundColor = .clear
            view.translatesAutoresizingMaskIntoConstraints = false
            return view
        }
    }

    private enum ImageViewFactory {
        static func create() -> UIImageView {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            return imageView
        }
    }

    private enum TitleLabelFactory {
        static func create() -> UILabel {
            let label = UILabel()
            label.textColor = RuuviColor.dashboardIndicatorBig.color
            label.font = UIFont.Montserrat(.bold, size: 16)
            label.textAlignment = .left
            label.numberOfLines = 1
            label.setContentHuggingPriority(.required, for: .vertical)
            label.setContentCompressionResistancePriority(.required, for: .vertical)
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }
    }

    private enum ValueLabelFactory {
        static func create() -> UILabel {
            let label = UILabel()
            label.textColor = RuuviColor.dashboardIndicatorBig.color
            label.font = UIFont.Montserrat(.bold, size: 16)
            label.textAlignment = .right
            label.numberOfLines = 1
            label.setContentHuggingPriority(.required, for: .vertical)
            label.setContentCompressionResistancePriority(.required, for: .vertical)
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }
    }

    private enum UnitLabelFactory {
        static func create() -> UILabel {
            let label = UILabel()
            label.textColor = RuuviColor.dashboardIndicatorBig.color
            label.font = UIFont.Muli(.bold, size: 12)
            label.textAlignment = .right
            label.numberOfLines = 1
            label.setContentHuggingPriority(.required, for: .vertical)
            label.setContentCompressionResistancePriority(.required, for: .vertical)
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }
    }

    private enum DescriptionLabelFactory {
        static func create() -> UILabel {
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
        }
    }

    // MARK: - UI Components
    private lazy var scrollView = UIScrollViewFactory.create()
    private lazy var contentView = ContentViewFactory.create()
    private lazy var headerView = HeaderViewFactory.create()
    private lazy var imgView = ImageViewFactory.create()
    private lazy var lblTitle = TitleLabelFactory.create()
    private lazy var valueLabel = ValueLabelFactory.create()
    private lazy var unitLabel = UnitLabelFactory.create()
    private lazy var lblDescription = DescriptionLabelFactory.create()

    // MARK: - Properties
    private var linkTapHandler: ((String) -> Void)?
    private var tapGestureRecognizer: UITapGestureRecognizer!

    // MARK: - Initialization
    static func instantiate() -> CardsMeasurementDetailsView {
        return CardsMeasurementDetailsView()
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupLinkTapGesture()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updatePreferredContentSize()
    }

    // MARK: - Public Configuration
    func configure(
        title: String? = nil,
        value: String? = nil,
        unit: String? = nil,
        description: NSAttributedString? = nil,
        icon: UIImage? = nil,
        linkHandler: ((String) -> Void)? = nil
    ) {
        configureContent(
            title: title,
            value: value,
            unit: unit,
            description: description,
            icon: icon
        )

        self.linkTapHandler = linkHandler

        DispatchQueue.main.async { [weak self] in
            self?.updatePreferredContentSize()
        }
    }
}

// MARK: - Private Setup Methods
private extension CardsMeasurementDetailsView {

    func setupUI() {
        view.backgroundColor = RuuviColor.dashboardCardBG.color
        addSubviews()
        setupConstraints()
    }

    func addSubviews() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(headerView)
        contentView.addSubview(lblDescription)

        headerView.addSubview(imgView)
        headerView.addSubview(lblTitle)
        headerView.addSubview(valueLabel)
        headerView.addSubview(unitLabel)
    }

    // swiftlint:disable:next function_body_length
    func setupConstraints() {
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
                        constant: Constants.headerTopMargin
                    ),
                headerView.leadingAnchor
                    .constraint(
                        equalTo: contentView.leadingAnchor,
                        constant: Constants.horizontalMargin
                    ),
                headerView.trailingAnchor
                    .constraint(
                        equalTo: contentView.trailingAnchor,
                        constant: -Constants.horizontalMargin
                    ),
                headerView.heightAnchor
                    .constraint(
                        equalToConstant: Constants.headerHeight
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
                        equalToConstant: Constants.iconSize
                    ),
                imgView.heightAnchor
                    .constraint(
                        equalToConstant: Constants.iconSize
                    ),

                // Title
                lblTitle.leadingAnchor
                    .constraint(
                        equalTo: imgView.trailingAnchor,
                        constant: Constants.iconTitleSpacing
                    ),
                lblTitle.centerYAnchor
                    .constraint(
                        equalTo: headerView.centerYAnchor
                    ),

                // Value and unit
                valueLabel.leadingAnchor
                    .constraint(
                        greaterThanOrEqualTo: lblTitle.trailingAnchor,
                        constant: Constants.valueTitleSpacing
                    ),
                valueLabel.centerYAnchor
                    .constraint(
                        equalTo: headerView.centerYAnchor
                    ),
                unitLabel.leadingAnchor
                    .constraint(
                        equalTo: valueLabel.trailingAnchor,
                        constant: Constants.valueUnitSpacing
                    ),
                unitLabel.trailingAnchor
                    .constraint(
                        equalTo: headerView.trailingAnchor
                    ),
                unitLabel.bottomAnchor
                    .constraint(
                        equalTo: valueLabel.bottomAnchor,
                        constant: Constants.unitBottomOffset
                    ),

                // Description
                lblDescription.topAnchor
                    .constraint(
                        equalTo: headerView.bottomAnchor,
                        constant: Constants.headerDescriptionSpacing
                    ),
                lblDescription.leadingAnchor
                    .constraint(
                        equalTo: contentView.leadingAnchor,
                        constant: Constants.horizontalMargin
                    ),
                lblDescription.trailingAnchor
                    .constraint(
                        equalTo: contentView.trailingAnchor,
                        constant: -Constants.horizontalMargin
                    ),
                lblDescription.bottomAnchor
                    .constraint(
                        equalTo: contentView.bottomAnchor,
                        constant: UIDevice.current.userInterfaceIdiom == .pad ? Constants.iPadBottomMargin : 0
                    ),
            ]
        )
    }

    func configureContent(
        title: String?,
        value: String?,
        unit: String?,
        description: NSAttributedString?,
        icon: UIImage?
    ) {
        lblTitle.text = title
        valueLabel.text = value
        unitLabel.text = unit
        lblDescription.attributedText = description

        if let icon = icon {
            imgView.image = icon.withRenderingMode(.alwaysOriginal)
        }
    }
}

// MARK: - Link Handling
private extension CardsMeasurementDetailsView {

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
private extension CardsMeasurementDetailsView {

    func updatePreferredContentSize() {
        view.layoutIfNeeded()
        contentView.layoutIfNeeded()

        let contentHeight = contentView.systemLayoutSizeFitting(
            CGSize(width: view.bounds.width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height

        let safeAreaHeight = view.safeAreaInsets.top + view.safeAreaInsets.bottom
        let totalHeight = contentHeight + safeAreaHeight
        let maxHeight = UIScreen.main.bounds.height - Constants.maxSheetHeight
        let finalHeight = min(totalHeight, maxHeight)

        if preferredContentSize.height != finalHeight {
            preferredContentSize = CGSize(width: view.bounds.width, height: finalHeight)
            updateSheetPresentationIfNeeded()
        }
    }

    func updateSheetPresentationIfNeeded() {
        if #available(iOS 15.0, *) {
            if let sheetController = presentingViewController?.presentedViewController?.sheetPresentationController {
                if #available(iOS 16.0, *) {
                    sheetController.invalidateDetents()
                }
            }
        }
    }
}

extension CardsMeasurementDetailsView {

    static func createSheet(
        from indicator: RuuviTagCardSnapshotIndicatorData
    ) -> CardsMeasurementDetailsView {
        let viewController = CardsMeasurementDetailsView.instantiate()

        let processedUnit = processIndicatorUnit(indicator)
        let attributedDescription = createAttributedDescription(for: indicator.type)

        viewController.configure(
            title: indicator.type.displayName,
            value: indicator.value,
            unit: processedUnit,
            description: attributedDescription,
            icon: indicator.type.icon,
            linkHandler: handleLinkTap
        )

        return viewController
    }
}

// MARK: - Private Factory Methods
private extension CardsMeasurementDetailsView {

    static func processIndicatorUnit(_ indicator: RuuviTagCardSnapshotIndicatorData) -> String {
        var unit = indicator.unit

        // Some units gets special treatment because they are formatted on
        // Snapshot Builder with name of the measurements for showing on Dashboard.
        // However, this screen shows the title already and
        // does not need the title as part of unit.
        if indicator.type == .aqi {
            unit = ""
        }

        if indicator.type == .pm25 {
            unit = RuuviLocalization.unitPm25
        }

        if indicator.type == .pm10 {
            unit = RuuviLocalization.unitPm10
        }

        if indicator.type == .soundInstant {
            unit = RuuviLocalization.unitSound
        }

        return unit
    }

    static func createAttributedDescription(for type: MeasurementType) -> NSAttributedString {
        return NSAttributedString.fromFormattedDescription(
            type.descriptionText,
            titleFont: UIFont.Montserrat(.bold, size: 16),
            paragraphFont: UIFont.Muli(.regular, size: 14),
            titleColor: RuuviColor.dashboardIndicator.color,
            paragraphColor: RuuviColor.dashboardIndicator.color.withAlphaComponent(0.8)
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
