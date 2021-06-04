import Foundation
import Swinject

class DfuAssembly: Assembly {
    func assemble(container: Container) {
        container.register(RuuviDfu.self) { _ in
            return RuuviDfu.shared
        }.inObjectScope(.container)
    }
}
