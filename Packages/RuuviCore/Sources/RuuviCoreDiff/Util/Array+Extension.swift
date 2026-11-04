#if SWIFT_PACKAGE
    import RuuviCore
#endif
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

public extension Array where Element: Equatable {
    /// Moves an element up by one position (towards index 0)
    func movingUp(_ element: Element) -> [Element] {
        guard let currentIndex = firstIndex(of: element), currentIndex > 0 else {
            return self
        }

        var newArray = self
        newArray.swapAt(currentIndex, currentIndex - 1)
        return newArray
    }

    /// Moves an element down by one position (towards last index)
    func movingDown(_ element: Element) -> [Element] {
        guard let currentIndex = firstIndex(of: element), currentIndex < count - 1 else {
            return self
        }

        var newArray = self
        newArray.swapAt(currentIndex, currentIndex + 1)
        return newArray
    }
}

extension String {
    subscript(safe range: NSRange) -> String? {
        let length = utf16.count
        guard range.location >= 0, range.length >= 0, range.location <= length else { return nil }
        let bounded = NSRange(location: range.location, length: Swift.min(range.length, length - range.location))
        let start = utf16.index(utf16.startIndex, offsetBy: bounded.location)
        let end = utf16.index(start, offsetBy: bounded.length)
        guard start.samePosition(in: unicodeScalars) != nil, end.samePosition(in: unicodeScalars) != nil else {
            return nil
        }
        return String(decoding: utf16[start..<end], as: UTF16.self)
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

public extension Array where Element == Int {

    /// Compares two version arrays lexicographically.
    /// Returns .orderedAscending if lhs < rhs, .orderedDescending if lhs > rhs, .orderedSame if equal.
    static func compareVersions(_ lhs: [Int], _ rhs: [Int]) -> ComparisonResult {
        let maxCount = Swift.max(lhs.count, rhs.count)
        for i in 0..<maxCount {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l < r {
                return .orderedAscending
            } else if l > r {
                return .orderedDescending
            }
        }
        return .orderedSame
    }
}
