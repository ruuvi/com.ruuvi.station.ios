import Foundation
@testable import station

final class SettingsTableOutputSpy: DevicesViewOutput, RuuviCloudViewOutput, ASSelectionViewOutput,
    PushAlertSoundSelectionViewOutput
{
    var loads = 0
    var appearances = 0
    var devices = [DevicesViewModel]()
    var selections = [SelectionItemProtocol]()
    func viewDidLoad() { loads += 1 }
    func viewWillAppear() { appearances += 1 }
    func viewDidTapDevice(viewModel: DevicesViewModel) { devices.append(viewModel) }
    func viewDidSelectItem(item: SelectionItemProtocol) { selections.append(item) }
    func viewDidSelectItem(item: SelectionItemProtocol, type: AppearanceSettingType) { selections.append(item) }
}
