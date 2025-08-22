import UIKit
import RuuviOntology

class DashboardCardHeightCache {
    private var cache: [String: CGFloat] = [:]

    func height(
        for snapshot: RuuviTagCardSnapshot,
        width: CGFloat,
        displayType: DashboardType,
        numberOfColumns: Int,
        showRedesignedUI: Bool
    ) -> CGFloat {
        let key = cacheKey(
            for: snapshot,
            width: width,
            displayType: displayType,
            numberOfColumns: numberOfColumns
        )

        if let cachedHeight = cache[key] {
            return cachedHeight
        }

        let height = DashboardCell.calculateHeight(
            for: snapshot,
            width: width,
            dashboardType: displayType,
            showRedesigndUI: showRedesignedUI,
            numberOfColumns: numberOfColumns,
        )

        cache[key] = height
        return height
    }

    func clearCache() {
        cache.removeAll()
    }

    private func cacheKey(
        for snapshot: RuuviTagCardSnapshot,
        width: CGFloat,
        displayType: DashboardType,
        numberOfColumns: Int
    ) -> String {
        let indicatorCount = snapshot.displayData.indicatorGrid?.indicators.count ?? 0
        let hasAQI = snapshot.displayData.indicatorGrid?.indicators.contains { $0.type == .aqi } ?? false

        let components = [
            snapshot.displayData.name,
            "\(width)",
            "\(indicatorCount)",
            "\(hasAQI)",
            displayType.rawValue,
            "\(numberOfColumns)",
        ]
        return components.joined(separator: "_")
    }
}
