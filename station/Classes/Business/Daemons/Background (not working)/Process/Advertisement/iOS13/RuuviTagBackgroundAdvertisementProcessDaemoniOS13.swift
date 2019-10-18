import Foundation
import BackgroundTasks

@available(iOS 13, *)
class RuuviTagBackgroundAdvertisementProcessDaemoniOS13: RuuviTagBackgroundAdvertisementProcessDaemon {
    
    var advertisementDaemon: RuuviTagAdvertisementDaemon!
    
    private let id = "com.ruuvi.station.RuuviTagBackgroundAdvertisementProcessDaemoniOS13"
    private let queue = DispatchQueue(label: "RuuviTagBackgroundAdvertisementProcessDaemoniOS13", qos: .background)
    
    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: id, using: queue) { task in
            self.listenToAdvertisements(in: task as! BGProcessingTask, for: 60)
        }
    }
    
    func schedule() {
        queue.async {
            do {
                let request = BGProcessingTaskRequest(identifier: self.id)
                request.requiresExternalPower = false
                request.requiresNetworkConnectivity = false
                try BGTaskScheduler.shared.submit(request)
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    private func listenToAdvertisements(in task: BGProcessingTask, for deadline: TimeInterval) {
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
