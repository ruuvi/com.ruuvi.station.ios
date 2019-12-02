import UIKit

class HumidityCalibrationTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {

    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return HumidityCalibrationPresentationController(presentedViewController: presented, presenting: presenting)
    }

}
