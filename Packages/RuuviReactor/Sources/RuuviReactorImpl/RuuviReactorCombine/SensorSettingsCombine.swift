import Combine
import Foundation
import GRDB
import RuuviAnalytics
import RuuviContext
import RuuviOntology

final class SensorSettingsCombine {
    var luid: LocalIdentifier?
    var macId: MACIdentifier?
    var sqlite: SQLiteContext

    let insertSubject = PassthroughSubject<SensorSettings, Never>()
    let updateSubject = PassthroughSubject<SensorSettings, Never>()
    let deleteSubject = PassthroughSubject<SensorSettings, Never>()

    private let errorReporter: RuuviErrorReporter
    private var previousData: [SensorSettingsSQLite] = []
    private var ruuviTagDataTransactionObserver: AnyDatabaseCancellable?

    deinit {
        ruuviTagDataTransactionObserver?.cancel()
    }

    init(
        luid: LocalIdentifier?,
        macId: MACIdentifier?,
        sqlite: SQLiteContext,
        errorReporter: RuuviErrorReporter
    ) {
        self.luid = luid
        self.macId = macId
        self.sqlite = sqlite
        self.errorReporter = errorReporter

        let request = SensorSettingsSQLite
            .filter(
                (luid?.value != nil && SensorSettingsSQLite.luidColumn == luid?.value)
                    || (macId?.value != nil && SensorSettingsSQLite.macIdColumn == macId?.value)
            )

        let observation = ValueObservation.tracking { db in try request.fetchAll(db) }

        do {
            try sqlite.database.dbPool.read { [weak self] db in
                guard let self else { return }
                self.previousData = try request.fetchAll(db)

                ruuviTagDataTransactionObserver = observation.start(
                    in: sqlite.database.dbPool
                ) { [weak self] error in
                    self?.errorReporter.report(error: error)
                } onChange: { [weak self] newData in
                    guard let self else { return }
                    // Find inserts (present in newData but not in previousData)
                    let inserts = newData.filter { newItem in
                        !self.previousData.contains { $0.id == newItem.id }
                    }

                    // Find deletes (present in previousData but not in newData)
                    let deletes = self.previousData.filter { oldItem in
                        !newData.contains { $0.id == oldItem.id }
                    }

                    // Find updates (present in both, but maybe different in some other properties)
                    let updates = newData.filter { newItem in
                        self.previousData.contains { $0 == newItem }
                    }

                    if !inserts.isEmpty {
                        DispatchQueue.main.async {
                            inserts.forEach { self.insertSubject.send($0) }
                        }
                    }
                    if !updates.isEmpty {
                        DispatchQueue.main.async {
                            updates.forEach { self.updateSubject.send($0) }
                        }
                    }
                    if !deletes.isEmpty {
                        DispatchQueue.main.async {
                            deletes.forEach { self.deleteSubject.send($0) }
                        }
                    }

                    // Update previousData for the next onChange call
                    self.previousData = newData
                }
            }
        } catch {
            errorReporter.report(error: error)
        }
    }
}

extension SensorSettingsSQLite: Equatable {
    public static func == (lhs: SensorSettingsSQLite, rhs: SensorSettingsSQLite) -> Bool {
        lhs.luid?.any == rhs.luid?.any
        && lhs.macId?.any == rhs.macId?.any
        && lhs.temperatureOffset == rhs.temperatureOffset
        && lhs.temperatureOffsetDate == rhs.temperatureOffsetDate
        && lhs.humidityOffset == rhs.humidityOffset
        && lhs.humidityOffsetDate == rhs.humidityOffsetDate
        && lhs.pressureOffset == rhs.pressureOffset
        && lhs.pressureOffsetDate == rhs.pressureOffsetDate
    }
}
