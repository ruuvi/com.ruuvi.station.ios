import Combine
import Foundation

protocol FirmwareViewModelOutput: AnyObject {
    func firmwareUpgradeDidFinishSuccessfully()
}

final class FirmwareViewModel: ObservableObject {
    @Published private(set) var state: State = .idle
    @Published var downloadProgress: Double = 0
    @Published var flashProgress: Double = 0
    var output: FirmwareViewModelOutput?
    private let input = PassthroughSubject<Event, Never>()
    private let uuid: String
    private var currentFirmware: String?
    private let interactor: FirmwareInteractor
    private var bag = Set<AnyCancellable>()
    
    init(
        uuid: String,
        currentFirmware: String?,
        interactor: FirmwareInteractor
    ) {
        self.uuid = uuid
        self.currentFirmware = currentFirmware
        self.interactor = interactor
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

    func send(event: Event) {
        input.send(event)
    }
    
    func finish() {
        output?.firmwareUpgradeDidFinishSuccessfully()
    }
}

// MARK: - Feedbacks
extension FirmwareViewModel {
    func userInput(input: AnyPublisher<Event, Never>) -> Feedback<State, Event> {
        Feedback { _ in
            return input
        }
    }

    func whenLoading() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case .loading = state, let self else {
                return Empty().eraseToAnyPublisher()
            }
            return self.interactor.loadLatestGitHubRelease()
                .receive(on: RunLoop.main)
                .map(Event.onLoaded)
                .catch { Just(Event.onDidFailLoading($0)) }
                .eraseToAnyPublisher()
        }
    }
    
    func whenServing() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case .serving = state, let self else {
                return Empty().eraseToAnyPublisher()
            }
            if let currentFirmware = self.currentFirmware {
                return Just(CurrentRelease(version: currentFirmware))
                    .map(Event.onServed)
                    .eraseToAnyPublisher()
            } else {
                return self.interactor.serveCurrentRelease(uuid: self.uuid)
                    .receive(on: RunLoop.main)
                    .map(Event.onServed)
                    .catch { _ in Just(Event.onServed(nil)) }
                    .eraseToAnyPublisher()
            }
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
    
    func whenDownloading() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case let .downloading(latestRelease, currentRelease) = state, let self else {
                return Empty().eraseToAnyPublisher()
            }
            return self.interactor.download(release: latestRelease)
                .receive(on: RunLoop.main)
                .compactMap({ [weak self] response in
                    switch response {
                    case let .response(appUrl, fullUrl):
                        return Event.onDownloaded(latestRelease, currentRelease, appUrl: appUrl, fullUrl: fullUrl)
                    case .progress(let progress):
                        self?.downloadProgress = progress.fractionCompleted
                        return nil
                    }
                })
                .catch { Just(Event.onDidFailDownloading($0)) }
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
}

extension FirmwareViewModel {
    enum State {
        case idle
        case loading
        case loaded(GitHubRelease)
        case serving(GitHubRelease)
        case checking(GitHubRelease, CurrentRelease?)
        case noNeedToUpgrade(GitHubRelease, CurrentRelease?)
        case isAbleToUpgrade(GitHubRelease, CurrentRelease?)
        case reading(GitHubRelease, CurrentRelease?)
        case downloading(GitHubRelease, CurrentRelease?)
        case listening(
            GitHubRelease,
            CurrentRelease?,
            appUrl: URL,
            fullUrl: URL
        )
        case readyToUpdate(
            GitHubRelease,
            CurrentRelease?,
            uuid: String,
            appUrl: URL,
            fullUrl: URL
        )
        case flashing(
            GitHubRelease,
            CurrentRelease?,
            uuid: String,
            appUrl: URL,
            fullUrl: URL
        )
        case successfulyFlashed(GitHubRelease)
        case error(Error)
    }

    enum Event {
        case onAppear
        case onLoaded(GitHubRelease)
        case onDidFailLoading(Error)
        case onServed(CurrentRelease?)
        case onLoadedAndServed(GitHubRelease, CurrentRelease?)
        case onStartUpgrade(GitHubRelease, CurrentRelease?)
        case onRead(
            GitHubRelease,
            CurrentRelease?,
            appUrl: URL,
            fullUrl: URL
        )
        case onDidFailReading(GitHubRelease, CurrentRelease?, Error)
        case onDownloading(GitHubRelease, CurrentRelease?, Double)
        case onDownloaded(
            GitHubRelease,
            CurrentRelease?,
            appUrl: URL,
            fullUrl: URL
        )
        case onDidFailDownloading(Error)
        case onHeardRuuviBootDevice(
            GitHubRelease,
            CurrentRelease?,
            uuid: String,
            appUrl: URL,
            fullUrl: URL
        )
        case onLostRuuviBootDevice(
            GitHubRelease,
            CurrentRelease?,
            uuid: String,
            appUrl: URL,
            fullUrl: URL
        )
        case onUserDidConfirmToFlash(
            GitHubRelease,
            CurrentRelease?,
            uuid: String,
            appUrl: URL,
            fullUrl: URL
        )
        case onSuccessfullyFlashedFirmware(GitHubRelease)
        case onServedAfterUpdate(CurrentRelease?)
        case onDidFailFlashingFirmware(Error)
    }
}

extension FirmwareViewModel {
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
        latestRelease: GitHubRelease,
        currentRelease: CurrentRelease?
    ) -> Bool {
        guard let currentRelease = currentRelease else { return true }
        return !currentRelease.version.contains(latestRelease.version)
    }
}
