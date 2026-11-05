import Combine
import Foundation

public enum DownloadResponse {
    case progress(Progress)
    case response(fileUrl: URL)
}

public extension URLSession {
    func downloadTaskPublisher(for url: URL, progress: Progress) -> URLSession.DownloadTaskPublisher {
        downloadTaskPublisher(for: .init(url: url), progress: progress)
    }

    func downloadTaskPublisher(for request: URLRequest, progress: Progress) -> URLSession.DownloadTaskPublisher {
        .init(request: request, session: self, progress: progress)
    }

    struct DownloadTaskPublisher: Publisher {
        public typealias Output = DownloadResponse
        public typealias Failure = URLError

        public let request: URLRequest
        public let session: URLSession
        public let progress: Progress

        public init(request: URLRequest, session: URLSession, progress: Progress) {
            self.request = request
            self.session = session
            self.progress = progress
        }

        public func receive<S>(subscriber: S)
        where
            S: Subscriber,
            DownloadTaskPublisher.Failure == S.Failure,
            DownloadTaskPublisher.Output == S.Input
        {
            let subscription = DownloadTaskSubscription(
                subscriber: subscriber,
                session: session,
                request: request,
                progress: progress
            )
            subscriber.receive(subscription: subscription)
        }
    }
}

extension URLSession {
    final class DownloadTaskSubscription<SubscriberType: Subscriber>: Subscription
    where
        SubscriberType.Input == DownloadResponse,
        SubscriberType.Failure == URLError
    {
        private let lock = NSRecursiveLock()
        private var subscriber: SubscriberType?
        private var session: URLSession?
        private let request: URLRequest
        private let progress: Progress
        private var task: URLSessionDownloadTask?
        private var observation: NSKeyValueObservation?
        private var demand: Subscribers.Demand = .none
        private var started = false
        private var pendingFile: URL?

        init(subscriber: SubscriberType, session: URLSession, request: URLRequest, progress: Progress) {
            self.subscriber = subscriber
            self.session = session
            self.request = request
            self.progress = progress
        }

        deinit { cancel() }

        func request(_ newDemand: Subscribers.Demand) {
            lock.lock()
            defer { lock.unlock() }
            guard newDemand > .none, subscriber != nil else { return }
            demand += newDemand
            if !started {
                started = true
                let download = session?.downloadTask(with: request) { [weak self] url, response, error in
                    self?.complete(url: url, response: response, error: error)
                }
                guard let download else { return }
                task = download
                progress.addChild(download.progress, withPendingUnitCount: 1)
                observation = progress.observe(\.fractionCompleted) { [weak self] progress, _ in
                    self?.sendProgress(progress)
                }
                download.resume()
            }
            deliverFileIfRequested()
        }

        func cancel() {
            lock.lock()
            defer { lock.unlock() }
            subscriber = nil
            observation?.invalidate()
            observation = nil
            let download = task
            task = nil
            session = nil
            if let pendingFile { try? FileManager.default.removeItem(at: pendingFile) }
            pendingFile = nil
            download?.cancel()
        }

        private func sendProgress(_ progress: Progress) {
            lock.lock()
            defer { lock.unlock() }
            guard let subscriber, demand > .none, pendingFile == nil else { return }
            demand -= 1
            demand += subscriber.receive(.progress(progress))
        }

        private func complete(url: URL?, response: URLResponse?, error: Error?) {
            lock.lock()
            defer { lock.unlock() }
            guard subscriber != nil, pendingFile == nil else { return }
            if let error {
                finish(.failure(error as? URLError ?? URLError(.unknown, userInfo: [NSUnderlyingErrorKey: error])))
                return
            }
            guard let response,
                (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true
            else {
                finish(.failure(URLError(.badServerResponse)))
                return
            }
            guard let url else {
                finish(.failure(URLError(.badURL)))
                return
            }
            do {
                let cache = try FileManager.default.url(
                    for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                let saved = cache.appendingPathComponent(UUID().uuidString)
                try FileManager.default.moveItem(at: url, to: saved)
                pendingFile = saved
                observation?.invalidate()
                observation = nil
                task = nil
                session = nil
                deliverFileIfRequested()
            } catch {
                finish(.failure(URLError(.cannotCreateFile, userInfo: [NSUnderlyingErrorKey: error])))
            }
        }

        private func deliverFileIfRequested() {
            guard let subscriber, let file = pendingFile, demand > .none else { return }
            pendingFile = nil
            demand -= 1
            // The receiver owns the file once it has been delivered, even if it cancels here.
            _ = subscriber.receive(.response(fileUrl: file))
            finish(.finished)
        }

        private func finish(_ completion: Subscribers.Completion<URLError>) {
            let receiver = subscriber
            subscriber = nil
            observation?.invalidate()
            observation = nil
            task = nil
            session = nil
            receiver?.receive(completion: completion)
        }
    }
}
