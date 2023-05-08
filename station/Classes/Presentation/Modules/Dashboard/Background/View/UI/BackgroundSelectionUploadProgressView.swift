import UIKit

// swiftlint:disable:next type_name
protocol BackgroundSelectionUploadProgressViewDelegate: NSObjectProtocol {
    func didTapCancel()
}

class BackgroundSelectionUploadProgressView: UIView {

    weak var delegate: BackgroundSelectionUploadProgressViewDelegate?

    lazy var progressLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.Muli(.bold, size: 14)
        return label
    }()

    private lazy var cancelButton: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        iv.tintColor = RuuviColor.ruuviTintColor
        iv.isUserInteractionEnabled = true
        iv.image = UIImage(systemName: "xmark.circle.fill")
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleCancelTap))
        iv.addGestureRecognizer(tap)
        return iv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension BackgroundSelectionUploadProgressView {
    fileprivate func setUpUI() {
        backgroundColor = RuuviColor.ruuviGraphBGColor
        layer.cornerRadius = 4
        clipsToBounds = true

        addSubview(progressLabel)
        progressLabel.anchor(top: topAnchor,
                          leading: safeLeftAnchor,
                          bottom: bottomAnchor,
                          trailing: nil,
                          padding: .init(top: 8,
                                         left: 8,
                                         bottom: 8,
                                         right: 0))

        addSubview(cancelButton)
        cancelButton.anchor(top: nil,
                          leading: progressLabel.trailingAnchor,
                          bottom: nil,
                          trailing: safeRightAnchor,
                          padding: .init(top: 0,
                                         left: 24,
                                         bottom: 8,
                                         right: 8),
                          size: .init(width: 24, height: 24))
        cancelButton.centerYInSuperview()
    }
}

extension BackgroundSelectionUploadProgressView {
    @objc private func handleCancelTap() {
        delegate?.didTapCancel()
    }
}
