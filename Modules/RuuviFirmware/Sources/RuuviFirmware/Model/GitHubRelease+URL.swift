import Foundation

extension GitHubRelease {
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
    
    private var defaultFullZipAsset: GitHubRelease.Asset? {
         return assets.first(where: {
             $0.name.hasSuffix("zip")
                 && $0.name.contains("default")
                 && !$0.name.contains("app")
         })
     }

    private var defaultAppZipAsset: GitHubRelease.Asset? {
         return assets.first(where: {
             $0.name.hasSuffix("zip")
                 && $0.name.contains("default")
                 && $0.name.contains("app")
         })
     }
}
