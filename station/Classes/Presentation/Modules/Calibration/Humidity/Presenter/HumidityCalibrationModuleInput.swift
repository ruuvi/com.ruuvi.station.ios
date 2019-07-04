import Foundation

protocol HumidityCalibrationModuleInput: class {
    func configure(ruuviTag: RuuviTagRealm, humidity: Double)
}
