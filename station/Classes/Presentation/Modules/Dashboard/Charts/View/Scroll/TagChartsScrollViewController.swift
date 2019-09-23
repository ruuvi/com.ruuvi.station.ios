import UIKit
import Charts

class TagChartsScrollViewController: UIViewController {
    var output: TagChartsViewOutput!
    
    @IBOutlet weak var settingsButton: UIBarButtonItem!
    @IBOutlet weak var scrollView: UIScrollView!
    
    var viewModels = [TagChartsViewModel]() { didSet { updateUIViewModels() }  }
    
    private var views = [TagChartsView]()
    private var currentPage: Int {
        return Int(scrollView.contentOffset.x / scrollView.frame.size.width)
    }
}

// MARK: - TagChartsViewInput
extension TagChartsScrollViewController: TagChartsViewInput {
    func localize() {
        
    }
    
    func apply(theme: Theme) {
        
    }
    
    func scroll(to index: Int, immediately: Bool = false) {
        if immediately {
            view.layoutIfNeeded()
            scrollView.layoutIfNeeded()
            let x: CGFloat = scrollView.frame.size.width * CGFloat(index)
            scrollView.setContentOffset(CGPoint(x: x, y: 0), animated: false)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let sSelf = self else { return }
                let x: CGFloat = sSelf.scrollView.frame.size.width * CGFloat(index)
                sSelf.scrollView.setContentOffset(CGPoint(x: x, y: 0), animated: true)
            }
        }
    }
}

// MARK: - IBActions
extension TagChartsScrollViewController {
    @IBAction func settingsButtonTouchUpInside(_ sender: UIButton) {
        
    }
    
    @IBAction func dashboardButtonTouchUpInside(_ sender: Any) {
        output.viewDidTriggerDashboard()
    }
    
    @IBAction func menuButtonTouchUpInside(_ sender: Any) {
        
    }
}

// MARK: - View lifecycle
extension TagChartsScrollViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        output.viewDidLoad()
    }
}

// MARK: - Update UI
extension TagChartsScrollViewController: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        output.viewDidScroll(to: currentPage)
    }
}

// MARK: - ChartViewDelegate
extension TagChartsScrollViewController: ChartViewDelegate {
    
}

// MARK: - View configuration
extension TagChartsScrollViewController {
    
    private func bind(view: TagChartsView, with viewModel: TagChartsViewModel) {
        view.nameLabel.bind(viewModel.name, block: { $0.text = $1?.uppercased() ?? "N/A".localized() })
        view.backgroundImage.bind(viewModel.background) { $0.image = $1 }
        view.temperatureChart.bind(viewModel.temperature) { [weak self] (chartView, values) in
            if let values = values {
                chartView.delegate = self
                
                chartView.chartDescription?.enabled = false
                
                chartView.dragEnabled = true
                chartView.setScaleEnabled(true)
                chartView.pinchZoomEnabled = false
                chartView.highlightPerDragEnabled = false
                
                chartView.backgroundColor = .clear
                
                chartView.legend.enabled = false
                
                let xAxis = chartView.xAxis
                xAxis.labelPosition = .bottom
                xAxis.labelFont = .systemFont(ofSize: 10, weight: .light)
                xAxis.labelTextColor = UIColor.white
                xAxis.drawAxisLineEnabled = false
                xAxis.drawGridLinesEnabled = true
                xAxis.centerAxisLabelsEnabled = false
                xAxis.granularity = 300
                xAxis.valueFormatter = DateValueFormatter()
                xAxis.granularityEnabled = true
                
                let leftAxis = chartView.leftAxis
                leftAxis.labelPosition = .outsideChart
                leftAxis.labelFont = .systemFont(ofSize: 10, weight: .light)
                leftAxis.drawGridLinesEnabled = true
                
                leftAxis.labelTextColor = UIColor.white
                
                chartView.rightAxis.enabled = false
                chartView.legend.form = .line
                
                let points = values.map { (point) -> ChartDataEntry in
                    return ChartDataEntry(x: point.date.timeIntervalSince1970, y: point.value)
                }
                
                let set1 = LineChartDataSet(entries: points, label: "Temperature")
                set1.axisDependency = .left
                set1.setColor(UIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1))
                set1.lineWidth = 1.5
                set1.drawCirclesEnabled = true
                set1.circleRadius = 2
                set1.drawValuesEnabled = false
                set1.fillAlpha = 0.26
                set1.fillColor = UIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1)
                set1.highlightColor = UIColor(red: 244/255, green: 117/255, blue: 117/255, alpha: 1)
                set1.drawCircleHoleEnabled = false
                set1.drawFilledEnabled = true
                set1.highlightEnabled = false
                
                let data = LineChartData(dataSet: set1)
                data.setValueTextColor(.white)
                data.setValueFont(.systemFont(ofSize: 9, weight: .light))
                
                chartView.data = data
                
                if let firstX = values.first?.date.timeIntervalSince1970,
                    let lastX = values.last?.date.timeIntervalSince1970 {
                    let scaleX = CGFloat((lastX - firstX) / (60 * 60 * 24))
                    chartView.zoom(scaleX: scaleX, scaleY: 0, x: 0, y: 0)
                    chartView.moveViewToX(lastX - (60 * 60 * 24))
                }
                
            } else {
                print("// TODO: show no values for chart")
            }
        }
        
        
    }
    
}

// MARK: - Update UI
extension TagChartsScrollViewController {
    private func updateUI() {
        updateUIViewModels()
    }
    
    private func updateUIViewModels() {
        if isViewLoaded {
            views.forEach({ $0.removeFromSuperview() })
            views.removeAll()

            if viewModels.count > 0 {
                var leftView: UIView = scrollView
                for viewModel in viewModels {
                    let view = Bundle.main.loadNibNamed("TagChartsView", owner: self, options: nil)?.first as! TagChartsView
                    view.translatesAutoresizingMaskIntoConstraints = false
                    scrollView.addSubview(view)
                    position(view, leftView)
                    bind(view: view, with: viewModel)
                    views.append(view)
                    leftView = view
                }
                scrollView.addConstraint(NSLayoutConstraint(item: leftView, attribute: .trailing, relatedBy: .equal
                    , toItem: scrollView, attribute: .trailing, multiplier: 1.0, constant: 0.0))
            }
        }
    }
    
    private func position(_ view: TagChartsView, _ leftView: UIView) {
        scrollView.addConstraint(NSLayoutConstraint(item: view, attribute: .leading, relatedBy: .equal, toItem: leftView, attribute: leftView == scrollView ? .leading : .trailing, multiplier: 1.0, constant: 0.0))
        scrollView.addConstraint(NSLayoutConstraint(item: view, attribute: .top, relatedBy: .equal, toItem: scrollView, attribute: .top, multiplier: 1.0, constant: 0.0))
        scrollView.addConstraint(NSLayoutConstraint(item: view, attribute: .bottom, relatedBy: .equal, toItem: scrollView, attribute: .bottom, multiplier: 1.0, constant: 0.0))
        scrollView.addConstraint(NSLayoutConstraint(item: view, attribute: .width, relatedBy: .equal, toItem: scrollView, attribute: .width, multiplier: 1.0, constant: 0.0))
        scrollView.addConstraint(NSLayoutConstraint(item: view, attribute: .height, relatedBy: .equal, toItem: scrollView, attribute: .height, multiplier: 1.0, constant: 0.0))
    }
}
