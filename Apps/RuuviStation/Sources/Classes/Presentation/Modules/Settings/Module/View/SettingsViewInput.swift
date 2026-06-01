import Foundation
import RuuviOntology

protocol SettingsViewInput: ViewInput {
    var language: Language { get set }
    var experimentalFunctionsEnabled: Bool { get set }
    var cloudModeVisible: Bool { get set }
    var globalUnitsSettingsEnabled: Bool { get set }
    func viewDidShowLanguageChangeDialog()
}
