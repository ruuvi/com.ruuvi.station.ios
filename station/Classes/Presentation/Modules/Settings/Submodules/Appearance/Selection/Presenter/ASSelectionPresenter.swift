import Foundation
import RuuviLocal
import RuuviOntology
import UIKit

class ASSelectionPresenter: NSObject {
    weak var view: ASSelectionViewInput?

    var settings: RuuviLocalSettings!

    private var viewModel: AppearanceSettingsViewModel? {
        didSet {
            view?.viewModel = viewModel
        }
    }
}

extension ASSelectionPresenter: ASSelectionViewOutput {
    func viewDidLoad() {
        // No op.
    }

    func viewDidSelectItem(
        item: SelectionItemProtocol,
        type: AppearanceSettingType
    ) {
        update(with: item, type: type)
    }
}

extension ASSelectionPresenter: ASSelectionModuleInput {
    func configure(viewModel: AppearanceSettingsViewModel) {
        self.viewModel = viewModel
    }
}

extension ASSelectionPresenter {
    private func update(
        with selection: SelectionItemProtocol,
        type: AppearanceSettingType
    ) {
        switch type {
        case .theme:
            if let theme = selection as? RuuviTheme,
               let viewModel {
                settings.theme = theme
                let updatedViewModel = AppearanceSettingsViewModel(
                    title: viewModel.title,
                    items: viewModel.items,
                    selection: theme,
                    type: viewModel.type
                )
                self.viewModel = updatedViewModel
            }
        }
    }
}
