import Foundation

class LocalizationService {
    static let shared = LocalizationService()

    init() {}

    private var listeners = NSHashTable<AnyObject>.weakObjects()

    func add(localizable: Localizable, applyImmediately: Bool = true) {
        guard !listeners.contains(localizable) else { return }
        listeners.add(localizable)
        if applyImmediately {
            localizable.localize()
        }
    }

    @objc func apply() {
        listeners.allObjects
            .compactMap { $0 as? Localizable }
            .forEach { $0.localize()}
    }
}
