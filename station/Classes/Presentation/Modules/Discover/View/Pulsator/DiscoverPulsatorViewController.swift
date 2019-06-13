import UIKit
import BTKit

class DiscoverPulsatorViewController: UIViewController {
    var output: DiscoverViewOutput!
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var btEnabledImageView: UIImageView!
    @IBOutlet weak var btDisabledImageView: UIImageView!
    
    var ruuviTags: [RuuviTag] = [RuuviTag]() { didSet { updateUIRuuviTags() } }
    var isBluetoothEnabled: Bool = false { didSet { updateUIISBluetoothEnabled() } }
    
    private let cellReuseIdentifier = "DiscoverPulsatorCollectionViewCellReuseIdentifier"
}

// MARK: - DiscoverViewInput
extension DiscoverPulsatorViewController: DiscoverViewInput {
    func apply(theme: Theme) {
        
    }
    
    func localize() {
        
    }
}

// MARK: - View lifecycle
extension DiscoverPulsatorViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
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
        return ruuviTags.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseIdentifier, for: indexPath) as! DiscoverPulsatorCollectionViewCell
        let ruuviTag = ruuviTags[indexPath.row]
        configure(cell: cell, with: ruuviTag)
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension DiscoverPulsatorViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.item < ruuviTags.count {
            output.viewDidSelect(ruuviTag: ruuviTags[indexPath.item])
        }
    }
}

// MARK: - Cell configuration
extension DiscoverPulsatorViewController {
    private func configure(cell: DiscoverPulsatorCollectionViewCell, with ruuviTag: RuuviTag) {
        
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
        updateUIRuuviTags()
        updateUIISBluetoothEnabled()
    }
    
    private func updateUIISBluetoothEnabled() {
        if isViewLoaded {
            btEnabledImageView.isHidden = !isBluetoothEnabled
            btDisabledImageView.isHidden = isBluetoothEnabled
        }
    }
    
    private func updateUIRuuviTags() {
        if isViewLoaded {
            collectionView.reloadData()
        }
    }
}
