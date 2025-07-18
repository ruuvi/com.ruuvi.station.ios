import Foundation
import RuuviOntology
import UIKit

// MARK: - Main Landing View Protocol
protocol CardsLandingViewInput: AnyObject {
    func updateSnapshots(_ snapshots: [RuuviTagCardSnapshot])
    func updateCurrentSnapshotIndex(_ index: Int)
    func updateCurrentTab(_ tab: CardsMenuType)
    func showBluetoothDisabled(userDeclined: Bool)
    func showError(_ error: Error)
    func showLoading()
    func hideLoading()
}

protocol CardsLandingViewOutput: AnyObject {
    func viewDidLoad()
    func viewWillAppear()
    func viewWillDisappear()
    func viewDidChangeTab(_ tab: CardsMenuType)
    func viewDidNavigateToSnapshot(at index: Int)
    func viewDidTriggerRefresh()
}

// MARK: - Tab-Specific Protocols

// MARK: - Measurement Tab
protocol CardsMeasurementViewInput: AnyObject {
    func showSelectedSnapshot(_ snapshot: RuuviTagCardSnapshot?)
    func updateMeasurementData()
    func updateSnapshots(_ snapshots: [RuuviTagCardSnapshot], currentIndex: Int)
    func updateCurrentSnapshotData(_ snapshot: RuuviTagCardSnapshot)
    func navigateToIndex(_ index: Int, animated: Bool)
    func presentIndicatorDetailsSheet(
        for indicator: RuuviTagCardSnapshotIndicatorData
    )
}

protocol CardsMeasurementViewOutput: AnyObject {
    func measurementViewDidLoad()
    func measurementViewDidBecomeActive()
    func measurementViewDidSelectMeasurement(_ type: MeasurementType)
    func measurementViewDidChangeSnapshotIndex(_ index: Int)
}

// MARK: - Graph Tab
protocol CardsGraphViewInput: AnyObject {
    func showSelectedSnapshot(_ snapshot: RuuviTagCardSnapshot?)
    func updateGraphData()
}

protocol CardsGraphViewOutput: AnyObject {
    func graphViewDidLoad()
    func graphViewDidBecomeActive()
    func graphViewDidSelectTimeRange(_ range: GraphTimeRange)
}

// MARK: - Alerts Tab
protocol CardsAlertsViewInput: AnyObject {
    func showSelectedSnapshot(_ snapshot: RuuviTagCardSnapshot?)
    func updateAlertsData()
}

protocol CardsAlertsViewOutput: AnyObject {
    func alertsViewDidLoad()
    func alertsViewDidBecomeActive()
    func alertsViewDidToggleAlert(_ type: MeasurementType, isOn: Bool)
}

// MARK: - Settings Tab
protocol CardsSettingsViewInput: AnyObject {
    func showSelectedSnapshot(_ snapshot: RuuviTagCardSnapshot?)
    func updateSettingsData()
}

protocol CardsSettingsViewOutput: AnyObject {
    func settingsViewDidLoad()
    func settingsViewDidBecomeActive()
    func settingsViewDidUpdateSensorName(_ name: String)
}

// MARK: - Supporting Types
enum GraphTimeRange: CaseIterable {
    case hour1, hours12, day1, week1, month1, year1

    var title: String {
        switch self {
        case .hour1: return "1H"
        case .hours12: return "12H"
        case .day1: return "1D"
        case .week1: return "1W"
        case .month1: return "1M"
        case .year1: return "1Y"
        }
    }
}
