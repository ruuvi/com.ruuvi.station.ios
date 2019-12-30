import Foundation

protocol TagChartsModuleInput: class {
    func configure(output: TagChartsModuleOutput)
    func configure(uuid: String)
    func dismiss()
}
