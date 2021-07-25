import Foundation

public typealias FeatureToggleCallback = ([FeatureToggle]) -> Void

public protocol FeatureToggleProvider {
    func fetchFeatureToggles(_ completion: @escaping FeatureToggleCallback)
}
