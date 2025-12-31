import CoreNFC
import Foundation

protocol SensorForceClaimViewOutput {
    func viewDidLoad()
    func viewWillAppear()
    func viewDidTapUseNFC()
    func viewDidTapUseBluetooth()
    func viewDidReceiveNFCMessages(messages: [NFCNDEFMessage])
    func viewDidDismiss()
}
