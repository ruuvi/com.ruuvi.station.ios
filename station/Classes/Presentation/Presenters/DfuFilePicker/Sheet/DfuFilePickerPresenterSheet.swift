import Foundation
import UIKit

class DfuFilePickerPresenterSheet: NSObject, DfuFilePickerPresenter {
    weak var delegate: DfuFilePickerPresenterDelegate?
    var permissionsManager: PermissionsManager!
    var permissionPresenter: PermissionPresenter!
    var sourceView: UIView?

    func pick(sourceView: UIView?) {
        self.sourceView = sourceView
        showDocumentSheet()
    }
}

extension DfuFilePickerPresenterSheet: UIDocumentPickerDelegate {
    private func showDocumentSheet() {
        guard let viewController = UIApplication.shared.topViewController() else { return }
        let vc = UIDocumentPickerViewController(documentTypes: ["com.pkware.zip-archive"],
                                                in: .open)
        if #available(iOS 11.0, *) {
            vc.allowsMultipleSelection = false
        }
        vc.delegate = self
        viewController.present(vc, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard controller.documentPickerMode == .open,
              let url = urls.first, url.startAccessingSecurityScopedResource()
        else { return }
        defer {
            DispatchQueue.main.async {
                url.stopAccessingSecurityScopedResource()
            }
        }
        controller.dismiss(animated: true)
        delegate?.dfuFilePicker(presenter: self, didPick: url)
    }
}
