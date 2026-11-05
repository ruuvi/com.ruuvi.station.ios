import Combine
import Foundation

public extension URLSession {
    func firmwareDataPublisher(for url: URL) -> AnyPublisher<Data, Error> {
        dataTaskPublisher(for: url)
            .tryMap { output in
                guard let response = output.response as? HTTPURLResponse,
                    (200..<300).contains(response.statusCode)
                else {
                    throw URLError(.badServerResponse)
                }
                return output.data
            }
            .eraseToAnyPublisher()
    }
}
