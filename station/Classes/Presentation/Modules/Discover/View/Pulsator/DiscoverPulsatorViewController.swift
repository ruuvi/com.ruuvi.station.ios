import UIKit
import BTKit

class DiscoverPulsatorViewController: UIViewController {
    var output: DiscoverViewOutput!
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var btEnabledImageView: UIImageView!
    @IBOutlet weak var btDisabledImageView: UIImageView!
    
    var webTags: [DiscoverWebTagViewModel] = [DiscoverWebTagViewModel]()
    var savedWebTagProviders: [WeatherProvider] = [WeatherProvider]()
    var devices: [DiscoverDeviceViewModel] = [DiscoverDeviceViewModel]() { didSet { updateUIDevices() } }
    var savedDevicesUUIDs: [String] = [String]()
    var isBluetoothEnabled: Bool = false { didSet { updateUIISBluetoothEnabled() } }
    var isCloseEnabled: Bool = false
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    private let cellReuseIdentifier = "DiscoverPulsatorCollectionViewCellReuseIdentifier"
}

// MARK: - DiscoverViewInput
extension DiscoverPulsatorViewController: DiscoverViewInput {
    func apply(theme: Theme) {
        
    }
    
    func localize() {
        
    }
    
    func showBluetoothDisabled() {
        let alertVC = UIAlertController(title: "DiscoverPulsator.BluetoothDisabledAlert.title".localized(), message: "DiscoverPulsator.BluetoothDisabledAlert.message".localized(), preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "OK".localized(), style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }
}

// MARK: - IBActions
extension DiscoverPulsatorViewController {
    @IBAction func continueButtonTouchUpInside(_ sender: Any) {
        output.viewDidTriggerContinue()
    }
}

// MARK: - View lifecycle
extension DiscoverPulsatorViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
        output.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        output.viewWillAppear()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        output.viewWillDisappear()
    }
}

// MARK: - UICollectionViewDataSource
extension DiscoverPulsatorViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return devices.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseIdentifier, for: indexPath) as! DiscoverPulsatorCollectionViewCell
        let device = devices[indexPath.row]
        configure(cell: cell, with: device)
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension DiscoverPulsatorViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.item < devices.count {
            output.viewDidSelect(device: devices[indexPath.item])
        }
    }
}

// MARK: - Cell configuration
extension DiscoverPulsatorViewController {
    private func configure(cell: DiscoverPulsatorCollectionViewCell, with device: DiscoverDeviceViewModel) {
        cell.imageView.image = device.logo
        cell.nameLabel.text = device.name
    }
}

// MARK: - View configuration
extension DiscoverPulsatorViewController {
    private func configureViews() {
        btEnabledImageView.tintColor = .white
        btDisabledImageView.tintColor = .red
    }
}

// MARK: - Update UI
extension DiscoverPulsatorViewController {
    private func updateUI() {
        updateUIDevices()
        updateUIISBluetoothEnabled()
    }
    
    private func updateUIISBluetoothEnabled() {
        if isViewLoaded {
            btEnabledImageView.isHidden = !isBluetoothEnabled
            btDisabledImageView.isHidden = isBluetoothEnabled
        }
    }
    
    private func updateUIDevices() {
        if isViewLoaded {
            collectionView.reloadData()
        }
    }
}
