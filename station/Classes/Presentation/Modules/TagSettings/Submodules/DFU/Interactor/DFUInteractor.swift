import Foundation
import Combine
import BTKit
import RuuviOntology

protocol DFUInteractorInput {
    func download(release: LatestRelease) -> AnyPublisher<DownloadResponse, Error>
    func loadLatestRelease() -> AnyPublisher<LatestRelease, Error>
    func readCurrentRelease(for ruuviTag: RuuviTagSensor) -> Future<CurrentRelease, Error>
}

final class DFUInteractor {
    private let firmwareRepository: FirmwareRepository = FirmwareRepositoryImpl()
}

enum DFUError: Error {
    case failedToConstructUrl
    case failedToGetLuid
}

struct LatestRelease: Codable {
    var version: String
    var assets: [LatestReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case version = "tag_name"
        case assets = "assets"
    }

    private var defaultFullZipAsset: LatestReleaseAsset? {
        return assets.first(where: {
            $0.name.hasSuffix("zip")
                && $0.name.contains("default")
                && !$0.name.contains("app")
        })
    }

    var defaultFullZipName: String? {
        return defaultFullZipAsset?.name
    }

    var defaultFullZipUrl: URL? {
        if let downloadUrlString = defaultFullZipAsset?.downloadUrlString {
            return URL(string: downloadUrlString)
        } else {
            return nil
        }
    }
}

struct LatestReleaseAsset: Codable {
    var name: String
    var downloadUrlString: String

    enum CodingKeys: String, CodingKey {
        case name
        case downloadUrlString = "browser_download_url"
    }
}

struct CurrentRelease {
    var version: String
}

extension DFUInteractor: DFUInteractorInput {
    func download(release: LatestRelease) -> AnyPublisher<DownloadResponse, Error> {
        guard let name = release.defaultFullZipName,
              let url = release.defaultFullZipUrl else {
            return Fail<DownloadResponse, Error>(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        return URLSession.shared
            .downloadTaskPublisher(for: url)
            .catch { error in Fail<DownloadResponse, Error>(error: error) }
            .receive(on: RunLoop.main)
            .map({ [weak self] response in
                guard let sSelf = self else { return response }
                switch response {
                case .response(let fileUrl):
                    try? sSelf.firmwareRepository.save(
                        name: name,
                        fileUrl: fileUrl
                    )
                case .progress(let percentage):
                    print(percentage)
                }
                return response
            })
            .eraseToAnyPublisher()
    }

    func loadLatestRelease() -> AnyPublisher<LatestRelease, Error> {
        let urlString = "https://api.github.com/repos/ruuvi/ruuvi.firmware.c/releases/latest"
        guard let url = URL(string: urlString) else {
            return Fail<LatestRelease, Error>(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        return
            URLSession.shared.dataTaskPublisher(for: url)
                .map { $0.data }
                .decode(type: LatestRelease.self, decoder: JSONDecoder())
                .catch { error in Fail<LatestRelease, Error>(error: error)}
                .receive(on: RunLoop.main)
                .eraseToAnyPublisher()
    }

    func readCurrentRelease(for ruuviTag: RuuviTagSensor) -> Future<CurrentRelease, Error> {
        return Future { [weak self] promise in
            guard let sSelf = self else { return }
            guard let uuid = ruuviTag.luid?.value else {
                promise(.failure(DFUError.failedToGetLuid))
                return
            }
            BTKit.background.services.gatt.firmwareRevision(
                for: sSelf,
                uuid: uuid,
                options: [.connectionTimeout(15)]
            ) { _, result in
                switch result {
                case .success(let version):
                    let currentRelease = CurrentRelease(version: version)
                    promise(.success(currentRelease))
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }
    }
}
