import Combine
import Foundation
import RuuviCore
import RuuviOntology

protocol FirmwareViewModelOutput: AnyObject {
    func firmwareUpgradeDidFinishSuccessfully()
}

final class FirmwareViewModel: ObservableObject {
    @Published private(set) var state: State = .idle
    @Published var downloadProgress: Double = 0
    @Published var flashProgress: Double = 0
    @Published var isBatteryLow: Bool = false

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
        self.currentFirmware = currentFirmware.ruuviFirmwareDisplayValue ?? currentFirmware
        self.interactor = interactor
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
                userInput(input: input.eraseToAnyPublisher()),
            ]
        )
        .assign(to: \.state, on: self)
        .store(in: &bag)

        interactor.batteryIsLow.assign(to: &$isBatteryLow)
    }

    func send(event: Event) {
        input.send(event)
    }

    func finish() {
        output?.firmwareUpgradeDidFinishSuccessfully()
    }

    func ensureBatteryHasEnoughPower(uuid: String) {
        interactor.ensureBatteryHasEnoughPower(uuid: uuid)
    }

    func restartPropertiesDaemon() {
        interactor.restartPropertiesDaemon()
    }
}

// MARK: - Feedbacks

extension FirmwareViewModel {
    func userInput(input: AnyPublisher<Event, Never>) -> Feedback<State, Event> {
        Feedback { _ in
            input
        }
    }

    func whenLoading() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case .loading = state, let self
            else {
                return Empty().eraseToAnyPublisher()
            }
            return interactor.loadLatestGitHubRelease()
                .receive(on: RunLoop.main)
                .map(Event.onLoaded)
                .catch { Just(Event.onDidFailLoading($0)) }
                .eraseToAnyPublisher()
        }
    }

    func whenServing() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case .serving = state, let self
            else {
                return Empty().eraseToAnyPublisher()
            }
            if let currentFirmware {
                return Just(CurrentRelease(version: currentFirmware))
                    .map(Event.onServed)
                    .eraseToAnyPublisher()
            } else {
                let interactor = interactor
                let uuid = uuid
                return asyncThrowingPublisher {
                    try await interactor.serveCurrentRelease(uuid: uuid)
                }
                    .receive(on: RunLoop.main)
                    .map(Event.onServed)
                    .catch { _ in Just(Event.onServed(nil)) }
                    .eraseToAnyPublisher()
            }
        }
    }

    func whenDownloading() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case let .downloading(latestRelease, currentRelease) = state, let self
            else {
                return Empty().eraseToAnyPublisher()
            }
            return interactor.download(release: latestRelease)
                .receive(on: RunLoop.main)
                .compactMap { [weak self] response in
                    switch response {
                    case let .response(appUrl, fullUrl):
                        return Event.onDownloaded(latestRelease, currentRelease, appUrl: appUrl, fullUrl: fullUrl)
                    case let .progress(progress):
                        self?.downloadProgress = progress.fractionCompleted
                        return nil
                    }
                }
                .catch { Just(Event.onDidFailDownloading($0)) }
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
            let interactor = sSelf.interactor
            return sSelf.asyncPublisher {
                await interactor.listen()
            }
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

    func whenReadyToUpdate() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case let .readyToUpdate(latestRelease, currentRelease, uuid, appUrl, fullUrl) = state,
                  let sSelf = self
            else {
                return Empty().eraseToAnyPublisher()
            }
            let interactor = sSelf.interactor
            return sSelf.asyncPublisher {
                await interactor.observeLost(uuid: uuid)
            }
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
        case .successfulyFlashed:
            state
        case .error:
            state
        }
    }

    static func isRecommendedToUpdate(
        latestRelease: GitHubRelease,
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
}

private extension FirmwareViewModel {
    func asyncPublisher<T>(_ operation: @escaping () async -> T) -> AnyPublisher<T, Never> {
        Deferred {
            let subject = PassthroughSubject<T, Never>()
            let task = Task {
                let value = await operation()
                subject.send(value)
                subject.send(completion: .finished)
            }
            return subject
                .handleEvents(receiveCancel: { task.cancel() })
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    func asyncThrowingPublisher<T>(
        _ operation: @escaping () async throws -> T
    ) -> AnyPublisher<T, Error> {
        Deferred {
            let subject = PassthroughSubject<T, Error>()
            let task = Task {
                do {
                    let value = try await operation()
                    subject.send(value)
                    subject.send(completion: .finished)
                } catch {
                    subject.send(completion: .failure(error))
                }
            }
            return subject
                .handleEvents(receiveCancel: { task.cancel() })
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
}
