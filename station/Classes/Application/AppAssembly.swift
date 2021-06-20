import Swinject

final class AppAssembly {
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
                DfuAssembly(),
                VirtualAssembly()
            ])
    }
}
