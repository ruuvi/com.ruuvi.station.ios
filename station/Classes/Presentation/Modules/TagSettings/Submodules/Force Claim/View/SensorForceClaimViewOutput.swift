import Foundation
import CoreNFC

protocol SensorForceClaimViewOutput {
    func viewDidLoad()
    func viewDidTapUseNFC()
    func viewDidTapUseBluetooth()
    func viewDidReceiveNFCMessages(messages: [NFCNDEFMessage])
    func viewDidDismiss()
}
