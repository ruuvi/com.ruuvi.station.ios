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

        if #available(iOS 15.0, *) {
            configureSheetPresentation(for: vc, configuration: configuration)
        }

        vc.presentationController?.delegate = delegate
        present(vc, animated: true)
    }

    func presentDynamicBottomSheetWithNav(
        vc: UIViewController,
        configuration: SheetConfiguration = .default
    ) {
        let navigationController = UINavigationController(rootViewController: vc)
        navigationController.modalPresentationStyle = .pageSheet

        if #available(iOS 15.0, *) {
            configureSheetPresentationWithNavigation(
                for: navigationController,
                rootVC: vc,
                configuration: configuration
            )
        }

        present(navigationController, animated: true)
    }
}

// MARK: - Private Sheet Configuration
private extension UIViewController {

    @available(iOS 15.0, *)
    func configureSheetPresentation(
        for viewController: UIViewController,
        configuration: SheetConfiguration
    ) {
        guard let sheet = viewController.sheetPresentationController else { return }

        if #available(iOS 16.0, *) {
            configureModernSheetPresentation(
                sheet: sheet,
                viewController: viewController,
                configuration: configuration
            )
        } else {
            configureLegacySheetPresentation(
                sheet: sheet,
                configuration: configuration
            )
        }
    }

    @available(iOS 15.0, *)
    func configureSheetPresentationWithNavigation(
        for navigationController: UINavigationController,
        rootVC: UIViewController,
        configuration: SheetConfiguration
    ) {
        guard let sheet = navigationController.sheetPresentationController else { return }

        if #available(iOS 16.0, *) {
            configureModernSheetPresentationWithNavigation(
                sheet: sheet,
                navigationController: navigationController,
                rootVC: rootVC,
                configuration: configuration
            )
        } else {
            configureLegacySheetPresentation(
                sheet: sheet,
                configuration: configuration
            )
        }
    }

    @available(iOS 16.0, *)
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

    @available(iOS 16.0, *)
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

    @available(iOS 15.0, *)
    func configureLegacySheetPresentation(
        sheet: UISheetPresentationController,
        configuration: SheetConfiguration
    ) {
        sheet.detents = [.medium()]
        sheet.prefersGrabberVisible = configuration.prefersGrabberVisible
    }
}
