import Foundation

protocol TagChartsViewInput: ViewInput {
    var viewModels: [TagChartsViewModel] { get set }
    
    func scroll(to index: Int)
}
