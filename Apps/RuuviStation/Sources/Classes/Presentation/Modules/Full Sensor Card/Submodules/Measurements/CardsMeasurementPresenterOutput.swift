import RuuviOntology

protocol CardsMeasurementPresenterOutput: AnyObject {
    func measurementPresenter(
        _ presenter: CardsMeasurementPresenter,
        didNavigateToIndex index: Int
    )
    func showMeasurementDetails(
        for indicator: RuuviTagCardSnapshotIndicatorData,
        snapshot: RuuviTagCardSnapshot,
        sensor: RuuviTagSensor,
        settings: SensorSettings?,
        presenter: CardsMeasurementPresenter,
    )
}
