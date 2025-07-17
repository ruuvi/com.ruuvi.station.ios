//import UIKit
//
//extension UIViewController {
//    func presentDynamicBottomSheet(vc: UIViewController) {
//        let nav = UINavigationController(rootViewController: vc)
//        nav.modalPresentationStyle = .pageSheet
//        if #available(iOS 15.0, *) {
//            if let sheet = nav.sheetPresentationController {
//                if #available(iOS 16.0, *) {
//                    sheet.detents = [
//                        .custom { _ in
//                            return vc.preferredContentSize.height
//                        }
//                    ]
//                    sheet.prefersGrabberVisible = true
//                    sheet.preferredCornerRadius = 16
//                } else {
//                    sheet.detents = [.medium(), .large()]
//                }
//            }
//        } else {
//            self.present(nav, animated: true)
//        }
//        self.present(nav, animated: true)
//    }
//}
