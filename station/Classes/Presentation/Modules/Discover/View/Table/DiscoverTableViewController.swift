import UIKit
import BTKit

class DiscoverTableViewController: UITableViewController {
    
    var output: DiscoverViewOutput!

    var ruuviTags: [RuuviTag] = [RuuviTag]() { didSet { updateUIRuuviTags() } }
        
    private let cellReuseIdentifier = "DiscoverCellReuseIdentifier"
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
        return ruuviTags.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath) as! DiscoverTableViewCell
        let tag = ruuviTags[indexPath.row]
        configure(cell: cell, with: tag)
        return cell
    }
}

// MARK: - Cell configuration
extension DiscoverTableViewController {
    private func configure(cell: DiscoverTableViewCell, with ruuviTag: RuuviTag) {
        
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

// MARK: - Update UI
extension DiscoverTableViewController {
    private func updateUI() {
        updateUIRuuviTags()
    }
    
    private func updateUIRuuviTags() {
        if isViewLoaded {
            tableView.reloadData()
        }
    }
}
