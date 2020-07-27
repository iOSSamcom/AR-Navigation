
import UIKit
import CoreLocation
import MapKit

class ViewController: UIViewController {
    @IBOutlet weak var txtAddress: UITextField!
    @IBOutlet weak var tblView: UITableView!
    var locationManager = CLLocationManager()
    var mapSearchResults: [MKMapItem]?

    override func viewDidLoad() {
        super.viewDidLoad()
        setLocationManager()
        // Do any additional setup after loading the view.
    }
    
    func setLocationManager(){
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.headingFilter = kCLHeadingFilterNone
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.delegate = self
        locationManager.startUpdatingHeading()
        locationManager.startUpdatingLocation()
        locationManager.requestWhenInUseAuthorization()
        tblView.tableFooterView = UIView()
        tblView.reloadData()
    }
    func getDirections(to mapLocation: MKMapItem) -> [MKRoute] {

        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = mapLocation
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)
        var routes = [MKRoute]()
        directions.calculate(completionHandler: { response, error in
            defer {
                DispatchQueue.main.async { [weak self] in
                }
            }
            if let error = error {
                return print("Error getting directions: \(error.localizedDescription)")
            }
            guard let response = response else {
                return assertionFailure("No error, but no response, either.")
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    return
                }

                
            routes = response.routes
                
                let vc = ShowARRouteVC.initViewController(routes: routes)
                self.navigationController?.pushViewController(vc, animated: true)
            }
        })
        return routes
    }
    func searchForLocation() {
        guard let addressText = txtAddress.text, !addressText.isEmpty else {
            return
        }

//        showRouteDirections.isOn = true
//        toggledSwitch(showRouteDirections)

//        refreshControl.startAnimating()
        
        defer {
            self.txtAddress.resignFirstResponder()
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = addressText

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            defer {
                DispatchQueue.main.async { [weak self] in
//                    self?.refreshControl.stopAnimating()
                }
            }
            if let error = error {
                return assertionFailure("Error searching for \(addressText): \(error.localizedDescription)")
            }
            guard let response = response, response.mapItems.count > 0 else {
                return assertionFailure("No response or empty response")
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    return
                }
                self.mapSearchResults = response.sortedMapItems(byDistanceFrom: self.locationManager.location)
                self.tblView.reloadData()
            }
        }
    }
    
    @IBAction func navigateClicked(_ sender: UIButton) {
        guard let text = txtAddress.text, !text.isEmpty else {
            return
        }
        searchForLocation()
    }
    
}

extension ViewController: UITableViewDataSource,UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if mapSearchResults?.count ?? 0 == 0{
            tblView.isHidden = true
            return 0
        }
        tblView.isHidden = false

        return mapSearchResults?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        let mapItem = mapSearchResults?[indexPath.row]
        cell.textLabel?.text = mapItem?.titleLabelText
        guard locationManager.location != nil else {
            cell.detailTextLabel?.text = ""
            return cell
        }
        guard let mapItemLocation = mapItem?.placemark.location else {
            cell.detailTextLabel?.text = ""
            return cell
        }
        cell.detailTextLabel?.text = String(format: "%.0f km", mapItemLocation.distance(from: locationManager.location!)/1000)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        let selectedMapItem = mapSearchResults?[indexPath.row]
        let routes = getDirections(to: selectedMapItem ?? MKMapItem())
        
    }

}

// MARK: - CLLocationManagerDelegate

extension ViewController: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

    }
}
extension MKLocalSearch.Response {

    func sortedMapItems(byDistanceFrom location: CLLocation?) -> [MKMapItem] {
        guard let location = location else {
            return mapItems
        }

        return mapItems.sorted { (first, second) -> Bool in
            guard let d1 = first.placemark.location?.distance(from: location),
                let d2 = second.placemark.location?.distance(from: location) else {
                    return true
            }

            return d1 < d2
        }
    }

}
private extension MKMapItem {

    var titleLabelText: String {
        var result = ""

        if let name = name {
            result += name
        }
        if let addressDictionary = placemark.addressDictionary {
            if let street = addressDictionary["Street"] as? String {
                result += "\n\(street)"
            }
            if let city = addressDictionary["City"] as? String,
                let state = addressDictionary["State"] as? String,
                let zip = addressDictionary["ZIP"] as? String {
                result += "\n\(city), \(state) \(zip)"
            }
        } else if let location = placemark.location {
            result += "\n\(location.coordinate)"
        }

        return result
    }

}

