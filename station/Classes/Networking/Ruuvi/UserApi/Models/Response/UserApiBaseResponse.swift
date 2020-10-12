import Foundation

struct UserApiBaseResponse<T: Decodable>: Decodable {
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

extension UserApiBaseResponse {
    var result: Swift.Result<T, RUError> {
        switch status {
        case .success:
            guard let data = data else {
                return .failure(RUError.userApi(.emptyResponse))
            }
            return .success(data)
        case .error:
            guard let error = errorDescription else {
                return .failure(RUError.userApi(.emptyResponse))
            }
            let userApiError = UserApiError(description: error)
            return .failure(RUError.userApi(userApiError))
        }
    }
}
