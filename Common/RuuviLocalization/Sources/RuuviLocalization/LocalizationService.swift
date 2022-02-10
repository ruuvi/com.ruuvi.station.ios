import Localize_Swift
import Foundation

class LocalizationService {
    static let shared = LocalizationService()

    var localization: String? = Locale.current.languageCode {
        didSet {
            if let localization = localization?.lowercased() {
                Localize.setCurrentLanguage(localization)
            }
        }
    }

    init() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(LocalizationService.apply),
                                               name: NSNotification.Name(LCLLanguageChangeNotification),
                                               object: nil)
    }

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
