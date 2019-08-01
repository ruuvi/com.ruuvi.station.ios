import Foundation

enum RUError: Error {
    case core(CoreError)
    case persistence(Error)
    case networking(Error)
    case parse(Error)
    case map(Error)
    case expected(ExpectedError)
    case unexpected(UnexpectedError)
}

extension RUError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .core(let error):
            return error.localizedDescription
        case .persistence(let error):
            return error.localizedDescription
        case .networking(let error):
            return error.localizedDescription
        case .parse(let error):
            return error.localizedDescription
        case .map(let error):
            return error.localizedDescription
        case .expected(let error):
            return error.localizedDescription
        case .unexpected(let error):
            return error.localizedDescription
        }
    }
}

enum CoreError: Error {
    case failedToGetDocumentsDirectory
    case failedToGetPngRepresentation
    case failedToGetCurrentLocation
    case failedToGetDataFromResponse
}

extension CoreError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .failedToGetDataFromResponse:
            return "CoreError.failedToGetDataFromResponse".localized()
        case .failedToGetCurrentLocation:
            return "CoreError.failedToGetCurrentLocation".localized()
        case .failedToGetPngRepresentation:
            return "CoreError.failedToGetPngRepresentation".localized()
        case .failedToGetDocumentsDirectory:
            return "CoreError.failedToGetDocumentsDirectory".localized()
        }
    }
}

enum ExpectedError: Error {
    case missingOpenWeatherMapAPIKey
}

extension ExpectedError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingOpenWeatherMapAPIKey:
            return "ExpectedError.missingOpenWeatherMapAPIKey".localized()
        }
    }
}

enum UnexpectedError: Error {
    case callbackErrorAndResultAreNil
    case callerDeinitedDuringOperation
}

extension UnexpectedError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .callbackErrorAndResultAreNil:
            return "UnexpectedError.callbackErrorAndResultAreNil".localized()
        case .callerDeinitedDuringOperation:
            return "UnexpectedError.callerDeinitedDuringOperation".localized()
        }
    }
}
