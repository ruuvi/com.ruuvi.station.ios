// swiftlint:disable file_length
import BTKit
import Combine
import Foundation
import RuuviCore
import RuuviDaemon
import RuuviFirmware
import RuuviLocal
import RuuviOntology
import RuuviPersistence
import RuuviPool
import RuuviPresenters
import RuuviStorage
import RuuviDFU

protocol DFUViewModelOutput: AnyObject {
    func firmwareUpgradeDidFinishSuccessfully()
}

final class DFUViewModel: ObservableObject {
    @Published private(set) var state: State = .idle
    @Published var downloadProgress: Double = 0
    @Published var flashProgress: Double = 0
    @Published var isMigrationFailed: Bool = false

    var output: DFUViewModelOutput?

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

    func finish() {
        output?.firmwareUpgradeDidFinishSuccessfully()
    }

    func storeUpdatedFirmware(
        latestRelease: LatestRelease,
        currentRelease: CurrentRelease?
    ) {
        guard ruuviTag.luid != nil else { return }
        if ruuviTag.macId != nil {
            var updatedVersion: String?
            if let currentVersion = currentRelease?.version {
                updatedVersion = currentVersion
            } else {
                let firmwareType = RuuviFirmwareVersion.firmwareVersion(
                    from: ruuviTag.version
                )
                let prefix = (
                    firmwareType == .e1 || firmwareType == .v6
                ) ? RuuviDeviceType.ruuviAir.fwVersionPrefix :
                    RuuviDeviceType.ruuviTag.fwVersionPrefix
                updatedVersion = prefix + " " + latestRelease.version
            }
            guard let updatedVersion = updatedVersion else { return }
            isLoading = true
            ruuviPool.update(ruuviTag
                .with(isConnectable: true)
                .with(firmwareVersion: updatedVersion))
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

    func isRuuviAir() -> Bool {
        let firmwareVersion = RuuviFirmwareVersion.firmwareVersion(
            from: ruuviTag.version
        )
        return firmwareVersion == .e1 || firmwareVersion == .v6
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
            dfuDevice: DFUDevice,
            appUrl: URL,
            fullUrl: URL
        )
        case flashing(
            LatestRelease,
            CurrentRelease?,
            dfuDevice: DFUDevice,
            appUrl: URL,
            fullUrl: URL
        )
        case successfulyFlashed(LatestRelease)
        case servingAfterUpdate(LatestRelease)
        case firmwareAfterUpdate(LatestRelease, CurrentRelease?)
        case error(Error)
    }

    enum Event {
        case onAppear
        case onLoaded(LatestRelease)
        case onDidFailLoading(Error)
        case onServed(CurrentRelease?)
        case onLoadedAndServed(LatestRelease, CurrentRelease?)
        case onStartUpgrade(LatestRelease, CurrentRelease?)
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
            dfuDevice: DFUDevice,
            appUrl: URL,
            fullUrl: URL
        )
        case onLostRuuviBootDevice(
            LatestRelease,
            CurrentRelease?,
            dfuDevice: DFUDevice,
            appUrl: URL,
            fullUrl: URL
        )
        case onUserDidConfirmToFlash(
            LatestRelease,
            CurrentRelease?,
            dfuDevice: DFUDevice,
            appUrl: URL,
            fullUrl: URL
        )
        case onSuccessfullyFlashedFirmware(LatestRelease)
        case onServingAfterUpdate(LatestRelease, CurrentRelease?)
        case onServedAfterUpdate(LatestRelease, CurrentRelease?)
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
            .downloading(latestRelease, currentRelease)
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
            case let .onHeardRuuviBootDevice(latestRelease, currentRelease, dfuDevice, appUrl, fullUrl):
                .readyToUpdate(latestRelease, currentRelease, dfuDevice: dfuDevice, appUrl: appUrl, fullUrl: fullUrl)
            default:
                state
            }
        case .readyToUpdate:
            switch event {
            case let .onLostRuuviBootDevice(latestRelease, currentRelease, _, appUrl, fullUrl):
                .listening(latestRelease, currentRelease, appUrl: appUrl, fullUrl: fullUrl)
            case let .onUserDidConfirmToFlash(latestRelease, currentRelease, dfuDevice, appUrl, fullUrl):
                .flashing(latestRelease, currentRelease, dfuDevice: dfuDevice, appUrl: appUrl, fullUrl: fullUrl)
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
            case let .onServedAfterUpdate(latestRelease, currentRelease):
                .firmwareAfterUpdate(latestRelease, currentRelease)
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
        let latestVersion = latestRelease.version.semVar
        let currentVersion = currentRelease.version.semVar

        // If parsing fails, assume update is recommended
        guard let latest = latestVersion, let current = currentVersion else {
            return true
        }

        return Array.compareVersions(latest, current) == .orderedDescending
    }

