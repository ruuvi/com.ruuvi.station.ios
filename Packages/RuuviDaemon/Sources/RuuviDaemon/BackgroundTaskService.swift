import Foundation

public protocol BackgroundTaskService {
    func register()
    func schedule()
}
