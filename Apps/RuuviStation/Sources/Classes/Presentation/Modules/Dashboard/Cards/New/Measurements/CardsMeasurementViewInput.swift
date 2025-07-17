protocol CardsMeasurementViewInput: AnyObject {
    func showSelectedSnapshot(_ snapshot: RuuviTagCardSnapshot?)
    func updateMeasurementData()
    func updateSnapshots(_ snapshots: [RuuviTagCardSnapshot], currentIndex: Int)
    func updateCurrentSnapshotData(_ snapshot: RuuviTagCardSnapshot)
    func navigateToIndex(_ index: Int, animated: Bool)
    func presentIndicatorDetailsSheet(
        for indicator: RuuviTagCardSnapshotIndicatorData
    )
}
