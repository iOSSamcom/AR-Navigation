
import UIKit
import ARCL
import ARKit
import MapKit
import SceneKit

class ShowARRouteVC: UIViewController {
    
    @IBOutlet var mapView: MKMapView!
    @IBOutlet var infoLabel: UILabel!
    @IBOutlet weak var nodePositionLabel: UILabel!
    
    @IBOutlet var contentView: UIView!
    let sceneLocationView = SceneLocationView()
    
    var userAnnotation: MKPointAnnotation?
    var locationEstimateAnnotation: MKPointAnnotation?
    
    var updateUserLocationTimer: Timer?
    var updateInfoLabelTimer: Timer?
    
    var centerMapOnUserLocation: Bool = true
    var routes: [MKRoute]?
    let displayDebugging = false
    
    let adjustNorthByTappingSidesOfScreen = false
    let addNodeByTappingScreen = true
    //MARK:- Initializers
    class func initViewController(routes:[MKRoute]) -> ShowARRouteVC{
        let vc = mainStoryBoard.instantiateViewController(withIdentifier: "ShowARRouteVC") as! ShowARRouteVC
        vc.routes = routes
        return vc
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        addSceneModels()
        setSceneView()
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification,
                                               object: nil,
                                               queue: nil) { [weak self] _ in
                                                self?.pauseAnimation()
        }
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                               object: nil,
                                               queue: nil) { [weak self] _ in
                                                self?.restartAnimation()
        }
        updateUserLocationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateUserLocation()
        }
        
        mapView.isHidden = false
        routes?.forEach { mapView.addOverlay($0.polyline) }
        // Do any additional setup after loading the view.
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        restartAnimation()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        pauseAnimation()
        super.viewWillDisappear(animated)
    }
    
    func pauseAnimation() {
        print("pause")
        sceneLocationView.pause()
    }
    
    func restartAnimation() {
        print("run")
        sceneLocationView.run()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        sceneLocationView.frame = contentView.bounds
    }
    func setSceneView(){
        sceneLocationView.showAxesNode = false
        sceneLocationView.showFeaturePoints = displayDebugging
        sceneLocationView.locationNodeTouchDelegate = self
        sceneLocationView.arViewDelegate = self
        sceneLocationView.locationNodeTouchDelegate = self
        contentView.addSubview(sceneLocationView)
        sceneLocationView.frame = contentView.bounds
        sceneLocationView.autoenablesDefaultLighting = true
        
    }
    func addSceneModels() {
        guard sceneLocationView.sceneLocationManager.currentLocation != nil else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.addSceneModels()
            }
            return
        }
        if let routes = routes {
            sceneLocationView.addRoutes(routes: routes) { distance -> SCNBox in
                let box = SCNBox(width: 2, height: 2, length: distance, chamferRadius: 2)
                box.firstMaterial?.diffuse.contents = UIColor.blue.withAlphaComponent(1)
                return box
            }
        } else {
            let alert = UIAlertController(title: "Error", message: "No Route Found", preferredStyle: .alert)
            let action = UIAlertAction(title: "Ok", style: .default, handler: nil)
            alert.addAction(action)
            self.present(alert, animated: true, completion: nil)
        }
    }
    /// Builds the location annotations for a few random objects, scattered across the country
    ///
    /// - Returns: an array of annotation nodes.
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first,
            let view = touch.view else { return }
        
        if mapView == view || mapView.recursiveSubviews().contains(view) {
            centerMapOnUserLocation = false
        } else {
            let location = touch.location(in: self.view)
            
            if location.x <= 40 && adjustNorthByTappingSidesOfScreen {
                print("left side of the screen")
                sceneLocationView.moveSceneHeadingAntiClockwise()
            } else if location.x >= view.frame.size.width - 40 && adjustNorthByTappingSidesOfScreen {
                print("right side of the screen")
                sceneLocationView.moveSceneHeadingClockwise()
            } else if addNodeByTappingScreen {
                let image = UIImage(named: "pin")!
                let annotationNode = LocationAnnotationNode(location: nil, image: image)
                annotationNode.scaleRelativeToDistance = false
                annotationNode.scalingScheme = .normal
                DispatchQueue.main.async {
                    //                self.sceneLocationView.addLocationNodeForCurrentPosition(locationNode: annotationNode)
                }
            }
        }
    }
    @objc
    func updateUserLocation() {
        guard let currentLocation = sceneLocationView.sceneLocationManager.currentLocation else {
            return
        }
        
        DispatchQueue.main.async { [weak self ] in
            guard let self = self else {
                return
            }
            
            if self.userAnnotation == nil {
                self.userAnnotation = MKPointAnnotation()
                self.mapView.addAnnotation(self.userAnnotation!)
            }
            
            UIView.animate(withDuration: 0.5, delay: 0, options: .allowUserInteraction, animations: {
                self.userAnnotation?.coordinate = currentLocation.coordinate
            }, completion: nil)
            
            if self.centerMapOnUserLocation {
                UIView.animate(withDuration: 0.45,
                               delay: 0,
                               options: .allowUserInteraction,
                               animations: {
                                self.mapView.setCenter(self.userAnnotation!.coordinate, animated: false)
                }, completion: { _ in
                    self.mapView.region.span = MKCoordinateSpan(latitudeDelta: 0.0005, longitudeDelta: 0.0005)
                })
            }
            
            if self.displayDebugging {
                if let bestLocationEstimate = self.sceneLocationView.sceneLocationManager.bestLocationEstimate {
                    if self.locationEstimateAnnotation == nil {
                        self.locationEstimateAnnotation = MKPointAnnotation()
                        self.mapView.addAnnotation(self.locationEstimateAnnotation!)
                    }
                    self.locationEstimateAnnotation?.coordinate = bestLocationEstimate.location.coordinate
                } else if self.locationEstimateAnnotation != nil {
                    self.mapView.removeAnnotation(self.locationEstimateAnnotation!)
                    self.locationEstimateAnnotation = nil
                }
            }
        }
    }
    
}
extension ShowARRouteVC: LNTouchDelegate {
    
