//
//  AboutViewController.swift
//  station
//
//  Created by Elias Berg on 05/04/2019.
//  Copyright © 2019 Ruuvi Innovations Oy. All rights reserved.
//

import UIKit

class AboutViewController: UIViewController {

    @IBOutlet weak var aboutTextView: UITextView!
    
    override func viewDidLoad() {
        // this is stupid but for some reasons setting the font to bold in ib did not work
        let attrString = NSMutableAttributedString(attributedString: aboutTextView.attributedText)
        let makeBold = ["ABOUT / HELP", "OPERATIONS MANUAL", "TROUBLESHOOTING", "OPEN-SOURCE", "MORE TO READ"]
        for bold in makeBold {
            let range = NSString(string: attrString.string).range(of: bold)
            attrString.addAttribute(NSAttributedStringKey.font, value: UIFont(name: "Muli-Bold", size: 18)!, range: range)
        }
        // .. and this is to reduce the linespacing below the titles
        for range in attrString.string.ranges(of: "  ") {
        
            attrString.addAttribute(NSAttributedStringKey.font, value: UIFont(name: "Muli-Bold", size: 8)!, range: NSRange(range, in: attrString.string))
        }
        aboutTextView.attributedText = attrString
    }
    
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        UIApplication.shared.open(URL, options: [:])
        return false
    }
    
    @IBAction func backClick(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
}
