import UIKit

// MARK: - Sheet Configuration
struct SheetConfiguration {
    let maxHeight: CGFloat?
    let prefersGrabberVisible: Bool
    let preferredCornerRadius: CGFloat
    let prefersScrollingExpandsWhenScrolledToEdge: Bool
    let prefersEdgeAttachedInCompactHeight: Bool
    /// Evaluated on every detent resolution; when set it overrides `maxHeight`.
    /// Lets a sheet follow rotation, window resizing and iPhone Duo's display changes while it is
    /// presented (UIKit resolves the detents again whenever the sheet's container changes size).
    var maxHeightProvider: (() -> CGFloat?)?

    static let `default` = SheetConfiguration(
        maxHeight: nil,
        prefersGrabberVisible: true,
        preferredCornerRadius: 16,
        prefersScrollingExpandsWhenScrolledToEdge: false,
        prefersEdgeAttachedInCompactHeight: true
    )
}

extension SheetConfiguration {
    /// The sheet height for `contentHeight`: at most the configured maximum, and never more than the
    /// sheet can be in its current container (window), which UIKit passes in `context`.
    func detentHeight(
        for contentHeight: CGFloat,
        in context: UISheetPresentationControllerDetentResolutionContext
    ) -> CGFloat {
        let maxHeight = maxHeightProvider?() ?? self.maxHeight
        return min(contentHeight, maxHeight ?? .greatestFiniteMagnitude, context.maximumDetentValue)
    }
}

// MARK: - UIViewController Extension
extension UIViewController {

    func presentDynamicBottomSheet(
        vc: UIViewController,
        configuration: SheetConfiguration = .default,
        delegate: UIAdaptivePresentationControllerDelegate? = nil
    ) {
        vc.modalPresentationStyle = .pageSheet
        vc.presentationController?.delegate = delegate
        configureSheetPresentation(for: vc, configuration: configuration)
        present(vc, animated: true)
    }

    func presentDynamicBottomSheetWithNav(
        vc: UIViewController,
        configuration: SheetConfiguration = .default
    ) {
        let navigationController = UINavigationController(rootViewController: vc)
        navigationController.modalPresentationStyle = .pageSheet

        configureSheetPresentationWithNavigation(
            for: navigationController,
            rootVC: vc,
            configuration: configuration
        )

        present(navigationController, animated: true)
    }
}

// MARK: - Private Sheet Configuration
private extension UIViewController {

    func configureSheetPresentation(
        for viewController: UIViewController,
        configuration: SheetConfiguration
    ) {
        guard let sheet = viewController.sheetPresentationController else { return }
        configureModernSheetPresentation(
            sheet: sheet,
            viewController: viewController,
            configuration: configuration
        )
    }

    func configureSheetPresentationWithNavigation(
        for navigationController: UINavigationController,
        rootVC: UIViewController,
        configuration: SheetConfiguration
    ) {
        guard let sheet = navigationController.sheetPresentationController else { return }
        configureModernSheetPresentationWithNavigation(
            sheet: sheet,
            navigationController: navigationController,
            rootVC: rootVC,
            configuration: configuration
        )
    }

    func configureModernSheetPresentation(
        sheet: UISheetPresentationController,
        viewController: UIViewController,
        configuration: SheetConfiguration
    ) {
        sheet.detents = [
            .custom { context in
                let contentHeight = viewController.preferredContentSize.height
                return configuration.detentHeight(for: contentHeight, in: context)
            },
        ]
        sheet.prefersGrabberVisible = configuration.prefersGrabberVisible
        sheet.preferredCornerRadius = configuration.preferredCornerRadius
        sheet.prefersScrollingExpandsWhenScrolledToEdge = configuration.prefersScrollingExpandsWhenScrolledToEdge
        sheet.prefersEdgeAttachedInCompactHeight = configuration.prefersEdgeAttachedInCompactHeight
    }

    func configureModernSheetPresentationWithNavigation(
        sheet: UISheetPresentationController,
        navigationController: UINavigationController,
        rootVC: UIViewController,
        configuration: SheetConfiguration
    ) {
        sheet.detents = [
            .custom { context in
                let navBarHeight = navigationController.navigationBar.frame.height
                let contentHeight = rootVC.preferredContentSize.height + navBarHeight + 20
                return configuration.detentHeight(for: contentHeight, in: context)
            },
        ]
        sheet.prefersGrabberVisible = configuration.prefersGrabberVisible
        sheet.preferredCornerRadius = configuration.preferredCornerRadius
        sheet.prefersScrollingExpandsWhenScrolledToEdge = configuration.prefersScrollingExpandsWhenScrolledToEdge
        sheet.prefersEdgeAttachedInCompactHeight = configuration.prefersEdgeAttachedInCompactHeight
    }
}
