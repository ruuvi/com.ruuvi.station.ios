//
//  AboutViewController.swift
//  station
//
//  Created by Elias Berg on 05/04/2019.
//  Copyright © 2019 Ruuvi Innovations Oy. All rights reserved.
//

import UIKit

class AboutViewController: UIViewController {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    override func viewDidLoad() {
    }
    
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        UIApplication.shared.open(URL, options: [:])
        return false
    }
    
    @IBAction func backClick(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}
