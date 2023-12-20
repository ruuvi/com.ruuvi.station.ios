import CoreNFC
import Foundation

protocol SensorForceClaimViewOutput {
    func viewDidLoad()
    func viewDidTapUseNFC()
    func viewDidTapUseBluetooth()
    func viewDidReceiveNFCMessages(messages: [NFCNDEFMessage])
    func viewDidDismiss()
}
