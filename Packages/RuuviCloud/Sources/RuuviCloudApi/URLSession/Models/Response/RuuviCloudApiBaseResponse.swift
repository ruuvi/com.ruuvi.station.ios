import Foundation

public struct RuuviCloudApiBaseResponse<T: Any>: Decodable where T: Decodable {
    enum Status: String, Decodable {
        case success
        case error
    }

    private let status: Status
    private let data: T?
    private let errorDescription: String?
    private let code: RuuviCloudApiErrorCode?
    private let subCode: RuuviCloudApiErrorCode?

    enum CodingKeys: String, CodingKey {
        case status = "result"
        case data
        case errorDescription = "error"
        case code
        case subCode = "sub_code"
    }

    // Codes are read as strings, so that a value this app version does not know is ignored
    // instead of failing the whole response.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(Status.self, forKey: .status)
        data = try container.decodeIfPresent(T.self, forKey: .data)
        errorDescription = try container.decodeIfPresent(String.self, forKey: .errorDescription)
        code = try container.decodeIfPresent(String.self, forKey: .code)
            .flatMap(RuuviCloudApiErrorCode.init(rawValue:))
        subCode = try container.decodeIfPresent(String.self, forKey: .subCode)
            .flatMap(RuuviCloudApiErrorCode.init(rawValue:))
    }
}

public extension RuuviCloudApiBaseResponse {
    var result: Swift.Result<T, RuuviCloudApiError> {
        switch status {
        case .success:
            guard let data
            else {
                if let emptyModel = T.emptyModel {
                    return .success(emptyModel)
                } else {
                    return .failure(.emptyResponse)
                }
            }
            return .success(data)
        case .error:
            if let subCode, subCode.isVerifySubCode {
                return .failure(.api(subCode))
            }
            guard let code
            else {
                if errorDescription != nil {
                    return .failure(.api(.erInternal))
                } else {
                    return .failure(.emptyResponse)
                }
            }

            return .failure(.api(code))
        }
    }
}

private extension RuuviCloudApiErrorCode {
    // Sub codes of /verify, which tell why the code was refused. Other sub codes do not replace the code.
    var isVerifySubCode: Bool {
        switch self {
        case .erSubInvalidCode, .erSubCodeUsed, .erSubCodeExpired, .erSubTooManyAttempts:
            true
        default:
            false
        }
    }
}

public extension Decodable {
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
