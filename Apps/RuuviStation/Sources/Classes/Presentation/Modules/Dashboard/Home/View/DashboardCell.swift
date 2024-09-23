import RuuviLocal
import RuuviOntology
import RuuviService
import UIKit

class DashboardCell: UICollectionViewCell {
    func configure(
        with viewModel: CardsViewModel,
        measurementService: RuuviServiceMeasurement?
    ) {}
    func restartAlertAnimation(
        for viewModel: CardsViewModel
    ) {}
    func removeAlertAnimations(
        alpha: Double = 1
    ) {}
    func resetMenu(
        menu: UIMenu
    ) {}
}
