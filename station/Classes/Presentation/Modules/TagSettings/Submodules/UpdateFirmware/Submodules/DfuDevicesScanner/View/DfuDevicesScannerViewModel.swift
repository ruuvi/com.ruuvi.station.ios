import Foundation
import UIKit

struct DfuDeviceViewModel {
    var id: String
    var isConnectable: Bool = false
    var rssi: Int?
    var name: String?
    var rssiImage: UIImage?
}
