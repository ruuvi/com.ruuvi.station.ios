import Foundation

extension Double {
    var decimalPoint: Int {
        if self == Double(Int(self)) {
            return 0
        }

        let integerString = String(Int(self))
        let doubleString = String(Double(self))
        let decimalCount = doubleString.count - integerString.count - 1
        return decimalCount
    }
}

extension Double? {
    var intValue: Int {
        guard let self
        else {
            return 0
        }
        return Int(self)
    }
}

extension Double {
    var intValue: Int {
        Int(self)
    }
}
