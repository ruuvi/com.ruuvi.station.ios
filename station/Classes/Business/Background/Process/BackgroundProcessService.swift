import Foundation

protocol BackgroundProcessService {
    func register()
    func schedule()
    func launch()
}
