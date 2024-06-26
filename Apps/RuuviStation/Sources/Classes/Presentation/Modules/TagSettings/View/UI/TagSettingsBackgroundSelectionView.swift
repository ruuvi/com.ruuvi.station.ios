import RuuviLocalization
import UIKit

// swiftlint:disable:next type_name
protocol TagSettingsBackgroundSelectionViewDelegate: NSObjectProtocol {
    func didTapChangeBackground()
}

class TagSettingsBackgroundSelectionView: UIView {
    weak var delegate: TagSettingsBackgroundSelectionViewDelegate?

    private lazy var backgroundView = CardsBackgroundView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUpUI() {
        addSubview(backgroundView)
        backgroundView.fillSuperview()
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleViewTap(_:))))
    }

    @objc private func handleViewTap(_: UITapGestureRecognizer) {
        delegate?.didTapChangeBackground()
    }
}

extension TagSettingsBackgroundSelectionView {
    func setBackgroundImage(with image: UIImage?) {
        backgroundView.setBackgroundImage(
            with: image,
            withAnimation: false
        )
    }
}
