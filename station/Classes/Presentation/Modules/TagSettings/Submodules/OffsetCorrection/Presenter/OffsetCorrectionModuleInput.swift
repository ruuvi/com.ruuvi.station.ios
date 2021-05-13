import Foundation

enum OffsetCorrectionType: Int {
    case temperature = 0
    case humidity = 1
    case pressure = 2
}

protocol OffsetCorrectionModuleInput: class {
    func configure(type: OffsetCorrectionType, ruuviTag: RuuviTagSensor, sensorSettings: SensorSettings?)
}
