import CoreBluetooth
import CoreNFC
import RuuviLocalization
import UIKit

protocol DiscoverHeaderViewDelegate: NSObjectProtocol {
    func didTapAddWithNFCButton(sender: DiscoverHeaderView)
}

class DiscoverHeaderView: UIView {
    weak var delegate: DiscoverHeaderViewDelegate?

    // ----- Private
    private var isNFCAvailable: Bool {
        NFCNDEFReaderSession.readingAvailable
    }

    private var isBluetoothPermissionGranted: Bool {
        let centralAuthorization = CBManager.authorization
        if centralAuthorization == .denied || centralAuthorization == .restricted {
            return false
        }

        let peripheralStatus = CBManager.authorization
        switch peripheralStatus {
        case .denied, .restricted:
            return false
        default:
            return true
        }
    }

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

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        let headerView = createHeaderView()
        addSubview(headerView)

        headerView.addSubview(descriptionLabel)
        headerView.addSubview(nfcButton)

        setupLayout(
            headerView: headerView,
            descriptionLabel: descriptionLabel,
            nfcButton: nfcButton
        )
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

        let addSensorString: String = RuuviLocalization.addSensorDescription
        let addSensorViaNFCString = RuuviLocalization.addSensorViaNfc
        let descriptionString =
            (isBluetoothPermissionGranted && isNFCAvailable) ?
            (addSensorString + "\n\n" + addSensorViaNFCString) : addSensorString

        descriptionLabel.text = descriptionString
        descriptionLabel.textColor = UIColor(named: "ruuvi_text_color")
        descriptionLabel.font = UIFont.ruuviSubheadline()
        return descriptionLabel
    }

    private func createAddWithNFCButton() -> UIButton {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        button.setTitle(RuuviLocalization.addWithNfc, for: .normal)
        button.setTitleColor(.label, for: .normal)
        button.setInsets(forContentPadding: .zero, imageTitlePadding: 8)
        button.titleLabel?.font = UIFont.ruuviButtonMedium()
        button.tintColor = RuuviColor.tintColor.color
        button.addTarget(
            self,
            action: #selector(handleButtonTap),
            for: .touchUpInside
        )
        return button
    }

    private func setupLayout(
        headerView: UIView, descriptionLabel: UILabel, nfcButton: UIButton
    ) {
        let headerPadding = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        NSLayoutConstraint.activate(headerView.constraints(to: self, padding: headerPadding))

        NSLayoutConstraint.activate([
            descriptionLabel.topAnchor.constraint(equalTo: headerView.topAnchor),
            descriptionLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
        ])

        NSLayoutConstraint.activate([
            nfcButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            nfcButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
        ])

        // variable constraints
        nfcButtonTopConstraint = nfcButton
            .topAnchor
            .constraint(
                equalTo: descriptionLabel.bottomAnchor, constant: 12
            )
        nfcButtonBottomConstraint = nfcButton
            .bottomAnchor
            .constraint(
                equalTo: headerView.bottomAnchor, constant: -12
            )
        descriptionLabelBottomConstraint = descriptionLabel
            .bottomAnchor
            .constraint(equalTo: headerView.bottomAnchor)

        nfcButton.isHidden = !(isBluetoothPermissionGranted && isNFCAvailable)

        if isBluetoothPermissionGranted, isNFCAvailable {
            NSLayoutConstraint.activate([
                nfcButtonTopConstraint,
                nfcButtonBottomConstraint,
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

extension DiscoverHeaderView {
    func handleNFCButtonViewVisibility(show: Bool) {
        let showNFCButton = show && isNFCAvailable
        nfcButton.isHidden = !showNFCButton
        if showNFCButton {
            NSLayoutConstraint.deactivate([
                descriptionLabelBottomConstraint
            ])
            NSLayoutConstraint.activate([
                nfcButtonTopConstraint,
                nfcButtonBottomConstraint,
            ])
        } else {
            NSLayoutConstraint.deactivate([
                nfcButtonTopConstraint,
                nfcButtonBottomConstraint,
            ])
            NSLayoutConstraint.activate([
                descriptionLabelBottomConstraint
            ])
        }
        let addSensorString: String = RuuviLocalization.addSensorDescription
        let addSensorViaNFCString = RuuviLocalization.addSensorViaNfc
        let descriptionString =
            (showNFCButton && isBluetoothPermissionGranted) ?
            (addSensorString + "\n\n" + addSensorViaNFCString) : addSensorString
        descriptionLabel.text = descriptionString
    }
}