    func annotationNodeTouched(node: AnnotationNode) {
        if let node = node.parent as? LocationNode {
            let coords = "\(node.location.coordinate.latitude.short)° \(node.location.coordinate.longitude.short)°"
            let altitude = "\(node.location.altitude.short)m"
            let tag = node.tag ?? ""
            nodePositionLabel.text = " Annotation node at \(coords), \(altitude) - \(tag)"
        }
    }
    
    func locationNodeTouched(node: LocationNode) {
        print("Location node touched - tag: \(node.tag ?? "")")
        let coords = "\(node.location.coordinate.latitude.short)° \(node.location.coordinate.longitude.short)°"
        let altitude = "\(node.location.altitude.short)m"
        let tag = node.tag ?? ""
        nodePositionLabel.text = " Location node at \(coords), \(altitude) - \(tag)"
    }
    
}

// MARK: - Helpers

extension DispatchQueue {
    func asyncAfter(timeInterval: TimeInterval, execute: @escaping () -> Void) {
        self.asyncAfter(
            deadline: DispatchTime.now() + Double(Int64(timeInterval * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC),
            execute: execute)
    }
}

extension UIView {
    func recursiveSubviews() -> [UIView] {
        var recursiveSubviews = self.subviews
        
        subviews.forEach { recursiveSubviews.append(contentsOf: $0.recursiveSubviews()) }
        
        return recursiveSubviews
    }
}


// MARK: - MKMapViewDelegate

extension ShowARRouteVC: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.lineWidth = 3
        renderer.strokeColor = UIColor.blue.withAlphaComponent(0.5)
        
        return renderer
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation),
            let pointAnnotation = annotation as? MKPointAnnotation else { return nil }
        
        let marker = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: nil)
        
        if pointAnnotation == self.userAnnotation {
            marker.displayPriority = .required
            marker.glyphImage = UIImage(named: "user")
        } else {
            marker.displayPriority = .required
            marker.markerTintColor = UIColor(hue: 0.267, saturation: 0.67, brightness: 0.77, alpha: 1.0)
            marker.glyphImage = UIImage(named: "compass")
        }
        
        return marker
    }
}
extension ShowARRouteVC: ARSCNViewDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        print("Added SCNNode: \(node)")    // you probably won't see this fire
    }
    
    func renderer(_ renderer: SCNSceneRenderer, willUpdate node: SCNNode, for anchor: ARAnchor) {
        print("willUpdate: \(node)")    // you probably won't see this fire
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        print("Camera: \(camera)")
    }
    
}
