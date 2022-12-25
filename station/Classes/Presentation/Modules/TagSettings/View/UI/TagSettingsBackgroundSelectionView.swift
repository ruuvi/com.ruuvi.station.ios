import UIKit

// swiftlint:disable:next type_name
protocol TagSettingsBackgroundSelectionViewDelegate: NSObjectProtocol {
    func didTapChangeBackground()
}

class TagSettingsBackgroundSelectionView: UIView {

    weak var delegate: TagSettingsBackgroundSelectionViewDelegate?

    private lazy var backgroundView = CardsBackgroundView()
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.Muli(.bold, size: 14)
        label.text = "change_background_image".localized()
        return label
    }()

    private lazy var cameraIconContainer: UIView = {
        let container = UIView(color: RuuviColor.ruuviTintColor,
                               cornerRadius: 30)
        let cameraIconView = UIImageView()
        cameraIconView.image = UIImage(systemName: "camera.fill")
        cameraIconView.tintColor = .white
        cameraIconView.backgroundColor = .clear
        cameraIconView.contentMode = .scaleAspectFit
        container.addSubview(cameraIconView)
        cameraIconView.centerInSuperview(size: .init(width: 32, height: 32))
        return container
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUpUI() {

        addSubview(backgroundView)
        backgroundView.fillSuperview()

        let iconAndLabelContainer = UIView(color: .clear)
        iconAndLabelContainer.addSubview(cameraIconContainer)
        cameraIconContainer.anchor(top: iconAndLabelContainer.topAnchor,
                                   leading: nil,
                                   bottom: nil,
                                   trailing: nil,
                                   size: .init(width: 60, height: 60))
        cameraIconContainer.centerXInSuperview()

        iconAndLabelContainer.addSubview(titleLabel)
        titleLabel.anchor(top: cameraIconContainer.bottomAnchor,
                          leading: iconAndLabelContainer.leadingAnchor,
                          bottom: iconAndLabelContainer.bottomAnchor,
                          trailing: iconAndLabelContainer.trailingAnchor,
                          padding: .init(top: 8, left: 8, bottom: 0, right: 8))

        addSubview(iconAndLabelContainer)
        iconAndLabelContainer.anchor(top: nil,
                     leading: safeLeftAnchor,
                     bottom: nil,
                     trailing: safeRightAnchor,
                     padding: .init(top: 0, left: 8, bottom: 0, right: 8))
        iconAndLabelContainer.centerYInSuperview()

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleViewTap(_:))))
    }

    @objc private func handleViewTap(_ gestureRecognizer: UITapGestureRecognizer) {
        delegate?.didTapChangeBackground()
    }
}

extension TagSettingsBackgroundSelectionView {
    func setBackgroundImage(with image: UIImage?) {
        backgroundView.setBackgroundImage(with: image,
                                          withAnimation: false)
    }
}
