import RuuviOntology

struct VisibilitySettingsPreviewViewModel {
    let snapshot: RuuviTagCardSnapshot
    let dashboardType: DashboardType
}

struct VisibilitySettingsItemViewModel: Identifiable, Equatable {
    let variant: MeasurementDisplayVariant
    let title: String

    var id: MeasurementDisplayVariant { variant }
}

struct VisibilitySettingsViewModel {
    let descriptionText: String
    let useDefault: Bool
    let visibleItems: [VisibilitySettingsItemViewModel]
    let hiddenItems: [VisibilitySettingsItemViewModel]
    let preview: VisibilitySettingsPreviewViewModel?

    static let empty = VisibilitySettingsViewModel(
        descriptionText: "",
        useDefault: true,
        visibleItems: [],
        hiddenItems: [],
        preview: nil
    )
}
