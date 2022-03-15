// swiftlint:disable file_length
import Foundation
import Combine
import RuuviOntology
import RuuviPool
import RuuviLocal

final class DFUViewModel: ObservableObject {
    @Published private(set) var state: State = .idle
    @Published var downloadProgress: Double = 0
    @Published var flashProgress: Double = 0

    private var bag = Set<AnyCancellable>()
    private let input = PassthroughSubject<Event, Never>()
    private let interactor: DFUInteractorInput
    private let ruuviTag: RuuviTagSensor
    private let ruuviPool: RuuviPool
    private let settings: RuuviLocalSettings

    init(
        interactor: DFUInteractorInput,
        ruuviTag: RuuviTagSensor,
        ruuviPool: RuuviPool,
        settings: RuuviLocalSettings
    ) {
        self.interactor = interactor
        self.ruuviTag = ruuviTag
        self.ruuviPool = ruuviPool
        self.settings = settings
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
                self.userInput(input: input.eraseToAnyPublisher())
            ]
        )
        .assign(to: \.state, on: self)
        .store(in: &bag)
    }

    deinit {
        bag.removeAll()
    }

    func send(event: Event) {
        input.send(event)
    }
    /// Update the localdb only when the tag data format is not "Very Old"
    /// Otherwise a migration to realm to sqlite is needed since older data format tags are stored in the realm db
    /// before trying to update the db record
    func storeUpdatedFirmware(latestRelease: LatestRelease) {
        guard let luid = ruuviTag.luid else { return }
        guard settings.firmwareVersion(for: luid) != nil else { return }
        ruuviPool.update(ruuviTag
                            .with(firmwareVersion: latestRelease.version.replace("Ruuvi FW ", with: "")))
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
        case .successfulyFlashed:
            return state
        case .error:
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

    func userInput(input: AnyPublisher<Event, Never>) -> Feedback<State, Event> {
        Feedback(run: { _ in
            return input
        })
    }
}
