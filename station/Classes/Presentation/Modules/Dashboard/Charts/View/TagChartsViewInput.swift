import Foundation

protocol TagChartsViewInput: ViewInput {
    var viewModels: [TagChartsViewModel] { get set }
    
    func scroll(to index: Int, immediately: Bool)
}

extension TagChartsViewInput {
    func scroll(to index: Int) {
        scroll(to: index, immediately: false)
    }
}
