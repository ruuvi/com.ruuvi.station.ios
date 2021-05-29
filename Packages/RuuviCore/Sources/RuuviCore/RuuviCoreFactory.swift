import UIKit

public protocol RuuviCoreFactory {
    func createImage() -> RuuviCoreImage
}

public final class RuuviCoreFactoryImpl: RuuviCoreFactory {
    public init() {}
    
    public func createImage() -> RuuviCoreImage {
        return RuuviCoreImageImpl()
    }
}
