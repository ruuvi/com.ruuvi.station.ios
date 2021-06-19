import Foundation

public protocol RuuviCoreFactory {
    func createImage() -> RuuviCoreImage
}
