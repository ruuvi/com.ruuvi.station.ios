import Foundation
import BTKit

protocol DiscoverViewInput: ViewInput {
    var ruuviTags: [RuuviTag] { get set }
    
    var isBluetoothEnabled: Bool { get set }
}
