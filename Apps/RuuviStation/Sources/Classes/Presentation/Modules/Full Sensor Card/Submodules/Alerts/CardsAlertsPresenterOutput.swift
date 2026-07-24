protocol CardsAlertsPresenterOutput: AnyObject {
    func cardsAlerts(
        module: CardsAlertsPresenterInput,
        didRequest destination: CardsAlertsDeliveryPromptDestination
    )
}
