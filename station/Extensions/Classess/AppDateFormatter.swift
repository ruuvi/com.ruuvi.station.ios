import Foundation

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
        df.dateStyle = .none
        df.timeStyle = .short
        return df
    }()

    private let enLocaleDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MM/dd"
        return df
    }()

    private let nonEnLocaleDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "dd/MM"
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

    func enLocaleDateString(from date: Date) -> String {
        return enLocaleDateFormatter.string(from: date)
    }

    func nonEnLocaleDateString(from date: Date) -> String {
        return nonEnLocaleDateFormatter.string(from: date)
    }
}
