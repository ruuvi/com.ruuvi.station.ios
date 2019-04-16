import UIKit

class AddViewController: UITableViewController, RuuviTagListener {
    var addedRuuviTags: [RuuviTag] = []
    var ruuviTags: [RuuviTag] = []
    var scanner: RuuviTagScanner?
    var timer: Timer?
    
    func found(tag: RuuviTag) {
        for index in 0..<addedRuuviTags.count {
            if (addedRuuviTags[index].uuid == tag.uuid) {
                return
            }
        }
        for index in 0..<ruuviTags.count {
            if (ruuviTags[index].uuid == tag.uuid) {
                ruuviTags[index] = tag
                return
            }
        }
        ruuviTags.append(tag)
    }
    
    func reloadTable() {
        ruuviTags.sort() { $0.rssi > $1.rssi }
        self.tableView.reloadData()
    }
    
    func bluetoothDisabled() {
        let alertVC = UIAlertController(title: "Bluetooth is not enabled", message: "Make sure that your bluetooth is turned on.", preferredStyle: UIAlertControllerStyle.alert)
        let action = UIAlertAction(title: "ok", style: UIAlertActionStyle.default, handler: { (action: UIAlertAction) -> Void in
            self.dismiss(animated: true, completion: nil)
        })
        alertVC.addAction(action)
        self.present(alertVC, animated: true, completion: nil)
    }
    
    func reload() {
        DispatchQueue.main.async() {
            self.reloadTable()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        scanner = RuuviTagScanner(caller: self as RuuviTagListener)
        addedRuuviTags = []
        let tags = RuuviTag().getAll()
        for tag in tags {
            addedRuuviTags.append(tag)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
//        self.navigationController?.navigationBar.barStyle = UIBarStyle.default
//        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor:UIColor.black]
    }
    
    override func viewDidAppear(_ animated: Bool) {
        scanner?.start()
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(removeOldTags), userInfo: nil, repeats: true)
    }
    
    @objc func removeOldTags() {
        var i = -1;
        for (index, rt) in ruuviTags.enumerated() {
            let elapsed = Int(Date().timeIntervalSince(rt.updatedAt! as Date))
            if elapsed > 5 {
                i = index
                break
            }
        }
        if i > -1 {
            if ruuviTags.count > i {
                ruuviTags.remove(at: i)
                removeOldTags()
            }
        }
        reload()
    }
    
    func randomNumber<T : SignedInteger>(inRange range: ClosedRange<T> = 1...6) -> T {
        let length = Int64(range.upperBound - range.lowerBound + 1)
        let value = Int64(arc4random()) % length + Int64(range.lowerBound)
        return T(value)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        scanner?.stop()
        timer?.invalidate()
        timer = nil
    }
    
    override func willMove(toParentViewController parent: UIViewController?) {
//        navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor:UIColor.white]
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return max(ruuviTags.count, 1)
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Tags"
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "addCell", for: indexPath)
        if ruuviTags.count == 0 {
            cell.textLabel?.text = "Get More Sensors"
            cell.imageView?.image = UIImage(named: "eye_circle")
            return cell
        }
        
        let tag = ruuviTags[indexPath.row]
        if tag.mac == "" {
            cell.textLabel?.text = tag.uuid
        } else {
            cell.textLabel?.text = tag.mac
        }
        if (tag.rssi < -80) {
            cell.imageView?.image = UIImage(named: "icon-connection-1")
        } else if (tag.rssi < -50) {
            cell.imageView?.image = UIImage(named: "icon-connection-2")
        } else {
            cell.imageView?.image = UIImage(named: "icon-connection-3")
        }
        if let image = cell.imageView?.image {
            cell.imageView?.image = image.resizeImage(targetSize: CGSize(width: 30.0, height: 30.0))
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if ruuviTags.count == 0 {
            UIApplication.shared.open(URL(string: "https://ruuvi.com")!, options: [:], completionHandler: nil)
            return
        }
        let tag = ruuviTags[indexPath.row]
        tag.defaultBackground = randomNumber(inRange: 1...9)
        tag.save()
        navigationController?.popViewController(animated: true)
        dismiss(animated: true, completion: nil)
    }
}
