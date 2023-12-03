import Foundation
import CoreNFC
import RuuviOntology

protocol DiscoverViewOutput {
    func viewDidLoad()
    func viewWillAppear()
    func viewWillDisappear()
    func viewDidChoose(device: DiscoverRuuviTagViewModel, displayName: String)
    func viewDidTriggerClose()
    func viewDidTriggerDisabledBTRow()
    func viewDidTriggerBuySensors()
    func viewDidTapUseNFC()
    func viewDidReceiveNFCMessages(messages: [NFCNDEFMessage])
    func viewDidAddDeviceWithNFC(with sensor: NFCSensor?)
    func viewDidGoToSensor(with sensor: NFCSensor?)
    func viewDidACopyMacAddress(of sensor: NFCSensor?)
    func viewDidACopySecret(of sensor: NFCSensor?)
    func viewDidAskToUpgradeFirmware(of sensor: NFCSensor?)
}
