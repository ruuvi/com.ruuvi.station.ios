import Foundation

protocol TagActionsModuleInput: class {
    func configure(uuid: String)
    func configure(isConnectable: Bool)
}
