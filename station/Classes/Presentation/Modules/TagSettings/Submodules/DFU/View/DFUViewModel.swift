// swiftlint:disable file_length
import Foundation
import Combine
import RuuviOntology
import RuuviPool
import RuuviStorage
import RuuviLocal
import RuuviDaemon
import RuuviPresenters
import BTKit
import RuuviPersistence

final class DFUViewModel: ObservableObject {
    @Published private(set) var state: State = .idle
    @Published var downloadProgress: Double = 0
    @Published var flashProgress: Double = 0
    @Published var isMigrationFailed: Bool = false

    private var bag = Set<AnyCancellable>()
    private let input = PassthroughSubject<Event, Never>()
    private let interactor: DFUInteractorInput
    private let foreground: BTForeground!
    private let idPersistence: RuuviLocalIDs
    private let realmPersistence: RuuviPersistence
    private let sqiltePersistence: RuuviPersistence
    private let ruuviTag: RuuviTagSensor
    private let ruuviPool: RuuviPool
    private let ruuviStorage: RuuviStorage
    private let settings: RuuviLocalSettings
    private let propertiesDaemon: RuuviTagPropertiesDaemon
    private let activityPresenter: ActivityPresenter
    private var ruuviTagObserveToken: ObservationToken?
    private var isMigrating: Bool = false

    var isLoading: Bool = false {
        didSet {
            isLoading ? activityPresenter.increment() : activityPresenter.decrement()
        }
    }

    private class RuuviTagPropertiesDaemonPair: NSObject {
        var ruuviTag: AnyRuuviTagSensor
        var device: RuuviTag

        init(ruuviTag: AnyRuuviTagSensor, device: RuuviTag) {
            self.ruuviTag = ruuviTag
            self.device = device
        }
    }

    init(
        interactor: DFUInteractorInput,
        foreground: BTForeground,
        idPersistence: RuuviLocalIDs,
        realmPersistence: RuuviPersistence,
        sqiltePersistence: RuuviPersistence,
        ruuviTag: RuuviTagSensor,
        ruuviPool: RuuviPool,
        ruuviStorage: RuuviStorage,
        settings: RuuviLocalSettings,
        propertiesDaemon: RuuviTagPropertiesDaemon,
        activityPresenter: ActivityPresenter
    ) {
        self.interactor = interactor
        self.foreground = foreground
        self.idPersistence = idPersistence
        self.realmPersistence = realmPersistence
        self.sqiltePersistence = sqiltePersistence
        self.ruuviTag = ruuviTag
        self.ruuviPool = ruuviPool
        self.ruuviStorage = ruuviStorage
        self.settings = settings
        self.propertiesDaemon = propertiesDaemon
        self.activityPresenter = activityPresenter
        Publishers.system(
            initial: state,
            reduce: Self.reduce,
            scheduler: RunLoop.main,
            feedbacks: [
                self.whenLoading(),
                self.whenServing(),
                self.whenReading(),
                self.whenDownloading(),
                self.whenListening(),
                self.whenReadyToUpdate(),
                self.whenFlashing(),
                self.whenFlashed(),
                self.whenServingAfterUpdate(),
                self.userInput(input: input.eraseToAnyPublisher())
            ]
        )
        .assign(to: \.state, on: self)
        .store(in: &bag)
    }

    deinit {
        bag.removeAll()
        ruuviTagObserveToken?.invalidate()
    }

    func restartPropertiesDaemon() {
        propertiesDaemon.start()
    }

    func send(event: Event) {
        input.send(event)
    }

    func storeUpdatedFirmware(currentRelease: CurrentRelease?) {
        guard ruuviTag.luid != nil else { return }
        // If the tag is stored on realm then migration needed
        // Usually tags without macId are stored in the realm database
        // For tags with macId don't need migration
        if ruuviTag.macId != nil {
            guard let currentRelease = currentRelease else {
                return
            }
            let firmwareVersion = currentRelease.version.replace("Ruuvi FW ", with: "")
            isLoading = true
            ruuviPool.update(ruuviTag
                .with(isConnectable: true)
                .with(firmwareVersion: firmwareVersion))
            .on(success: { [weak self] _ in
                self?.isLoading = false
            }, failure: { [weak self] _ in
                self?.isLoading = false
            })
        } else {
            isLoading = true
            propertiesDaemon.stop()
            startObserving()
        }
    }

