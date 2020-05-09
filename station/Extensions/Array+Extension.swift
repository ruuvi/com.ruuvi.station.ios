import Foundation

extension Array where Element: Hashable {
    func filterDuplicates() -> [Element] {
        var set = Set<Element>()
        var filteredArray = [Element]()
        for item in self {
            if set.insert(item).inserted {
                filteredArray.append(item)
            }
        }
        return filteredArray
    }
}
