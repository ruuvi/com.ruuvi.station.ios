import Foundation

protocol InfoProvider {
    var deviceModel: String { get }
    var appVersion: String { get }
    var appName: String { get }
    var systemName: String { get }
    var systemVersion: String { get }

    func summary(completion: @escaping (String) -> Void)
}