    private func startObserving() {
        guard let luid = ruuviTag.luid else {
            isLoading = false
            return
        }
        ruuviTagObserveToken?.invalidate()
        ruuviTagObserveToken = foreground.observe(self,
                                                uuid: luid.value,
                                                options: [.callbackQueue(.untouch)]) {
            [weak self] (_, device) in
            guard let sSelf = self else { return }
            if let tag = device.ruuvi?.tag {
                guard !sSelf.isMigrating else {
                    return
                }
                sSelf.ruuviTagObserveToken?.invalidate()
                sSelf.isMigrating = true
                let pair = RuuviTagPropertiesDaemonPair(ruuviTag: sSelf.ruuviTag.any, device: tag)
                sSelf.tryToMigrate(pair: pair)
            }
        }
    }

    // MARK: - Migration starts
    @objc private func tryToMigrate(pair: RuuviTagPropertiesDaemonPair) {
        if let mac = pair.device.mac {
            moveTagToSqlite(mac: mac.mac, pair: pair)
        }
    }

    /// This method creates the updated instance of the Ruuvi Tag after firmware update.
    private func moveTagToSqlite(mac: MACIdentifier,
                                 pair: RuuviTagPropertiesDaemonPair) {
        sqiltePersistence.create(
            pair.ruuviTag
                .with(macId: mac)
                .with(isConnectable: true)
                .with(version: pair.device.version)
                .with(isOwner: true)
        ).on(success: { [weak self] _ in
            self?.moveLatestRecordToSqlite(mac: mac, pair: pair)
        }, failure: { [weak self] _ in
            self?.notifyMigrationError()
        })
    }

    /// This method fetches the latest record from the Realm and creates the same record to SQLite.
    /// If there's no record move to the next step.
    private func moveLatestRecordToSqlite(mac: MACIdentifier,
                                          pair: RuuviTagPropertiesDaemonPair) {
        realmPersistence.readLatest(pair.ruuviTag).on(success: { [weak self] record in
            // If there's no record move to next action
            guard let record = record else {
                self?.moveRecordsHistoryToSqlite(mac: mac, pair: pair)
                return
            }
            self?.sqiltePersistence.createLast(record.with(macId: mac)).on(success: { [weak self] _ in
                self?.moveRecordsHistoryToSqlite(mac: mac, pair: pair)
            }, failure: { [weak self] _ in
                self?.notifyMigrationError()
            })
        }, failure: { [weak self] _ in
            self?.notifyMigrationError()
        })
    }

    /// This method fetches the all the records from the Realm and creates the same records to SQLite.
    /// If there are no records move to the next step.
    private func moveRecordsHistoryToSqlite(mac: MACIdentifier,
                                            pair: RuuviTagPropertiesDaemonPair) {

        realmPersistence.readAll(pair.device.uuid).on(success: { [weak self] realmRecords in
            guard realmRecords.count > 0 else {
                self?.moveSettingsToSqlite(mac: mac, pair: pair)
                return
            }
            let records = realmRecords.map({ $0.with(macId: mac) })
            self?.sqiltePersistence.create(records).on(success: { _ in
                self?.idPersistence.set(mac: mac, for: pair.device.uuid.luid)
                self?.moveSettingsToSqlite(mac: mac, pair: pair)
            }, failure: { [weak self] _ in
                self?.notifyMigrationError()
            })
        }, failure: { [weak self] _ in
            self?.notifyMigrationError()
        })
    }

    /// This method fetches the sensor settings from the Realm and creates the same sensor settings record to SQLite.
    /// If there's no record move to the next step.
    private func moveSettingsToSqlite(mac: MACIdentifier,
                                      pair: RuuviTagPropertiesDaemonPair) {
        realmPersistence.readSensorSettings(pair.ruuviTag.withoutMac())
            .on(success: { [weak self] sensorSettings in
                if let withMacSettings = sensorSettings?.with(macId: mac) {
                    self?.sqiltePersistence.save(sensorSettings: withMacSettings)
                        .on(success: { _ in
                            self?.deleteRealmRecords(pair: pair)
                        }, failure: { [weak self] _ in
                            self?.notifyMigrationError()
                        })
                } else {
                    self?.deleteRealmRecords(pair: pair)
                }
            }, failure: { [weak self] _ in
                self?.notifyMigrationError()
            })
    }

