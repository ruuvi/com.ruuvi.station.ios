import RuuviOntology

protocol VisibilitySettingsModuleInput: AnyObject {
    func configure(
        snapshot: RuuviTagCardSnapshot,
        sensor: RuuviTagSensor,
        sensorSettings: SensorSettings?
    )
    func configure(output: VisibilitySettingsModuleOutput?)
    func dismiss(completion: (() -> Void)?)
}
