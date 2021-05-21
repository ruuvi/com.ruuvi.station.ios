import UIKit

class TagManagerTableViewCell: UITableViewCell {
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView?.image = #imageLiteral(resourceName: "no-image")
    }
}
