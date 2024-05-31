import UIKit

class TagChartsCollectionViewFlowLayout: UICollectionViewFlowLayout {

    override func prepare() {
        super.prepare()

        guard let collectionView = collectionView else {
            return
        }

        let isPortrait = collectionView.bounds.height > collectionView.bounds.width
        let numberOfItems = collectionView.numberOfItems(
            inSection: 0
        )

        if isPortrait {
            let collectionViewHeight = collectionView.bounds.height
            switch numberOfItems {
            case 1:
                itemSize = CGSize(
                    width: collectionView.bounds.width,
                    height: collectionViewHeight / 3
                )
            case 2:
                itemSize = CGSize(
                    width: collectionView.bounds.width,
                    height: collectionViewHeight / 2
                )
            case 3:
                itemSize = CGSize(
                    width: collectionView.bounds.width,
                    height: collectionViewHeight / 3
                )
            default:
                itemSize = CGSize(
                    width: collectionView.bounds.width,
                    height: collectionViewHeight / CGFloat(
                        numberOfItems
                    )
                )
            }
        } else {
            let collectionViewHeight = collectionView.bounds.height
            itemSize = CGSize(
                width: collectionView.bounds.width,
                height: collectionViewHeight
            )
            scrollDirection = .vertical
            collectionView.isPagingEnabled = true
        }

        minimumLineSpacing = 0
        minimumInteritemSpacing = 0
    }

    override func shouldInvalidateLayout(
        forBoundsChange newBounds: CGRect
    ) -> Bool {
        return true
    }

    override func targetContentOffset(
        forProposedContentOffset proposedContentOffset: CGPoint,
        withScrollingVelocity velocity: CGPoint
    ) -> CGPoint {
        guard let collectionView = collectionView else {
            return proposedContentOffset
        }

        let targetRect = CGRect(
            origin: proposedContentOffset,
            size: collectionView.bounds.size
        )
        let layoutAttributes = layoutAttributesForElements(
            in: targetRect
        )

        let verticalCenter = proposedContentOffset.y + collectionView.bounds.height / 2

        var closestAttribute: UICollectionViewLayoutAttributes?
        var closestDistance: CGFloat = .greatestFiniteMagnitude

        layoutAttributes?.forEach { attributes in
            let itemVerticalCenter = attributes.center.y
            let distance = abs(
                itemVerticalCenter - verticalCenter
            )

            if distance < closestDistance {
                closestDistance = distance
                closestAttribute = attributes
            }
        }

        guard let closest = closestAttribute else {
            return proposedContentOffset
        }

        return CGPoint(
            x: proposedContentOffset.x,
            y: floor(
                closest.center.y - collectionView.bounds.height / 2
            )
        )
    }
}
