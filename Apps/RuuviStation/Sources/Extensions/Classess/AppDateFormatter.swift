import Foundation
import RuuviLocalization

class AppDateFormatter {
    static let shared = AppDateFormatter()
    private init() {}

    private let ruuviAgoFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale.autoupdatingCurrent
        df.setLocalizedDateFormatFromTemplate("ddMMyyyy")
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
        let localeId = Locale.autoupdatingCurrent.identifier.lowercased()

        // Check if the region is Finnish.
        // They do not use leading zeros in date format hence we use "dM"
        if localeId.contains("_fi") ||
            localeId.hasPrefix("fi") {
            df.setLocalizedDateFormatFromTemplate("dM")
        } else {
            df.setLocalizedDateFormatFromTemplate("ddMM")
        }
        return df
    }()
}

extension AppDateFormatter {
    func ruuviAgoString(from date: Date) -> String {
        ruuviAgoFormatter.string(from: date) + " " + shortTimeString(from: date)
    }

    func shortTimeString(from date: Date) -> String {
        shortTimeFormatter.string(from: date)
    }

    func graphXAxisTimeString(from date: Date) -> String {
        shortTimeFormatter.string(from: date)
    }

    func graphXAxisDateString(from date: Date) -> String {
        let calendar = Calendar.autoupdatingCurrent
        let dateComponents = calendar.dateComponents([.day, .month, .year], from: date)
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
