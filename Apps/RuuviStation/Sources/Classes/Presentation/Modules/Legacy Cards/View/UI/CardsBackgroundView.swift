import RuuviLocalization
import UIKit

class CardsBackgroundView: UIView {
    private lazy var cardImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.backgroundColor = .clear
        return iv
    }()

    private lazy var cardImageViewOverlay: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.backgroundColor = .clear
        iv.image = RuuviAsset.tagBgLayer.image
        return iv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate func setUpUI() {
        clipsToBounds = true

        addSubview(cardImageView)
        cardImageView.fillSuperview()

        addSubview(cardImageViewOverlay)
        cardImageViewOverlay.fillSuperview()
    }
}

extension CardsBackgroundView {
    func setBackgroundImage(
        with image: UIImage?,
        isDashboard: Bool = true,
        withAnimation: Bool = true
    ) {
        if isDashboard {
            cardImageViewOverlay.image = RuuviAsset.tagBgLayer.image
        } else {
            cardImageViewOverlay.image = RuuviAsset.bgOverlay.image
        }
        guard image != cardImageView.image else { return }
        if withAnimation {
            UIView.transition(
                with: cardImageView,
                duration: 0.3,
                options: .transitionCrossDissolve,
                animations: { [weak self] in
                    self?.cardImageView.image = image
                },
                completion: nil
            )
        } else {
            cardImageView.image = image
        }
    }

    func backgroundImage() -> UIImage? {
        return cardImageView.image
    }
}
