import Foundation
import GRDB
import RxSwift
import RealmSwift
import RuuviOntology
import RuuviContext

class SensorSettingsRxSwift {
    var luid: LocalIdentifier?
    var macId: MACIdentifier?
    var sqlite: SQLiteContext
    var realm: RealmContext

    let insertSubject: PublishSubject<SensorSettings> = PublishSubject()
    let updateSubject: PublishSubject<SensorSettings> = PublishSubject()
    let deleteSubject: PublishSubject<SensorSettings> = PublishSubject()

    private var ruuviTagController: FetchedRecordsController<SensorSettingsSQLite>
    private var ruuviTagsRealmToken: NotificationToken?
    private var ruuviTagRealmCache = [SensorSettings]()

    deinit {
        ruuviTagsRealmToken?.invalidate()
        insertSubject.onCompleted()
        updateSubject.onCompleted()
        deleteSubject.onCompleted()
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    init(
        luid: LocalIdentifier?,
        macId: MACIdentifier?,
        sqlite: SQLiteContext,
        realm: RealmContext
    ) {
        self.luid = luid
        self.macId = macId
        self.sqlite = sqlite
        self.realm = realm

        let request = SensorSettingsSQLite
            .filter(
                (luid?.value != nil && SensorSettingsSQLite.luidColumn == luid?.value)
                || (macId?.value != nil && SensorSettingsSQLite.macIdColumn == macId?.value)
            )
        self.ruuviTagController = try! FetchedRecordsController(sqlite.database.dbPool, request: request)

        try! self.ruuviTagController.performFetch()
        self.ruuviTagController.trackChanges(onChange: { [weak self] _, record, event in
            guard let sSelf = self else { return }
            switch event {
            case .insertion:
                sSelf.insertSubject.onNext(record.sensorSettings)
            case .update:
                sSelf.updateSubject.onNext(record.sensorSettings)
            case .deletion:
                sSelf.deleteSubject.onNext(record.sensorSettings)
            case .move:
                break
            }
        })

        DispatchQueue.main.async { [weak self] in
            guard let sSelf = self else { return }
            let results = sSelf.realm.main.objects(SensorSettingsRealm.self)
                .filter("luid == %@ || macId == %@", luid?.value, macId?.value)
            sSelf.ruuviTagRealmCache = results.map({ $0.sensorSettings })
            sSelf.ruuviTagsRealmToken = results.observe { [weak self] (change) in
                guard let sSelf = self else { return }
                switch change {
                case .update(let sensorSettings, let deletions, let insertions, let modifications):
                    for del in deletions {
                        sSelf.deleteSubject.onNext(sSelf.ruuviTagRealmCache[del])
                    }
                    sSelf.ruuviTagRealmCache = sSelf.ruuviTagRealmCache
                        .enumerated()
                        .filter { !deletions.contains($0.offset) }
                        .map { $0.element }
                    for ins in insertions {
                        sSelf.insertSubject.onNext(sensorSettings[ins].sensorSettings)
                        sSelf.ruuviTagRealmCache.insert(sensorSettings[ins].sensorSettings, at: ins)
                    }
                    for mod in modifications {
                        sSelf.updateSubject.onNext(sensorSettings[mod].sensorSettings)
                        sSelf.ruuviTagRealmCache[mod] = sensorSettings[mod].sensorSettings
                    }
                default:
                    break
                }
            }
        }
    }
}
