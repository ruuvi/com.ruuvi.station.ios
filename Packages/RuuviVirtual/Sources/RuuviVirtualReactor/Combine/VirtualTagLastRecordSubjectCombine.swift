import Foundation
import Combine
import RuuviContext
import RuuviOntology
import RealmSwift
#if canImport(RuuviVirtualModel)
import RuuviVirtualModel
#endif

final class VirtualTagLastRecordSubjectCombine {
    var isServing: Bool = false

    private let realm: RealmContext
    private let id: String

    let subject = PassthroughSubject<AnyVirtualTagSensorRecord, Never>()

    private var virtualSensorDataRealmToken: NotificationToken?

    deinit {
        virtualSensorDataRealmToken?.invalidate()
    }

    init(
        id: String,
        realm: RealmContext
    ) {
        self.realm = realm
        self.id = id
    }

    func start() {
        self.isServing = true

        let results = self.realm.main.objects(WebTagDataRealm.self)
            .filter("webTag.uuid == %@", id)
            .sorted(byKeyPath: "date")
        self.virtualSensorDataRealmToken = results.observe { [weak self] (change) in
            guard let sSelf = self else { return }
            switch change {
            case .update(let records, _, _, _):
                if let lastRecord = records.last?.record {
                    sSelf.subject.send(lastRecord.any)
                }
            default:
                break
            }
        }
    }
}
