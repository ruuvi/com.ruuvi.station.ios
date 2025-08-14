import RuuviOntology

protocol CardsBasePresenterInput: AnyObject {
    // swiftlint:disable:next function_parameter_count
    func configure(
        for snapshot: RuuviTagCardSnapshot,
        snapshots: [RuuviTagCardSnapshot],
        ruuviTagSensors: [AnyRuuviTagSensor],
        sensorSettings: [SensorSettings],
        activeMenu: CardsMenuType,
        output: CardsBasePresenterOutput?
    )

    func dismiss(completion: (() -> Void)?)
}
