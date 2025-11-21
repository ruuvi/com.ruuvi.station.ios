import RuuviLocal
import RuuviOntology
import RuuviService

final class VisibilitySettingsModuleFactoryImpl: VisibilitySettingsModuleFactory {
    func create(
        snapshot: RuuviTagCardSnapshot,
        sensor: RuuviTagSensor,
        sensorSettings: SensorSettings?
    ) -> VisibilitySettingsViewController {
        let resolver = AppAssembly.shared.assembler.resolver

        let viewController = VisibilitySettingsViewController()
        let router = VisibilitySettingsRouter()
        router.transitionHandler = viewController

        let presenter = VisibilitySettingsPresenter(
            flags: resolver.resolve(RuuviLocalFlags.self)!,
            sensorPropertiesService: resolver.resolve(RuuviServiceSensorProperties.self)!,
            settings: resolver.resolve(RuuviLocalSettings.self)!
        )
        presenter.view = viewController
        presenter.router = router
        viewController.output = presenter

        presenter.configure(
            snapshot: snapshot,
            sensor: sensor,
            sensorSettings: sensorSettings
        )

        return viewController
    }
}
