import UIKit
import RuuviLocalization

class CardsIndicatorDetailsSheetView: UIViewController {

    // MARK: - UI Components
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()

    private lazy var contentView: UIView = {
        let view = UIView()
        view.backgroundColor = RuuviColor.ruuviGreenBackground.color
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var imgView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private lazy var lblTitle: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.Montserrat(.bold, size: 16)
        label.textAlignment = .left
        label.numberOfLines = 1
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var valueLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.Montserrat(.bold, size: 16)
        label.textAlignment = .right
        label.numberOfLines = 1
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var unitLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.Muli(.bold, size: 12)
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
    private var heightConstraint: NSLayoutConstraint?
    private var linkTapHandler: ((String) -> Void)?
    private var linkRanges: [(range: NSRange, url: String)] = []
    private var tapGestureRecognizer: UITapGestureRecognizer!

    // MARK: - Initialization
    static func instantiate() -> CardsIndicatorDetailsSheetView {
        return CardsIndicatorDetailsSheetView()
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

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = RuuviColor.ruuviGreenBackground.color

        // Add scroll view
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        // Setup main content
        contentView.addSubview(headerView)
        contentView.addSubview(lblDescription)

        // Setup header content
        headerView.addSubview(imgView)
        headerView.addSubview(lblTitle)
        headerView.addSubview(valueLabel)
        headerView.addSubview(unitLabel)

        setupConstraints()
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll view constraints
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            // Content view constraints
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            // Header view constraints
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            headerView.heightAnchor.constraint(equalToConstant: 30),

            // Icon constraints
            imgView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            imgView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            imgView.widthAnchor.constraint(equalToConstant: 24),
            imgView.heightAnchor.constraint(equalToConstant: 24),

            // Title constraints
            lblTitle.leadingAnchor.constraint(equalTo: imgView.trailingAnchor, constant: 8),
            lblTitle.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            // Value label constraints
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: lblTitle.trailingAnchor, constant: 8),
            valueLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            unitLabel.leadingAnchor
                .constraint(equalTo: valueLabel.trailingAnchor, constant: 4),
            unitLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            unitLabel.bottomAnchor
                .constraint(equalTo: valueLabel.bottomAnchor, constant: -1),

            // Description constraints
            lblDescription.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 12),
            lblDescription.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            lblDescription.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            lblDescription.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func setupLinkTapGesture() {
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleLabelTap(_:)))
        tapGestureRecognizer.cancelsTouchesInView = false
        lblDescription.addGestureRecognizer(tapGestureRecognizer)
    }

    @objc private func handleLabelTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }

        let location = gesture.location(in: lblDescription)

        // Check if tap is on a link using UILabel-specific method
        if let tappedLinkURL = getLinkAtLocation(location, in: lblDescription) {
            linkTapHandler?(tappedLinkURL)
        }
    }

    private func getLinkAtLocation(_ location: CGPoint, in label: UILabel) -> String? {
        guard let attributedText = label.attributedText,
              attributedText.length > 0 else { return nil }

        // Create text container and layout manager for the label
        let textContainer = NSTextContainer(size: label.bounds.size)
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = label.numberOfLines
        textContainer.lineBreakMode = label.lineBreakMode

        let layoutManager = NSLayoutManager()
        let textStorage = NSTextStorage(attributedString: attributedText)

        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        // Get the character index for the tap location
        let characterIndex = layoutManager.characterIndex(
            for: location,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )

        // Check if this character has a custom link URL
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

    private func updatePreferredContentSize() {
        // Force layout to get accurate measurements
        view.layoutIfNeeded()
        contentView.layoutIfNeeded()

        // Calculate the total content height
        let contentHeight = contentView.systemLayoutSizeFitting(
            CGSize(width: view.bounds.width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height

        // Add safe area insets and some padding
        let safeAreaHeight = view.safeAreaInsets.top + view.safeAreaInsets.bottom
        let totalHeight = contentHeight + safeAreaHeight

        // Limit maximum height to screen height - 100
        let maxHeight = UIScreen.main.bounds.height - 200
        let finalHeight = min(totalHeight, maxHeight)

        if preferredContentSize.height != finalHeight {
            preferredContentSize = CGSize(width: view.bounds.width, height: finalHeight)

            // Notify the presentation controller about the size change
            if #available(iOS 15.0, *) {
                if let sheetController = presentingViewController?.presentedViewController?.sheetPresentationController {
                    if #available(iOS 16.0, *) {
                        sheetController.invalidateDetents()
                    } else {
                        // Fallback on earlier versions
                    }
                }
            } else {
                // Fallback on earlier versions
            }
        }
    }

    // MARK: - Public Configuration Methods
    func configure(
        title: String? = nil,
        value: String? = nil,
        unit: String? = nil,
        description: NSAttributedString? = nil,
        icon: UIImage? = nil,
        linkHandler: ((String) -> Void)? = nil
    ) {
        if let title = title {
            lblTitle.text = title
        }

        if let value = value {
            valueLabel.text = value
        }

        if let unit = unit {
            unitLabel.text = unit
        }

        if let description = description {
            lblDescription.attributedText = description
        }

        if let icon = icon {
            imgView.image = icon.withRenderingMode(.alwaysOriginal)
        }

        self.linkTapHandler = linkHandler

        // Trigger layout update after configuration
        DispatchQueue.main.async { [weak self] in
            self?.updatePreferredContentSize()
        }
    }
}

