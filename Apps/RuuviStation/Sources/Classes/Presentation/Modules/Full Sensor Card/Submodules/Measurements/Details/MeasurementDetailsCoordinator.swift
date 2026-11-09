import UIKit
import RuuviOntology
import RuuviLocal
import RuuviService
import RuuviCore
import RuuviDaemon
import RuuviUser
import RuuviPresenters
import BTKit
import RuuviReactor
import RuuviPool
import RuuviStorage
import RuuviNotifier

protocol MeasurementDetailsCoordinatorDelegate: AnyObject {
    func measurementDetailsCoordinatorDidDismiss(
        _ coordinator: MeasurementDetailsCoordinator
    )
    func measurementDetailsCoordinatorDidDismissWithGraphTap(
        for snapshot: RuuviTagCardSnapshot,
        measurement: MeasurementType,
        variant: MeasurementDisplayVariant?,
        ruuviTag: RuuviTagSensor,
        _ coordinator: MeasurementDetailsCoordinator
    )
}

class MeasurementDetailsCoordinator: RuuviCoordinator {
    private var viewController: MeasurementDetailsViewController!
    private var presenter: MeasurementDetailsPresenter!

    private var indicator: RuuviTagCardSnapshotIndicatorData!
    private var snapshot: RuuviTagCardSnapshot!
    private var ruuviTagSensor: RuuviTagSensor!
    private var sensorSetting: SensorSettings?
    private var topPadding: CGFloat = 80.0

    private weak var delegate: MeasurementDetailsCoordinatorDelegate?

    init(
        baseViewController: CardsBaseViewController,
        for indicator: RuuviTagCardSnapshotIndicatorData,
        snapshot: RuuviTagCardSnapshot,
        ruuviTagSensor: RuuviTagSensor,
        sensorSetting: SensorSettings?,
        delegate: MeasurementDetailsCoordinatorDelegate?
    ) {
        super.init(baseViewController: baseViewController)
        self.indicator = indicator
        self.snapshot = snapshot
        self.ruuviTagSensor = ruuviTagSensor
        self.sensorSetting = sensorSetting
        self.topPadding = baseViewController.spaceUntilSecondaryToolbar
        self.delegate = delegate
    }

    override func start() {
        super.start()
        // The card screen's height (the window's, so the screen's when full screen) minus the space
        // down to the sensor name row, so the header and the sensor name stay visible above it.
        let maximumSheetHeight = baseViewController.view.bounds.height - topPadding
        let maximumSheetHeightProvider = makeMaximumSheetHeightProvider(initialValue: maximumSheetHeight)
        var config = SheetConfiguration(
            maxHeight: maximumSheetHeight,
            prefersGrabberVisible: true,
            preferredCornerRadius: 16,
            prefersScrollingExpandsWhenScrolledToEdge: false,
            prefersEdgeAttachedInCompactHeight: true
        )
        config.maxHeightProvider = maximumSheetHeightProvider
        viewController = createViewController(
            maximumSheetHeight: maximumSheetHeight
        )
        viewController.maximumSheetHeightProvider = maximumSheetHeightProvider
        baseViewController.presentDynamicBottomSheet(
            vc: viewController,
            configuration: config,
            delegate: self
        )
    }

    /// The sheet height cap, read again on every detent resolution and content size update, so it
    /// follows rotation, window resizing and iPhone Duo display changes while the sheet is shown:
    /// the card screen's current height minus its current space down to the sensor name row.
    /// Unchanged while the card screen keeps its size, so the same value as when the sheet opened.
    private func makeMaximumSheetHeightProvider(initialValue: CGFloat) -> () -> CGFloat? {
        let baseView = baseViewController.view
        let initialTopPadding = topPadding
        let cardsViewController = baseViewController as? CardsBaseViewController
        return { [weak baseView, weak cardsViewController] in
            guard let baseView, baseView.bounds.height > 0 else {
                return initialValue
            }
            let topPadding = cardsViewController?.currentSpaceUntilSecondaryToolbar ?? initialTopPadding
            return baseView.bounds.height - topPadding
        }
    }

    override func stop() {
        super.stop()
        delegate = nil
        presenter.stop()
    }
}

// MARK: - MeasurementDetailsPresenterOutput
extension MeasurementDetailsCoordinator: MeasurementDetailsPresenterOutput {
    func detailsViewDidDismiss(
        for snapshot: RuuviTagCardSnapshot,
        measurement: MeasurementType,
        variant: MeasurementDisplayVariant?,
        ruuviTag: RuuviTagSensor,
        module: MeasurementDetailsPresenterInput
    ) {
        baseViewController.dismiss(animated: true, completion: { [weak self] in
            guard let self else { return }
            self.delegate?.measurementDetailsCoordinatorDidDismissWithGraphTap(
                for: snapshot,
                measurement: measurement,
                variant: variant,
                ruuviTag: ruuviTag,
                self
            )
            module.stop()
        })
    }
}

extension MeasurementDetailsCoordinator: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        delegate?.measurementDetailsCoordinatorDidDismiss(self)
    }
}

private extension MeasurementDetailsCoordinator {
    func createViewController(
        maximumSheetHeight: CGFloat
    ) -> MeasurementDetailsViewController {
        let r = AppAssembly.shared.assembler.resolver

        let viewController = MeasurementDetailsViewController.createSheet(
            from: indicator,
            for: snapshot,
            maximumSheetHeight: maximumSheetHeight
        )

        let presenter = MeasurementDetailsPresenter(
            settings: r.resolve(RuuviLocalSettings.self)!,
            flags: r.resolve(RuuviLocalFlags.self)!,
            measurementService: r.resolve(RuuviServiceMeasurement.self)!,
            alertService: r.resolve(RuuviServiceAlert.self)!,
            ruuviStorage: r.resolve(RuuviStorage.self)!,
            cloudSyncService: r.resolve(RuuviServiceCloudSync.self)!,
            ruuviReactor: r.resolve(RuuviReactor.self)!,
            localSyncState: r.resolve(RuuviLocalSyncState.self)!
        )

        presenter.view = viewController
        viewController.output = presenter

        presenter.configure(
            with: snapshot,
            measurementType: indicator.type,
            variant: indicator.variant,
            ruuviTag: ruuviTagSensor,
            sensorSettings: sensorSetting,
            output: self
        )

        self.presenter = presenter
        self.viewController = viewController

        return viewController
    }
}
