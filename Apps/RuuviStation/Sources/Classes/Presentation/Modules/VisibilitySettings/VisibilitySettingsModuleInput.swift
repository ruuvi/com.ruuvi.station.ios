import RuuviOntology

protocol VisibilitySettingsModuleInput: AnyObject {
    func configure(
        snapshot: RuuviTagCardSnapshot,
        sensor: RuuviTagSensor,
        sensorSettings: SensorSettings?
    )
}
