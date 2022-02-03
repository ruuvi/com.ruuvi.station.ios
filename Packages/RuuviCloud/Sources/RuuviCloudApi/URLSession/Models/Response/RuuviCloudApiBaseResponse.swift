import Foundation
import RuuviCloud

public struct RuuviCloudApiBaseResponse<T: Any>: Decodable where T: Decodable {
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

extension RuuviCloudApiBaseResponse {
    public var result: Swift.Result<T, RuuviCloudApiError> {
        switch status {
        case .success:
            guard let data = data else {
                if let emptyModel = T.emptyModel {
                    return .success(emptyModel)
                } else {
                    return .failure(.emptyResponse)
                }
            }
            return .success(data)
        case .error:
            // Check whether the error is related to sensor claim
            if let code = code, code == "ER_SENSOR_ALREADY_CLAIMED", let description = errorDescription {
                return .failure(.claim(RuuviCloudApiClaimError(error: description, code: "UserApiError." + code)))
            }
            // Other errors
            guard let code = code else {
                if let description = errorDescription {
                    return .failure(.api(description))
                } else {
                    return .failure(.emptyResponse)
                }
            }
            return .failure(.api("UserApiError." + (subCode ?? code)))
        }
    }
}

extension Decodable {
    public static var emptyModel: Self? {
        let emptyString = "{}"
        if let emptyData = emptyString.data(using: .utf8),
           let emptyModel = try? JSONDecoder().decode(self, from: emptyData) {
            return emptyModel
        } else {
            return nil
        }
    }
}
