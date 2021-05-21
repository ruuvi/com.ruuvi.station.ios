import Foundation

protocol OffsetCorrectionViewOutput {
    func viewDidLoad()
    func viewDidOpenCalibrateDialog()
    func viewDidOpenClearDialog()
    func viewDidClearOffsetValue()
    func viewDidSetCorrectValue(correctValue: Double)
}
