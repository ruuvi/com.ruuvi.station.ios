import Combine
import Foundation
import GRDB
import RealmSwift
import RuuviContext
import RuuviOntology
#if canImport(RuuviOntologyRealm)
    import RuuviOntologyRealm
#endif
#if canImport(RuuviOntologySQLite)
    import RuuviOntologySQLite
#endif

final class SensorSettingsCombine {
    var luid: LocalIdentifier?
    var macId: MACIdentifier?
    var sqlite: SQLiteContext
    var realm: RealmContext

    let insertSubject = PassthroughSubject<SensorSettings, Never>()
    let updateSubject = PassthroughSubject<SensorSettings, Never>()
    let deleteSubject = PassthroughSubject<SensorSettings, Never>()

    private var ruuviTagController: FetchedRecordsController<SensorSettingsSQLite>
    private var ruuviTagsRealmToken: NotificationToken?
    private var ruuviTagRealmCache = [SensorSettings]()

    deinit {
        ruuviTagsRealmToken?.invalidate()
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
        ruuviTagController = try! FetchedRecordsController(sqlite.database.dbPool, request: request)
        try! ruuviTagController.performFetch()

        ruuviTagController.trackChanges(onChange: { [weak self] _, record, event in
            guard let sSelf = self else { return }
            switch event {
            case .insertion:
                sSelf.insertSubject.send(record.sensorSettings)
            case .update:
                sSelf.updateSubject.send(record.sensorSettings)
            case .deletion:
                sSelf.deleteSubject.send(record.sensorSettings)
            case .move:
                break
            }
        })

        DispatchQueue.main.async { [weak self] in
            guard let sSelf = self else { return }
            let results = sSelf.realm.main.objects(SensorSettingsRealm.self)
                .filter("luid == %@ || macId == %@",
                        luid?.value ?? "invalid",
                        macId?.value ?? "invalid")
            sSelf.ruuviTagRealmCache = results.map(\.sensorSettings)
            sSelf.ruuviTagsRealmToken = results.observe { [weak self] change in
                guard let sSelf = self else { return }
                switch change {
                case let .update(sensorSettings, deletions, insertions, modifications):
                    for del in deletions {
                        sSelf.deleteSubject.send(sSelf.ruuviTagRealmCache[del])
                    }
                    sSelf.ruuviTagRealmCache = sSelf.ruuviTagRealmCache
                        .enumerated()
                        .filter { !deletions.contains($0.offset) }
                        .map(\.element)
                    for ins in insertions {
                        sSelf.insertSubject.send(sensorSettings[ins].sensorSettings)
                        // TODO: test if ok with multiple
                        sSelf.ruuviTagRealmCache.insert(sensorSettings[ins].sensorSettings, at: ins)
                    }
                    for mod in modifications {
                        sSelf.updateSubject.send(sensorSettings[mod].sensorSettings)
                        sSelf.ruuviTagRealmCache[mod] = sensorSettings[mod].sensorSettings
                    }
                default:
                    break
                }
            }
        }
    }
}