extension CardsIndicatorDetailsSheetView {
    static func createSheet(
        from indicator: RuuviTagCardSnapshotIndicatorData
    ) -> CardsIndicatorDetailsSheetView {
        let vc = CardsIndicatorDetailsSheetView.instantiate()
        var value = indicator.value
        if indicator.type == .aqi {
            let components = indicator.value.components(
                separatedBy: "/"
            )
            value = components.first ?? indicator.value
        }
        vc.configure(
            title: indicator.type.displayName,
            value: value,
            unit: indicator.unit,
            description: NSAttributedString.fromFormattedDescription(
                indicator.type.descriptionText,
                titleFont: UIFont.Montserrat(.bold, size: 16),
                paragraphFont: UIFont.Muli(.regular, size: 14),
                titleColor: .white,
                paragraphColor: .white.withAlphaComponent(0.8)
            ),
            icon: indicator.type.icon,
            linkHandler: { url in
                guard let linkURL = URL(string: url) else {
                    return
                }
                DispatchQueue.main.async {
                    UIApplication.shared.open(linkURL)
                }
            }
        )
        return vc
    }
}

// MARK: - UIViewController Extension
extension UIViewController {
    func presentDynamicBottomSheet(vc: UIViewController) {
        vc.modalPresentationStyle = .pageSheet

        if #available(iOS 15.0, *) {
            if let sheet = vc.sheetPresentationController {
                if #available(iOS 16.0, *) {
                    sheet.detents = [
                        .custom { context in
                            // Return the preferred content size height
                            return vc.preferredContentSize.height
                        }
                    ]
                    sheet.prefersGrabberVisible = true
                    sheet.preferredCornerRadius = 16
                    sheet.prefersScrollingExpandsWhenScrolledToEdge = false
                    sheet.prefersEdgeAttachedInCompactHeight = true
                } else {
                    // For iOS 15, use medium detent as fallback
                    sheet.detents = [.medium()]
                    sheet.prefersGrabberVisible = true
                }
            }
        }

        self.present(vc, animated: true)
    }

    func presentDynamicBottomSheetWithNav(vc: UIViewController) {
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet

        if #available(iOS 15.0, *) {
            if let sheet = nav.sheetPresentationController {
                if #available(iOS 16.0, *) {
                    sheet.detents = [
                        .custom { context in
                            // Add navigation bar height to preferred content size
                            let navBarHeight = nav.navigationBar.frame.height
                            return vc.preferredContentSize.height + navBarHeight + 20
                        }
                    ]
                    sheet.prefersGrabberVisible = true
                    sheet.preferredCornerRadius = 16
                    sheet.prefersScrollingExpandsWhenScrolledToEdge = false
                    sheet.prefersEdgeAttachedInCompactHeight = true
                } else {
                    sheet.detents = [.medium()]
                    sheet.prefersGrabberVisible = true
                }
            }
        }

        self.present(nav, animated: true)
    }
    
}

