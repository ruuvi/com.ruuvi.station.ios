import Foundation
import RuuviOntology

protocol LanguageViewInput: ViewInput {
    var languages: [Language] { get set }
}
