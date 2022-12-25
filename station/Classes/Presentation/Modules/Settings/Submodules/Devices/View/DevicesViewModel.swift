import UIKit
import RuuviOntology

struct DevicesViewModel {
    let id: Observable<Int?> = Observable<Int?>()
    let lastAccessed: Observable<TimeInterval?> = Observable<TimeInterval?>()
    let name: Observable<String?> = Observable<String?>()
}
