import Foundation
import SwiftUI
import Combine
import RuuviOntology
import RuuviPool
import RuuviStorage
import RuuviLocal
import RuuviDaemon
import RuuviPresenters
import BTKit
import RuuviPersistence

final class DFUPresenter: DFUModuleInput {
    var viewController: UIViewController {
        if let view = self.weakView {
            return view
        } else {
            let view = UIHostingController(rootView: DFUUIView(viewModel: viewModel))
            self.weakView = view
            return view
        }

    }
    private weak var weakView: UIViewController?
    private let viewModel: DFUViewModel
    private let interactor: DFUInteractorInput
    private let foreground: BTForeground!
    private let idPersistence: RuuviLocalIDs
    private let realmPersistence: RuuviPersistence
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
        realmPersistence: RuuviPersistence,
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
        self.realmPersistence = realmPersistence
        self.sqiltePersistence = sqiltePersistence
        self.ruuviTag = ruuviTag
        self.ruuviPool = ruuviPool
        self.ruuviStorage = ruuviStorage
        self.settings = settings
        self.propertiesDaemon = propertiesDaemon
        self.activityPresenter = activityPresenter
        self.viewModel = DFUViewModel(
            interactor: interactor,
            foreground: foreground,
            idPersistence: idPersistence,
            realmPersistence: realmPersistence,
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
            return false
        default:
            return true
        }
    }
}
