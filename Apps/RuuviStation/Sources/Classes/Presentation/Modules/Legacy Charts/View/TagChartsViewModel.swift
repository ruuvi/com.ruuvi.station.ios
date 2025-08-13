import DGCharts
import Humidity
import RuuviOntology
import UIKit

enum TagChartsType {
    case ruuvi
}

struct TagChartsViewModel {
    var type: TagChartsType = .ruuvi
    var uuid: Observable<String?> = .init(UUID().uuidString)
    var mac: Observable<String?> = .init()
    var name: Observable<String?> = .init()
    var background: Observable<UIImage?> = .init()
    var isConnectable: Observable<Bool?> = .init(false)
    var isCloud: Observable<Bool?> = .init()
    var alertState: Observable<AlertState?> = .init()
    var isConnected: Observable<Bool?> = .init()
    var isHandleInitialResult: Observable<Bool?> = .init(false)

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
