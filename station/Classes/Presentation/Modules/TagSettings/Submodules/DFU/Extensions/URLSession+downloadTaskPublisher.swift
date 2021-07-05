import Foundation
import Combine

public enum DownloadResponse {
    case progress(Progress)
    case response(fileUrl: URL)
}

extension URLSession {
    public func downloadTaskPublisher(for url: URL, progress: Progress) -> URLSession.DownloadTaskPublisher {
        self.downloadTaskPublisher(for: .init(url: url), progress: progress)
    }

    public func downloadTaskPublisher(for request: URLRequest, progress: Progress) -> URLSession.DownloadTaskPublisher {
        .init(request: request, session: self, progress: progress)
    }

    public struct DownloadTaskPublisher: Publisher {
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

        public func receive<S>(subscriber: S) where S: Subscriber,
            DownloadTaskPublisher.Failure == S.Failure,
            DownloadTaskPublisher.Output == S.Input {
            let subscription = DownloadTaskSubscription(
                subscriber: subscriber,
                session: self.session,
                request: self.request,
                progress: self.progress
            )
            subscriber.receive(subscription: subscription)
        }
    }
}

extension URLSession {
    final class DownloadTaskSubscription<SubscriberType: Subscriber>: Subscription where
        SubscriberType.Input == DownloadResponse,
        SubscriberType.Failure == URLError {
        private var subscriber: SubscriberType?
        private weak var session: URLSession?
        private var request: URLRequest
        private var progress: Progress
        private var task: URLSessionDownloadTask?
        private var observation: NSKeyValueObservation?

        deinit {
            observation?.invalidate()
        }

        init(
            subscriber: SubscriberType,
            session: URLSession,
            request: URLRequest,
            progress: Progress
        ) {
            self.subscriber = subscriber
            self.session = session
            self.request = request
            self.progress = progress
        }

        func request(_ demand: Subscribers.Demand) {
            guard demand > 0 else {
                return
            }
            guard task == nil else {
                return
            }
            self.task = self.session?.downloadTask(with: request) { [weak self] url, response, error in
                if let error = error as? URLError {
                    self?.subscriber?.receive(completion: .failure(error))
                    return
                }
                guard response != nil else {
                    self?.subscriber?.receive(completion: .failure(URLError(.badServerResponse)))
                    return
                }
                guard let url = url else {
                    self?.subscriber?.receive(completion: .failure(URLError(.badURL)))
                    return
                }
                do {
                    let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
                    let fileUrl = cacheDir.appendingPathComponent((UUID().uuidString))
                    try FileManager.default.moveItem(atPath: url.path, toPath: fileUrl.path)
                    _ = self?.subscriber?.receive(.response(fileUrl: fileUrl))
                    self?.subscriber?.receive(completion: .finished)
                } catch {
                    self?.subscriber?.receive(completion: .failure(URLError(.cannotCreateFile)))
                }
            }
            guard let task = self.task else { return }
            progress.addChild(task.progress, withPendingUnitCount: 1)

            observation = progress.observe(\.fractionCompleted) { [weak self] progress, _ in
                _ = self?.subscriber?.receive(.progress(progress))
            }

            task.resume()
        }

        func cancel() {
            self.task?.cancel()
        }
    }
}
