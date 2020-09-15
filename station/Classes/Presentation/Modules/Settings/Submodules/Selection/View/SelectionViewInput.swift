import Foundation

protocol SelectionViewInput: ViewInput {
    var items: [SelectionItemProtocol] { get set }
}
