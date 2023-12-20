import RuuviOntology
import UIKit

struct DevicesViewModel {
    let id: Observable<Int?> = .init()
    let lastAccessed: Observable<TimeInterval?> = .init()
    let name: Observable<String?> = .init()
}
