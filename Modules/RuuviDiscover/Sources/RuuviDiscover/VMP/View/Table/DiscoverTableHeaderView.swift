import UIKit
import CoreBluetooth
import CoreNFC

protocol DiscoverTableHeaderViewDelegate: NSObjectProtocol {
    func didTapAddWithNFCButton(sender: DiscoverTableHeaderView)
}

class DiscoverTableHeaderView: UIView {

    weak var delegate: DiscoverTableHeaderViewDelegate?

    // ----- Private
    private var isNFCAvailable: Bool {
        return NFCNDEFReaderSession.readingAvailable
    }

    private var isBluetoothPermissionGranted: Bool {
        if #available(iOS 13.1, *) {
            return CBCentralManager.authorization == .allowedAlways
        } else if #available(iOS 13.0, *) {
            return CBCentralManager().authorization == .allowedAlways
        }
        // Before iOS 13, Bluetooth permissions are not required
        return true
    }

    private let addSensorDescriptionKey: String = "add_sensor_description"
    private let addSensorViaNFCKey: String = "add_sensor_via_nfc"

    // UI
    private lazy var descriptionLabel = createDescriptionLabel()
    private lazy var nfcButton = createAddWithNFCButton()

    private var descriptionLabelBottomConstraint: NSLayoutConstraint!
    private var nfcButtonTopConstraint: NSLayoutConstraint!
    private var nfcButtonBottomConstraint: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        let headerView = createHeaderView()
        addSubview(headerView)

        headerView.addSubview(descriptionLabel)

        if isBluetoothPermissionGranted && isNFCAvailable {
            headerView.addSubview(nfcButton)
        }

        setupLayout(headerView: headerView,
                    descriptionLabel: descriptionLabel,
                    button: nfcButton)
    }

    private func createHeaderView() -> UIView {
        let headerView = UIView()
        headerView.backgroundColor = .clear
        headerView.translatesAutoresizingMaskIntoConstraints = false
        return headerView
    }

    private func createDescriptionLabel() -> UILabel {
        let descriptionLabel = UILabel()
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.numberOfLines = 0

        let addSensorString: String = addSensorDescriptionKey.localized(for: Self.self)
        let addSensorViaNFCString = addSensorViaNFCKey.localized(for: Self.self)
        let descriptionString =
            (isBluetoothPermissionGranted && isNFCAvailable) ?
            (addSensorString + "\n\n" + addSensorViaNFCString) : addSensorString

        descriptionLabel.text = descriptionString
        descriptionLabel.textColor = UIColor(named: "ruuvi_text_color")
        if let font = UIFont(name: "Muli-Regular", size: 14) {
            descriptionLabel.font = font
        }
        return descriptionLabel
    }

    private func createAddWithNFCButton() -> UIButton {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        button.setTitle("add_with_nfc".localized(for: Self.self), for: .normal)
        button.setTitleColor(.label, for: .normal)
        button.setInsets(forContentPadding: .zero, imageTitlePadding: 8)
        if let font = UIFont(name: "Muli-Regular", size: 16) {
            button.titleLabel?.font = font
        }
        button.tintColor = UIColor(named: "RuuviTintColor")
        button.addTarget(self,
                         action: #selector(handleButtonTap),
                         for: .touchUpInside)
        return button
    }

    private func setupLayout(
        headerView: UIView, descriptionLabel: UILabel, button: UIButton
    ) {
        let headerPadding = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        NSLayoutConstraint.activate(headerView.constraints(to: self, padding: headerPadding))

        NSLayoutConstraint.activate([
            descriptionLabel.topAnchor.constraint(equalTo: headerView.topAnchor),
            descriptionLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor)
        ])

        // variable constraints
        nfcButtonTopConstraint = button
            .topAnchor
            .constraint(
                equalTo: descriptionLabel.bottomAnchor, constant: 12
            )
        nfcButtonBottomConstraint = button
            .bottomAnchor
            .constraint(
                equalTo: headerView.bottomAnchor, constant: -12
            )
        descriptionLabelBottomConstraint = descriptionLabel
            .bottomAnchor
            .constraint(equalTo: headerView.bottomAnchor)

        if isBluetoothPermissionGranted && isNFCAvailable {
            NSLayoutConstraint.activate([
                nfcButtonTopConstraint,
                button.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
                button.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
                nfcButtonBottomConstraint
            ])
        } else {
            NSLayoutConstraint.activate([
                descriptionLabelBottomConstraint
            ])
        }
    }

    @objc private func handleButtonTap() {
        delegate?.didTapAddWithNFCButton(sender: self)
    }
}

extension DiscoverTableHeaderView {
    func handleNFCButtonViewVisibility(show: Bool) {
        if isBluetoothPermissionGranted && isNFCAvailable {
            nfcButtonTopConstraint.isActive = show
            nfcButtonBottomConstraint.isActive = show
            nfcButton.isHidden = !show
        }
        descriptionLabelBottomConstraint.isActive = !show
        let addSensorString: String = addSensorDescriptionKey.localized(for: Self.self)
        let addSensorViaNFCString = addSensorViaNFCKey.localized(for: Self.self)
        let descriptionString =
            (show && isBluetoothPermissionGranted && isNFCAvailable) ?
            (addSensorString + "\n\n" + addSensorViaNFCString) : addSensorString
        descriptionLabel.text =  descriptionString
    }
}

extension UIButton {
    func setInsets(
        forContentPadding contentPadding: UIEdgeInsets,
        imageTitlePadding: CGFloat
    ) {
        self.contentEdgeInsets = UIEdgeInsets(
            top: contentPadding.top,
            left: contentPadding.left,
            bottom: contentPadding.bottom,
            right: contentPadding.right + imageTitlePadding
        )
        self.titleEdgeInsets = UIEdgeInsets(
            top: 0,
            left: imageTitlePadding,
            bottom: 0,
            right: -imageTitlePadding
        )
    }
}

extension UIView {
    func constraints(to view: UIView, padding: UIEdgeInsets = .zero) -> [NSLayoutConstraint] {
        return [
            self.topAnchor.constraint(equalTo: view.topAnchor, constant: padding.top),
            self.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding.left),
            self.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -padding.bottom),
            self.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding.right)
        ]
    }
}
