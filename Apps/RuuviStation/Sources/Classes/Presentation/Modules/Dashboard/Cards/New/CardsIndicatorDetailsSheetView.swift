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
        view.backgroundColor = RuuviColor.dashboardCardBG.color
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
        iv.tintColor = .white
        iv.image = UIImage(systemName: "aqi.medium")?.withRenderingMode(.alwaysTemplate)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private lazy var lblTitle: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
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
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textAlignment = .right
        label.numberOfLines = 1
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .left
        label.numberOfLines = 0
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var lblDescription: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.white.withAlphaComponent(0.8)
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .left
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Properties
    private var heightConstraint: NSLayoutConstraint?

    // MARK: - Initialization
    static func instantiate() -> CardsIndicatorDetailsSheetView {
        return CardsIndicatorDetailsSheetView()
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updatePreferredContentSize()
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = RuuviColor.dashboardCardBG.color

        // Add scroll view
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        // Setup main content
        contentView.addSubview(headerView)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(lblDescription)

        // Setup header content
        headerView.addSubview(imgView)
        headerView.addSubview(lblTitle)
        headerView.addSubview(valueLabel)

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
            imgView.widthAnchor.constraint(equalToConstant: 16),
            imgView.heightAnchor.constraint(equalToConstant: 16),

            // Title constraints
            lblTitle.leadingAnchor.constraint(equalTo: imgView.trailingAnchor, constant: 8),
            lblTitle.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            // Value label constraints
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: lblTitle.trailingAnchor, constant: 8),
            valueLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            // Subtitle constraints
            subtitleLabel.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 16),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            // Description constraints
            lblDescription.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 12),
            lblDescription.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            lblDescription.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            lblDescription.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
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
        subtitle: String? = nil,
        description: String? = nil,
        icon: UIImage? = nil
    ) {
        if let title = title {
            lblTitle.text = title
        }

        if let value = value {
            valueLabel.text = value
        }

        if let subtitle = subtitle {
            subtitleLabel.text = subtitle
        }

        if let description = description {
            lblDescription.text = description
        }

        if let icon = icon {
            imgView.image = icon.withRenderingMode(.alwaysTemplate)
        }

        // Trigger layout update after configuration
        DispatchQueue.main.async { [weak self] in
            self?.updatePreferredContentSize()
        }
    }
}

// MARK: - Usage Example
extension CardsIndicatorDetailsSheetView {
    static func createPM25Sheet() -> CardsIndicatorDetailsSheetView {
        let vc = CardsIndicatorDetailsSheetView.instantiate()
        vc.configure(
            title: "PM2.5",
            value: "11,4 μg/m³",
            subtitle: "About particulate matter",
            // swiftlint:disable:next line_length
            description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
            icon: UIImage(systemName: "aqi.medium")
        )
        return vc
    }
}

// MARK: - Fixed UIViewController Extension
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
