import Foundation
import Future

protocol SensorService {
    // background
    func background(luid: LocalIdentifier?, macId: MACIdentifier?) -> Future<UIImage, RUError>
    func setBackground(_ id: Int, for identifier: Identifier)
    func setNextDefaultBackground(for identifier: Identifier) -> Future<UIImage, RUError>
    func setCustomBackground(image: UIImage, virtualSensor: VirtualTagSensor) -> Future<URL, RUError>
    func setCustomBackground(image: UIImage, sensor: RuuviTagSensor) -> Future<URL, RUError>
    func deleteCustomBackground(for uuid: Identifier)
    @discardableResult
    func ensureNetworkBackgroundIsLoaded(for macId: MACIdentifier, from url: URL) -> Future<UIImage, RUError>
}
