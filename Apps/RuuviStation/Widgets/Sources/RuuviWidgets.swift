import AppIntents
import RuuviWidgets
import SwiftUI
import WidgetKit

@main
struct RuuviWidgetsBundle: WidgetBundle {
    @WidgetBundleBuilder var body: some Widget {
        RuuviSingleSensorWidget()
        RuuviMultiSensorWidget()
    }
}

@available(iOS 17.0, *)
struct WidgetIntentPackages: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] { [RuuviWidgetIntentsPackage.self] }
}
