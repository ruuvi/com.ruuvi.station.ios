import Foundation
import Combine
import BTKit
import RuuviOntology

protocol DFUInteractorInput {
    func loadLatestRelease() -> AnyPublisher<LatestRelease, Error>
    func readCurrentRelease(for ruuviTag: RuuviTagSensor) -> Future<CurrentRelease, Error>
}

final class DFUInteractor {
}

enum DFUError: Error {
    case failedToConstructUrl
    case failedToGetLuid
}

struct LatestRelease: Codable {
    var version: String

    enum CodingKeys: String, CodingKey {
        case version = "tag_name"
    }
}

struct CurrentRelease {
    var version: String
}

extension DFUInteractor: DFUInteractorInput {
    func loadLatestRelease() -> AnyPublisher<LatestRelease, Error> {
        let urlString = "https://api.github.com/repos/ruuvi/ruuvi.firmware.c/releases/latest"
        guard let url = URL(string: urlString) else {
            return Fail<LatestRelease, Error>(error: DFUError.failedToConstructUrl).eraseToAnyPublisher()
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
