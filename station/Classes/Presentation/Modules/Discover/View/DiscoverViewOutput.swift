import Foundation
import BTKit

protocol DiscoverViewOutput {
    func viewWillAppear()
    func viewWillDisappear()
    func viewDidSelect(ruuviTag: RuuviTag)
}
