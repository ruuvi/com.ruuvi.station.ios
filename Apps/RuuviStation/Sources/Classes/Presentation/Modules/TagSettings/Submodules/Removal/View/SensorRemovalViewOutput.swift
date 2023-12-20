import CoreNFC
import Foundation

protocol SensorRemovalViewOutput {
    func viewDidLoad()
    func viewDidTriggerRemoveTag()
    func viewDidConfirmTagRemoval(with removeCloudData: Bool)
    func viewDidDismiss()
}
