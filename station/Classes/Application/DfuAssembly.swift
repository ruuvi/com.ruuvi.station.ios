import Foundation
import Swinject
import RuuviDFU

class DfuAssembly: Assembly {
    func assemble(container: Container) {
        container.register(RuuviDFU.self) { _ in
            return RuuviDFUImpl.shared
        }.inObjectScope(.container)
    }
}
