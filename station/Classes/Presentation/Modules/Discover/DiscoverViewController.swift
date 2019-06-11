import UIKit
import BTKit

class DiscoverViewController: UITableViewController {
    
    private let scanner = Ruuvi.scanner
    private var ruuviTags = Set<RuuviTag>()
    private var orderedRuuviTags = [RuuviTag]()
    private let cellReuseIdentifier = "DiscoverCellReuseIdentifier"
    private var reloadTimer: Timer?
    private var scanToken: ObservationToken?
    private var stateToken: ObservationToken?
    
    deinit {
        scanToken?.invalidate()
        stateToken?.invalidate()
    }
}

// MARK: - View lifecycle
extension DiscoverViewController {
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationItem.setHidesBackButton(true, animated: animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        startObservingBluetoothState()
        startScanning()
        startReloading()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        stopObservingBluetoothState()
        stopScanning()
        stopReloading()
    }
}

// MARK: - UITableViewDataSource
extension DiscoverViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return orderedRuuviTags.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath) as! DiscoverCell
        let tag = orderedRuuviTags[indexPath.row]
        configure(cell: cell, with: tag)
        return cell
    }
}

// MARK: - Cell configuration
extension DiscoverViewController {
    private func configure(cell: DiscoverCell, with ruuviTag: RuuviTag) {
        
        // identifier
        if let mac = ruuviTag.mac {
            cell.identifierLabel.text = mac
        } else {
            cell.identifierLabel.text = ruuviTag.uuid
        }
        
        // RSSI
        if (ruuviTag.rssi < -80) {
            cell.rssiImageView.image = UIImage(named: "icon-connection-1")
        } else if (ruuviTag.rssi < -50) {
            cell.rssiImageView.image = UIImage(named: "icon-connection-2")
        } else {
            cell.rssiImageView.image = UIImage(named: "icon-connection-3")
        }
        
    }
}

// MARK: - Show
extension DiscoverViewController {
    private func showBluetoothDisabled() {
        print("Bluetooth disabled")
    }
}

// MARK: - Private
extension DiscoverViewController {
    
    private func startObservingBluetoothState() {
        stateToken = scanner.state(self, closure: { (observer, state) in
            if state == .poweredOff {
                observer.showBluetoothDisabled()
            }
        })
    }
    
    private func stopObservingBluetoothState() {
        stateToken?.invalidate()
    }
    
    private func startScanning() {
        scanToken = scanner.scan(self) { (observer, device) in
            if let ruuviTag = device.ruuvi?.tag {
                observer.ruuviTags.update(with: ruuviTag)
            }
        }
    }
    
    private func stopScanning() {
        scanToken?.invalidate()
    }
    
    private func startReloading() {
        reloadTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] (timer) in
            self?.reload()
        })
    }
    
    private func stopReloading() {
        reloadTimer?.invalidate()
    }
    
    private func reload() {
        orderedRuuviTags = ruuviTags.sorted(by: {$0.rssi > $1.rssi })
        tableView.reloadData()
    }
}
