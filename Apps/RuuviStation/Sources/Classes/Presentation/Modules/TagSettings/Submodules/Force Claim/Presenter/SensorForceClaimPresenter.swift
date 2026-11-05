import BTKit
import CoreNFC
import Foundation
import RuuviLocal
import RuuviOntology
import RuuviPool
import RuuviPresenters
import RuuviService
import RuuviUser

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
    private var macId: String?

    private var context = UUID()
    private var ownershipTask: Task<Void, Never>?
    private var gattRequest: UUID?
    private var timer: Timer?
    var gattTimeoutSeconds: Double = 15
    var readGattSecret: ((String, TimeInterval, @escaping (Result<String, Error>) -> Void) -> Void)?

    func configure(ruuviTag: RuuviTagSensor) {
        if gattRequest != nil { activityPresenter.dismiss() }
        invalidateTimer()
        context = UUID()
        secret = nil
        macId = nil
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

    func viewWillAppear() {
        guard let ruuviTag = ruuviTag else {
            return
        }
        let format = RuuviDataFormat.dataFormat(
            from: ruuviTag.version
        )
        let ruuviDeviceType: RuuviDeviceType =
            format == .e1 || format == .v6 ? .ruuviAir : .ruuviTag
        view?.deviceType = ruuviDeviceType
    }

    func viewDidTapUseNFC() {
        view?.startNFCSession()
    }

    func viewDidTapUseBluetooth() {
        getTagSecretFromGatt()
    }

    func viewDidReceiveNFCMessages(messages: [NFCNDEFMessage]) {
        // Each scan must supply its own credentials; never reuse a previous tag's secret.
        secret = nil
        macId = nil
        view?.stopNFCSession()
        // Parse the message
        for message in messages {
            for record in message.records {
                if let (key, value) = parse(record: record) {
                    switch key {
                    case "idID":
                        secret = value
                    case "adMAC":
                        macId = trimNulls(from: value)
                    default:
                        break
                    }
                }
            }
        }
        if let nfcMacId = macId, let tagMacId = ruuviTag?.macId?.mac,
            nfcMacId != tagMacId
        {
            view?.showWrongTagScanDialog()
            return
        }
        // Claim
        contestSensor(with: secret)
    }

    func viewDidDismiss() {
        router?.dismiss()
    }
}

extension SensorForceClaimPresenter {
    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
        gattRequest = nil
    }

    private func getTagSecretFromGatt() {
        guard ownershipTask == nil, gattRequest == nil, let luid = ruuviTag?.luid else { return }
        let request = UUID()
        gattRequest = request
        timer = Timer.scheduledTimer(withTimeInterval: gattTimeoutSeconds, repeats: false) { [weak self] _ in
            guard let self, gattRequest == request else { return }
            invalidateTimer()
            activityPresenter.dismiss()
            view?.showGATTConnectionTimeoutDialog()
        }
        activityPresenter.show(with: .loading(message: nil))
        let completion: (Result<String, Error>) -> Void = { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self, gattRequest == request else { return }
                switch result {
                case let .success(secret):
                    guard secret != "XX:XX:XX:XX:XX:XX:XX:XX", !secret.isEmpty else { return }
                    invalidateTimer()
                    contestSensor(with: secret)
                case let .failure(error):
                    invalidateTimer()
                    activityPresenter.dismiss()
                    errorPresenter.present(error: error)
                }
            }
        }
        if let readGattSecret {
            readGattSecret(luid.value, gattTimeoutSeconds, completion)
        } else {
            background.services.gatt.serialRevision(
                for: self, uuid: luid.value, options: [.connectionTimeout(gattTimeoutSeconds)]
            ) { _, result in completion(result.mapError { $0 as Error }) }
        }
    }

    private func contestSensor(with secret: String?) {
        guard ownershipTask == nil, let ruuviTag, let secret, !secret.isEmpty else { return }
        invalidateTimer()
        let context = context
        activityPresenter.show(with: .loading(message: nil))
        ownershipTask = Task {
            @MainActor [weak self, service = ruuviOwnershipService!, activity = activityPresenter!] in
            defer {
                activity.dismiss()
                self?.ownershipTask = nil
            }
            do {
                _ = try await service.contest(sensor: ruuviTag, secret: secret)
                guard let self, self.context == context else { return }
                router?.dismiss()
            } catch {
                guard let self, self.context == context else { return }
                errorPresenter.present(error: error)
            }
        }
    }

    /// Parse the NFC payload
    private func parse(record: NFCNDEFPayload) -> (String, String)? {
        let payload = record.payload
        let prefix = payload.prefix(1)
        let rest = payload.dropFirst(1)

        switch prefix {
        case .init([0x02]):
            guard
                let restString = String(
                    data: rest, encoding: .utf8
                )
            else { return nil }

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

    private func trimNulls(from string: String) -> String {
        string.replacingOccurrences(of: "\0", with: "")
    }
}
