import UIKit
import RuuviOntology
import RuuviLocalization

/// Keeps the timestamp in place when the measurement source or freshness changes.
final class SensorDataSourceButton: UIControl {
    static let width: CGFloat = 24

    private let sourceImageView = UIImageView()
    private let warningImageView = UIImageView()
    private lazy var sourceLeading = sourceImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3)
    private lazy var sourceWidth = sourceImageView.widthAnchor.constraint(equalToConstant: 16)
    private lazy var sourceHeight = sourceImageView.heightAnchor.constraint(equalToConstant: 16)
    private(set) var isStale = false
    private var previousSource: RuuviTagSensorRecordSource?

    override init(frame: CGRect) {
        super.init(frame: frame)
        sourceImageView.accessibilityIdentifier = "measurement-source-icon"
        warningImageView.accessibilityIdentifier = "measurement-warning-badge"
        sourceImageView.contentMode = .scaleAspectFit
        sourceImageView.alpha = 0.7
        warningImageView.contentMode = .scaleAspectFit
        warningImageView.image = RuuviAsset.badgeWarning.image.withRenderingMode(.alwaysOriginal)
        for imageView in [sourceImageView, warningImageView] {
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.isAccessibilityElement = false
            addSubview(imageView)
        }
        NSLayoutConstraint.activate([
            sourceLeading,
            sourceImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            sourceWidth,
            sourceHeight,
            warningImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            warningImageView.topAnchor.constraint(equalTo: sourceImageView.topAnchor),
            warningImageView.widthAnchor.constraint(equalToConstant: 12),
            warningImageView.heightAnchor.constraint(equalToConstant: 12),
        ])
        accessibilityIdentifier = "measurement-source"
        accessibilityLabel = RuuviLocalization.sensorMeasurementsOutdated
        setContentCompressionResistancePriority(.required, for: .horizontal)
        warningImageView.isHidden = true
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(source: RuuviTagSensorRecordSource?, isStale: Bool) {
        if source != previousSource {
            previousSource = source
            sourceLeading.constant = source == .ruuviNetwork ? 0 : 3
            sourceWidth.constant = source == .ruuviNetwork ? 22 : 16
            sourceHeight.constant = source == .ruuviNetwork ? 20 : 16
            switch source {
            case .advertisement, .bgAdvertisement:
                sourceImageView.image = RuuviAsset.iconBluetooth.image
            case .heartbeat, .log:
                sourceImageView.image = RuuviAsset.iconBluetoothConnected.image
            case .ruuviNetwork:
                sourceImageView.image = RuuviAsset.iconGateway.image
            case .unknown, nil:
                sourceImageView.image = nil
            }
            sourceImageView.image = sourceImageView.image?.withRenderingMode(.alwaysTemplate)
            setNeedsLayout()
        }
        guard self.isStale != isStale else { return }
        self.isStale = isStale
        warningImageView.isHidden = !isStale
        isUserInteractionEnabled = isStale
        isAccessibilityElement = isStale
        accessibilityTraits = isStale ? .button : []
    }
}
