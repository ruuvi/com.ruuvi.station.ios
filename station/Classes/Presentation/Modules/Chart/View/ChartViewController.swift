import UIKit
import Charts

class ChartViewController: UIViewController {
    var output: ChartViewOutput!

    @IBOutlet weak var chartView: LineChartView!
    
    var data: [ChartViewModel] = [ChartViewModel]() { didSet { updateUIData() } }
}

extension ChartViewController: ChartViewInput {
    func apply(theme: Theme) {
        
    }
    
    func localize() {
        
    }
}

extension ChartViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
        updateUI()
        output.viewDidLoad()
    }
}

extension ChartViewController {
    private func configureViews() {
        configureChartView()
    }
    
    private func configureChartView() {
        
        chartView.chartDescription?.enabled = false
        chartView.legend.enabled = false
        chartView.rightAxis.enabled = false
        chartView.legend.form = .line
        
        let xAxis = chartView.xAxis
        xAxis.labelPosition = .topInside
        xAxis.labelFont = .systemFont(ofSize: 10, weight: .light)
        xAxis.labelTextColor = UIColor(red: 255/255, green: 192/255, blue: 56/255, alpha: 1)
        xAxis.drawAxisLineEnabled = false
        xAxis.drawGridLinesEnabled = true
        xAxis.centerAxisLabelsEnabled = true
        xAxis.granularity = 3600
        xAxis.valueFormatter = DateValueFormatter()
        
        let leftAxis = chartView.leftAxis
        leftAxis.labelPosition = .insideChart
        leftAxis.labelFont = .systemFont(ofSize: 12, weight: .light)
        leftAxis.drawGridLinesEnabled = true
        leftAxis.granularityEnabled = true
//        leftAxis.axisMinimum = 0
//        leftAxis.axisMaximum = 170
//        leftAxis.yOffset = -9
        leftAxis.labelTextColor = UIColor(red: 255/255, green: 192/255, blue: 56/255, alpha: 1)
    }
}

extension ChartViewController {
    private func updateUI() {
        updateUIData()
    }
    
    private func updateUIData() {
        if isViewLoaded {
            
            let values = data.map( { ChartDataEntry(x: $0.date.timeIntervalSince1970, y: $0.value) } )
            
            let set1 = LineChartDataSet(entries: values, label: "DataSet 1")
            set1.axisDependency = .left
            set1.setColor(UIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1))
            set1.lineWidth = 1.5
            set1.drawCirclesEnabled = false
            set1.drawValuesEnabled = false
            set1.fillAlpha = 0.26
            set1.fillColor = UIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1)
            set1.highlightColor = UIColor(red: 244/255, green: 117/255, blue: 117/255, alpha: 1)
            set1.drawCircleHoleEnabled = false
            
            let data = LineChartData(dataSet: set1)
            data.setValueTextColor(.white)
            data.setValueFont(.systemFont(ofSize: 9, weight: .light))
            
            chartView.data = data
        }
    }
}
