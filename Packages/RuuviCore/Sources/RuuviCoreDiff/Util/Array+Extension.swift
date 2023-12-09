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
    subscript(safe range: NSRange) -> String? {
        guard count > range.location
        else {
            return nil
        }
        let length = count > range.location + range.length ? range.location + range.length : count
        let startIndex = index(startIndex, offsetBy: range.location)
        let endIndex = index(self.startIndex, offsetBy: length)
        return String(self[startIndex ..< endIndex])
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
