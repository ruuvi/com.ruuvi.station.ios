import UIKit
import CoreBluetooth


class TagViewController: UIViewController, RuuviTagListener {
    
    var ruuviTags: NSMutableArray = []
    var scanner: RuuviTagScanner?
    var timer: Timer?
    
    @IBOutlet weak var editBtn: UIBarButtonItem!
    @IBOutlet weak var tagPager: UIScrollView!
    @IBOutlet weak var noTagsBtn: UIButton!
    
    func found(tag: RuuviTag) {
        for ruuviTag in ruuviTags {
            let v = ruuviTag as! TagView
            if (v.ruuviTag?.uuid == tag.uuid) {
                v.ruuviTag = tag
                //v.draw()
                return
            }
        }
        //let tagView = getView(tag: tag)
        //tagView.draw()
    }
    
    func bluetoothDisabled() {
        let alertVC = UIAlertController(title: "Bluetooth is not enabled", message: "Ruuvi Station needs bluetooth to be able to listen for RuuviTags. Go to Settings and turn Bluetooth on.", preferredStyle: UIAlertControllerStyle.alert)
        let action = UIAlertAction(title: "ok", style: UIAlertActionStyle.default, handler: { (action: UIAlertAction) -> Void in
            self.dismiss(animated: true, completion: nil)
        })
        alertVC.addAction(action)
        self.present(alertVC, animated: true, completion: nil)
    }
    
    func getCurrentPage() -> Int {
        return Int(self.tagPager.contentOffset.x / self.tagPager.frame.size.width);
    }
    
