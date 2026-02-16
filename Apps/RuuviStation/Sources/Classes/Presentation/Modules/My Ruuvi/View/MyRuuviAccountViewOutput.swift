protocol MyRuuviAccountViewOutput {
    func viewDidLoad()
    func viewDidTapDeleteButton()
    func viewDidTapSignoutButton()
    func viewDidTriggerClose()
    func viewDidTriggerSupport(with email: String)
    func viewDidChangeMarketingPreference(isEnabled: Bool)
}
