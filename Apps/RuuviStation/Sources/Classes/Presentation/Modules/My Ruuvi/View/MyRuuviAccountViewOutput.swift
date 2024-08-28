protocol MyRuuviAccountViewOutput {
    func viewDidLoad()
    func viewDidTapDeleteButton()
    func viewDidTapSignoutButton()
    func viewDidTriggerClose()
    func viewDidTriggerSupport(with email: String)
}
