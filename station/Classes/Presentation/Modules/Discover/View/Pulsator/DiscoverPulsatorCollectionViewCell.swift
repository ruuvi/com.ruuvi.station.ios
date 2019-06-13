import UIKit

class DiscoverPulsatorCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    
    private let pulsator: Pulsator = Pulsator()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        configurePulsator()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        pulsator.position = imageView.layer.position
    }
    
    private func configurePulsator() {
        pulsator.backgroundColor = UIColor.white.cgColor
        pulsator.numPulse = 3
        pulsator.radius = 100
        imageView.layer.superlayer?.insertSublayer(pulsator, below: imageView.layer)
        pulsator.start()
    }
    
}
