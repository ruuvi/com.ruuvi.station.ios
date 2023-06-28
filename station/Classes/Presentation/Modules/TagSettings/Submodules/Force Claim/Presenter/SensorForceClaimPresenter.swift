import Foundation
import RuuviOntology
import RuuviService
import RuuviUser
import RuuviPool
import RuuviPresenters
import BTKit
import CoreNFC
import RuuviLocal

final class SensorForceClaimPresenter: SensorForceClaimModuleInput {
    weak var view: SensorForceClaimViewInput?
    var router: SensorForceClaimRouterInput?
    var ruuviOwnershipService: RuuviServiceOwnership!
    var activityPresenter: ActivityPresenter!
    var ruuviUser: RuuviUser!
    var ruuviPool: RuuviPool!
    var background: BTBackground!
    var errorPresenter: ErrorPresenter!
    var settings: RuuviLocalSettings!

    private var ruuviTag: RuuviTagSensor?
    private var secret: String?
    private var isLoading: Bool = false {
        didSet {
            if isLoading {
                activityPresenter.increment()
            } else {
                activityPresenter.decrement()
            }
        }
    }
    private var timer: Timer?
    private var gattTimeoutSeconds: Double = 15

    func configure(ruuviTag: RuuviTagSensor) {
        self.ruuviTag = ruuviTag
    }

    deinit {
        timer?.invalidate()
    }
}

extension SensorForceClaimPresenter: SensorForceClaimViewOutput {
    func viewDidLoad() {
        if settings.hideNFCForSensorContest {
            view?.hideNFCButton()
        }
    }

    func viewDidTapUseNFC() {
        view?.startNFCSession()
    }

    func viewDidTapUseBluetooth() {
        setUpTimeoutTimerForGATTSecret()
        getTagSecretFromGatt()
    }

    func viewDidReceiveNFCMessages(messages: [NFCNDEFMessage]) {
        // Stop NFC session
        view?.stopNFCSession()
        // Parse the message
        for message in messages {
            for record in message.records {
                if let (key, value) = parse(record: record) {
                    switch key {
                    case "idID":
                        secret = value
                    default:
                        break
                    }
                }
            }
        }
        // Claim
        contestSensor(with: secret)
    }

    func viewDidDismiss() {
        router?.dismiss()
    }
}

extension SensorForceClaimPresenter {
    /// Sets up a 15 seconds timer to attempt GATT connection and get secret.
    private func setUpTimeoutTimerForGATTSecret() {
        timer = Timer.scheduledTimer(
            withTimeInterval: gattTimeoutSeconds,
            repeats: true,
            block: { [weak self] (_) in
                self?.isLoading = false
                self?.invalidateTimer()
                self?.view?.showGATTConnectionTimeoutDialog()
            })
    }

    /// Invalidates the running timer
    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func getTagSecretFromGatt() {
        guard let luid = ruuviTag?.luid else {
            return
        }
        isLoading = true
        // TODO: Check the timeout issue. Timeout not trigerred now.
        background.services.gatt.serialRevision(
            for: self,
            uuid: luid.value,
            options: [.connectionTimeout(gattTimeoutSeconds)] // Doesn't work now.
        ) { [weak self] _, result in
            switch result {
            case .success(let secret):
                self?.contestSensor(with: secret)
            case .failure(let error):
                self?.errorPresenter.present(error: error)
                self?.isLoading = false
            }
        }
    }

    /// Contest sensor with tag secret.
    private func contestSensor(with secret: String?) {
        guard let ruuviTag = ruuviTag,
              let secret = secret else { return }

        isLoading = true
        ruuviOwnershipService
            .contest(sensor: ruuviTag, secret: secret)
            .on(success: { [weak self] _ in
                self?.router?.dismiss()
            }, failure: { [weak self] error in
                self?.errorPresenter.present(error: error)
            }, completion: { [weak self] in
                self?.isLoading = false
            })
    }

    /// Parse the NFC payload
    private func parse(record: NFCNDEFPayload) -> (String, String)? {
        let payload = record.payload
        let prefix = payload.prefix(1)
        let rest = payload.dropFirst(1)

        switch prefix {
        case .init([0x02]):
            guard let restString = String(
                data: rest, encoding: .utf8
            ) else { return nil }

            let components = restString.components(separatedBy: ": ")
            if components.count == 2 {
                let key = components[0]
                let value = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                return (key, value)
            }
        default:
            return nil
        }
        return nil
    }
}
