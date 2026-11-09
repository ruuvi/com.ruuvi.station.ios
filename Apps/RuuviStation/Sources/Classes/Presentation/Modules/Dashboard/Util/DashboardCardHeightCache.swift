import UIKit
import RuuviOntology

class DashboardCardHeightCache {
    /// Heights per card width, for the few widths seen most recently (oldest first in
    /// `recentWidths`). A live window resize gives a new width on every frame, so only a few
    /// widths are kept; rotating an iPhone back and forth still finds both of its widths.
    private var heightsByWidth: [CGFloat: [String: CGFloat]] = [:]
    private var recentWidths: [CGFloat] = []
    private let maximumWidthCount = 4

    func height(
        for snapshot: RuuviTagCardSnapshot,
        width: CGFloat,
        displayType: DashboardType,
        numberOfColumns: Int
    ) -> CGFloat {
        let key = cacheKey(
            for: snapshot,
            width: width,
            displayType: displayType,
            numberOfColumns: numberOfColumns
        )

        if let cachedHeight = heightsByWidth[width]?[key] {
            return cachedHeight
        }

        let height = DashboardCell.calculateHeight(
            for: snapshot,
            width: width,
            dashboardType: displayType,
            numberOfColumns: numberOfColumns,
        )

        store(height, forKey: key, width: width)
        return height
    }

    func clearCache() {
        heightsByWidth.removeAll()
        recentWidths.removeAll()
    }

    private func store(_ height: CGFloat, forKey key: String, width: CGFloat) {
        if heightsByWidth[width] == nil {
            recentWidths.append(width)
            if recentWidths.count > maximumWidthCount {
                heightsByWidth[recentWidths.removeFirst()] = nil
            }
        }
        heightsByWidth[width, default: [:]][key] = height
    }

    private func cacheKey(
        for snapshot: RuuviTagCardSnapshot,
        width: CGFloat,
        displayType: DashboardType,
        numberOfColumns: Int
    ) -> String {
        let indicatorCount: Int
        let indicatorSignature: String
        if displayType == .image {
            indicatorCount = snapshot.displayData.secondaryIndicators.count
            indicatorSignature = snapshot.displayData.secondaryIndicators
                .map { variantSignature(for: $0.variant, type: $0.type) }
                .joined(separator: "|")
        } else {
            indicatorCount = snapshot.displayData.indicatorGrid?.indicators.count ?? 0
            indicatorSignature = snapshot.displayData.indicatorGrid?.indicators
                .map { variantSignature(for: $0.variant, type: $0.type) }
                .joined(separator: "|") ?? "none"
        }
        let prominentType = snapshot.displayData.primaryIndicator?.type

        let visibilitySignature = snapshot.displayData.measurementVisibility?
            .visibleVariants
            .map { variantSignature(for: $0, type: $0.type) }
            .joined(separator: "|") ?? "default"

        let components = [
            snapshot.displayData.name,
            "\(width)",
            "\(indicatorCount)",
            indicatorSignature,
            visibilitySignature,
            prominentType?.shortName ?? "none",
            displayType.rawValue,
            "\(numberOfColumns)",
        ]
        return components.joined(separator: "_")
    }

    private func variantSignature(
        for variant: MeasurementDisplayVariant?,
        type: MeasurementType
    ) -> String {
        guard let variant else {
            return String(describing: type)
        }

        var components = [String(describing: variant.type)]
        if let temperatureUnit = variant.temperatureUnit {
            components.append("temp:\(temperatureUnit)")
        }
        if let humidityUnit = variant.humidityUnit {
            components.append("hum:\(humidityUnit)")
        }
        if let pressureUnit = variant.pressureUnit {
            components.append("pres:\(pressureUnit)")
        }
        return components.joined(separator: "-")
    }
}
