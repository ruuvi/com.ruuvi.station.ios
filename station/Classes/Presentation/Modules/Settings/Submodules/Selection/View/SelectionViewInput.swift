import Foundation

protocol SelectionViewInput: ViewInput {
    var items: [SelectionItemProtocol] { get set }
    var title: String? { get set }
}
