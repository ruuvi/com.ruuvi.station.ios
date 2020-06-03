import UIKit

struct DiscoverDeviceViewModel {
    var id: String
    var isConnectable: Bool = false
    var rssi: Int?
    var mac: String?
    var name: String?
    var logo: UIImage?
}
