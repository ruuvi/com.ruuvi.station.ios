#if SWIFT_PACKAGE
    import RuuviReactor
    import RuuviOntologySQLite
#endif
import Foundation
import GRDB
import RuuviAnalytics
import RuuviContext
import RuuviOntology
import RuuviPersistence

/// Each subscription gets a single database observation. The initial snapshot and all later
/// changes are read by GRDB in commit order and delivered on its serial main-queue scheduler.
final class RuuviReactorImpl: RuuviReactor {
    private let sqliteContext: SQLiteContext
    private let errorReporter: RuuviErrorReporter

    init(sqliteContext: SQLiteContext, sqlitePersistence _: RuuviPersistence, errorReporter: RuuviErrorReporter) {
        self.sqliteContext = sqliteContext
        self.errorReporter = errorReporter
    }

    func observe(_ block: @escaping (RuuviReactorChange<AnyRuuviTagSensor>) -> Void) -> RuuviReactorToken {
        let request = RuuviTagSQLite.order(RuuviTagSQLite.versionColumn)
        var previous: [RuuviTagSQLite]?
        let observation = ValueObservation.tracking { db in try request.fetchAll(db) }.removeDuplicates()
        let token = observation.start(
            in: sqliteContext.database.dbPool,
            onError: { error in
                block(.error(.ruuviPersistence(.grdb(error))))
            },
            onChange: { values in
                defer { previous = values }
                guard let previous else { block(.initial(values.map(\.any))); return }
                for value in values where !previous.contains(where: { $0.id == value.id }) { block(.insert(value.any)) }
                for value in values where previous.contains(where: { $0.id == value.id && $0 != value }) {
                    block(.update(value.any))
                }
                for value in previous where !values.contains(where: { $0.id == value.id }) { block(.delete(value.any)) }
            })
        return RuuviReactorToken { token.cancel() }
    }

    func observe(_ luid: LocalIdentifier, _ block: @escaping ([AnyRuuviTagSensorRecord]) -> Void) -> RuuviReactorToken {
        let request = RuuviTagDataSQLite.order(RuuviTagDataSQLite.dateColumn).filter(
            RuuviTagDataSQLite.luidColumn == luid.value)
        let observation = ValueObservation.tracking { db in try Row.fetchAll(db, request) }.removeDuplicates()
        let token = observation.start(
            in: sqliteContext.database.dbPool,
            onError: { [errorReporter] in
                errorReporter.report(error: $0)
            }, onChange: { block($0.map { RuuviTagDataSQLite(row: $0).any }) })
        return RuuviReactorToken { token.cancel() }
    }

    func observeLast(
        _ sensor: RuuviTagSensor, _ block: @escaping (RuuviReactorChange<AnyRuuviTagSensorRecord?>) -> Void
    ) -> RuuviReactorToken {
        let request = RuuviTagDataSQLite.order(RuuviTagDataSQLite.dateColumn.desc)
            .filter(identityFilter(sensor, luid: RuuviTagDataSQLite.luidColumn, mac: RuuviTagDataSQLite.macColumn))
        let observation = ValueObservation.tracking { db in try Row.fetchOne(db, request) }.removeDuplicates()
        let token = observation.start(
            in: sqliteContext.database.dbPool,
            onError: {
                block(.error(.ruuviPersistence(.grdb($0))))
            }, onChange: { block(.update($0.map { RuuviTagDataSQLite(row: $0).any })) })
        return RuuviReactorToken { token.cancel() }
    }

    func observeLatest(
        _ sensor: RuuviTagSensor, _ block: @escaping (RuuviReactorChange<AnyRuuviTagSensorRecord?>) -> Void
    ) -> RuuviReactorToken {
        let request = RuuviTagLatestDataSQLite.order(RuuviTagLatestDataSQLite.dateColumn.desc)
            .filter(
                identityFilter(
                    sensor, luid: RuuviTagLatestDataSQLite.luidColumn, mac: RuuviTagLatestDataSQLite.macColumn))
        let observation = ValueObservation.tracking { db in try Row.fetchOne(db, request) }.removeDuplicates()
        let token = observation.start(
            in: sqliteContext.database.dbPool,
            onError: {
                block(.error(.ruuviPersistence(.grdb($0))))
            }, onChange: { block(.update($0.map { RuuviTagLatestDataSQLite(row: $0).any })) })
        return RuuviReactorToken { token.cancel() }
    }

    func observe(_ sensor: RuuviTagSensor, _ block: @escaping (RuuviReactorChange<SensorSettings>) -> Void)
        -> RuuviReactorToken
    {
        let request = SensorSettingsSQLite.filter(
            identityFilter(sensor, luid: SensorSettingsSQLite.luidColumn, mac: SensorSettingsSQLite.macIdColumn))
        var previous: [SensorSettingsSQLite]?
        let observation = ValueObservation.tracking { db in try request.fetchAll(db) }.removeDuplicates()
        let token = observation.start(
            in: sqliteContext.database.dbPool,
            onError: {
                block(.error(.ruuviPersistence(.grdb($0))))
            },
            onChange: { values in
                defer { previous = values }
                guard let previous else { block(.initial(values)); return }
                for value in values where !previous.contains(where: { $0.id == value.id }) { block(.insert(value)) }
                for value in values where previous.contains(where: { $0.id == value.id && $0 != value }) {
                    block(.update(value))
                }
                for value in previous where !values.contains(where: { $0.id == value.id }) { block(.delete(value)) }
            })
        return RuuviReactorToken { token.cancel() }
    }

    private func identityFilter(_ sensor: RuuviTagSensor, luid: Column, mac: Column) -> SQLExpression {
        let suffix = sensor.macId?.value.macSuffix
        let hasSuffix = suffix?.count == 8
        return (sensor.luid != nil && luid == sensor.luid?.value)
            || (hasSuffix && mac.like("%\(suffix ?? "")"))
            || (!hasSuffix && sensor.macId != nil && mac == sensor.macId?.value)
    }
}
