import UIKit

protocol RUAlertDetailsCellChildViewDelegate: NSObjectProtocol {
    func didTapView(sender: RUAlertDetailsCellChildView)
}

class RUAlertDetailsCellChildView: UIView {

    // Public
    weak var delegate: RUAlertDetailsCellChildViewDelegate?

    // Private
    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .right
        label.numberOfLines = 0
        label.textColor = .label
        label.font = UIFont.Muli(.regular, size: 14)
        return label
    }()

    private lazy var imageView: UIImageView = {
        let iv = UIImageView()
        iv.backgroundColor = .clear
        iv.image = UIImage(systemName: "pencil")
        iv.tintColor = RuuviColor.ruuviTintColor
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setUpUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setUpUI()
    }
}

extension RUAlertDetailsCellChildView {
    private func setUpUI() {
        self.backgroundColor = .clear

        addSubview(titleLabel)
        titleLabel.anchor(top: topAnchor,
                          leading: leadingAnchor,
                          bottom: bottomAnchor,
                          trailing: nil,
                          padding: .init(top: 8,
                                         left: 14,
                                         bottom: 8,
                                         right: 0))

        addSubview(imageView)
        imageView.anchor(top: nil,
                         leading: titleLabel.trailingAnchor,
                         bottom: nil,
                         trailing: trailingAnchor,
                         padding: .init(top: 0, left: 16, bottom: 0, right: 16),
                         size: .init(width: 20, height: 20))
        imageView.centerYInSuperview()

        isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(handleViewTap))
        addGestureRecognizer(tapGesture)
    }
}

extension RUAlertDetailsCellChildView {
    @objc private func handleViewTap() {
        delegate?.didTapView(sender: self)
    }
}
// MARK: - Public Setter
extension RUAlertDetailsCellChildView {
    func configure(with message: String?) {
        titleLabel.text = message
    }
}
