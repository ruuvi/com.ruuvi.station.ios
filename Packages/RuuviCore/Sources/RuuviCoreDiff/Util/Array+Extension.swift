import Foundation

extension Array where Element: Hashable {
    func filterDuplicates() -> [Element] {
        var set = Set<Element>()
        var filteredArray = [Element]()
        for item in self where set.insert(item).inserted {
            filteredArray.append(item)
        }
        return filteredArray
    }
}
extension String {
    subscript (safe range: NSRange) -> String? {
        guard self.count > range.location else {
            return nil
        }
        let length = self.count > range.location + range.length ? range.location + range.length : self.count
        let startIndex = self.index(self.startIndex, offsetBy: range.location)
        let endIndex = self.index(self.startIndex, offsetBy: length)
        return String(self[startIndex..<endIndex])
    }
}
extension Collection {
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
