import Foundation
import Future

protocol SensorService {
    // background
    func background(for identifier: Identifier) -> Future<UIImage, RUError>
    func setBackground(_ id: Int, for identifier: Identifier)
    func setNextDefaultBackground(for identifier: Identifier) -> Future<UIImage, RUError>
    func setCustomBackground(image: UIImage, for identifier: Identifier) -> Future<URL, RUError>
}
