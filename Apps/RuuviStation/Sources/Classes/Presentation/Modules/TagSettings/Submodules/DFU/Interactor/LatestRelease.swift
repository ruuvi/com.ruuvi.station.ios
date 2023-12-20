import Foundation

struct LatestRelease: Codable {
    var version: String
    var assets: [LatestReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case version = "tag_name"
        case assets
    }

    private var defaultFullZipAsset: LatestReleaseAsset? {
        assets.first(where: {
            $0.name.hasSuffix("zip")
                && $0.name.contains("default")
                && !$0.name.contains("app")
        })
    }

    private var defaultAppZipAsset: LatestReleaseAsset? {
        assets.first(where: {
            $0.name.hasSuffix("zip")
                && $0.name.contains("default")
                && $0.name.contains("app")
        })
    }

    var defaultFullZipName: String? {
        defaultFullZipAsset?.name
    }

    var defaultFullZipUrl: URL? {
        if let downloadUrlString = defaultFullZipAsset?.downloadUrlString {
            URL(string: downloadUrlString)
        } else {
            nil
        }
    }

    var defaultAppZipName: String? {
        defaultAppZipAsset?.name
    }

    var defaultAppZipUrl: URL? {
        if let downloadUrlString = defaultAppZipAsset?.downloadUrlString {
            URL(string: downloadUrlString)
        } else {
            nil
        }
    }
}

struct LatestReleaseAsset: Codable {
    var name: String
    var downloadUrlString: String

    enum CodingKeys: String, CodingKey {
        case name
        case downloadUrlString = "browser_download_url"
    }
}
