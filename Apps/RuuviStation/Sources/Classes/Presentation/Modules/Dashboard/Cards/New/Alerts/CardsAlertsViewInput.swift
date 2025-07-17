protocol CardsAlertsViewInput: AnyObject {
    func showSelectedSnapshot(_ snapshot: RuuviTagCardSnapshot?)
    func updateAlertsData()
}
