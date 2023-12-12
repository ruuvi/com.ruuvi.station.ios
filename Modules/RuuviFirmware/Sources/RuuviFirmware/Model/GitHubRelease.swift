import Foundation

struct GitHubRelease: Codable {
    struct Asset: Codable {
        var name: String
        var downloadUrlString: String

        enum CodingKeys: String, CodingKey {
            case name
            case downloadUrlString = "browser_download_url"
        }
    }

    var version: String
    var assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case version = "tag_name"
        case assets
    }
}
