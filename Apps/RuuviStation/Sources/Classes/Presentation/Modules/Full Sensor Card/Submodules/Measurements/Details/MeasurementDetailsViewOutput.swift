protocol MeasurementDetailsViewOutput: AnyObject {
    func viewDidLoad()
    func didTapGraph()
    func didTapMeasurement(_ measurement: RuuviTagCardSnapshotIndicatorData)
}
