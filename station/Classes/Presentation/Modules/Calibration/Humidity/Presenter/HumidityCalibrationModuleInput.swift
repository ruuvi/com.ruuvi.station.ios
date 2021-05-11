import Foundation

protocol HumidityCalibrationModuleInput: AnyObject {
    func configure(ruuviTag: RuuviTagSensor, humidity: Double)
}
