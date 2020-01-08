import UIKit

extension UIDevice {
    var readableModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let iOSDeviceModelsPath = Bundle.main.path(forResource: "iOSDeviceModelMapping", ofType: "plist")!
        let iOSDevices = NSDictionary(contentsOfFile: iOSDeviceModelsPath)

        var sysinfo = utsname()
        uname(&sysinfo)
        let deviceModel = String(bytes: Data(bytes: &sysinfo.machine,
                                             count: Int(_SYS_NAMELEN)),
                                 encoding: .ascii)!
            .trimmingCharacters(in: .controlCharacters)

        var modelReadable = iOSDevices?.value(forKey: deviceModel) as? String
        if modelReadable == nil {
            modelReadable = "unknown"
        }
        return modelReadable!
    }
}
