import Foundation

protocol RuuviTagDecoder {
    func decode(data: Data) -> RuuviTag
}
