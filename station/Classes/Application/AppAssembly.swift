import Swinject

class AppAssembly {
    static let shared = AppAssembly()
    var assembler: Assembler

    init() {
        assembler = Assembler(
            [
                BusinessAssembly(),
                CoreAssembly(),
                NetworkingAssembly(),
                PersistenceAssembly(),
                PresentationAssembly(),
                ReactorAssembly(),
                TankAssembly(),
                TrunkAssembly(),
                DfuAssembly()
            ])
    }
}
