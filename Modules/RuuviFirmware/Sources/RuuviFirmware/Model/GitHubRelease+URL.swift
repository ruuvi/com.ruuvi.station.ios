import Foundation

extension GitHubRelease {
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

    private var defaultFullZipAsset: GitHubRelease.Asset? {
        assets.first(where: {
            $0.name.hasSuffix("zip")
                && $0.name.contains("default")
                && !$0.name.contains("app")
        })
    }

    private var defaultAppZipAsset: GitHubRelease.Asset? {
        assets.first(where: {
            $0.name.hasSuffix("zip")
                && $0.name.contains("default")
                && $0.name.contains("app")
        })
    }
}
