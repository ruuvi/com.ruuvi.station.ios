import Foundation

struct UserApiBaseResponse<T: Any>: Decodable where T: Decodable {
    enum Status: String, Decodable {
        case success
        case error
    }
    private let status: Status
    private let data: T?
    private let errorDescription: String?
    private let code: String?
    private let subCode: String?

    enum CodingKeys: String, CodingKey {
        case status = "result"
        case data
        case errorDescription = "error"
        case code
        case subCode
    }
}

extension UserApiBaseResponse {
    var result: Swift.Result<T, RUError> {
        switch status {
        case .success:
            guard let data = data else {
                if let emptyModel = T.emptyModel {
                    return .success(emptyModel)
                } else {
                    return .failure(RUError.userApi(.emptyResponse))
                }
            }
            return .success(data)
        case .error:
            guard let code = code else {
                if let description = errorDescription {
                    let userApiError = UserApiError(description: description)
                    return .failure(RUError.userApi(userApiError))
                } else {
                    return .failure(RUError.userApi(.emptyResponse))
                }
            }
            let userApiError = UserApiError(description: "UserApiError." + (subCode ?? code))
            return .failure(RUError.userApi(userApiError))
        }
    }
}

extension Decodable {
    static var emptyModel: Self? {
        let emptyString = "{}"
        if let emptyData = emptyString.data(using: .utf8),
           let emptyModel = try? JSONDecoder().decode(self, from: emptyData) {
            return emptyModel
        } else {
            return nil
        }
    }
}
