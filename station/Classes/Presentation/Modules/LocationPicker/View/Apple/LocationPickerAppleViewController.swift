import UIKit
import MapKit
import RuuviOntology

class LocationPickerAppleViewController: UIViewController {
    var output: LocationPickerViewOutput!

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet var doneBarButtonItem: UIBarButtonItem!
    @IBOutlet var cancelBarButtonItem: UIBarButtonItem!

    var selectedLocation: Location? {
        didSet {
            updateUISelectedLocation()
        }
    }

    private var searchBar: UISearchBar!
    private let annotationViewReuseIdentifier = "LocationPickerMKAnnotationViewReuseIdentifier"
}

// MARK: - LocationPickerViewInput
extension LocationPickerAppleViewController: LocationPickerViewInput {
    func localize() {
        doneBarButtonItem.title = "Done".localized()
        cancelBarButtonItem.title = "Cancel".localized()
    }
}

// MARK: - IBActions
extension LocationPickerAppleViewController {
    @IBAction func doneBarButtonItemAction(_ sender: Any) {
        output.viewDidTriggerDone()
    }

    @IBAction func cancelBarButtonItemAction(_ sender: Any) {
        output.viewDidTriggerCancel()
    }

    @IBAction func dismissBarButtonItemAction(_ sender: Any) {
        output.viewDidTriggerDismiss()
    }

    @IBAction func pinBarButtonItemAction(_ sender: Any) {
        output.viewDidTriggerCurrentLocation()
    }

    @objc func mapViewLongPressHandler(_ gr: UIGestureRecognizer) {
        if gr.state == .began {
            let point = gr.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            output.viewDidLongPressOnMap(at: coordinate)
        }
    }

    @objc func mapViewTapHandler(_ gr: UIGestureRecognizer) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - View lifecycle
extension LocationPickerAppleViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
        configureViews()
        updateUI()
    }
}

// MARK: - MKMapViewDelegate
extension LocationPickerAppleViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let view = mapView.dequeueReusableAnnotationView(withIdentifier: annotationViewReuseIdentifier) {
            return view
        } else {
            let view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: annotationViewReuseIdentifier)
            view.canShowCallout = true
            view.animatesDrop = true
            return view
        }
    }

    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - UISearchBarDelegate
extension LocationPickerAppleViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        if let query = searchBar.text {
            output.viewDidEnterSearchQuery(query)
        }
    }
}

// MARK: - View configuration
extension LocationPickerAppleViewController {
    private func configureViews() {
        if #available(iOS 13, *) {
            let appearance = navigationController?.navigationBar.standardAppearance.copy()
            navigationItem.standardAppearance = appearance
        }

        searchBar = UISearchBar(frame: .zero)
        searchBar.delegate = self
        navigationItem.titleView = searchBar

        let gr = UILongPressGestureRecognizer(target: self,
                                              action:
            #selector(LocationPickerAppleViewController.mapViewLongPressHandler(_:)))
        gr.minimumPressDuration = 0.3
        mapView.addGestureRecognizer(gr)

        let tr = UITapGestureRecognizer(target: self,
                                        action: #selector(LocationPickerAppleViewController.mapViewTapHandler(_:)))
        mapView.addGestureRecognizer(tr)
    }
}

// MARK: - Update UI
extension LocationPickerAppleViewController {
    private func updateUI() {
        updateUISelectedLocation()
    }

    private func updateUISelectedLocation() {
        if isViewLoaded {
            mapView.removeAnnotations(mapView.annotations)
            if let location = selectedLocation {
                let annotation = MKPointAnnotation()
                annotation.coordinate = location.coordinate
                annotation.title = location.cityCommaCountry
                mapView.addAnnotation(annotation)
                mapView.centerCoordinate = location.coordinate
                mapView.selectAnnotation(annotation, animated: true)
                searchBar.text = location.cityCommaCountry
                navigationItem.rightBarButtonItems = [doneBarButtonItem]
            } else {
                navigationItem.rightBarButtonItems = [cancelBarButtonItem]
            }
        }
    }
}
