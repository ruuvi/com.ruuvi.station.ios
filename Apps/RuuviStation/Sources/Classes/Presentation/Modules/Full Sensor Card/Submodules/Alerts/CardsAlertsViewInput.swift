import RuuviOntology

protocol CardsAlertsViewInput: AnyObject {
    func configure(snapshot: RuuviTagCardSnapshot)
    func updateAlertSections(_ sections: [CardsSettingsAlertSectionModel])
}
