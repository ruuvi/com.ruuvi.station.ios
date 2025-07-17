protocol CardsLandingViewOutput: AnyObject {
    func viewDidLoad()
    func viewWillAppear()
    func viewWillDisappear()
    func viewDidChangeTab(_ tab: CardsMenuType)
    func viewDidNavigateToSnapshot(at index: Int)
    func viewDidTriggerRefresh()
}
