import RuuviOntology
import UIKit

protocol DevicesViewOutput {
    func viewDidLoad()
    func viewWillAppear()
    func viewDidTapDevice(viewModel: DevicesViewModel)
}
