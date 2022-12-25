import Foundation
import RuuviOntology

protocol DevicesInteractorOutput: AnyObject {
    func interactorDidUpdate(tokens: [RuuviCloudPNToken])
    func interactorDidError(_ error: RUError)
}
