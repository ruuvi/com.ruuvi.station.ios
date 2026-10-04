import GRDB

/// Kept separate so migrations and the real persistence tests use the same schema.
enum RuuviHistorySchema {
    static func create(in db: Database) throws {
        try db.execute(sql: """
        CREATE INDEX IF NOT EXISTS history_mac_date ON ruuvi_tag_sensor_records(mac, date);
        CREATE INDEX IF NOT EXISTS history_luid_date ON ruuvi_tag_sensor_records(luid, date);
        CREATE INDEX IF NOT EXISTS history_date ON ruuvi_tag_sensor_records(date);
        CREATE TABLE history_revision(sensor TEXT PRIMARY KEY NOT NULL, revision INTEGER NOT NULL DEFAULT 0);
        CREATE TABLE history_generation(sensor TEXT PRIMARY KEY NOT NULL, generation INTEGER NOT NULL DEFAULT 0);
        CREATE TABLE history_coverage(
            sensor TEXT NOT NULL, scope TEXT NOT NULL, start DOUBLE NOT NULL,
            end DOUBLE NOT NULL, fetched DOUBLE NOT NULL
        );
        CREATE INDEX history_coverage_sensor ON history_coverage(sensor, scope);
        """)
        for event in ["INSERT", "DELETE", "UPDATE"] {
            let row = event == "DELETE" ? "OLD" : "NEW"
            try db.execute(sql: """
            CREATE TRIGGER history_revision_\(event.lowercased()) AFTER \(event) ON ruuvi_tag_sensor_records BEGIN
                INSERT OR IGNORE INTO history_revision(sensor) SELECT \(row).mac WHERE \(row).mac IS NOT NULL;
                INSERT OR IGNORE INTO history_revision(sensor) SELECT \(row).luid WHERE \(row).luid IS NOT NULL;
                UPDATE history_revision SET revision = revision + 1 WHERE sensor = \(row).mac OR sensor = \(
                    row
                ).luid;
            END;
            """)
        }
    }
}