extension NSAttributedString {
    static func fromFormattedDescription(
        _ escapedHTML: String,
        titleFont: UIFont,
        paragraphFont: UIFont,
        titleColor: UIColor,
        paragraphColor: UIColor
    ) -> NSAttributedString {
        let unescaped = escapedHTML.replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")

        return processFormattedText(
            unescaped,
            titleFont: titleFont,
            paragraphFont: paragraphFont,
            titleColor: titleColor,
            paragraphColor: paragraphColor
        )
    }

    private static func processFormattedText(
        _ text: String,
        titleFont: UIFont,
        paragraphFont: UIFont,
        titleColor: UIColor,
        paragraphColor: UIColor
    ) -> NSAttributedString {

        let result = NSMutableAttributedString()
        var remainingText = text

        let titlePattern = "<title>(.*?)</title>"
        let linkPattern = "<link url=\"(.*?)\">(.*?)</link>"

        let titleRegex = try! NSRegularExpression(pattern: titlePattern, options: [])
        let linkRegex = try! NSRegularExpression(pattern: linkPattern, options: [])

        while !remainingText.isEmpty {
            let titleMatch = titleRegex.firstMatch(
                in: remainingText,
                range: NSRange(location: 0, length: remainingText.utf16.count)
            )
            let linkMatch = linkRegex.firstMatch(
                in: remainingText,
                range: NSRange(location: 0, length: remainingText.utf16.count)
            )

            var nextMatch: NSTextCheckingResult?
            var isTitle = false

            if let title = titleMatch, let link = linkMatch {
                if title.range.location < link.range.location {
                    nextMatch = title
                    isTitle = true
                } else {
                    nextMatch = link
                    isTitle = false
                }
            } else if let title = titleMatch {
                nextMatch = title
                isTitle = true
            } else if let link = linkMatch {
                nextMatch = link
                isTitle = false
            }

            guard let match = nextMatch else {
                if !remainingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let attr = NSAttributedString(
                        string: remainingText,
                        attributes: [
                            .font: paragraphFont,
                            .foregroundColor: paragraphColor,
                        ]
                    )
                    result.append(attr)
                }
                break
            }

            let matchRange = match.range
            let nsString = remainingText as NSString

            let beforeTagRange = NSRange(location: 0, length: matchRange.location)
            let beforeTagText = nsString.substring(with: beforeTagRange)

            if !beforeTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let attr = NSAttributedString(
                    string: beforeTagText,
                    attributes: [
                        .font: paragraphFont,
                        .foregroundColor: paragraphColor,
                    ]
                )
                result.append(attr)
            }

            if isTitle {
                if let titleRange = Range(match.range(at: 1), in: remainingText) {
                    let titleText = String(remainingText[titleRange])
                    let attr = NSAttributedString(
                        string: titleText,
                        attributes: [
                            .font: titleFont,
                            .foregroundColor: titleColor,
                        ]
                    )
                    result.append(attr)
                }
            } else {
                if let urlRange = Range(match.range(at: 1), in: remainingText),
                   let textRange = Range(match.range(at: 2), in: remainingText) {
                    let url = String(remainingText[urlRange])
                    let linkText = String(remainingText[textRange])

                    var linkAttributes: [NSAttributedString.Key: Any] = [
                        .font: paragraphFont,
                        .foregroundColor: paragraphColor,
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                    ]

                    linkAttributes[.init("CustomLinkURL")] = url

                    let attr = NSAttributedString(
                        string: linkText,
                        attributes: linkAttributes
                    )
                    result.append(attr)
                }
            }

            let matchEnd = matchRange.location + matchRange.length
            remainingText = nsString.substring(from: matchEnd)
        }

        return result
    }
}
