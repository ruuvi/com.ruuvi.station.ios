import Foundation

protocol SelectionViewOutput {
    func viewDidLoad()
    func viewDidSelect(itemAtIndex index: Int)
}
