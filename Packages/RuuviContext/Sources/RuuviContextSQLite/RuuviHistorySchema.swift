import GRDB

/// Kept separate so migrations and the real persistence tests use the same schema.
enum RuuviHistorySchema {
    static func createIntervalRevisions(in db: Database) throws {
        try db.execute(sql: """
        CREATE TABLE history_interval_revision(
            sensor TEXT NOT NULL, day INTEGER NOT NULL, revision INTEGER NOT NULL,
            PRIMARY KEY(sensor, day)
        );
        """)
        for event in ["INSERT", "DELETE", "UPDATE"] {
            // Updates can move a reading to another date or sensor. Invalidate both.
            let rows = event == "UPDATE" ? ["OLD", "NEW"] : [event == "DELETE" ? "OLD" : "NEW"]
            let statements = rows.flatMap { row in
                ["mac", "luid"].map { column in
                    """
                    INSERT INTO history_interval_revision(sensor, day, revision)
                    SELECT \(row).\(column), CAST(strftime('%s', \(row).date) AS INTEGER) / 86400, 1
                    WHERE \(row).\(column) IS NOT NULL
                    ON CONFLICT(sensor, day) DO UPDATE SET revision = revision + 1;
                    """
                }
            }.joined(separator: "\n")
            try db.execute(sql: """
            CREATE TRIGGER history_interval_\(event.lowercased()) AFTER \(event) ON ruuvi_tag_sensor_records BEGIN
                \(statements)
            END;
            """)
        }
    }

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
