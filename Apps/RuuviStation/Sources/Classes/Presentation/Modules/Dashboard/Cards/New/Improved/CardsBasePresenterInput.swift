import RuuviOntology

protocol CardsBasePresenterInput: AnyObject {
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
