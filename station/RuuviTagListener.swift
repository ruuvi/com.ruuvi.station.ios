protocol RuuviTagListener {
    func found(tag: RuuviTag)
    func bluetoothDisabled()
}
