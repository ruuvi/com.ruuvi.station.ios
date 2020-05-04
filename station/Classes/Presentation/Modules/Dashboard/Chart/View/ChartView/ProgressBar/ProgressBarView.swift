import UIKit

class ProgressBarView: UIProgressView {
    private(set) lazy var progressLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 1
        return label
    }()

    public var hideOnComplete: Bool = true
    
    private var inProgress: Bool {
        return !(progress == 0.0 || progress == 1.0)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubviews()
        makeConstraints()
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func addSubviews() {
        addSubview(progressLabel)
    }

    private func makeConstraints() {
        addConstraint(NSLayoutConstraint(item: progressLabel,
                                         attribute: .centerX,
                                         relatedBy: .equal,
                                         toItem: self,
                                         attribute: .centerX,
                                         multiplier: 1.0,
                                         constant: 0.0))
        addConstraint(NSLayoutConstraint(item: progressLabel,
                                         attribute: .centerY,
                                         relatedBy: .equal,
                                         toItem: self,
                                         attribute: .centerY,
                                         multiplier: 1.0,
                                         constant: 0.0))
    }

    private func configure() {
        isHidden = !inProgress
        progressViewStyle = .bar
        progressImage = UIImage(named: "gradient_layer")

        layer.borderColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.5).cgColor
        layer.borderWidth = 1
        clipsToBounds = true
    }

    override func setProgress(_ progress: Float, animated: Bool) {
        super.setProgress(progress, animated: animated)
        if hideOnComplete,
            !inProgress {
            isHidden = true
            setProgress(0, animated: false)
        }
        progressLabel.text = String(format: "%.f%%", progress * 100)
    }
}