    @IBAction func removeClick(_ sender: Any) {
        if ruuviTags.count == 0 {
            return
        }
        var indexOfPage = getCurrentPage()
        if let ruuvitag = (self.ruuviTags[indexOfPage] as! TagView).ruuviTag {
            var infoText = "Data format: " + String(ruuvitag.dataFormat)
            if ruuvitag.voltage != 0.0 {
                 infoText.append("\nVoltage: " + String(ruuvitag.voltage) + " V")
            }
            let alertController = UIAlertController(title: nil, message: infoText, preferredStyle: .actionSheet)
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { action in
            }
            alertController.addAction(cancelAction)
            
            let destroyAction = UIAlertAction(title: "Remove Tag", style: .destructive) { action in
                DispatchQueue.main.async {
                    for view in self.tagPager.subviews {
                        view.removeFromSuperview()
                    }
                    ruuvitag.delete()
                    self.ruuviTags.removeAllObjects()
                    let tags = RuuviTag().getAll()
                    self.noTagsBtn.isHidden = tags.count > 0
                    for tag in tags {
                        let tagView = self.getView(tag: tag)
                        tagView.draw()
                    }
                    self.tagPager.contentOffset.x = CGFloat(Int(self.tagPager.frame.size.width) * indexOfPage)
                    if indexOfPage > tags.count - 1 {
                        indexOfPage = tags.count - 1
                    }
                    self.tagPager.setContentOffset(CGPoint(x: CGFloat(Int(self.tagPager.frame.size.width) * indexOfPage), y:0), animated: true)
                    //self.tagPager.contentOffset.x = CGFloat(Int(self.tagPager.frame.size.width) * indexOfPage)
                    self.view.setNeedsLayout()
                }
            }
            alertController.addAction(destroyAction)
            
            let renameAction = UIAlertAction(title: "Rename tag", style: .default) { action in
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Enter a name", message: "", preferredStyle: .alert)
                    alert.addTextField { (textField) in
                        textField.autocapitalizationType = UITextAutocapitalizationType.words
                        textField.text = ruuvitag.name
                    }
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak alert] (_) in
                        let textField = alert?.textFields![0]
                        ruuvitag.updateName(name: textField?.text ?? "")
                        self.updateView()
                    }))
                    self.present(alert, animated: true, completion: nil)
                }
            }
            alertController.addAction(renameAction)
            
            if let presenter = alertController.popoverPresentationController {
                presenter.barButtonItem = self.editBtn
            }

            self.present(alertController, animated: true) {
            }
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        let page = getCurrentPage()
        coordinator.animate(alongsideTransition: { (UIViewControllerTransitionCoordinatorContext) -> Void in
            self.tagPager.contentSize = CGSize(width: size.width * CGFloat(self.ruuviTags.count), height: self.tagPager.frame.height)
            for (i, rt) in self.ruuviTags.enumerated() {
                if let tagView = rt as? TagView {
                    tagView.frame = CGRect(origin: CGPoint(x: size.width * CGFloat(i), y: 0), size: CGSize(width: size.width, height: self.self.tagPager.contentSize.height))
                }
            }
            self.tagPager.contentOffset.x = CGFloat(page) * self.tagPager.frame.width
            let orient = UIApplication.shared.statusBarOrientation
            switch orient {
            case .portrait:
                print("Portrait")
            case .landscapeLeft,.landscapeRight :
                print("Landscape")
            default:
                print("Anything But Portrait")
            }
        }, completion: { (UIViewControllerTransitionCoordinatorContext) -> Void in
            //tagPager.contentSize = CGSize(width: size.width * CGFloat(ruuviTags.count), height: size.height)
            /*
            self.tagPager.contentSize = CGSize(width: size.width * CGFloat(self.ruuviTags.count), height: self.tagPager.frame.height)
            for (i, rt) in self.ruuviTags.enumerated() {
                if let tagView = rt as? TagView {
                    tagView.frame = CGRect(origin: CGPoint(x: size.width * CGFloat(i), y: 0), size: CGSize(width: size.width, height: self.self.tagPager.contentSize.height))
                }
            }
            self.tagPager.contentOffset.x = CGFloat(page) * self.tagPager.frame.width
            */
        })
        super.viewWillTransition(to: size, with: coordinator)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        noTagsBtn.layer.borderColor = UIColor.white.cgColor
        scanner = RuuviTagScanner(caller: self as RuuviTagListener)
        NotificationCenter.default.addObserver(self, selector: #selector(self.background), name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.foreground), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        
        if !UserDefaults.standard.bool(forKey: "hasShownWelcome") {
            let mainStoryboard = UIStoryboard(name: "Main", bundle: Bundle.main)
            let vc : UIViewController = mainStoryboard.instantiateViewController(withIdentifier: "welcomeView") as UIViewController
            self.present(vc, animated: true, completion: nil)
        }
    }
    
    @objc func background()  {
        scanner?.stop()
    }
    @objc func foreground()  {
        scanner?.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        timer = nil
        //NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
        //NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let currentPage = getCurrentPage()
        var animateToPage = currentPage
        let tags = RuuviTag().getAll()
        if ruuviTags.count > 0 && tags.count > ruuviTags.count {
            // there is a new tag, focus on that
            animateToPage = tags.count - 1
        }
        ruuviTags.removeAllObjects()
        noTagsBtn.isHidden = tags.count > 0
        for tag in tags {
            let tagView = getView(tag: tag)
            tagView.draw()
        }
        self.tagPager.contentOffset.x = CGFloat(Int(self.tagPager.frame.size.width) * currentPage)
        if animateToPage != currentPage {
            self.tagPager.setContentOffset(CGPoint(x: CGFloat(Int(self.tagPager.frame.size.width) * animateToPage), y:0), animated: true)
        }
        if tags.count > 1 && !UserDefaults.standard.bool(forKey: "hasShownSwipe") {
            UserDefaults.standard.set(true, forKey: "hasShownSwipe")
            let alert = UIAlertController(title: "Swipe to switch between RuuviTags", message: "", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            }))
            self.present(alert, animated: true, completion: nil)
        }
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateView), userInfo: nil, repeats: true)
        scanner?.start()
    }
    
    @objc func updateView() {
        for rt in ruuviTags {
            let tag = rt as! TagView
            tag.draw()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        scanner?.stop()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func getView(tag: RuuviTag) -> TagView {
        let tagView = Bundle.main.loadNibNamed("TagView", owner: self, options: nil)?.first as! TagView
        tagView.frame = CGRect(origin: CGPoint(x: self.view.frame.size.width * CGFloat(ruuviTags.count), y: 0), size: CGSize(width: self.view.frame.size.width, height: tagPager.frame.size.height))
        tagView.ruuviTag = tag
        ruuviTags.add(tagView)
        tagPager.addSubview(tagView)
        tagPager.contentSize = CGSize(width: self.view.frame.size.width * CGFloat(ruuviTags.count), height: tagPager.frame.size.height)
        return tagView
    }
}
