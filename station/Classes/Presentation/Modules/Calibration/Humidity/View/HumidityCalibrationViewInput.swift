import Foundation

protocol HumidityCalibrationViewInput: ViewInput {
    var oldHumidity: Double { get set }
    var humidityOffset: Double { get set }
}
