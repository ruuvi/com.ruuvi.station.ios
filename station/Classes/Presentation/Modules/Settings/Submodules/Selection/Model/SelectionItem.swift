import Foundation

protocol SelectionItemProtocol {
    var title: String { get }
}

struct SelectionViewModel {
    let title: String
    let items: [SelectionItemProtocol]
    let description: String
}
