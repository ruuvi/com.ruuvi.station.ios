public protocol RuuviMigrationFactory {
    func createAllOrdered() -> [RuuviMigration]
}
