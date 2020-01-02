import Foundation

class PullWebDaemonOperations: PullWebDaemon {

    var settings: Settings!
    var webTagOperationsManager: WebTagOperationsManager!

    @UserDefault("PullWebDaemonOperations.webTagLastPullDate", defaultValue: Date())
    private var webTagLastPullDate: Date

    func wakeUp() {
        if needsToPullWebTagData() {
            pullWebTagData()
            webTagLastPullDate = Date()
        }
    }

    private func needsToPullWebTagData() -> Bool {
        let elapsed = Int(Date().timeIntervalSince(webTagLastPullDate))
        return elapsed > settings.webPullIntervalMunites * 60
    }

    private func pullWebTagData() {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        let operations = webTagOperationsManager.alertsPullOperations()
        queue.addOperations(operations, waitUntilFinished: false)
    }

}
