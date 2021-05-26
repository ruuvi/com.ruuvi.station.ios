import Foundation

public protocol Reorderable {
    associatedtype OrderElement: Equatable
    var orderElement: OrderElement { get }
}

extension Array where Element: Reorderable {
    public func reorder(by preferredOrder: [Element.OrderElement]) -> [Element] {
        sorted {
            guard let first = preferredOrder.firstIndex(of: $0.orderElement) else {
                return false
            }
            guard let second = preferredOrder.firstIndex(of: $1.orderElement) else {
                return true
            }
            return first < second
        }
    }
}
