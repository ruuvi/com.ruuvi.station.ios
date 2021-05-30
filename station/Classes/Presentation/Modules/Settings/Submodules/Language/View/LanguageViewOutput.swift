import Foundation
import RuuviOntology

protocol LanguageViewOutput {
    func viewDidLoad()
    func viewDidSelect(language: Language)
}
