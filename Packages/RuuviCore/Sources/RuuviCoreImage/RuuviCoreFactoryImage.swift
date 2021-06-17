import UIKit

public final class RuuviCoreFactoryImpl: RuuviCoreFactory {
    public init() {}

    public func createImage() -> RuuviCoreImage {
        return RuuviCoreImageImpl()
    }
}
