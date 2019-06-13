import UIKit
import BTKit

class DiscoverPulsatorViewController: UIViewController {
    var output: DiscoverViewOutput!
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var bluetoothIconImageView: UIImageView!
    
    var ruuviTags: [RuuviTag] = [RuuviTag]() { didSet { updateUIRuuviTags() } }
    
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

// MARK: - Cell configuration
extension DiscoverPulsatorViewController {
    private func configure(cell: DiscoverPulsatorCollectionViewCell, with ruuviTag: RuuviTag) {
        
    }
}

// MARK: - Update UI
extension DiscoverPulsatorViewController {
    private func updateUI() {
        updateUIRuuviTags()
    }
    
    private func updateUIRuuviTags() {
        if isViewLoaded {
            collectionView.reloadData()
        }
    }
}
