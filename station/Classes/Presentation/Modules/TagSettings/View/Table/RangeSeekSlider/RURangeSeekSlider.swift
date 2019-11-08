import RangeSeekSlider

class RURangeSeekSlider: RangeSeekSlider {
    override var isEnabled: Bool {
        didSet {
            print("rot")
        }
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return !(gestureRecognizer is UIPanGestureRecognizer)
    }
}
