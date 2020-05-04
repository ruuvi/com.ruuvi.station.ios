import Foundation

protocol HumidityCalibrationModuleInput: class {
    func configure(ruuviTag: RuuviTagSensor, humidity: Double)
}
