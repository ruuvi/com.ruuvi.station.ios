import FirebaseCrashlytics
import RuuviAnalytics

final class RuuviErrorReporterImpl: RuuviErrorReporter {
    func report(error: Error) {
        Crashlytics.crashlytics().record(error: error)
    }
}
