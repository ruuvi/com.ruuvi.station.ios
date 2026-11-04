public protocol RuuviMigration {
    @MainActor func migrate() async throws
}

public enum RuuviMigrationRunner {
    /// A later migration may depend on the preceding migration's persisted values.
    @MainActor public static func migrate(_ migrations: [RuuviMigration]) async throws {
        for migration in migrations {
            try Task.checkCancellation()
            try await migration.migrate()
        }
    }
}