    /// Delete all the records related to the tag on RealmDB.
    /// If these delete operations are not completed return migration error because these redundant data
    /// will cause unexpected behaviour.
    private func deleteRealmRecords(pair: RuuviTagPropertiesDaemonPair) {
        realmPersistence.deleteAllRecords(pair.device.uuid).on(success: { [weak self] _ in
            self?.realmPersistence.deleteLatest(pair.device.uuid).on(success: { _ in
                self?.realmPersistence.delete(pair.ruuviTag.withoutMac()).on(success: { _ in
                    self?.realmPersistence.deleteOffsetCorrection(ruuviTag:
                                                                    pair.ruuviTag.withoutMac()).on(completion: {
                        self?.isMigrating = false
                        self?.isLoading = false
                    })
                }, failure: { [weak self] _ in
                    self?.notifyMigrationError()
                })
            }, failure: { [weak self] _ in
                self?.notifyMigrationError()
            })
        }, failure: { [weak self] _ in
            self?.notifyMigrationError()
        })
    }

    private func notifyMigrationError() {
        isMigrating = false
        isLoading = false
        isMigrationFailed = true
    }

    // Migration ends

    func checkBatteryState(completion: @escaping(Bool) -> Void ) {
        let batteryStatusProvider = RuuviTagBatteryStatusProvider()
        ruuviStorage
            .readLatest(ruuviTag)
            .on(success: { record in
                let batteryNeedsReplacement = batteryStatusProvider
                    .batteryNeedsReplacement(temperature: record?.temperature,
                                             voltage: record?.voltage)
                completion(batteryNeedsReplacement)
            }, failure: { _ in
                completion(false)
            })
    }
}

extension DFUViewModel {
    enum State {
        case idle
        case loading
        case loaded(LatestRelease)
        case serving(LatestRelease)
        case checking(LatestRelease, CurrentRelease?)
        case noNeedToUpgrade(LatestRelease, CurrentRelease?)
        case isAbleToUpgrade(LatestRelease, CurrentRelease?)
        case reading(LatestRelease, CurrentRelease?)
        case downloading(LatestRelease, CurrentRelease?)
        case listening(
                LatestRelease,
                CurrentRelease?,
                appUrl: URL,
                fullUrl: URL
             )
        case readyToUpdate(
                LatestRelease,
                CurrentRelease?,
                uuid: String,
                appUrl: URL,
                fullUrl: URL
             )
        case flashing(
                LatestRelease,
                CurrentRelease?,
                uuid: String,
                appUrl: URL,
                fullUrl: URL
             )
        case successfulyFlashed(LatestRelease)
        case servingAfterUpdate(LatestRelease)
        case firmwareAfterUpdate(CurrentRelease?)
        case error(Error)
    }

    enum Event {
        case onAppear
        case onLoaded(LatestRelease)
        case onDidFailLoading(Error)
        case onServed(CurrentRelease?)
        case onLoadedAndServed(LatestRelease, CurrentRelease?)
        case onStartUpgrade(LatestRelease, CurrentRelease?)
        case onRead(
                LatestRelease,
                CurrentRelease?,
                appUrl: URL,
                fullUrl: URL
             )
        case onDidFailReading(LatestRelease, CurrentRelease?, Error)
        case onDownloading(LatestRelease, CurrentRelease?, Double)
        case onDownloaded(
                LatestRelease,
                CurrentRelease?,
                appUrl: URL,
                fullUrl: URL
             )
        case onDidFailDownloading(Error)
        case onHeardRuuviBootDevice(
                LatestRelease,
                CurrentRelease?,
                uuid: String,
                appUrl: URL,
                fullUrl: URL
             )
        case onLostRuuviBootDevice(
                LatestRelease,
                CurrentRelease?,
                uuid: String,
                appUrl: URL,
                fullUrl: URL
             )
        case onUserDidConfirmToFlash(
                LatestRelease,
                CurrentRelease?,
                uuid: String,
                appUrl: URL,
                fullUrl: URL
             )
        case onSuccessfullyFlashedFirmware(LatestRelease)
        case onServingAfterUpdate(CurrentRelease?)
        case onServedAfterUpdate(CurrentRelease?)
        case onDidFailFlashingFirmware(Error)
    }
}

