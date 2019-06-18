import Foundation

protocol ChartViewInput: ViewInput {
    var data: [ChartViewModel] { get set }
}
