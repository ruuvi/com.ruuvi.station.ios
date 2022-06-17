import Foundation

extension FileManager {
    var appInstalledDate: Date {
        if
            let urlToDocumentsFolder = FileManager.default.urls(for: .documentDirectory,
                                                                in: .userDomainMask).last,
            let installDateAny = try? FileManager.default.attributesOfItem(atPath:
                                                                            urlToDocumentsFolder.path)[.creationDate],
            let installDate = installDateAny as? Date
        {
            return installDate
        } else {
            return Date()
        }
    }
}
