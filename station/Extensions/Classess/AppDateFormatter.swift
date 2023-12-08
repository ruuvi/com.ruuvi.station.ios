import Foundation
import RuuviLocalization

class AppDateFormatter {
    static let shared = AppDateFormatter()
    private init() {}

    private let ruuviAgoFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "E MMM dd yyyy HH:mm:ss"
        return df
    }()

    private let shortTimeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale.autoupdatingCurrent
        df.dateStyle = .none
        df.timeStyle = .short
        return df
    }()

    private let graphXAxisDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale.autoupdatingCurrent
        df.setLocalizedDateFormatFromTemplate("ddMM")
        return df
    }()
}

extension AppDateFormatter {
    func ruuviAgoString(from date: Date) -> String {
        return ruuviAgoFormatter.string(from: date)
    }

    func shortTimeString(from date: Date) -> String {
        return shortTimeFormatter.string(from: date)
    }

    func graphXAxisTimeString(from date: Date) -> String {
        return shortTimeFormatter.string(from: date)
    }

    func graphXAxisDateString(from date: Date) -> String {
        let calendar = Calendar.autoupdatingCurrent
        let dateComponents = calendar.dateComponents([.day, .month], from: date)
        if let formattedDate = calendar.date(from: dateComponents) {
            return graphXAxisDateFormatter.string(from: formattedDate)
        } else {
            return RuuviLocalization.na
        }
    }

    func graphMarkerDateString(from epoch: Double) -> String {
        let date = Date(timeIntervalSince1970: epoch)

        let timeString = graphXAxisTimeString(from: date)
        let dateString = graphXAxisDateString(from: date)

        return timeString + "\n" + dateString
    }
}
