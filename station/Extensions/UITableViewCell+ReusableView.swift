import UIKit

protocol ReusableView: AnyObject {
    static var reuseIdentifier: String { get }
}

extension ReusableView where Self: UIView {
    static var reuseIdentifier: String {
        String(describing: self)
    }
}

extension UICollectionViewCell: ReusableView {}

extension UITableViewCell: ReusableView {}

extension UITableViewHeaderFooterView: ReusableView {}

extension UITableView {
    func dequeueReusableCell<T: UITableViewCell>(with _: T.Type,
                                                 for indexPath: IndexPath) -> T
    {
        guard let cell = dequeueReusableCell(withIdentifier: T.reuseIdentifier, for: indexPath) as? T else {
            preconditionFailure("Unable to dequeue \(T.description()) for indexPath: \(indexPath)")
        }
        return cell
    }

    func dequeueReusableHeaderFooterView<T: UITableViewHeaderFooterView>(with _: T.Type) -> T {
        guard let cell = dequeueReusableHeaderFooterView(withIdentifier: T.reuseIdentifier) as? T else {
            preconditionFailure("Unable to dequeue \(T.description())")
        }
        return cell
    }
}
