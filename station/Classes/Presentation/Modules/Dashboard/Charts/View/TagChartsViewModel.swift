import UIKit
import Humidity
import Charts

enum TagChartsType {
    case ruuvi
    case web
}

struct TagChartsViewModel {
    var type: TagChartsType = .ruuvi
    var uuid: Observable<String?> = Observable<String?>(UUID().uuidString)
    var mac: Observable<String?> = Observable<String?>()
    var name: Observable<String?> = Observable<String?>()
    var background: Observable<UIImage?> = Observable<UIImage?>()
    var isConnectable: Observable<Bool?> = Observable<Bool?>()
    var alertState: Observable<AlertState?> = Observable<AlertState?>()
    var isConnected: Observable<Bool?> = Observable<Bool?>()
    var isHandleInitialResult: Observable<Bool?> = Observable<Bool?>(false)

    init(type: TagChartsType) {
        self.type = type
    }
    
    init(_ ruuviTag: RuuviTagRealm) {
        type = .ruuvi
        uuid.value = ruuviTag.uuid
        name.value = ruuviTag.name
        mac.value = ruuviTag.mac
        isConnectable.value = ruuviTag.isConnectable
    }

    init(_ webTag: WebTagRealm) {
        type = .web
        uuid.value = webTag.uuid
        name.value = webTag.name
        isConnectable.value = false
    }

    init(_ ruuviTag: RuuviTagSensor) {
        type = .ruuvi
        uuid.value = ruuviTag.luid ?? ruuviTag.id
        mac.value = ruuviTag.mac
        name.value = ruuviTag.name
        isConnectable.value = ruuviTag.isConnectable
    }
}
