//
//  AppSettingsTableViewController.swift
//  station
//
//  Created by Elias Berg on 05/04/2019.
//  Copyright © 2019 Ruuvi Innovations Oy. All rights reserved.
//

import UIKit

class AppSettingsTableViewController: UITableViewController {
    
    @IBOutlet weak var useFahrenheit: UISwitch!
    
    override func viewDidLoad() {
        self.tableView.tableFooterView = UIView(frame: CGRect.zero)
        self.tableView.delegate = self
        useFahrenheit.isOn = UserDefaults.standard.bool(forKey: "useFahrenheit")
    }
    
    @IBAction func fahrenheitSwitchChanged(_ sender: Any) {
        UserDefaults.standard.set(useFahrenheit.isOn, forKey: "useFahrenheit")
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    @IBAction func backClick(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}
