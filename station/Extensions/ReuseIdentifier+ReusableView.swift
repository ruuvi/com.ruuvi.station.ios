//
//  ReuseIdentifier+ReusableView.swift
//  station
//
//  Created by Viik.ufa on 22.04.2020.
//  Copyright © 2020 Ruuvi Innovations Oy. BSD-3-Clause.
//
import UIKit

protocol ReusableView: class {
    static var reuseIdentifier: String { get }
}

extension ReusableView where Self: UIView {
    static var reuseIdentifier: String {
        return String(describing: self)
    }
}

extension UICollectionViewCell: ReusableView {
}

extension UITableViewCell: ReusableView {
}

extension UITableView {
    func dequeueReusableCell<T: UITableViewCell>(with type: T.Type,
                                                 for indexPath: IndexPath) -> T {
        guard let cell = dequeueReusableCell(withIdentifier: T.reuseIdentifier, for: indexPath) as? T else {
            preconditionFailure("Unable to dequeue \(T.description()) for indexPath: \(indexPath)")
        }
        return cell
    }
}
