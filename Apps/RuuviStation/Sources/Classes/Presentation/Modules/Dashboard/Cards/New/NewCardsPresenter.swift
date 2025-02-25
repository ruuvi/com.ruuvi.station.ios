import BTKit
import CoreBluetooth
import Foundation
import RuuviCore
import RuuviDaemon
import RuuviLocal
import RuuviNotification
import RuuviNotifier
import RuuviOntology
import RuuviPresenters
import RuuviReactor
import RuuviService
import RuuviStorage
import UIKit

class NewCardsPresenter {

    weak var view: CardsViewInput?
    var router: CardsRouterInput!
    var interactor: CardsInteractorInput!
    var errorPresenter: ErrorPresenter!
    var settings: RuuviLocalSettings!
    var ruuviReactor: RuuviReactor!
    var alertService: RuuviServiceAlert!
    var alertHandler: RuuviNotifier!
    var foreground: BTForeground!
    var background: BTBackground!
    var connectionPersistence: RuuviLocalConnections!
    var featureToggleService: FeatureToggleService!
    var ruuviSensorPropertiesService: RuuviServiceSensorProperties!
    var localSyncState: RuuviLocalSyncState!
    var ruuviStorage: RuuviStorage!
    var permissionPresenter: PermissionPresenter!
    var permissionsManager: RuuviCorePermission!
    var measurementService: RuuviServiceMeasurement! {
        didSet {
            measurementService?.add(self)
        }
    }
}

extension NewCardsPresenter: NewCardsModuleInput {
    func configure(
        viewModels: [CardsViewModel],
        ruuviTagSensors: [AnyRuuviTagSensor],
        sensorSettings: [SensorSettings],
        scrollTo: CardsViewModel?,
        openWith: SensorCardSelectedTab,
        output: CardsModuleOutput
    ) {
        print("NewCardsViewProvider: configure", viewModels.count)
        view?.viewModels = viewModels
        if let scrollTo = scrollTo, let index = viewModels.firstIndex(of: scrollTo) {
            view?.scrollIndex = index
        }
    }

    func dismiss(completion: (() -> Void)?) {

    }
}

extension NewCardsPresenter: RuuviServiceMeasurementDelegate {
    func measurementServiceDidUpdateUnit() {
        
    }
}

extension NewCardsPresenter: CardsModuleOutput {
    func cardsViewDidRefresh(module: CardsModuleInput) {

    }

    func cardsViewDidDismiss(module: CardsModuleInput) {

    }
}
