import Foundation

protocol TagSettingsRouterInput {
    func dismiss()

    func openHumidityCalibration(ruuviTag: RuuviTagRealmImpl, humidity: Double)
}
