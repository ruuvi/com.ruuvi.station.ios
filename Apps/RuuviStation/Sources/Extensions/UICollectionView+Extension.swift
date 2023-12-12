import UIKit

extension UICollectionView {
    func reloadWithoutAnimation() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        DispatchQueue.main.async { [weak self] in
            self?.reloadData()
            CATransaction.commit()
        }
    }

    func scrollTo(index: Int, section: Int = 0, animated: Bool = false) {
        guard numberOfSections > 0,
              numberOfItems(inSection: section) > 0 else { return }
        let indexPath = IndexPath(
            item: index,
            section: section
        )
        scrollToItem(
            at: indexPath,
            at: .centeredHorizontally,
            animated: animated
        )
    }
}
