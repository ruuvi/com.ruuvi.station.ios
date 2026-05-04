import Foundation

#if DEBUG || ALPHA
public enum RuuviAlertDebugLog {
    private static let enabledKey = "RuuviAlertDebugLog.enabled"
    private static let entriesKey = "RuuviAlertDebugLog.entries"
    private static let maximumEntries = 600
    private static let queue = DispatchQueue(label: "com.ruuvi.station.alert-debug-log")

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    public static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
    }

    public static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    public static func append(
        _ category: String,
        _ message: @autoclosure () -> String
    ) {
        guard isEnabled else { return }
        let resolvedMessage = message()
        queue.async {
            let timestamp = formatter.string(from: Date())
            let line = "\(timestamp) [\(category)] \(resolvedMessage)"
            var entries = UserDefaults.standard.stringArray(forKey: entriesKey) ?? []
            entries.append(line)
            if entries.count > maximumEntries {
                entries.removeFirst(entries.count - maximumEntries)
            }
            UserDefaults.standard.set(entries, forKey: entriesKey)
        }
    }

    public static func text() -> String {
        queue.sync {
            let entries = UserDefaults.standard.stringArray(forKey: entriesKey) ?? []
            return entries.joined(separator: "\n")
        }
    }

    public static func clear() {
        queue.async {
            UserDefaults.standard.removeObject(forKey: entriesKey)
        }
    }

    public static func exportFileURL() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ruuvi-alert-debug-log.txt")
        try text().write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
#endif
