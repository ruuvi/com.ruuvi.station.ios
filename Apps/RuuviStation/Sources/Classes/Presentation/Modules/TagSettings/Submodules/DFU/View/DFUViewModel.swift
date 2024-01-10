// swiftlint:disable file_length
import BTKit
import Combine
import Foundation
import RuuviDaemon
import RuuviFirmware
import RuuviLocal
import RuuviOntology
import RuuviPersistence
import RuuviPool
import RuuviPresenters
import RuuviStorage

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
    private let sqiltePersistence: RuuviPersistence
    private let ruuviTag: RuuviTagSensor
    private let ruuviPool: RuuviPool
    private let ruuviStorage: RuuviStorage
    private let settings: RuuviLocalSettings
    private let propertiesDaemon: RuuviTagPropertiesDaemon
    private let activityPresenter: ActivityPresenter
    private var ruuviTagObserveToken: ObservationToken?
    private var isMigrating: Bool = false
    private let timeoutDuration: Int = 15

    var isLoading: Bool = false {
        didSet {
            isLoading ? activityPresenter.show(with: .loading(message: nil)) : activityPresenter.dismiss()
        }
    }

    init(
        interactor: DFUInteractorInput,
        foreground: BTForeground,
        idPersistence: RuuviLocalIDs,
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
                whenLoading(),
                whenServing(),
                whenReading(),
                whenDownloading(),
                whenListening(),
                whenReadyToUpdate(),
                whenFlashing(),
                whenFlashed(),
                whenServingAfterUpdate(),
                userInput(input: input.eraseToAnyPublisher()),
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
        if ruuviTag.macId != nil {
            guard let currentRelease
            else {
                return
            }
            isLoading = true
            ruuviPool.update(ruuviTag
                .with(isConnectable: true)
                .with(firmwareVersion: currentRelease.version))
                .on(success: { [weak self] _ in
                    self?.isLoading = false
                }, failure: { [weak self] _ in
                    self?.isLoading = false
                })
        } else {
            assertionFailure()
        }
    }

    func storeCurrentFirmwareVersion(from currentRelease: CurrentRelease?) {
        guard ruuviTag.firmwareVersion == nil ||
            !ruuviTag.firmwareVersion.hasText(),
            let currentRelease
        else {
            return
        }
        ruuviPool.update(ruuviTag
            .with(isConnectable: true)
            .with(firmwareVersion: currentRelease.version))
    }

    // Migration ends

    func checkBatteryState(completion: @escaping (Bool) -> Void) {
        let batteryStatusProvider = RuuviTagBatteryStatusProvider()
        ruuviStorage
            .readLatest(ruuviTag)
            .on(success: { record in
                let batteryNeedsReplacement = batteryStatusProvider
                    .batteryNeedsReplacement(
                        temperature: record?.temperature,
                        voltage: record?.voltage
                    )
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
                .loading
            default:
                state
            }
        case .loading:
            switch event {
            case let .onDidFailLoading(error):
                .error(error)
            case let .onLoaded(latestRelease):
                .loaded(latestRelease)
            default:
                state
            }
        case let .loaded(latestRelease):
            .serving(latestRelease)
        case let .serving(latestRelease):
            switch event {
            case let .onServed(currentRelease):
                .checking(latestRelease, currentRelease)
            default:
                state
            }
        case let .checking(latestRelease, currentRelease):
            if isRecommendedToUpdate(
                latestRelease: latestRelease,
                currentRelease: currentRelease
            ) {
                .isAbleToUpgrade(latestRelease, currentRelease)
            } else {
                .noNeedToUpgrade(latestRelease, currentRelease)
            }
        case .noNeedToUpgrade:
            state
        case let .isAbleToUpgrade(latestRelease, currentRelease):
            .reading(latestRelease, currentRelease)
        case .reading:
            switch event {
            case let .onRead(latestRelease, currentRelease, appUrl, fullUrl):
                .listening(
                    latestRelease,
                    currentRelease,
                    appUrl: appUrl,
                    fullUrl: fullUrl
                )
            case let .onDidFailReading(latestRelease, currentRelease, _):
                .downloading(latestRelease, currentRelease)
            default:
                state
            }
        case .downloading:
            switch event {
            case let .onDownloaded(
                latestRelease,
                currentRelease,
                appUrl,
                fullUrl
            ):
                .listening(
                    latestRelease,
                    currentRelease,
                    appUrl: appUrl,
                    fullUrl: fullUrl
                )
            default:
                state
            }
        case .listening:
            switch event {
            case let .onHeardRuuviBootDevice(latestRelease, currentRelease, uuid, appUrl, fullUrl):
                .readyToUpdate(latestRelease, currentRelease, uuid: uuid, appUrl: appUrl, fullUrl: fullUrl)
            default:
                state
            }
        case .readyToUpdate:
            switch event {
            case let .onLostRuuviBootDevice(latestRelease, currentRelease, _, appUrl, fullUrl):
                .listening(latestRelease, currentRelease, appUrl: appUrl, fullUrl: fullUrl)
            case let .onUserDidConfirmToFlash(latestRelease, currentRelease, uuid, appUrl, fullUrl):
                .flashing(latestRelease, currentRelease, uuid: uuid, appUrl: appUrl, fullUrl: fullUrl)
            default:
                state
            }
        case .flashing:
            switch event {
            case let .onSuccessfullyFlashedFirmware(latestRelease):
                .successfulyFlashed(latestRelease)
            case let .onDidFailFlashingFirmware(error):
                .error(error)
            default:
                state
            }
        case let .successfulyFlashed(latestRelease):
            .servingAfterUpdate(latestRelease)
        case .servingAfterUpdate:
            switch event {
            case let .onServedAfterUpdate(currentRelease):
                .firmwareAfterUpdate(currentRelease)
            default:
                state
            }
        case .error:
            state
        case .firmwareAfterUpdate:
            state
        }
    }

    static func isRecommendedToUpdate(
        latestRelease: LatestRelease,
        currentRelease: CurrentRelease?
    ) -> Bool {
        guard let currentRelease else { return true }
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
            ) = state, let sSelf = self
            else {
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
            .compactMap { [weak sSelf] response in
                switch response {
                case .done:
                    return Event.onSuccessfullyFlashedFirmware(latestRelease)
                case let .progress(percentage):
                    sSelf?.flashProgress = percentage
                    return nil
                case .log:
                    return nil
                }
            }
            .catch { Just(Event.onDidFailFlashingFirmware($0)) }
            .eraseToAnyPublisher()
        }
    }

    func whenReadyToUpdate() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case let .readyToUpdate(latestRelease, currentRelease, uuid, appUrl, fullUrl) = state,
                  let sSelf = self
            else {
                return Empty().eraseToAnyPublisher()
            }
            return sSelf.interactor.observeLost(uuid: uuid)
                .receive(on: RunLoop.main)
                .map { uuid in
                    Event.onLostRuuviBootDevice(
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
                  let sSelf = self
            else {
                return Empty().eraseToAnyPublisher()
            }
            return sSelf.interactor.listen()
                .receive(on: RunLoop.main)
                .map { uuid in
                    Event.onHeardRuuviBootDevice(
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
                  let sSelf = self
            else {
                return Empty().eraseToAnyPublisher()
            }
            return sSelf.interactor.read(release: latestRelease)
                .receive(on: RunLoop.main)
                .map { tuple in
                    Event.onRead(
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
            guard case .serving = state, let sSelf = self
            else {
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
            guard case .loading = state, let sSelf = self
            else {
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
            guard case let .downloading(latestRelease, currentRelease) = state, let sSelf = self
            else {
                return Empty().eraseToAnyPublisher()
            }
            return sSelf.interactor.download(release: latestRelease)
                .receive(on: RunLoop.main)
                .compactMap { [weak sSelf] response in
                    switch response {
                    case let .response(appUrl, fullUrl):
                        return Event.onDownloaded(latestRelease, currentRelease, appUrl: appUrl, fullUrl: fullUrl)
                    case let .progress(progress):
                        sSelf?.downloadProgress = progress.fractionCompleted
                        return nil
                    }
                }
                .catch { Just(Event.onDidFailDownloading($0)) }
                .eraseToAnyPublisher()
        }
    }

    func whenFlashed() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case .successfulyFlashed = state, let sSelf = self
            else {
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
            guard case .servingAfterUpdate = state, let sSelf = self
            else {
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
            input
        })
    }
}
