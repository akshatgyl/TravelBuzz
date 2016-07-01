//
//  ViewController.swift
//  TravelBuzz
//
//  Created by Akshat Goyal on 6/24/16.
//  Copyright © 2016 akshatgyl. All rights reserved.
//

import UIKit
import AudioToolbox

class FirstViewController: UIViewController, UISearchBarDelegate, LocateOnTheMap {

    var searchResultController: SearchResultsController!
    var resultsArray = [String]()
    @IBOutlet weak var mapView: UIView!
    @IBOutlet weak var googleMap: GMSMapView!
    
    @IBOutlet weak var opaqueView: UIView!
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var pinButton: UIButton!
    @IBOutlet weak var locationButton: UIButton!
    @IBOutlet weak var pin: UIImageView!
    @IBOutlet weak var backButton: UIButton!
    
    var pinSearch = false
    var targetPostion: CLLocationCoordinate2D?
    let locationManager = CLLocationManager()
    var vibrationStarted = false
    var mahLocation: CLLocation?
    var tempPinCoordinates: CLLocationCoordinate2D?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        googleMap.delegate = self
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        pin.hidden = true
        backButton.hidden = true
    }
    
    override func viewDidAppear(animated: Bool) {
        searchResultController = SearchResultsController()
        searchResultController.delegate = self
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func searchWithAdress(sender: AnyObject) {
        let searchController = UISearchController(searchResultsController: searchResultController)
        searchController.searchBar.delegate = self
        self.presentViewController(searchController, animated: true, completion: nil)
    }
    
    @IBAction func backPressed(sender: AnyObject) {
        
        pinSearch = false
        googleMap.clear()
        targetPostion = nil
        UIView.animateWithDuration(5.0, animations: {
            self.opaqueView.hidden = false
            self.addButton.hidden = false
            self.pinButton.hidden = false
            self.pin.hidden = true
            self.backButton.hidden = true
        })
        
    }
    
    func locateWithLongitude(lon: Double, andLatitude lat: Double, andTitle title: String) {
        pinSearch = false
        dispatch_async(dispatch_get_main_queue()) {
            UIView.animateWithDuration(0.5, animations: {
                self.opaqueView.hidden = true
              self.addButton.hidden = true
                self.pinButton.hidden = true
                self.pin.hidden = true
                self.backButton.hidden = false
                self.locationButton.hidden = true
            })
            
            let position = CLLocationCoordinate2DMake(lat, lon)
            let marker = GMSMarker(position: position)
            self.targetPostion = position
            let camera = GMSCameraPosition.cameraWithLatitude(lat, longitude: lon, zoom: 17)
            UIView.animateWithDuration(1, animations: { 
                self.googleMap.camera = camera
                
                marker.title = "Address: \(title)"
                marker.map = self.googleMap
            })
        }
    }
    
    @IBAction func pinButtonPressed(sender: AnyObject) {
        
        pinSearch = true
        
        let camera = GMSCameraPosition.cameraWithLatitude((mahLocation?.coordinate.latitude)!, longitude: (mahLocation?.coordinate.longitude)!, zoom: 17)
        googleMap.camera = camera
        dispatch_async(dispatch_get_main_queue()) { 
            self.opaqueView.hidden = true
            self.addButton.hidden = true
            self.pinButton.hidden = true
            self.pin.hidden = false
            self.locationButton.hidden = false
            self.backButton.hidden = false
        }
        
    }
    
    @IBAction func locationSelected(sender: AnyObject) {
        targetPostion = tempPinCoordinates
        pin.hidden = true
        locationButton.hidden = true
        let position = CLLocationCoordinate2DMake(targetPostion!.latitude, targetPostion!.longitude)
        let marker = GMSMarker(position: position)
        let camera = GMSCameraPosition.cameraWithLatitude(targetPostion!.latitude, longitude: targetPostion!.longitude, zoom: 17)
        UIView.animateWithDuration(1) { 
            self.googleMap.camera = camera
            marker.map = self.googleMap
        }
        
        
        
    }
    func reverseGeocodeCoordinate(coordinate: CLLocationCoordinate2D) {
        if pinSearch {
            let geocoder = GMSGeocoder()
            geocoder.reverseGeocodeCoordinate(coordinate) { response, error in
                if let address = response?.firstResult() {
                    print(coordinate)
                    self.tempPinCoordinates = coordinate
                    let lines = address.lines! as [String]
                    self.locationButton.setTitle(lines.joinWithSeparator("\n"), forState: .Normal)
                    UIView.animateWithDuration(0.25) {
                        self.view.layoutIfNeeded()
                    }
                }
            }
        }
    }
    
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        let placeClient = GMSPlacesClient()
        placeClient.autocompleteQuery(searchText, bounds: nil, filter: nil) { (results, error: NSError?) -> Void in
            
            self.resultsArray.removeAll()
            if results == nil {
                return
            }
            
            
            for result in results! {
                if let result = result as? GMSAutocompletePrediction {
                    self.resultsArray.append(result.attributedFullText.string)
                }
            }
            
            self.searchResultController.reloadDataWithArray(self.resultsArray)
        
        }
    }

}

extension FirstViewController: CLLocationManagerDelegate {
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        if status == .AuthorizedWhenInUse {
            locationManager.startUpdatingLocation()
            googleMap.myLocationEnabled = true
            googleMap.settings.myLocationButton = true
        }
    }

    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        mahLocation = googleMap.myLocation
        if let target = targetPostion {
            let myLocation = googleMap.myLocation
            let target = CLLocation(latitude: target.latitude , longitude: target.longitude)
            let distance: CLLocationDistance = (myLocation?.distanceFromLocation(target))!
            print(distance)
            if distance < 50 {
                AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
            }
        }
    }
}

extension FirstViewController: GMSMapViewDelegate {
    func mapView(mapView: GMSMapView, idleAtCameraPosition position: GMSCameraPosition) {
        reverseGeocodeCoordinate(position.target)
    }
}
