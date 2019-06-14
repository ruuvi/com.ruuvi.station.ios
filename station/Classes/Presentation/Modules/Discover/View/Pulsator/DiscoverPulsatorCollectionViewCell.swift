import UIKit

class DiscoverPulsatorCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    
    private let pulsator: Pulsator = Pulsator()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        configurePulsator()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        pulsator.position = contentView.layer.position
    }
    
    private func configurePulsator() {
        pulsator.backgroundColor = UIColor.white.cgColor
        pulsator.numPulse = 3
        pulsator.radius = 100
        contentView.layer.superlayer?.insertSublayer(pulsator, below: contentView.layer)
        pulsator.start()
    }
    
}
