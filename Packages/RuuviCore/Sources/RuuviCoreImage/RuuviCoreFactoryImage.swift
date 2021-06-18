import UIKit
import RuuviCore

public final class RuuviCoreFactoryImage: RuuviCoreFactory {
    public init() {}

    public func createImage() -> RuuviCoreImage {
        return RuuviCoreImageImpl()
    }
}
