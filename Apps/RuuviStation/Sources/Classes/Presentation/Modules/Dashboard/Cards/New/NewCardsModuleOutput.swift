protocol NewCardsModuleOutput: AnyObject {
    func cardsViewDidRefresh(module: NewCardsModuleInput)
    func cardsViewDidDismiss(module: NewCardsModuleInput)
}