    func whenFlashing() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case let .flashing(
                latestRelease,
                currentRelease,
                dfuDevice,
                appUrl,
                fullUrl
            ) = state, let sSelf = self
            else {
                return Empty().eraseToAnyPublisher()
            }
            return sSelf.interactor.flash(
                dfuDevice: dfuDevice,
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
            guard case let .readyToUpdate(latestRelease, currentRelease, dfuDevice, appUrl, fullUrl) = state,
                  let sSelf = self
            else {
                return Empty().eraseToAnyPublisher()
            }
            return sSelf.interactor.observeLost(uuid: dfuDevice.uuid)
                .receive(on: RunLoop.main)
                .map { _ in
                    Event.onLostRuuviBootDevice(
                        latestRelease,
                        currentRelease,
                        dfuDevice: dfuDevice,
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
            return sSelf.interactor.listen(ruuviTag: sSelf.ruuviTag)
                .receive(on: RunLoop.main)
                .map { dfuDevice in
                    return Event.onHeardRuuviBootDevice(
                        latestRelease,
                        currentRelease,
                        dfuDevice: dfuDevice,
                        appUrl: appUrl,
                        fullUrl: fullUrl
                    )
                }
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
            guard case let .successfulyFlashed(latestRelease) = state, let sSelf = self
            else {
                return Empty().eraseToAnyPublisher()
            }

            let firmwareType = RuuviFirmwareVersion.firmwareVersion(
                from: sSelf.ruuviTag.version
            )

            // It does not make sense to wait for E1/V6 since they can take several
            // seconds to boot and we should not hold connection until then.
            let skipCheckingCurrentRelease = firmwareType == .e1 || firmwareType == .v6
            if skipCheckingCurrentRelease {
                return Just(
                    Event.onServedAfterUpdate(latestRelease, nil)
                ).eraseToAnyPublisher()
            }

            return sSelf.interactor.serveCurrentRelease(for: sSelf.ruuviTag)
                .receive(on: RunLoop.main)
                .map { currentRelease in
                    Event.onServingAfterUpdate(latestRelease, currentRelease)
                }
                .catch { _ in
                    Just(Event.onServingAfterUpdate(latestRelease, nil))
                }
                .eraseToAnyPublisher()
        }
    }

    func whenServingAfterUpdate() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case let .servingAfterUpdate(latestRelease) = state, let sSelf = self
            else {
                return Empty().eraseToAnyPublisher()
            }

            let firmwareType = RuuviFirmwareVersion.firmwareVersion(
                from: sSelf.ruuviTag.version
            )

            // It does not make sense to wait for E1/V6 since they can take several
            // seconds to boot and we should not hold connection until then.
            let skipCheckingCurrentRelease = firmwareType == .e1 || firmwareType == .v6
            if skipCheckingCurrentRelease {
                return Just(
                    Event.onServedAfterUpdate(latestRelease, nil)
                ).eraseToAnyPublisher()
            }

            return sSelf.interactor.serveCurrentRelease(for: sSelf.ruuviTag)
                .receive(on: RunLoop.main)
                .map { currentRelease in
                    Event.onServedAfterUpdate(latestRelease, currentRelease)
                }
                .catch { _ in
                    Just(Event.onServedAfterUpdate(latestRelease, nil))
                }
                .eraseToAnyPublisher()
        }
    }

    func userInput(input: AnyPublisher<Event, Never>) -> Feedback<State, Event> {
        Feedback(run: { _ in
            input
        })
    }
}
