import Foundation

class DIContainer {
    private var dependencies: [String: Any] = [:]

    // Register dependencies
    func register<T>(_ dependency: T) {
        let key = String(describing: T.self)
        dependencies[key] = dependency
    }

    // Resolve dependencies
    func resolve<T>(_ type: T.Type) -> T {
        let key = String(describing: type)
        guard let dependency = dependencies[key] as? T else {
            fatalError("Dependency \(key) not registered")
        }
        return dependency
    }
}
