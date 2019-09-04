import UIKit
import BTKit
import EmptyDataSet_Swift

enum DiscoverTableSection: Int {
    case webTag = 0
    case device = 1
    
    static var count = 2
}

class DiscoverTableViewController: UITableViewController {
    
    var output: DiscoverViewOutput!

    @IBOutlet var closeBarButtonItem: UIBarButtonItem!
    @IBOutlet var btDisabledEmptyDataSetView: UIView!
    @IBOutlet weak var btDisabledImageView: UIImageView!
    @IBOutlet var getMoreSensorsEmptyDataSetView: UIView!
    @IBOutlet weak var getMoreSensorsFooterButton: UIButton!
    @IBOutlet weak var getMoreSensorsEmptyDataSetButton: UIButton!
    
    var webTags: [DiscoverWebTagViewModel] = [DiscoverWebTagViewModel]()
    var savedWebTagProviders: [WeatherProvider] = [WeatherProvider]() {
        didSet {
            shownWebTags = webTags
                .filter({
                    if hideAlreadyAddedWebProviders {
                        return !savedWebTagProviders.contains($0.provider)
                    } else {
                        return true
                    }
                })
                .sorted(by: { $0.locationType.title < $1.locationType.title })
        }
    }
    
    var devices: [DiscoverDeviceViewModel] = [DiscoverDeviceViewModel]() {
        didSet {
            shownDevices = devices
                .filter( { !savedDevicesUUIDs.contains($0.uuid) } )
                .sorted(by: { $0.rssi > $1.rssi })
        }
    }
    var savedDevicesUUIDs: [String] = [String]() {
        didSet {
            shownDevices = devices
            .filter( { !savedDevicesUUIDs.contains($0.uuid) } )
            .sorted(by: { $0.rssi > $1.rssi })
        }
    }
    
    var isBluetoothEnabled: Bool = true { didSet { updateUIISBluetoothEnabled() } }
    
    var isCloseEnabled: Bool = true { didSet { updateUIIsCloseEnabled() } }
    
    private let hideAlreadyAddedWebProviders = false
    private var emptyDataSetView: UIView?
    private let deviceCellReuseIdentifier = "DiscoverDeviceTableViewCellReuseIdentifier"
    private let webTagCellReuseIdentifier = "DiscoverWebTagTableViewCellReuseIdentifier"
    private var shownDevices: [DiscoverDeviceViewModel] =  [DiscoverDeviceViewModel]() { didSet { updateUIShownDevices() } }
    private var shownWebTags: [DiscoverWebTagViewModel] = [DiscoverWebTagViewModel]() { didSet { updateUIShownWebTags() } }
}

// MARK: - DiscoverViewInput
extension DiscoverTableViewController: DiscoverViewInput {
    func localize() {
        navigationItem.title = "DiscoverTable.NavigationItem.title".localized()
        getMoreSensorsFooterButton.setTitle("DiscoverTable.GetMoreSensors.button.title".localized(), for: .normal)
        getMoreSensorsEmptyDataSetButton.setTitle("DiscoverTable.GetMoreSensors.button.title".localized(), for: .normal)
        
        closeBarButtonItem.title = "DiscoverTable.Close.barButtonItem.title".localized()
    }
    
    func apply(theme: Theme) {
        
    }
    
    func showBluetoothDisabled() {
        let alertVC = UIAlertController(title: "DiscoverTable.BluetoothDisabledAlert.title".localized(), message: "DiscoverTable.BluetoothDisabledAlert.message".localized(), preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "OK".localized(), style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }
}

// MARK: - IBActions
extension DiscoverTableViewController {
    @IBAction func closeBarButtonItemAction(_ sender: Any) {
        output.viewDidTriggerClose()
    }
    
    @IBAction func getMoreSensorsTableFooterViewButtonTouchUpInside(_ sender: Any) {
        output.viewDidTapOnGetMoreSensors()
    }
}

// MARK: - View lifecycle
extension DiscoverTableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
        configureViews()
        updateUI()
        output.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationItem.setHidesBackButton(true, animated: animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        output.viewWillAppear()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        output.viewWillDisappear()
    }
}

// MARK: - UITableViewDataSource
extension DiscoverTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return DiscoverTableSection.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case DiscoverTableSection.webTag.rawValue:
            return shownWebTags.count
        case DiscoverTableSection.device.rawValue:
            return shownDevices.count
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case DiscoverTableSection.webTag.rawValue:
            let cell = tableView.dequeueReusableCell(withIdentifier: webTagCellReuseIdentifier, for: indexPath) as! DiscoverWebTagTableViewCell
            let tag = shownWebTags[indexPath.row]
            configure(cell: cell, with: tag)
            return cell
        case DiscoverTableSection.device.rawValue:
            let cell = tableView.dequeueReusableCell(withIdentifier: deviceCellReuseIdentifier, for: indexPath) as! DiscoverDeviceTableViewCell
            let tag = shownDevices[indexPath.row]
            configure(cell: cell, with: tag)
            return cell
        default:
            fatalError()
        }
    }
}

