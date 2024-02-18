import CoreNFC
import RuuviLocalization
import RuuviOntology
import UIKit

class SensorForceClaimViewController: UIViewController {
    private lazy var backButton: UIButton = {
        let button = UIButton()
        button.tintColor = .label
        let buttonImage = RuuviAsset.chevronBack.image
        button.setImage(buttonImage, for: .normal)
        button.setImage(buttonImage, for: .highlighted)
        button.imageView?.tintColor = .label
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(backButtonDidTap), for: .touchUpInside)
        return button
    }()

    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.textColor.color
        label.textAlignment = .left
        label.numberOfLines = 0
        label.text = RuuviLocalization.forceClaimSensorDescription1
        label.font = UIFont.Muli(.regular, size: 16)
        return label
    }()

    private lazy var claimSensorButton: UIButton = {
        let button = UIButton(
            color: RuuviColor.tintColor.color,
            cornerRadius: 25
        )
        button.setTitle(RuuviLocalization.forceClaim, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.Muli(.bold, size: 16)
        button.addTarget(
            self,
            action: #selector(handleClaimSensorTap),
            for: .touchUpInside
        )
        return button
    }()

    private lazy var sensorClaimNotesViewContainer: UIView = .init(
        color: RuuviColor.primary.color
    )
    private lazy var sensorClaimNotesView: UITextView = {
        let tv = UITextView()
        tv.isSelectable = false
        tv.isEditable = false
        tv.textAlignment = .left
        tv.text = RuuviLocalization.forceClaimSensorDescription2
        tv.textColor = RuuviColor.textColor.color
        tv.backgroundColor = .clear
        tv.font = UIFont.Muli(.regular, size: 16)
        tv.isScrollEnabled = true
        return tv
    }()

    private lazy var useNFCButton: UIButton = {
        let button = UIButton(
            color: RuuviColor.tintColor.color,
            cornerRadius: 25
        )
        button.setTitle(
            RuuviLocalization.useNfc,
            for: .normal
        )
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.Muli(.bold, size: 16)
        button.addTarget(
            self,
            action: #selector(handleUseNFCButtonTap),
            for: .touchUpInside
        )
        return button
    }()

    private lazy var useBluetoothButton: UIButton = {
        let button = UIButton(
            color: RuuviColor.tintColor.color,
            cornerRadius: 25
        )
        button.setTitle(
            RuuviLocalization.useBluetooth,
            for: .normal
        )
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.Muli(.bold, size: 16)
        button.addTarget(
            self,
            action: #selector(handleUseBluetoothButtonTap),
            for: .touchUpInside
        )
        return button
    }()

    // Implementation
    private var isNFCAvailable: Bool {
        NFCNDEFReaderSession.readingAvailable
    }

    private var session: NFCNDEFReaderSession?

    // Constraints
    private var bluetoothButtonRegularLeadingConstraint: NSLayoutConstraint!
    private var bluetoothButtonRegularTrailingConstraint: NSLayoutConstraint!
    private var bluetoothButtonRegularWidthConstraint: NSLayoutConstraint!
    private var bluetoothButtonNoNFCWidthConstraint: NSLayoutConstraint!
    private var bluetoothButtonNoNFCCenterXConstraint: NSLayoutConstraint!

    // Output
    var output: SensorForceClaimViewOutput?
}

// MARK: - VIEW LIFECYCLE

extension SensorForceClaimViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        localize()
        output?.viewDidLoad()
    }
}

// MARK: - SensorForceClaimViewInput

extension SensorForceClaimViewController: SensorForceClaimViewInput {
    func localize() {
        // No op.
    }

    func hideNFCButton() {
        hideNFCButton(hide: true)
    }

    func startNFCSession() {
        session = NFCNDEFReaderSession(
            delegate: self,
            queue: nil,
            invalidateAfterFirstRead: false
        )
        session?.begin()
    }

    func stopNFCSession() {
        session?.invalidate()
    }

    func showGATTConnectionTimeoutDialog() {
        let message = RuuviLocalization.sensorNotFoundError
        let controller = UIAlertController(
            title: nil, message: message, preferredStyle: .alert
        )
        controller.addAction(
            UIAlertAction(title: RuuviLocalization.ok, style: .cancel, handler: nil)
        )
        present(controller, animated: true)
    }
}

// MARK: - PRIVATE SET UI

extension SensorForceClaimViewController {
    private func setUpUI() {
        setUpBase()
        setUpClaimIntroView()
        setUpClaimNoteView()
    }

