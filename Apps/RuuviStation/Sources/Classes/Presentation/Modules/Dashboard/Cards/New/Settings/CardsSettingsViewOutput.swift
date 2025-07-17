
protocol CardsSettingsViewOutput: AnyObject {
    func settingsViewDidLoad()
    func settingsViewDidBecomeActive()
    func settingsViewDidUpdateSensorName(_ name: String)
}
