import Foundation

extension String {
    static let nbsp = "\u{00a0}"
}

extension String? {
    func hasText() -> Bool {
        if let self, !self.isEmpty {
            true
        } else {
            false
        }
    }
}

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

    var normalizedFirmwareVersionIdentifier: String? {
        let regex = try! NSRegularExpression(
            pattern: "[vV]?\\d+\\.\\d+\\.\\d+(?:-[0-9A-Za-z.-]+)?(?:\\+[0-9A-Za-z.-]+)?"
        )
        let range = NSRange(self.startIndex..<self.endIndex, in: self)
        guard let match = regex.firstMatch(in: self, options: [], range: range),
              let matchRange = Range(match.range, in: self) else {
            return nil
        }

        var version = String(self[matchRange])
        if let first = version.first, first == "v" || first == "V" {
            version.removeFirst()
        }
        return version
    }
}
