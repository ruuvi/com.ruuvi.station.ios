//
//  SideMenuTableViewController.swift
//  station
//
//  Created by Elias Berg on 24/03/2019.
//  Copyright © 2019 Ruuvi Innovations Oy. All rights reserved.
//

import UIKit

class SideMenuTableViewController: UITableViewController {
    override func viewDidLoad() {
        self.tableView.tableFooterView = UIView(frame: CGRect.zero)
        self.tableView.delegate = self
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        switch indexPath.row {
        case 0:
            //dismiss(animated: true, completion: {
            let addVC = storyboard.instantiateViewController(withIdentifier: "AddViewControllerContainerNav")
            self.present(addVC, animated: true, completion: nil)
               //(self.parent as! SideMenuViewController).tagVC?.performSegue(withIdentifier: "segueToAdd", sender: nil)
//                self.presentedViewController?.performSegue(withIdentifier: "segueToAdd", sender: nil)
//                (self.parent as! SideMenuViewController).tagViewController.performSegue(withIdentifier: "segueToAdd", sender: nil)
            //})

            //let secondViewController:AddViewController = AddViewController()
            //self.present(secondViewController, animated: true, completion: nil)
            break
        case 1:
            let appVC = storyboard.instantiateViewController(withIdentifier: "AppSettingsNav")
            self.present(appVC, animated: true, completion: nil)
            break
        case 2:
            let aboutVC = storyboard.instantiateViewController(withIdentifier: "aboutViewController")
            self.present(aboutVC, animated: true, completion: nil)
            break
        default:
            return
        }
    }
}