extension DFUViewModel {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func reduce(_ state: State, _ event: Event) -> State {
        switch state {
        case .idle:
            switch event {
            case .onAppear:
                return .loading
            default:
                return state
            }
        case .loading:
            switch event {
            case let .onDidFailLoading(error):
                return .error(error)
            case let .onLoaded(latestRelease):
                return .loaded(latestRelease)
            default:
                return state
            }
        case let .loaded(latestRelease):
            return .serving(latestRelease)
        case let .serving(latestRelease):
            switch event {
            case let .onServed(currentRelease):
                return .checking(latestRelease, currentRelease)
            default:
                return state
            }
        case let .checking(latestRelease, currentRelease):
            if isRecommendedToUpdate(
                latestRelease: latestRelease,
                currentRelease: currentRelease
            ) {
                return .isAbleToUpgrade(latestRelease, currentRelease)
            } else {
                return .noNeedToUpgrade(latestRelease, currentRelease)
            }
        case .noNeedToUpgrade:
            return state
        case let .isAbleToUpgrade(latestRelease, currentRelease):
            return .reading(latestRelease, currentRelease)
        case .reading:
            switch event {
            case let .onRead(latestRelease, currentRelease, appUrl, fullUrl):
                return .listening(
                    latestRelease,
                    currentRelease,
                    appUrl: appUrl,
                    fullUrl: fullUrl
                )
            case let .onDidFailReading(latestRelease, currentRelease, _):
                return .downloading(latestRelease, currentRelease)
            default:
                return state
            }
        case .downloading:
            switch event {
            case let .onDownloaded(
                    latestRelease,
                    currentRelease,
                    appUrl,
                    fullUrl
            ):
                return .listening(
                    latestRelease,
                    currentRelease,
                    appUrl: appUrl,
                    fullUrl: fullUrl
                )
            default:
                return state
            }
        case .listening:
            switch event {
            case let .onHeardRuuviBootDevice(latestRelease, currentRelease, uuid, appUrl, fullUrl):
                return .readyToUpdate(latestRelease, currentRelease, uuid: uuid, appUrl: appUrl, fullUrl: fullUrl)
            default:
                return state
            }
        case .readyToUpdate:
            switch event {
            case let .onLostRuuviBootDevice(latestRelease, currentRelease, _, appUrl, fullUrl):
                return .listening(latestRelease, currentRelease, appUrl: appUrl, fullUrl: fullUrl)
            case let .onUserDidConfirmToFlash(latestRelease, currentRelease, uuid, appUrl, fullUrl):
                return .flashing(latestRelease, currentRelease, uuid: uuid, appUrl: appUrl, fullUrl: fullUrl)
            default:
                return state
            }
        case .flashing:
            switch event {
            case .onSuccessfullyFlashedFirmware(let latestRelease):
                return .successfulyFlashed(latestRelease)
            case .onDidFailFlashingFirmware(let error):
                return .error(error)
            default:
                return state
            }
        case .successfulyFlashed(let latestRelease):
            return .servingAfterUpdate(latestRelease)
        case .servingAfterUpdate:
            switch event {
            case let .onServedAfterUpdate(currentRelease):
                return .firmwareAfterUpdate(currentRelease)
            default:
                return state
            }
        case .error:
            return state
        case .firmwareAfterUpdate:
            return state
        }
    }

    static func isRecommendedToUpdate(
        latestRelease: LatestRelease,
        currentRelease: CurrentRelease?
    ) -> Bool {
        guard let currentRelease = currentRelease else { return true }
        return !currentRelease.version.contains(latestRelease.version)
    }

