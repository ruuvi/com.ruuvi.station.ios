import UIKit
import BTKit
import EmptyDataSet_Swift

class DiscoverTableViewController: UITableViewController {
    
    var output: DiscoverViewOutput!

    @IBOutlet var btDisabledEmptyDataSetView: UIView!
    @IBOutlet weak var btDisabledImageView: UIImageView!
    @IBOutlet var getMoreSensorsEmptyDataSetView: UIView!
    
    var devices: [DiscoverDeviceViewModel] = [DiscoverDeviceViewModel]() { didSet {
            shownDevices = devices.filter( { !savedDevicesUUIDs.contains($0.uuid) } )
        }
    }
    var savedDevicesUUIDs: [String] = [String]() { didSet {
        shownDevices = devices.filter( { !savedDevicesUUIDs.contains($0.uuid) } )
        }
    }
    
    var isBluetoothEnabled: Bool = false { didSet { updateUIISBluetoothEnabled() } }
    
    private var emptyDataSetView: UIView?
    private let cellReuseIdentifier = "DiscoverTableViewCellReuseIdentifier"
    private var shownDevices:  [DiscoverDeviceViewModel] =  [DiscoverDeviceViewModel]() { didSet { updateUIShownDevices() } }
}

// MARK: - DiscoverViewInput
extension DiscoverTableViewController: DiscoverViewInput {
    func localize() {
        
    }
    
    func apply(theme: Theme) {
        
    }
}

// MARK: - View lifecycle
extension DiscoverTableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
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
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return devices.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath) as! DiscoverTableViewCell
        let tag = devices[indexPath.row]
        configure(cell: cell, with: tag)
        return cell
    }
}

// MARK: - UITableViewDelegate {
extension DiscoverTableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row < devices.count {
            output.viewDidChoose(device: devices[indexPath.row])
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "DiscoverTable.SectionTitle.Tags".localized()
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
}

// MARK: - Cell configuration
extension DiscoverTableViewController {
    private func configure(cell: DiscoverTableViewCell, with device: DiscoverDeviceViewModel) {
        
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
        updateUIISBluetoothEnabled()
        
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
}
