//
//  SideMenuViewController.swift
//  station
//
//  Created by Elias Berg on 24/03/2019.
//  Copyright © 2019 Ruuvi Innovations Oy. All rights reserved.
//

import UIKit

class SideMenuViewController: UIViewController {
    @IBOutlet weak var ruuviLogo: UIImageView!
    var tagVC: TagViewController?
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    override func viewDidLoad() {
    }
}
