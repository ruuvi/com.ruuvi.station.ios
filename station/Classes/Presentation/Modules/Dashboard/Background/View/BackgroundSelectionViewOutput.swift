import UIKit
import RuuviOntology

protocol BackgroundSelectionViewOutput {
    func viewDidLoad()
    func viewDidAskToSelectCamera()
    func viewDidAskToSelectGallery()
    func viewDidSelectDefaultPhoto(model: DefaultBackgroundModel)
    func viewDidCancelUpload()
}
