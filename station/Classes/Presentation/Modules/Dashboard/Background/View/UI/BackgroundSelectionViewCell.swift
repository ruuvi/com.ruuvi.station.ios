import UIKit

class BackgroundSelectionViewCell: UICollectionViewCell {

    private lazy var imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.backgroundColor = .clear
        iv.clipsToBounds = true
        return iv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
    }

    fileprivate func setUpUI() {
        contentView.addSubview(imageView)
        imageView.fillSuperview()
    }
}

extension BackgroundSelectionViewCell {
    func configure(with model: DefaultBackgroundModel?) {
        imageView.image = model?.thumbnail
    }
}
