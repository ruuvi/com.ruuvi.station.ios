import Foundation
import RuuviOntology

protocol PushAlertSoundSelectionViewInput: ViewInput {
    var viewModel: PushAlertSoundSelectionViewModel? { get set }
    func playSelectedSound(from sound: RuuviAlertSound)
}
