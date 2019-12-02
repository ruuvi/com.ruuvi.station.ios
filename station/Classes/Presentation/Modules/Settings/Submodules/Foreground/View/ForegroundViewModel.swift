import Foundation

enum ForegroundType {
    case advertisement
    case connection
    case webTags
}

class ForegroundViewModel: Identifiable {
    var id = UUID().uuidString
    var type: ForegroundType = .advertisement
    var isOn: Observable<Bool?> = Observable<Bool?>(true)
    var interval: Observable<Int?> = Observable<Int?>(1)

    var title: String {
        switch type {
        case .advertisement:
            return "ForegroundRow.advertisement.title".localized()
        case .connection:
            return "ForegroundRow.connection.title".localized()
        case .webTags:
            return "ForegroundRow.webTags.title".localized()
        }
    }

    var section: String {
        switch type {
        case .advertisement:
            return "ForegroundRow.advertisement.section".localized()
        case .connection:
            return "ForegroundRow.connection.section".localized()
        case .webTags:
            return "ForegroundRow.webTags.section".localized()
        }
    }

}
