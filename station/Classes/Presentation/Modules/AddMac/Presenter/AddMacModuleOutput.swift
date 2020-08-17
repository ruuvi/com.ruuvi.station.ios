protocol AddMacModuleOutput: class {
    func addMac(module: AddMacModuleInput,
                didEnter mac: String,
                for provider: RuuviNetworkProvider)
}
