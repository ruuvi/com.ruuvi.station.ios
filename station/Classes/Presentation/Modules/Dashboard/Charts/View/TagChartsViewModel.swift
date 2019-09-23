import UIKit

enum TagChartsType {
    case ruuvi
    case web
}

struct TagChartsPoint {
    var date: Date
    var value: Double
}

struct TagChartsViewModel {
    var type: TagChartsType = .ruuvi
    var uuid: Observable<String?> = Observable<String?>(UUID().uuidString)
    var name: Observable<String?> = Observable<String?>()
    var background: Observable<UIImage?> = Observable<UIImage?>()
    var celsius: Observable<[TagChartsPoint]?> = Observable<[TagChartsPoint]?>()
    
    init(_ ruuviTag: RuuviTagRealm) {
        type = .ruuvi
        uuid.value = ruuviTag.uuid
        name.value = ruuviTag.name
        celsius.value = ruuviTag.data.compactMap( {
            if let value = $0.celsius.value {
                return TagChartsPoint(date: $0.date, value: value)
            } else {
                return nil
            }
        } )
    }
    
    init(_ webTag: WebTagRealm) {
        type = .web
        uuid.value = webTag.uuid
        name.value = webTag.name
        celsius.value = webTag.data.compactMap( {
            if let value = $0.celsius.value {
                return TagChartsPoint(date: $0.date, value: value)
            } else {
                return nil
            }
        } )
    }
}