// MARK: - UITableViewDelegate {
extension DiscoverTableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case DiscoverTableSection.webTag.rawValue:
            if indexPath.row < shownWebTags.count {
                output.viewDidChoose(webTag: shownWebTags[indexPath.row])
            }
        case DiscoverTableSection.device.rawValue:
            if indexPath.row < shownDevices.count {
                output.viewDidChoose(device: shownDevices[indexPath.row])
            }
        default:
            break
        }
        
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case DiscoverTableSection.webTag.rawValue:
            return shownWebTags.count > 0 ? "DiscoverTable.SectionTitle.WebTags".localized() : nil
        case DiscoverTableSection.device.rawValue:
            return shownDevices.count > 0 ? "DiscoverTable.SectionTitle.Devices".localized() : nil
        default:
            return nil
        }
        
    }
}

// MARK: - EmptyDataSetSource
extension DiscoverTableViewController: EmptyDataSetSource {
    func customView(forEmptyDataSet scrollView: UIScrollView) -> UIView? {
        return emptyDataSetView
    }
}

// MARK: - EmptyDataSetDelegate
extension DiscoverTableViewController: EmptyDataSetDelegate {
    func emptyDataSetShouldAllowScroll(_ scrollView: UIScrollView) -> Bool {
        return true
    }
    
    func emptyDataSet(_ scrollView: UIScrollView, didTapView view: UIView) {
        if emptyDataSetView == getMoreSensorsEmptyDataSetView {
            output.viewDidTapOnGetMoreSensors()
        }
    }
    
    func emptyDataSetWillAppear(_ scrollView: UIScrollView) {
        tableView.tableFooterView?.isHidden = true
    }
    
    func emptyDataSetDidDisappear(_ scrollView: UIScrollView) {
        tableView.tableFooterView?.isHidden = false
    }
    
    func verticalOffset(forEmptyDataSet scrollView: UIScrollView) -> CGFloat {
        return -64
    }
}

// MARK: - Cell configuration
extension DiscoverTableViewController {
    private func configure(cell: DiscoverWebTagTableViewCell, with tag: DiscoverWebTagViewModel) {
        cell.nameLabel.text = tag.locationType.title
    }
    
    private func configure(cell: DiscoverDeviceTableViewCell, with device: DiscoverDeviceViewModel) {
        
        // identifier
        if let mac = device.mac {
            cell.identifierLabel.text = mac
        } else {
            cell.identifierLabel.text = device.uuid
        }
        
        // RSSI
        if (device.rssi < -80) {
            cell.rssiImageView.image = UIImage(named: "icon-connection-1")
        } else if (device.rssi < -50) {
            cell.rssiImageView.image = UIImage(named: "icon-connection-2")
        } else {
            cell.rssiImageView.image = UIImage(named: "icon-connection-3")
        }
        
    }
}

// MARK: - View configuration
extension DiscoverTableViewController {
    private func configureViews() {
        configureTableView()
        configureBTDisabledImageView()
    }
    
    private func configureTableView() {
        tableView.emptyDataSetSource = self
        tableView.emptyDataSetDelegate = self
    }
    
    private func configureBTDisabledImageView() {
        btDisabledImageView.tintColor = .red
    }
}

// MARK: - Update UI
extension DiscoverTableViewController {
    private func updateUI() {
        updateUIShownDevices()
        updateUIShownWebTags()
        updateUIISBluetoothEnabled()
        updateUIIsCloseEnabled()
    }
    
    private func updateUIIsCloseEnabled() {
        if isViewLoaded {
            if isCloseEnabled {
                navigationItem.leftBarButtonItem = closeBarButtonItem
            } else {
                navigationItem.leftBarButtonItem = nil
            }
        }
    }
    
    private func updateUIISBluetoothEnabled() {
        if isViewLoaded {
            emptyDataSetView = isBluetoothEnabled ? getMoreSensorsEmptyDataSetView : btDisabledEmptyDataSetView
            tableView.reloadEmptyDataSet()
        }
    }
    
    private func updateUIShownDevices() {
        if isViewLoaded {
            tableView.reloadData()
        }
    }
    
    private func updateUIShownWebTags() {
        if isViewLoaded {
            tableView.reloadData()
        }
    }
}
