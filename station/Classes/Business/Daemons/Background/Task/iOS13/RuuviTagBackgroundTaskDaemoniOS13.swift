import Foundation
import BackgroundTasks
import BTKit

@available(iOS 13.0, *)
class RuuviTagBackgroundTaskDaemoniOS13: RuuviTagBackgroundTaskDaemon {
    
    var advertisementDaemon: RuuviTagAdvertisementDaemon!
    
    private let id = "com.ruuvi.station.RuuviTagBackgroundTaskDaemoniOS13"
    private let queue = DispatchQueue(label: "RuuviTagBackgroundTaskDaemoniOS13", qos: .background)
    
    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: id, using: queue) { task in
            self.listenToAdvertisements(in: task as! BGAppRefreshTask, for: 25)
        }
    }
    
    func schedule() {
        queue.async {
            let request = BGAppRefreshTaskRequest(identifier: self.id)
            request.earliestBeginDate = Date(timeIntervalSinceNow: 60)
            do {
                try BGTaskScheduler.shared.submit(request)
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    private func listenToAdvertisements(in task: BGAppRefreshTask, for deadline: TimeInterval) {
        schedule()
        advertisementDaemon.start()
        task.expirationHandler = {
            self.advertisementDaemon.stop()
        }
        queue.asyncAfter(deadline: .now() + deadline) {
            self.advertisementDaemon.stop()
            task.setTaskCompleted(success: true)
        }
    }
    
}