    func whenFlashing() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case let .flashing(
                    latestRelease,
                    currentRelease,
                    uuid,
                    appUrl,
                    fullUrl
            ) = state, let sSelf = self else {
                return Empty().eraseToAnyPublisher()
            }
            return sSelf.interactor.flash(
                uuid: uuid,
                latestRelease: latestRelease,
                currentRelease: currentRelease,
                appUrl: appUrl,
                fullUrl: fullUrl
            )
            .receive(on: RunLoop.main)
            .compactMap({ [weak sSelf] response in
                switch response {
                case .done:
                    return Event.onSuccessfullyFlashedFirmware(latestRelease)
                case .progress(let percentage):
                    sSelf?.flashProgress = percentage
                    return nil
                case .log:
                    return nil
                }
            })
            .catch { Just(Event.onDidFailFlashingFirmware($0)) }
            .eraseToAnyPublisher()
        }
    }

    func whenReadyToUpdate() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case let .readyToUpdate(latestRelease, currentRelease, uuid, appUrl, fullUrl) = state,
                  let sSelf = self else {
                return Empty().eraseToAnyPublisher()
            }
            return sSelf.interactor.observeLost(uuid: uuid)
                .receive(on: RunLoop.main)
                .map { uuid in
                    return Event.onLostRuuviBootDevice(
                        latestRelease,
                        currentRelease,
                        uuid: uuid,
                        appUrl: appUrl,
                        fullUrl: fullUrl
                    )
                }
                .eraseToAnyPublisher()
        }
    }

    func whenListening() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case let .listening(latestRelease, currentRelease, appUrl, fullUrl) = state,
                  let sSelf = self else {
                return Empty().eraseToAnyPublisher()
            }
            return sSelf.interactor.listen()
                .receive(on: RunLoop.main)
                .map { uuid in
                    return Event.onHeardRuuviBootDevice(
                        latestRelease,
                        currentRelease,
                        uuid: uuid,
                        appUrl: appUrl,
                        fullUrl: fullUrl
                    )
                }
                .eraseToAnyPublisher()
        }
    }

    func whenReading() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case let .reading(latestRelease, currentRelease) = state,
                  let sSelf = self else {
                return Empty().eraseToAnyPublisher()
            }
            return sSelf.interactor.read(release: latestRelease)
                .receive(on: RunLoop.main)
                .map { tuple in
                    return Event.onRead(
                        latestRelease,
                        currentRelease,
                        appUrl: tuple.appUrl,
                        fullUrl: tuple.fullUrl
                    )
                }
                .catch { error in Just(Event.onDidFailReading(latestRelease, currentRelease, error)) }
                .eraseToAnyPublisher()
        }
    }

    func whenServing() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case .serving = state, let sSelf = self else {
                return Empty().eraseToAnyPublisher()
            }
            return sSelf.interactor.serveCurrentRelease(for: sSelf.ruuviTag)
                .receive(on: RunLoop.main)
                .map(Event.onServed)
                .catch { _ in Just(Event.onServed(nil)) }
                .eraseToAnyPublisher()
        }
    }

    func whenLoading() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case .loading = state, let sSelf = self else {
                return Empty().eraseToAnyPublisher()
            }
            return sSelf.interactor.loadLatestRelease()
                .receive(on: RunLoop.main)
                .map(Event.onLoaded)
                .catch { Just(Event.onDidFailLoading($0)) }
                .eraseToAnyPublisher()
        }
    }

    func whenDownloading() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case let .downloading(latestRelease, currentRelease) = state, let sSelf = self else {
                return Empty().eraseToAnyPublisher()
            }
            return sSelf.interactor.download(release: latestRelease)
                .receive(on: RunLoop.main)
                .compactMap({ [weak sSelf] response in
                    switch response {
                    case let .response(appUrl, fullUrl):
                        return Event.onDownloaded(latestRelease, currentRelease, appUrl: appUrl, fullUrl: fullUrl)
                    case .progress(let progress):
                        sSelf?.downloadProgress = progress.fractionCompleted
                        return nil
                    }
                })
                .catch { Just(Event.onDidFailDownloading($0)) }
                .eraseToAnyPublisher()
        }
    }

    func whenFlashed() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case .successfulyFlashed = state, let sSelf = self else {
                return Empty().eraseToAnyPublisher()
            }
            return sSelf.interactor.serveCurrentRelease(for: sSelf.ruuviTag)
                .receive(on: RunLoop.main)
                .map(Event.onServingAfterUpdate)
                .catch { _ in Just(Event.onServingAfterUpdate(nil)) }
                .eraseToAnyPublisher()
        }
    }

    func whenServingAfterUpdate() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case .servingAfterUpdate = state, let sSelf = self else {
                return Empty().eraseToAnyPublisher()
            }
            return sSelf.interactor.serveCurrentRelease(for: sSelf.ruuviTag)
                .receive(on: RunLoop.main)
                .map(Event.onServedAfterUpdate)
                .catch { _ in Just(Event.onServedAfterUpdate(nil)) }
                .eraseToAnyPublisher()
        }
    }

    func userInput(input: AnyPublisher<Event, Never>) -> Feedback<State, Event> {
        Feedback(run: { _ in
            return input
        })
    }
}
