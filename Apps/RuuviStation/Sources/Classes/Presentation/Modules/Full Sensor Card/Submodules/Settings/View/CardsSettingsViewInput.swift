import RuuviOntology

protocol CardsSettingsViewInput: AnyObject {
    func configure(
        snapshot: RuuviTagCardSnapshot,
        dashboardSortingType: DashboardSortingType?
    )
    func updateAlertSections(_ sections: [CardsSettingsAlertSectionModel])
    func showTagClaimDialog()
    func showMacAddressDetail()
    func showFirmwareUpdateDialog()
    func showFirmwareDismissConfirmationUpdateDialog()
    func resetKeepConnectionSwitch()
    func showKeepConnectionTimeoutDialog()
    func showKeepConnectionCloudModeDialog()
    func stopKeepConnectionAnimatingDots()
    func startKeepConnectionAnimatingDots()
    func freezeKeepConnectionDisplay()
    func unfreezeKeepConnectionDisplay()
    func updateVisibleMeasurementsSummary(
        value: String?,
        isVisible: Bool
    )
}
