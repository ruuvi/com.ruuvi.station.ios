import Foundation

struct LatestRelease: Codable {
    var version: String
    var assets: [LatestReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case version = "tag_name"
        case assets = "assets"
    }

    private var defaultFullZipAsset: LatestReleaseAsset? {
        return assets.first(where: {
            $0.name.hasSuffix("zip")
                && $0.name.contains("default")
                && !$0.name.contains("app")
        })
    }

    private var defaultAppZipAsset: LatestReleaseAsset? {
        return assets.first(where: {
            $0.name.hasSuffix("zip")
                && $0.name.contains("default")
                && $0.name.contains("app")
        })
    }

    var defaultFullZipName: String? {
        return defaultFullZipAsset?.name
    }

    var defaultFullZipUrl: URL? {
        if let downloadUrlString = defaultFullZipAsset?.downloadUrlString {
            return URL(string: downloadUrlString)
        } else {
            return nil
        }
    }

    var defaultAppZipName: String? {
        return defaultAppZipAsset?.name
    }

    var defaultAppZipUrl: URL? {
        if let downloadUrlString = defaultAppZipAsset?.downloadUrlString {
            return URL(string: downloadUrlString)
        } else {
            return nil
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
