import Foundation
import RuuviLocal

/// Tracks actual presentations per account, independently of app versions and subscription checks.
final class MarketingConsentPromptHistory {
    private enum Key {
        static let lastShown = "MarketingConsentPrompt.lastShownDates"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isEligible(
        account: String,
        intervalMinutes: Int = RuuviMarketingConsentPromptInterval.defaultMinutes,
        now: Date = Date()
    ) -> Bool {
        let dates = defaults.dictionary(forKey: Key.lastShown) ?? [:]
        guard let lastShown = dates[account.lowercased()] as? Date else { return true }
        let repeatInterval = TimeInterval(RuuviMarketingConsentPromptInterval.normalized(intervalMinutes)) * 60
        return now.timeIntervalSince(lastShown) > repeatInterval
    }

    func markPresented(account: String, now: Date = Date()) {
        var dates = defaults.dictionary(forKey: Key.lastShown) ?? [:]
        dates[account.lowercased()] = now
        defaults.set(dates, forKey: Key.lastShown)
    }
}
