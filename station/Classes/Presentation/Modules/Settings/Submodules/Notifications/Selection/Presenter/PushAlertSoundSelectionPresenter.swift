import Foundation
import RuuviLocal
import RuuviOntology
import UIKit

class PushAlertSoundSelectionPresenter: NSObject {
    weak var view: PushAlertSoundSelectionViewInput?

    var settings: RuuviLocalSettings!

    private var viewModel: PushAlertSoundSelectionViewModel? {
        didSet {
            view?.viewModel = viewModel
        }
    }
}

extension PushAlertSoundSelectionPresenter: PushAlertSoundSelectionViewOutput {
    func viewDidLoad() {
        // No op.
    }

    func viewDidSelectItem(item: SelectionItemProtocol) {
        if let selectedSound = item as? RuuviAlertSound,
           let viewModel
        {
            settings.alertSound = selectedSound
            let updatedViewModel = PushAlertSoundSelectionViewModel(
                title: viewModel.title,
                items: viewModel.items,
                selection: selectedSound
            )
            self.viewModel = updatedViewModel
            view?.playSelectedSound(from: selectedSound)
        }
    }
}

extension PushAlertSoundSelectionPresenter: PushAlertSoundSelectionModuleInput {
    func configure(viewModel: PushAlertSoundSelectionViewModel) {
        self.viewModel = viewModel
    }
}
