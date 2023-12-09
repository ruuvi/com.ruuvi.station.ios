import UIKit

protocol BackgroundSelectionButtonViewDelegate: NSObjectProtocol {
    func didTapButton(_ sender: BackgroundSelectionButtonView)
}

class BackgroundSelectionButtonView: UIView {
    private weak var delegate: BackgroundSelectionButtonViewDelegate?

    // UI
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.ruuviTextColor
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.Muli(.bold, size: 16)
        return label
    }()

    private lazy var buttonIcon: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        iv.tintColor = RuuviColor.ruuviTintColor
        return iv
    }()

    lazy var seprator = UIView(color: RuuviColor.ruuviLineColor)

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    convenience init(title: String,
                     icon: String,
                     delegate: BackgroundSelectionButtonViewDelegate? = nil)
    {
        self.init()
        titleLabel.text = title
        buttonIcon.image = UIImage(systemName: icon)
        self.delegate = delegate
        setUpUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension BackgroundSelectionButtonView {
    func setUpUI() {
        backgroundColor = .clear

        addSubview(titleLabel)
        titleLabel.anchor(top: topAnchor,
                          leading: safeLeftAnchor,
                          bottom: bottomAnchor,
                          trailing: nil,
                          padding: .init(top: 8,
                                         left: 0,
                                         bottom: 8,
                                         right: 0))

        addSubview(buttonIcon)
        buttonIcon.anchor(top: nil,
                          leading: titleLabel.trailingAnchor,
                          bottom: nil,
                          trailing: safeRightAnchor,
                          padding: .init(top: 0,
                                         left: 8,
                                         bottom: 8,
                                         right: 0),
                          size: .init(width: 24, height: 24))
        buttonIcon.centerYInSuperview()

        addSubview(seprator)
        seprator.anchor(top: nil,
                        leading: leadingAnchor,
                        bottom: bottomAnchor,
                        trailing: trailingAnchor,
                        size: .init(width: 0, height: 1))

        isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }
}

private extension BackgroundSelectionButtonView {
    @objc func handleTap() {
        delegate?.didTapButton(self)
    }
}
