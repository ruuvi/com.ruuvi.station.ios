import Foundation

class RuuviTagBackgroundTaskDaemoniOS12: RuuviTagBackgroundTaskDaemon {
    func schedule() {
        print("scheduled")
    }
    
    func register() {
        print("registered")
    }
}
