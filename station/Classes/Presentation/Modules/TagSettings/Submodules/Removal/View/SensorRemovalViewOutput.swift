import Foundation
import CoreNFC

protocol SensorRemovalViewOutput {
    func viewDidLoad()
    func viewDidTriggerRemoveTag()
    func viewDidConfirmTagRemoval(with removeCloudData: Bool)
    func viewDidDismiss()
}
