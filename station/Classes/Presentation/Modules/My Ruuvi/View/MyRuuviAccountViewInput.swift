protocol MyRuuviAccountViewInput: ViewInput {
    var viewModel: MyRuuviAccountViewModel? { get  set }
    func viewDidShowAccountDeletionConfirmation()
}
