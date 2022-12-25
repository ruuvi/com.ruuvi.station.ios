import UIKit
import RuuviOntology

protocol DevicesViewOutput {
    func viewDidLoad()
    func viewWillAppear()
    func viewDidTapDevice(viewModel: DevicesViewModel)
}
