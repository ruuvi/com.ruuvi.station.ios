import UIKit

protocol TagManagerButtonTableViewCellOutput: class {
    func tagManagerButtonCell(didTapButton action: TagManagerActionType)
}

class TagManagerButtonTableViewCell: UITableViewCell {

    @IBOutlet weak var button: UIButton!
    weak var output: TagManagerButtonTableViewCellOutput?
    var actionType: TagManagerActionType!

    @IBAction func didTapButton(_ sender: UIButton) {
        output?.tagManagerButtonCell(didTapButton: actionType)
    }
}
