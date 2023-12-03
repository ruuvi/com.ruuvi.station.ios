import Combine

public struct Feedback<State, Event> {
    public let run: (AnyPublisher<State, Never>) -> AnyPublisher<Event, Never>
    public init(run: @escaping (AnyPublisher<State, Never>) -> AnyPublisher<Event, Never>) {
        self.run = run
    }
}

public extension Feedback {
    init<Effect: Publisher>(
        effects: @escaping (State) -> Effect
    ) where Effect.Output == Event, Effect.Failure == Never {
        self.run = { state -> AnyPublisher<Event, Never> in
            state
                .map { effects($0) }
                .switchToLatest()
                .eraseToAnyPublisher()
        }
    }
}
