import RuuviLocalization
import UIKit

protocol RUAlertExpandButtonDelegate: NSObjectProtocol {
    func didTapButton(sender: RUAlertExpandButton, expanded: Bool)
}

class RUAlertExpandButton: UIView {
    // Public
    weak var delegate: RUAlertExpandButtonDelegate?

    // Private
    private var isExpanded: Bool = false

    lazy var imageView: UIImageView = {
        let iv = UIImageView()
        iv.backgroundColor = .clear
        iv.image = UIImage(named: "chevron.down")
        iv.tintColor = RuuviColor.tintColor.color
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpUI()
    }
}

extension RUAlertExpandButton {
    private func setUpUI() {
        backgroundColor = .clear
        addSubview(imageView)
        imageView.fillSuperview()

        isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleButtonTap))
        addGestureRecognizer(tapGesture)
    }
}

extension RUAlertExpandButton {
    @objc private func handleButtonTap() {
        if isExpanded {
            isExpanded = false
            UIView.animate(withDuration: 0.3, animations: { [weak self] in
                self?.imageView.transform = .identity
            })
        } else {
            isExpanded = true
            UIView.animate(withDuration: 0.3, animations: { [weak self] in
                self?.imageView.transform = CGAffineTransform(rotationAngle: .pi)
            })
        }

        delegate?.didTapButton(sender: self, expanded: isExpanded)
    }
}

// MARK: - Public Setter

extension RUAlertExpandButton {
    func toggle() {
        handleButtonTap()
    }
}
