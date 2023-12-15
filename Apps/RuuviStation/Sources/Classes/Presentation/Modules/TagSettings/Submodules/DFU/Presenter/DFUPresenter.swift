import BTKit
import Combine
import Foundation
import RuuviDaemon
import RuuviLocal
import RuuviOntology
import RuuviPersistence
import RuuviPool
import RuuviPresenters
import RuuviStorage
import SwiftUI

final class DFUPresenter: DFUModuleInput {
    var viewController: UIViewController {
        if let view = weakView {
            return view
        } else {
            let view = UIHostingController(rootView: DFUUIView(viewModel: viewModel))
            weakView = view
            return view
        }
    }

    private weak var weakView: UIViewController?
    private let viewModel: DFUViewModel
    private let interactor: DFUInteractorInput
    private let foreground: BTForeground!
    private let idPersistence: RuuviLocalIDs
    private let sqiltePersistence: RuuviPersistence
    private let ruuviTag: RuuviTagSensor
    private let ruuviPool: RuuviPool
    private let ruuviStorage: RuuviStorage
    private let settings: RuuviLocalSettings
    private let propertiesDaemon: RuuviTagPropertiesDaemon
    private let activityPresenter: ActivityPresenter

    init(
        interactor: DFUInteractorInput,
        ruuviTag: RuuviTagSensor,
        foreground: BTForeground,
        idPersistence: RuuviLocalIDs,
        sqiltePersistence: RuuviPersistence,
        ruuviPool: RuuviPool,
        ruuviStorage: RuuviStorage,
        settings: RuuviLocalSettings,
        propertiesDaemon: RuuviTagPropertiesDaemon,
        activityPresenter: ActivityPresenter
    ) {
        self.interactor = interactor
        self.foreground = foreground
        self.idPersistence = idPersistence
        self.sqiltePersistence = sqiltePersistence
        self.ruuviTag = ruuviTag
        self.ruuviPool = ruuviPool
        self.ruuviStorage = ruuviStorage
        self.settings = settings
        self.propertiesDaemon = propertiesDaemon
        self.activityPresenter = activityPresenter
        viewModel = DFUViewModel(
            interactor: interactor,
            foreground: foreground,
            idPersistence: idPersistence,
            sqiltePersistence: sqiltePersistence,
            ruuviTag: ruuviTag,
            ruuviPool: ruuviPool,
            ruuviStorage: ruuviStorage,
            settings: settings,
            propertiesDaemon: propertiesDaemon,
            activityPresenter: activityPresenter
        )
    }

    func isSafeToDismiss() -> Bool {
        switch viewModel.state {
        case .flashing:
            false
        default:
            true
        }
    }
}
