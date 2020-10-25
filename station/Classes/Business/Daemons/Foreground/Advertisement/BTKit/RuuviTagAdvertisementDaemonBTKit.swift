import BTKit
import Foundation

class RuuviTagAdvertisementDaemonBTKit: BackgroundWorker, RuuviTagAdvertisementDaemon {

    var ruuviTagTank: RuuviTagTank!
    var ruuviTagReactor: RuuviTagReactor!
    var foreground: BTForeground!
    var settings: Settings!

    private var ruuviTagsToken: RUObservationToken?
    private var observeTokens = [ObservationToken]()
    private var ruuviTags = [AnyRuuviTagSensor]()
    private var savedDate = [String: Date]() // uuid:date
    private var isOnToken: NSObjectProtocol?
    private var saveInterval: TimeInterval {
        return TimeInterval(settings.advertisementDaemonIntervalMinutes * 60)
    }

    @objc private class RuuviTagWrapper: NSObject {
        var device: RuuviTag
        init(device: RuuviTag) {
            self.device = device
        }
    }

    deinit {
        observeTokens.forEach({ $0.invalidate() })
        observeTokens.removeAll()
        ruuviTagsToken?.invalidate()
        isOnToken?.invalidate()
    }

    override init() {
        super.init()
        isOnToken = NotificationCenter
            .default
            .addObserver(forName: .isAdvertisementDaemonOnDidChange,
                         object: nil,
                         queue: .main) { [weak self] _ in
            guard let sSelf = self else { return }
            if sSelf.settings.isAdvertisementDaemonOn {
                sSelf.start()
            } else {
                sSelf.stop()
            }
        }
    }

    func start() {
        start { [weak self] in
            self?.ruuviTagsToken = self?.ruuviTagReactor.observe({ [weak self] change in
                guard let sSelf = self else { return }
                switch change {
                case .initial(let ruuviTags):
                    sSelf.ruuviTags = ruuviTags
                    sSelf.restartObserving()
                case .update(let ruuviTag):
                    if let index = sSelf.ruuviTags.firstIndex(of: ruuviTag) {
                        sSelf.ruuviTags[index] = ruuviTag
                    }
                    sSelf.restartObserving()
                case .insert(let ruuviTag):
                    sSelf.ruuviTags.append(ruuviTag)
                    sSelf.restartObserving()
                case .delete(let ruuviTag):
                    sSelf.ruuviTags.removeAll(where: { $0.id == ruuviTag.id })
                    sSelf.restartObserving()
                case .error(let error):
                    sSelf.post(error: RUError.persistence(error))
                }
            })
        }
    }

    func stop() {
        perform(#selector(RuuviTagAdvertisementDaemonBTKit.stopDaemon),
                on: thread,
                with: nil,
                waitUntilDone: false,
                modes: [RunLoop.Mode.default.rawValue])
    }

    @objc private func stopDaemon() {
        observeTokens.forEach({ $0.invalidate() })
        observeTokens.removeAll()
        ruuviTagsToken?.invalidate()
        stopWork()
    }

    private func restartObserving() {
        observeTokens.forEach({ $0.invalidate() })
        observeTokens.removeAll()
        for ruuviTag in ruuviTags {
            guard let luid = ruuviTag.luid else { continue }
            observeTokens.append(foreground.observe(self,
                                                    uuid: luid.value,
                                                    options: [.callbackQueue(.untouch)]) {
                                                        [weak self] (_, device) in
                guard let sSelf = self else { return }
                if let tag = device.ruuvi?.tag, !tag.isConnected {
                    sSelf.perform(#selector(RuuviTagAdvertisementDaemonBTKit.persist(wrapper:)),
                            on: sSelf.thread,
                            with: RuuviTagWrapper(device: tag),
                            waitUntilDone: false,
                            modes: [RunLoop.Mode.default.rawValue])
                }
            })
        }
    }

    @objc private func persist(wrapper: RuuviTagWrapper) {
        let uuid = wrapper.device.uuid
        if let date = savedDate[uuid] {
            if Date().timeIntervalSince(date) > saveInterval {
                persist(wrapper.device, uuid)
            }
        } else {
            persist(wrapper.device, uuid)
        }
    }

    private func post(error: Error) {
        DispatchQueue.main.async {
            NotificationCenter
                .default
                .post(name: .RuuviTagAdvertisementDaemonDidFail,
                      object: nil,
                      userInfo: [RuuviTagAdvertisementDaemonDidFailKey.error: error])
        }
    }

    private func persist(_ record: RuuviTag, _ uuid: String) {
        ruuviTagTank.create(record).on(failure: { [weak self] error in
            if case RUError.unexpected(let unexpectedError) = error,
                unexpectedError == .failedToFindRuuviTag {
                self?.ruuviTags.removeAll(where: { $0.id == uuid })
                self?.restartObserving()
            }
            self?.post(error: error)
        })
        savedDate[uuid] = Date()
    }
}
