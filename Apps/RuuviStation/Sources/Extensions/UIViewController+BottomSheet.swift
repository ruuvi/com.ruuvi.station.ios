import UIKit

extension UIViewController {

    func presentDynamicBottomSheet(vc: UIViewController) {
        vc.modalPresentationStyle = .pageSheet

        if #available(iOS 15.0, *) {
            configureSheetPresentation(for: vc)
        }

        present(vc, animated: true)
    }

    func presentDynamicBottomSheetWithNav(vc: UIViewController) {
        let navigationController = UINavigationController(rootViewController: vc)
        navigationController.modalPresentationStyle = .pageSheet

        if #available(iOS 15.0, *) {
            configureSheetPresentationWithNavigation(for: navigationController, rootVC: vc)
        }

        present(navigationController, animated: true)
    }
}

// MARK: - Private Sheet Configuration
private extension UIViewController {

    @available(iOS 15.0, *)
    func configureSheetPresentation(for viewController: UIViewController) {
        guard let sheet = viewController.sheetPresentationController else { return }

        if #available(iOS 16.0, *) {
            configureModernSheetPresentation(sheet: sheet, viewController: viewController)
        } else {
            configureLegacySheetPresentation(sheet: sheet)
        }
    }

    @available(iOS 15.0, *)
    func configureSheetPresentationWithNavigation(
        for navigationController: UINavigationController,
        rootVC: UIViewController
    ) {
        guard let sheet = navigationController.sheetPresentationController else { return }

        if #available(iOS 16.0, *) {
            configureModernSheetPresentationWithNavigation(
                sheet: sheet,
                navigationController: navigationController,
                rootVC: rootVC
            )
        } else {
            configureLegacySheetPresentation(sheet: sheet)
        }
    }

    @available(iOS 16.0, *)
    func configureModernSheetPresentation(sheet: UISheetPresentationController, viewController: UIViewController) {
        sheet.detents = [
            .custom { _ in
                return viewController.preferredContentSize.height
            },
        ]
        sheet.prefersGrabberVisible = true
        sheet.preferredCornerRadius = 16
        sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        sheet.prefersEdgeAttachedInCompactHeight = true
    }

    @available(iOS 16.0, *)
    func configureModernSheetPresentationWithNavigation(
        sheet: UISheetPresentationController,
        navigationController: UINavigationController,
        rootVC: UIViewController
    ) {
        sheet.detents = [
            .custom { _ in
                let navBarHeight = navigationController.navigationBar.frame.height
                return rootVC.preferredContentSize.height + navBarHeight + 20
            },
        ]
        sheet.prefersGrabberVisible = true
        sheet.preferredCornerRadius = 16
        sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        sheet.prefersEdgeAttachedInCompactHeight = true
    }

    @available(iOS 15.0, *)
    func configureLegacySheetPresentation(sheet: UISheetPresentationController) {
        sheet.detents = [.medium()]
        sheet.prefersGrabberVisible = true
    }
}
