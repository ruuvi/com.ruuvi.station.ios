import Foundation

protocol HumidityCalibrationModuleInput: class {
    func configure(ruuviTag: RuuviTagRealm)
}
