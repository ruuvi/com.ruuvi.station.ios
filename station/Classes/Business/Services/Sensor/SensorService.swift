import Foundation
import Future
import UIKit
import RuuviOntology

protocol SensorService {
    func setBackground(_ id: Int, for identifier: Identifier)
    func setNextDefaultBackground(for identifier: Identifier) -> Future<UIImage, RUError>
    func setCustomBackground(image: UIImage, virtualSensor: VirtualTagSensor) -> Future<URL, RUError>
    func deleteCustomBackground(for uuid: Identifier)
}
