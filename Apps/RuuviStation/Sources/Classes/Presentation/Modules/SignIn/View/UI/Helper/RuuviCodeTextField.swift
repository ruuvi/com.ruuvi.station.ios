import UIKit

class RuuviCodeTextField: UITextField {
    weak var previousEntry: RuuviCodeTextField?
    weak var nextEntry: RuuviCodeTextField?

    private let underlineCursor = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        tintColor = .clear
        textAlignment = .center

        underlineCursor.backgroundColor = .white
        underlineCursor.isHidden = true
        addSubview(underlineCursor)
    }

    override func caretRect(for position: UITextPosition) -> CGRect {
        return .zero
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let underlineWidth: CGFloat = bounds.width / 2
        let underlineHeight: CGFloat = 4
        let x = (bounds.width - underlineWidth) / 2
        let y = bounds.height * 0.70
        underlineCursor.frame = CGRect(
            x: x,
            y: y,
            width: underlineWidth,
            height: underlineHeight
        )

        underlineCursor.isHidden = !isFirstResponder
    }

    override func becomeFirstResponder() -> Bool {
        let did = super.becomeFirstResponder()
        if did {
            underlineCursor.isHidden = false
            startBlinkingAnimation()
        }
        return did
    }

    override func resignFirstResponder() -> Bool {
        let did = super.resignFirstResponder()
        if did {
            stopBlinkingAnimation()
            underlineCursor.isHidden = true
        }
        return did
    }

    override func deleteBackward() {
        text = ""
        previousEntry?.text = ""
        _ = previousEntry?.becomeFirstResponder()
    }

    private func startBlinkingAnimation() {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1
        animation.toValue = 0
        animation.duration = 0.7
        animation.autoreverses = true
        animation.repeatCount = .infinity
        underlineCursor.layer.add(animation, forKey: "blink")
    }

    private func stopBlinkingAnimation() {
        underlineCursor.layer.removeAnimation(forKey: "blink")
    }
}
