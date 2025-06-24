import UIKit
import RuuviOntology

// MARK: - Height Cache
final class DashboardCardHeightCache {
    private var heightCache: [String: CGFloat] = [:]
    private var lastKnownWidth: CGFloat = 0

    func height(
        for snapshot: RuuviTagCardSnapshot,
        width: CGFloat,
        numberOfColumns: Int = 2,
        dashboardType: DashboardType
    ) -> CGFloat {
        // Clear cache if width changed significantly
        if abs(lastKnownWidth - width) > 1.0 {
            heightCache.removeAll()
            lastKnownWidth = width
        }

        let cacheKey = createCacheKey(for: snapshot, width: width)

        if let cachedHeight = heightCache[cacheKey] {
            return cachedHeight
        }

        let calculatedHeight: CGFloat
        switch dashboardType {
        case .image:
            calculatedHeight = RuuviTagDashboardImageCell.calculateHeight(
                for: snapshot,
                width: width,
                numberOfColumns: numberOfColumns
            )
        case .simple:
            calculatedHeight = RuuviTagDashboardCell.calculateHeight(
                for: snapshot,
                width: width,
                numberOfColumns: numberOfColumns
            )
        }

        heightCache[cacheKey] = calculatedHeight
        return calculatedHeight
    }

    private func createCacheKey(for snapshot: RuuviTagCardSnapshot, width: CGFloat) -> String {
        let indicatorCount = snapshot.displayData.indicatorGrid?.indicators.count ?? 0
        let layoutType = snapshot.displayData.indicatorGrid?.layoutType.rawValue ?? "empty"
        let hasNoData = snapshot.displayData.hasNoData
        let widthRounded = Int(width)

        return "\(snapshot.id)_\(indicatorCount)_\(layoutType)_\(hasNoData)_\(widthRounded)"
    }

    func clearCache() {
        heightCache.removeAll()
    }
}
