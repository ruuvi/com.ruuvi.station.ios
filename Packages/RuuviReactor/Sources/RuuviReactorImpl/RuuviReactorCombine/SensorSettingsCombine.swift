import Combine
import Foundation
import GRDB
import RuuviContext
import RuuviOntology

final class SensorSettingsCombine {
    var luid: LocalIdentifier?
    var macId: MACIdentifier?
    var sqlite: SQLiteContext

    let insertSubject = PassthroughSubject<SensorSettings, Never>()
    let updateSubject = PassthroughSubject<SensorSettings, Never>()
    let deleteSubject = PassthroughSubject<SensorSettings, Never>()

    private var ruuviTagController: FetchedRecordsController<SensorSettingsSQLite>

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    init(
        luid: LocalIdentifier?,
        macId: MACIdentifier?,
        sqlite: SQLiteContext
    ) {
        self.luid = luid
        self.macId = macId
        self.sqlite = sqlite

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
    }
}
