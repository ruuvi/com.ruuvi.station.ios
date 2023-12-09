import UIKit

class RuuviSimpleViewCompositionalLayout: UICollectionViewCompositionalLayout {
    private var heights = [Int: [IndexPath: CGFloat]]()
    private var largests = [Int: CGFloat]()
    private let columns: Int

    init(section: NSCollectionLayoutSection, columns: Int) {
        self.columns = columns
        super.init(section: section)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let attributes = super.layoutAttributesForElements(in: rect)

        if #unavailable(iOS 15) {
            if let attributes {
                for attribute in attributes {
                    updateLayoutAttributesHeight(layoutAttributes: attribute)
                }
            }
        }

        return attributes
    }

    override func invalidateLayout() {
        super.invalidateLayout()

        heights.removeAll(keepingCapacity: true)
        largests.removeAll(keepingCapacity: true)
    }

    func updateLayoutAttributesHeight(layoutAttributes: UICollectionViewLayoutAttributes) {
        let height = layoutAttributes.frame.height
        let indexPath = layoutAttributes.indexPath
        let row = indexPath.item / columns

        heights[row]?[indexPath] = height

        largests[row] = max(largests[row] ?? 0, height)

        let size = CGSize(
            width: layoutAttributes.frame.width,
            height: largests[row] ?? 0
        )
        layoutAttributes.frame = .init(origin: layoutAttributes.frame.origin, size: size)
    }
}
