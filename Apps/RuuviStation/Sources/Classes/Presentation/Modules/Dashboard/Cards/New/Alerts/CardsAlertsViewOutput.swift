import RuuviOntology

protocol CardsAlertsViewOutput: AnyObject {
    func alertsViewDidLoad()
    func alertsViewDidBecomeActive()
    func alertsViewDidToggleAlert(_ type: MeasurementType, isOn: Bool)
}
