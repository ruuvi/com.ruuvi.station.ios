import Foundation
import Future
import UIKit
import RuuviOntology

protocol SensorService {
    func setNextDefaultBackground(for identifier: Identifier) -> Future<UIImage, RUError>
}
