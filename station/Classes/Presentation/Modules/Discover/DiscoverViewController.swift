import UIKit
import BTKit

class DiscoverViewController: UITableViewController {
    
    private let scanner = Ruuvi.scanner
    private var ruuviTags = Set<RuuviTag>()
    private var orderedRuuviTags = [RuuviTag]()
    private let cellReuseIdentifier = "DiscoverCellReuseIdentifier"
    private var reloadTimer: Timer?
    private var observationToken: ObservationToken!
    
    deinit {
        observationToken?.invalidate()
    }
}

// MARK: - View lifecycle
extension DiscoverViewController {
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationItem.setHidesBackButton(true, animated: animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        startScanning()
        startReloading()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
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
        configure(cell: cell, with: .ruuvi(.tag(tag)))
        return cell
    }
    
    private func configure(cell: DiscoverCell, with device: BTDevice) {
        
        // identifier
        switch device {
        case .ruuvi(let ruuviDevice):
            switch ruuviDevice {
            case .tag(let ruuviTag):
                if let mac = ruuviTag.mac {
                    cell.identifierLabel.text = mac
                } else {
                    cell.identifierLabel.text = ruuviTag.uuid
                }
            }
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

// MARK: - Private
extension DiscoverViewController {
    private func startScanning() {
        observationToken = scanner.scan(self, options: [.callbackQueue(.mainAsync)]) { (observer, device) in
            if let ruuviTag = device.ruuvi?.tag {
                observer.ruuviTags.update(with: ruuviTag)
            }
        }
    }
    
    private func stopScanning() {
        observationToken?.invalidate()
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
