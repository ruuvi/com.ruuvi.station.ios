import Combine
import Foundation

public struct FirmwareDownloadAsset {
    public let name: String
    public let url: URL

    public init(name: String, url: URL) {
        self.name = name
        self.url = url
    }
}

public enum FirmwareDownloadEvent {
    case progress(Progress)
    case files([URL])
}

/// Downloads belong to their subscription. Cancelling one batch never cancels another batch.
public struct FirmwareDownloader {
    private let download: (URL, Progress) -> AnyPublisher<DownloadResponse, Error>
    private let repository: FirmwareRepository

    public init(session: URLSession = .shared, repository: FirmwareRepository = FirmwareRepositoryImpl()) {
        self.init(repository: repository) { url, progress in
            session.downloadTaskPublisher(for: url, progress: progress)
                .mapError { $0 as Error }.eraseToAnyPublisher()
        }
    }

    init(repository: FirmwareRepository, download: @escaping (URL, Progress) -> AnyPublisher<DownloadResponse, Error>) {
        self.repository = repository
        self.download = download
    }

    public func download(assets: [FirmwareDownloadAsset]) -> AnyPublisher<FirmwareDownloadEvent, Error> {
        Deferred {
            guard !assets.isEmpty,
                assets.allSatisfy({
                    ["https", "http"].contains($0.url.scheme?.lowercased() ?? "") && $0.url.host?.isEmpty == false
                })
            else {
                return Fail<FirmwareDownloadEvent, Error>(error: URLError(.badURL)).eraseToAnyPublisher()
            }
            let progress = Progress(totalUnitCount: Int64(assets.count))
            let downloads = assets.enumerated().map { index, asset in
                download(asset.url, progress)
                    .tryMap { response -> IndexedDownloadEvent in
                        switch response {
                        case .progress: return .progress
                        case .response(let url):
                            return .file(index, try repository.save(name: asset.name, fileUrl: url))
                        }
                    }
                    .append(Just(IndexedDownloadEvent.finished(index)).setFailureType(to: Error.self))
                    .eraseToAnyPublisher()
            }
            return Publishers.MergeMany(downloads)
                .tryScan(DownloadBatch(files: Array(repeating: nil, count: assets.count))) { batch, event in
                    var result = batch
                    result.event = nil
                    switch event {
                    case .progress:
                        result.event = .progress(progress)
                    case .file(let index, let url):
                        result.files[index] = url
                        if result.files.allSatisfy({ $0 != nil }) {
                            result.event = .files(result.files.compactMap { $0 })
                        }
                    case .finished(let index):
                        guard result.files[index] != nil else { throw URLError(.badServerResponse) }
                    }
                    return result
                }
                .compactMap(\.event)
                .eraseToAnyPublisher()
        }.eraseToAnyPublisher()
    }
}

private enum IndexedDownloadEvent {
    case progress
    case file(Int, URL)
    case finished(Int)
}

private struct DownloadBatch {
    var files: [URL?]
    var event: FirmwareDownloadEvent?
}
