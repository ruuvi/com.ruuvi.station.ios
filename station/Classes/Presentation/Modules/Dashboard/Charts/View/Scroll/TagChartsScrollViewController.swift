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
    
    private func configure(_ chartView: LineChartView) {
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
    }
    
    private func configure(_ set: LineChartDataSet) {
        set.axisDependency = .left
        set.setColor(UIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1))
        set.lineWidth = 1.5
        set.drawCirclesEnabled = true
        set.circleRadius = 2
        set.drawValuesEnabled = false
        set.fillAlpha = 0.26
        set.fillColor = UIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1)
        set.highlightColor = UIColor(red: 244/255, green: 117/255, blue: 117/255, alpha: 1)
        set.drawCircleHoleEnabled = false
        set.drawFilledEnabled = true
        set.highlightEnabled = false
    }
    
    private func split(_ values: [TagChartsPoint]) -> [IChartDataSet]? {
        let interval: TimeInterval = 60 * 60
        var points = [ChartDataEntry]()
        var sets = [IChartDataSet]()
        var prevoiusValue: TimeInterval = Date.distantPast.timeIntervalSince1970
        for value in values {
            if value.date.timeIntervalSince1970 - prevoiusValue < interval {
                points.append(ChartDataEntry(x: value.date.timeIntervalSince1970, y: value.value))
            } else {
                let set = LineChartDataSet(entries: points, label: "Temperature")
                configure(set)
                sets.append(set)
                points = [ChartDataEntry]()
            }
            prevoiusValue = value.date.timeIntervalSince1970
        }
        let set = LineChartDataSet(entries: points, label: "Temperature")
        configure(set)
        sets.append(set)
        return sets
    }
    
    private func zoomAndScrollToLast24h(_ values: [TagChartsPoint], _ chartView: LineChartView) {
        if let firstX = values.first?.date.timeIntervalSince1970,
            let lastX = values.last?.date.timeIntervalSince1970 {
            let scaleX = CGFloat((lastX - firstX) / (60 * 60 * 24))
            chartView.zoom(scaleX: scaleX, scaleY: 0, x: 0, y: 0)
            chartView.moveViewToX(lastX - (60 * 60 * 24))
        }
    }
    
    private func bind(view: TagChartsView, with viewModel: TagChartsViewModel) {
        view.nameLabel.bind(viewModel.name, block: { $0.text = $1?.uppercased() ?? "N/A".localized() })
        view.backgroundImage.bind(viewModel.background) { $0.image = $1 }
        view.temperatureChart.bind(viewModel.temperature) { [weak self] (chartView, values) in
            if let values = values {
                self?.configure(chartView)
                let data = LineChartData(dataSets: self?.split(values))
                chartView.data = data
                self?.zoomAndScrollToLast24h(values, chartView)
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
