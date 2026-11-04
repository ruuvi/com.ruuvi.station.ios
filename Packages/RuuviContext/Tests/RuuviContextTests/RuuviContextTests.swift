import Foundation
import GRDB
import Testing
@testable import RuuviContext
#if SWIFT_PACKAGE
    @testable import RuuviContextSQLite
#endif

struct RuuviContextTests {
    @Test func migrationIsRepeatableAndPreservesExistingData() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let context = try SQLiteContextFactoryGRDB().create(at: directory.appendingPathComponent("test.sqlite"))
        try context.database.dbPool.write { db in
            try db.execute(sql: "CREATE TABLE sentinel(value TEXT NOT NULL)")
            try db.execute(sql: "INSERT INTO sentinel VALUES ('preserve me')")
        }
        try context.database.migrateIfNeeded()
        let value = try context.database.dbPool.read { db in try String.fetchOne(db, sql: "SELECT value FROM sentinel")
        }
        #expect(value == "preserve me")
    }

    @Test func failedMigrationDoesNotDeleteExistingDatabase() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("broken.sqlite")
        let database = try SQLiteGRDBDatabase(path: url.path)
        try database.dbPool.write { db in
            try db.execute(sql: "CREATE TABLE sentinel(value TEXT NOT NULL)")
            try db.execute(sql: "INSERT INTO sentinel VALUES ('must survive')")
            // A conflicting table forces the first schema migration to fail.
            try db.execute(sql: "CREATE TABLE ruuvi_tag_sensors (incompatible INTEGER)")
        }
        #expect(throws: (any Error).self) {
            _ = try SQLiteContextFactoryGRDB().create(at: url)
        }
        let sentinel = try database.dbPool.read { db in try String.fetchOne(db, sql: "SELECT value FROM sentinel") }
        #expect(sentinel == "must survive")
        #expect(FileManager.default.fileExists(atPath: url.path))
    }
}
