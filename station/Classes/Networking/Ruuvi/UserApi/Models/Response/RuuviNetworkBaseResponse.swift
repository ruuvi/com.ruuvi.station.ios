import Foundation

struct RuuviNetworkBaseResponse<T: Decodable>: Decodable {
    enum Status: String, Decodable {
        case success
        case error
    }
    let status: Status
    let data: T?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case status = "result"
        case data
        case errorDescription = "error"
    }
}
extension RuuviNetworkBaseResponse {
    var result: Swift.Result<T, RuuviNetworkError> {
        switch status {
        case .success:
            guard let data = data else {
                return .failure(.emptyResponse)
            }
            return .success(data)
        case .error:
            guard let error = error else {
                return .failure(.emptyResponse)
            }
            return .failure(.userApiError(error))
        }
    }
}
