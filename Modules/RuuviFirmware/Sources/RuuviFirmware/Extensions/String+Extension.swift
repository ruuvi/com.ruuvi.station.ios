import Foundation

extension String {
    var semVar: [Int]? {
        // Look for the first x.y.z sequence
        let regex = try! NSRegularExpression(pattern: "(\\d+)\\.(\\d+)\\.(\\d+)")
        let range = NSRange(self.startIndex..<self.endIndex, in: self)
        guard let match = regex.firstMatch(in: self, options: [], range: range) else {
            return nil
        }

        var components = [Int]()
        for i in 1..<match.numberOfRanges {
            if let range = Range(match.range(at: i), in: self),
               let value = Int(self[range]) {
                components.append(value)
            }
        }
        return components.count == 3 ? components : nil
    }
}
