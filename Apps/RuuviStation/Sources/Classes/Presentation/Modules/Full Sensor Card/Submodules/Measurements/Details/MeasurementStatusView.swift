import RuuviLocalization
import RuuviOntology
import UIKit

public class MeasurementStatusView: UIView {
    // MARK: - UI Components

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .right
        label.font = .mulish(.bold, size: 12)
        label.textColor = RuuviColor.dashboardIndicatorBig.color
        return label
    }()

    private let statusIndicator: UIView = {
        let view = UIView()
        view.clipsToBounds = true
        view.layer.cornerRadius = indicatorSize / 2
        return view
    }()

    // MARK: - Properties

    public var statusText: String? {
        get { statusLabel.text }
        set { statusLabel.text = newValue }
    }

    public var indicatorColor: UIColor? {
        get { statusIndicator.backgroundColor }
        set { statusIndicator.backgroundColor = newValue }
    }

    private static let indicatorSize: CGFloat = 8

    // MARK: - Initialization

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    // MARK: - Setup

    private func setupViews() {
        addSubview(statusLabel)
        addSubview(statusIndicator)

        statusLabel.anchor(
            top: topAnchor,
            leading: leadingAnchor,
            bottom: bottomAnchor,
            trailing: nil
        )

        statusIndicator.anchor(
            top: nil,
            leading: statusLabel.trailingAnchor,
            bottom: nil,
            trailing: trailingAnchor,
            padding: .init(top: 0, left: 8, bottom: 0, right: 0),
            size: .init(width: Self.indicatorSize, height: Self.indicatorSize)
        )
        statusIndicator.centerYInSuperview()
    }
}

// MARK: - Configuration

extension MeasurementStatusView {
    public func configure(from status: MeasurementQualityState) {
        statusText = status.title
        indicatorColor = status.color
    }
}
