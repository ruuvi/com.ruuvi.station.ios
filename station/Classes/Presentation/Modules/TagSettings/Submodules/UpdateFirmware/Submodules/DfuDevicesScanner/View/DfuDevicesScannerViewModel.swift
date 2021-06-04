import Foundation
import UIKit

class DfuDevicesScannerViewModel: NSObject {
    var title: String {
        return "Select Device".localized()
    }
}

struct DfuDeviceViewModel {
    var id: String
    var isConnectable: Bool = false
    var rssi: Int?
    var name: String?
    var rssiImage: UIImage?
}
