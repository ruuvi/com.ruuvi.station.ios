import Foundation

protocol LanguageViewOutput {
    func viewDidLoad()
    func viewDidSelect(language: Language)
}
