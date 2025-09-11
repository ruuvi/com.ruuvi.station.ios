import RuuviLocalization
import UIKit

enum SelectionMode {
    case camera
    case gallery
}

protocol BackgroundSelectionViewHeaderDelegate: NSObjectProtocol {
    func didTapSelectionButton(mode: SelectionMode)
}

class BackgroundSelectionViewHeader: UICollectionReusableView {
    weak var delegate: BackgroundSelectionViewHeaderDelegate?

    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.textColor.color
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.ruuviBody()
        label.text = RuuviLocalization.changeBackgroundMessage
        return label
    }()

    lazy var seprator = UIView(color: RuuviColor.lineColor.color)
    lazy var takePhotoButton = BackgroundSelectionButtonView(
        title: RuuviLocalization.takePhoto,
        icon: "camera.fill",
        delegate: self
    )
    lazy var selectFromGalleryButton = BackgroundSelectionButtonView(
        title: RuuviLocalization.selectFromGallery,
        icon: "photo",
        delegate: self
    )

    private lazy var selectFromDefaultLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.textColor.color
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.ruuviButtonMedium()
        label.text = RuuviLocalization.selectDefaultImage
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension BackgroundSelectionViewHeader {
    func setUpUI() {
        backgroundColor = .clear

        addSubview(descriptionLabel)
        descriptionLabel.anchor(
            top: safeTopAnchor,
            leading: safeLeftAnchor,
            bottom: nil,
            trailing: safeRightAnchor,
            padding: .init(
                top: 8,
                left: 4,
                bottom: 0,
                right: 4
            )
        )

        addSubview(seprator)
        seprator.anchor(
            top: descriptionLabel.bottomAnchor,
            leading: descriptionLabel.leadingAnchor,
            bottom: nil,
            trailing: descriptionLabel.trailingAnchor,
            padding: .init(top: 12, left: 0, bottom: 0, right: 0),
            size: .init(width: 0, height: 1)
        )

        addSubview(takePhotoButton)
        takePhotoButton.anchor(
            top: seprator.bottomAnchor,
            leading: seprator.leadingAnchor,
            bottom: nil,
            trailing: seprator.trailingAnchor,
            size: .init(width: 0, height: 44)
        )

        addSubview(selectFromGalleryButton)
        selectFromGalleryButton.anchor(
            top: takePhotoButton.bottomAnchor,
            leading: seprator.leadingAnchor,
            bottom: nil,
            trailing: seprator.trailingAnchor,
            size: .init(width: 0, height: 44)
        )

        addSubview(selectFromDefaultLabel)
        selectFromDefaultLabel.anchor(
            top: selectFromGalleryButton.bottomAnchor,
            leading: seprator.leadingAnchor,
            bottom: safeBottomAnchor,
            trailing: seprator.trailingAnchor,
            size: .init(width: 0, height: 44)
        )
    }
}

extension BackgroundSelectionViewHeader: BackgroundSelectionButtonViewDelegate {
    func didTapButton(_ sender: BackgroundSelectionButtonView) {
        if sender == takePhotoButton {
            delegate?.didTapSelectionButton(mode: .camera)
        } else if sender == selectFromGalleryButton {
            delegate?.didTapSelectionButton(mode: .gallery)
        }
    }
}
