import Swinject

class AppAssembly {
    static let shared = AppAssembly()
    var assembler: Assembler
    
    init() {
        assembler = Assembler(
            [
                PersistenceAssembly()
            ])
    }
}
