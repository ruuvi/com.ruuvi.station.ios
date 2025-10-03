import UIKit

// MARK: - Sheet Configuration
struct SheetConfiguration {
    let maxHeight: CGFloat?
    let prefersGrabberVisible: Bool
    let preferredCornerRadius: CGFloat
    let prefersScrollingExpandsWhenScrolledToEdge: Bool
    let prefersEdgeAttachedInCompactHeight: Bool

    static let `default` = SheetConfiguration(
        maxHeight: nil,
        prefersGrabberVisible: true,
        preferredCornerRadius: 16,
        prefersScrollingExpandsWhenScrolledToEdge: false,
        prefersEdgeAttachedInCompactHeight: true
    )
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
            .custom { _ in
                let contentHeight = viewController.preferredContentSize.height

                if let maxHeight = configuration.maxHeight {
                    return min(contentHeight, maxHeight)
                }
                return contentHeight
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
            .custom { _ in
                let navBarHeight = navigationController.navigationBar.frame.height
                let contentHeight = rootVC.preferredContentSize.height + navBarHeight + 20

                if let maxHeight = configuration.maxHeight {
                    return min(contentHeight, maxHeight)
                }
                return contentHeight
            },
        ]
        sheet.prefersGrabberVisible = configuration.prefersGrabberVisible
        sheet.preferredCornerRadius = configuration.preferredCornerRadius
        sheet.prefersScrollingExpandsWhenScrolledToEdge = configuration.prefersScrollingExpandsWhenScrolledToEdge
        sheet.prefersEdgeAttachedInCompactHeight = configuration.prefersEdgeAttachedInCompactHeight
    }
}
