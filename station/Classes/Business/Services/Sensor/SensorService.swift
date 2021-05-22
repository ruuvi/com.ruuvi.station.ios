import Foundation
import Future

protocol SensorService {
    func background(for identifier: Identifier) -> Future<UIImage, RUError>
    func setNextDefaultBackground(for identifier: Identifier) -> Future<UIImage, RUError>
}