    private func setUpBase() {
        title = RuuviLocalization.forceClaimSensor

        view.backgroundColor = RuuviColor.primary.color

        let backBarButtonItemView = UIView()
        backBarButtonItemView.addSubview(backButton)
        backButton.anchor(
            top: backBarButtonItemView.topAnchor,
            leading: backBarButtonItemView.leadingAnchor,
            bottom: backBarButtonItemView.bottomAnchor,
            trailing: backBarButtonItemView.trailingAnchor,
            padding: .init(top: 0, left: -16, bottom: 0, right: 0),
            size: .init(width: 48, height: 48)
        )
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backBarButtonItemView)
    }

    private func setUpClaimIntroView() {
        view.addSubview(messageLabel)
        messageLabel.anchor(
            top: view.safeTopAnchor,
            leading: view.safeLeftAnchor,
            bottom: nil,
            trailing: view.safeRightAnchor,
            padding: .init(top: 16, left: 12, bottom: 0, right: 12)
        )

        view.addSubview(claimSensorButton)
        claimSensorButton.anchor(
            top: messageLabel.bottomAnchor,
            leading: nil,
            bottom: nil,
            trailing: nil,
            padding: .init(top: 40, left: 0, bottom: 0, right: 0),
            size: .init(width: 200, height: 50)
        )
        claimSensorButton.centerXInSuperview()
    }

    // swiftlint:disable:next function_body_length
    private func setUpClaimNoteView() {
        view.addSubview(sensorClaimNotesViewContainer)
        sensorClaimNotesViewContainer.fillSuperviewToSafeArea()

        // Text view
        sensorClaimNotesViewContainer.addSubview(sensorClaimNotesView)
        sensorClaimNotesView.anchor(
            top: sensorClaimNotesViewContainer.topAnchor,
            leading: sensorClaimNotesViewContainer.leadingAnchor,
            bottom: nil,
            trailing: sensorClaimNotesViewContainer.trailingAnchor,
            padding: .init(top: 16, left: 12, bottom: 0, right: 12)
        )

        // Footer
        let footerView = UIView(color: .clear)
        sensorClaimNotesViewContainer.addSubview(footerView)
        footerView.anchor(
            top: sensorClaimNotesView.bottomAnchor,
            leading: sensorClaimNotesView.leadingAnchor,
            bottom: sensorClaimNotesViewContainer.bottomAnchor,
            trailing: sensorClaimNotesView.trailingAnchor
        )

        // Scan buttons
        footerView.addSubview(useNFCButton)
        useNFCButton.anchor(
            top: footerView.topAnchor,
            leading: footerView.leadingAnchor,
            bottom: footerView.bottomAnchor,
            trailing: nil,
            padding: .init(top: 16, left: 0, bottom: 16, right: 0),
            size: .init(width: 0, height: 50)
        )

        footerView.addSubview(useBluetoothButton)
        useBluetoothButton.anchor(
            top: useNFCButton.topAnchor,
            leading: nil,
            bottom: useNFCButton.bottomAnchor,
            trailing: nil
        )

        bluetoothButtonRegularLeadingConstraint = useBluetoothButton
            .leadingAnchor
            .constraint(
                equalTo: useNFCButton.trailingAnchor,
                constant: 12
            )
        bluetoothButtonRegularTrailingConstraint = useBluetoothButton
            .trailingAnchor
            .constraint(
                equalTo: footerView.trailingAnchor
            )
        bluetoothButtonRegularWidthConstraint = useBluetoothButton
            .widthAnchor
            .constraint(equalTo: useNFCButton.widthAnchor)

        bluetoothButtonNoNFCWidthConstraint = useBluetoothButton
            .widthAnchor
            .constraint(equalToConstant: 180)
        bluetoothButtonNoNFCCenterXConstraint = useBluetoothButton
            .centerXAnchor
            .constraint(equalTo: footerView.centerXAnchor)
        hideNFCButton(hide: !isNFCAvailable)

        sensorClaimNotesViewContainer.alpha = 0
    }
}

// MARK: - IBACTIONS

extension SensorForceClaimViewController {
    @objc private func backButtonDidTap() {
        _ = navigationController?.popViewController(animated: true)
    }

    @objc private func handleClaimSensorTap() {
        sensorClaimNotesViewContainer.alpha = 1
    }

    @objc private func handleUseNFCButtonTap() {
        output?.viewDidTapUseNFC()
    }

    @objc private func handleUseBluetoothButtonTap() {
        output?.viewDidTapUseBluetooth()
    }
}

// MARK: - PRIVATE

private extension SensorForceClaimViewController {
    func hideNFCButton(hide: Bool) {
        useNFCButton.alpha = hide ? 0 : 1
        bluetoothButtonRegularLeadingConstraint.isActive = !hide
        bluetoothButtonRegularTrailingConstraint.isActive = !hide
        bluetoothButtonRegularWidthConstraint.isActive = !hide
        bluetoothButtonNoNFCWidthConstraint.isActive = hide
        bluetoothButtonNoNFCCenterXConstraint.isActive = hide
    }
}

// MARK: - NFCNDEFReaderSessionDelegate

extension SensorForceClaimViewController: NFCNDEFReaderSessionDelegate {
    func readerSession(_: NFCNDEFReaderSession, didInvalidateWithError _: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.stopNFCSession()
        }
    }

    func readerSession(_: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        DispatchQueue.main.async { [weak self] in
            self?.output?.viewDidReceiveNFCMessages(messages: messages)
        }
    }
}
