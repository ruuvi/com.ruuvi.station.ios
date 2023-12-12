import UIKit

class RuuviCustomButton: UIView {
    var image: UIImage? {
        didSet {
            iconView.image = image
        }
    }

    private lazy var iconView: UIImageView = {
        let iv = UIImageView(
            image: nil,
            contentMode: .scaleAspectFit
        )
        return iv
    }()

    private var iconSize: CGSize = .zero

    convenience init(
        icon: UIImage?,
        tintColor: UIColor = .white,
        iconSize: CGSize = .init(width: 20, height: 20)
    ) {
        self.init()
        iconView.image = icon
        iconView.tintColor = tintColor
        self.iconSize = iconSize
        setUpUI()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension RuuviCustomButton {
    private func setUpUI() {
        addSubview(iconView)
        iconView.size(width: iconSize.width, height: iconSize.height)
        iconView.fillSuperview(padding: .init(top: 6, left: 12, bottom: 6, right: 12))
    }
}

extension RuuviCustomButton {
    func setImage(image: UIImage?) {
        iconView.image = image
    }
}
