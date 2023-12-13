import Foundation

struct Networking: Codable {
    var RuuviCloudURL: String
    var RuuviCloudURLDev: String
}

enum AppAssemblyConstants {
    static let networkingPath = Bundle.main.path(forResource: "Networking", ofType: "plist")!
    static let xml = FileManager.default.contents(atPath: networkingPath)!
    static let networkingPlist = try! PropertyListDecoder().decode(Networking.self, from: xml)

    static let ruuviCloudUrl = networkingPlist.RuuviCloudURL
    static let ruuviCloudUrlDev = networkingPlist.RuuviCloudURLDev
    static let simpleWidgetKindId = "ruuvi.simpleWidget"
}
