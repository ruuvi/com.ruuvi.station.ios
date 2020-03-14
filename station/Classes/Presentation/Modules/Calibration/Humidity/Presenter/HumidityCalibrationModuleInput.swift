import Foundation

protocol HumidityCalibrationModuleInput: class {
    func configure(ruuviTag: RuuviTagRealmImpl, humidity: Double)
}
