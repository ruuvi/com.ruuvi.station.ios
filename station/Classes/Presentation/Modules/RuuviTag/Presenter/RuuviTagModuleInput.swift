import Foundation
import BTKit

protocol RuuviTagModuleInput: class {
    func configure(ruuviTag: RuuviTag)
}
