import RangeSeekSlider
import UIKit

class RURangeSeekSlider: RangeSeekSlider {
    private let ruuviColor = UIColor(red: 21.0/255.0, green: 141.0/255.0, blue: 165.0/255.0, alpha: 1.0)

    override var isEnabled: Bool {
        didSet {
            if isEnabled {
                handleColor = ruuviColor
                colorBetweenHandles = ruuviColor
            } else {
                handleColor = .darkGray
                colorBetweenHandles = .darkGray
            }
            refresh()
        }
    }

    override var selectedMinValue: CGFloat {
        didSet {
            debugPrint(selectedMinValue)
        }
    }

    override var selectedMaxValue: CGFloat {
        didSet {
            debugPrint(selectedMaxValue)
        }
    }

    override var minValue: CGFloat {
        didSet {
            debugPrint(minValue)
        }
    }

    override var maxValue: CGFloat {
        didSet {
            debugPrint(maxValue)
        }
    }
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return !(gestureRecognizer is UIPanGestureRecognizer)
    }
}
