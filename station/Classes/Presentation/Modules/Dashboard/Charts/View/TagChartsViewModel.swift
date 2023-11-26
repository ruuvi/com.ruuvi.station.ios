import UIKit
import Humidity
import Charts
import RuuviOntology

enum TagChartsType {
    case ruuvi
}

struct TagChartsViewModel {
    var type: TagChartsType = .ruuvi
    var uuid: Observable<String?> = Observable<String?>(UUID().uuidString)
    var mac: Observable<String?> = Observable<String?>()
    var name: Observable<String?> = Observable<String?>()
    var background: Observable<UIImage?> = Observable<UIImage?>()
    var isConnectable: Observable<Bool?> = Observable<Bool?>(false)
    var isCloud: Observable<Bool?> = Observable<Bool?>()
    var alertState: Observable<AlertState?> = Observable<AlertState?>()
    var isConnected: Observable<Bool?> = Observable<Bool?>()
    var isHandleInitialResult: Observable<Bool?> = Observable<Bool?>(false)

    init(type: TagChartsType) {
        self.type = type
    }

    init(_ ruuviTag: RuuviTagSensor) {
        type = .ruuvi
        uuid.value = ruuviTag.luid?.value
        if let macId = ruuviTag.macId?.value {
            mac.value = macId
        }
        name.value = ruuviTag.name
        isConnectable.value = ruuviTag.isConnectable
        isCloud.value = ruuviTag.isCloud
    }
}
