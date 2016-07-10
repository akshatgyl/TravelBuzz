//
//  ViewController.swift
//  TravelBuzz
//
//  Created by Akshat Goyal on 6/24/16.
//  Copyright © 2016 akshatgyl. All rights reserved.
//

import UIKit
import AudioToolbox
import AVFoundation

var targetPostion: CLLocationCoordinate2D?
var player:AVAudioPlayer = AVAudioPlayer()
var savedArray = [String]()
var savedLocations = [Double]()

class FirstViewController: UIViewController, UISearchBarDelegate, LocateOnTheMap, UITableViewDelegate, UITableViewDataSource {
    
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
    @IBOutlet weak var recentButton: UIButton!
    
    @IBOutlet weak var recentSearchView: UIView!
    @IBOutlet weak var recentSearchTableView: UITableView!
    
    var notificationCreated = false
    
    var pinSearch = false
    let locationManager = CLLocationManager()
    var vibrationStarted = false
    var tempPinCoordinates: CLLocationCoordinate2D?
    var alarmSounding = false
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        googleMap.delegate = self
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        
        let audioPath = NSBundle.mainBundle().pathForResource("alarm", ofType: "mp3")
        do {
            player = try AVAudioPlayer(contentsOfURL: NSURL(fileURLWithPath: audioPath!))
        }
        catch {
            print("Something bad happened. Try catching specific errors to narrow things down")
        }
        
        recentSearchView.layer.cornerRadius = 10
        recentSearchView.clipsToBounds = true
        
        recentSearchTableView.delegate = self
        recentSearchTableView.dataSource = self
        
//        recentSearchView.hidden = true
        recentSearchView.alpha = 0
//        pin.hidden = true
        pin.alpha = 0
//        backButton.hidden = true
        backButton.alpha = 0
        locationButton.alpha = 0
        
        let userDefaults = NSUserDefaults.standardUserDefaults()
        if let tempArray = userDefaults.objectForKey("savedArray") as? [String] {
            savedArray = tempArray
            savedLocations = userDefaults.objectForKey("savedLocations") as! [Double]
        } else {
            print("no value set")
        }
        
    }
    
    override func viewDidAppear(animated: Bool) {
        searchResultController = SearchResultsController()
        searchResultController.delegate = self
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    //Search functions---------------------------------------------------------------------------
    
    @IBAction func searchWithAdress(sender: AnyObject) {
        let searchController = UISearchController(searchResultsController: searchResultController)
        searchController.searchBar.delegate = self
        self.presentViewController(searchController, animated: true, completion: nil)
    }
    
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        let placeClient = GMSPlacesClient()
        let myLocation = googleMap.myLocation
        let initial = CLLocationCoordinate2D(latitude: (myLocation?.coordinate.latitude)! - 2, longitude: (myLocation?.coordinate.longitude)! - 2)
        let other = CLLocationCoordinate2D(latitude: (myLocation?.coordinate.latitude)! + 2, longitude: (myLocation?.coordinate.longitude)! + 2)
        let bounds = GMSCoordinateBounds(coordinate: initial, coordinate: other)
        placeClient.autocompleteQuery(searchText, bounds: bounds , filter: nil) { (results, error: NSError?) -> Void in
            
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
    
    func locateWithLongitude(lon: Double, andLatitude lat: Double, andTitle title: String) {
        pinSearch = false
        dispatch_async(dispatch_get_main_queue()) { 
            UIView.animateWithDuration(0.5, animations: {
                //                self.opaqueView.hidden = true
                self.opaqueView.alpha = 0
                //                self.addButton.hidden = true
                self.addButton.alpha = 0
                //                self.pinButton.hidden = true
                self.pinButton.alpha = 0
                //                self.pin.hidden = true
                self.pin.alpha = 0
                //                self.backButton.hidden = false
                self.backButton.alpha = 1
                //                self.locationButton.hidden = true
                self.locationButton.alpha = 0
                //                self.recentButton.hidden = true
                self.recentButton.alpha = 0
            })
        
        
            let position = CLLocationCoordinate2DMake(lat, lon)
            let marker = GMSMarker(position: position)
            targetPostion = position
            
            if savedArray.contains(title) {
                savedArray.removeAtIndex(savedArray.indexOf(title)!)
            }
            
            savedArray.insert(title, atIndex: 0)
            savedLocations.insert(lon, atIndex: 0)
            savedLocations.insert(lat, atIndex: 0)
            
            print(savedArray)
            
            let myLocation = self.googleMap.myLocation
            let target = CLLocation(latitude: targetPostion!.latitude , longitude: targetPostion!.longitude)
            let distance: CLLocationDistance = (myLocation?.distanceFromLocation(target))!
            
            let fraction = 591657550.500000 / Float(distance)
            let zoom = log2(fraction) - 5
            
            print("zoom = \(zoom)")
            let camera = GMSCameraPosition.cameraWithLatitude(lat, longitude: lon, zoom: zoom)
            UIView.animateWithDuration(1, animations: {
                self.googleMap.camera = camera
                
                marker.title = "Address: \(title)"
                marker.map = self.googleMap
            })
            
            self.showConfirmation()
        }
        
    }
    
    
    //Pin Functions-----------------------------------------------------------------------------------
    
    @IBAction func backPressed(sender: AnyObject) {
        
        pinSearch = false
        googleMap.clear()
        targetPostion = nil
        player.stop()
        UIView.animateWithDuration(0.5, animations: {
            
            self.opaqueView.alpha = 0.7
            self.addButton.alpha = 1
            self.pinButton.alpha = 1
            self.pin.alpha = 0
            self.backButton.alpha = 0
            self.recentButton.alpha = 1
            
//            self.opaqueView.hidden = false
//            self.addButton.hidden = false
//            self.pinButton.hidden = false
//            self.pin.hidden = true
//            self.backButton.hidden = true
//            self.recentButton.hidden = false
        })
        self.recentSearchTableView.reloadData()
        
    }
    
    
    
    @IBAction func pinButtonPressed(sender: AnyObject) {
        
        pinSearch = true
        UIView.animateWithDuration(0.5, animations: {
//            self.opaqueView.hidden = true
//            self.addButton.hidden = true
//            self.pinButton.hidden = true
//            self.pin.hidden = false
//            self.locationButton.hidden = false
//            self.backButton.hidden = false
//            self.recentButton.hidden = true
            
            self.opaqueView.alpha = 0
            self.addButton.alpha = 0
            self.pinButton.alpha = 0
            self.pin.alpha = 1
            self.locationButton.alpha = 1
            self.backButton.alpha = 1
            self.recentButton.alpha = 0
        })
    }
    
    @IBAction func locationSelected(sender: AnyObject) {
        
        targetPostion = tempPinCoordinates
        
        if targetPostion == nil {
            let alert = UIAlertController(title: "Error", message: "Please select a location first", preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .Default, handler: nil))
            self.presentViewController(alert, animated: true, completion: nil)
            return
        }
        
        if (locationButton.titleLabel?.text)! != "Pick a location" {
            if savedArray.contains((locationButton.titleLabel?.text)!) {
                savedArray.removeAtIndex(savedArray.indexOf((locationButton.titleLabel?.text)!)!)
            }
            
            savedArray.insert((locationButton.titleLabel?.text)!, atIndex: 0)
            savedLocations.insert((targetPostion?.longitude)!, atIndex: 0)
            savedLocations.insert((targetPostion?.latitude)!, atIndex: 0)
            
        }
        
//        pin.hidden = true
//        locationButton.hidden = true
        
        UIView.animateWithDuration(0.5) { 
            self.pin.alpha = 0
            self.locationButton.alpha = 0
        }
        
        let position = CLLocationCoordinate2DMake(targetPostion!.latitude, targetPostion!.longitude)
        let marker = GMSMarker(position: position)
        
        let myLocation = self.googleMap.myLocation
        let target = CLLocation(latitude: targetPostion!.latitude , longitude: targetPostion!.longitude)
        let distance: CLLocationDistance = (myLocation?.distanceFromLocation(target))!
        
        let fraction = 591657550.500000 / Float(distance)
        let zoom = log2(fraction) - 5
        
        let camera = GMSCameraPosition.cameraWithLatitude(targetPostion!.latitude, longitude: targetPostion!.longitude, zoom: zoom)
        UIView.animateWithDuration(1) { 
            self.googleMap.camera = camera
            marker.map = self.googleMap
        }
        
        showConfirmation()
        
    }
    
    
    
    //Show confirmation of setting the location------------------------------------------------
    
    func showConfirmation() {
        if let targetPos = targetPostion {
            let myLocation = googleMap.myLocation
            let target = CLLocation(latitude: targetPos.latitude , longitude: targetPos.longitude)
            print(myLocation)
            print(target)
            let distance: CLLocationDistance = (myLocation?.distanceFromLocation(target))!
            if distance > 50 {
            
                let message = "You are now all set. I will buzz you when you are near your destination. Press the cancel button to cancel the ride."
                let alert = UIAlertController(title: "Location Set", message: message, preferredStyle: .Alert)
                let okAction = UIAlertAction(title: "Ok", style: .Default, handler: nil)
                alert.addAction(okAction)
                self.presentViewController(alert, animated: true, completion: nil)
            }
        }
    }
    
    //recent Searches--------------------------------------------------------------------------
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return savedArray.count
    }
    
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = recentSearchTableView.dequeueReusableCellWithIdentifier("recentCell", forIndexPath: indexPath) as! RecentSearchCell
        cell.address.text = savedArray[indexPath.row]
        return cell
        
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        UIView.animateWithDuration(0.5, animations: {
//            self.opaqueView.hidden = true
//            self.addButton.hidden = true
//            self.pinButton.hidden = true
//            self.pin.hidden = true
//            self.locationButton.hidden = true
//            self.backButton.hidden = false
//            self.recentButton.hidden = true
            self.recentSearchView.alpha = 0
            self.opaqueView.alpha = 0
            self.addButton.alpha = 0
            self.pinButton.alpha = 0
            self.pin.alpha = 0
            self.locationButton.alpha = 0
            self.backButton.alpha = 1
            self.recentButton.alpha = 0
            
        })
        
        targetPostion = CLLocationCoordinate2DMake(savedLocations[2*indexPath.row], savedLocations[2*indexPath.row + 1])
        let position = CLLocationCoordinate2DMake(targetPostion!.latitude, targetPostion!.longitude)
        let marker = GMSMarker(position: position)
        
        let myLocation = self.googleMap.myLocation
        let target = CLLocation(latitude: targetPostion!.latitude , longitude: targetPostion!.longitude)
        let distance: CLLocationDistance = (myLocation?.distanceFromLocation(target))!
        
        let fraction = 591657550.500000 / Float(distance)
        let zoom = log2(fraction) - 5
        
        let camera = GMSCameraPosition.cameraWithLatitude(targetPostion!.latitude, longitude: targetPostion!.longitude, zoom: zoom)
        UIView.animateWithDuration(1) {
            self.googleMap.camera = camera
            marker.map = self.googleMap
        }
        
        showConfirmation()
        
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        
        if editingStyle == .Delete {
            recentSearchTableView.beginUpdates()
            savedArray.removeAtIndex(indexPath.row)
            
            savedLocations.removeAtIndex(indexPath.row*2)
            savedLocations.removeAtIndex(indexPath.row*2)
            
            recentSearchTableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
            
            recentSearchTableView.endUpdates()
        }
        
    }
    
    @IBAction func recentBackPressed(sender: AnyObject) {
        UIView.animateWithDuration(0.5) {
            self.recentSearchView.alpha = 0
            //self.recentSearchView.hidden = true
        }
        
    }
    
    @IBAction func recentSearchesPressed(sender: AnyObject) {
        
        UIView.animateWithDuration(0.5) { 
            self.recentSearchView.alpha = 1
        }
        
        
//        let userDefaults = NSUserDefaults.standardUserDefaults()
//        if let tempArray = userDefaults.objectForKey("savedArray") as? [String] {
//            savedArray = tempArray
//            savedLocations = userDefaults.objectForKey("savedLocations") as! [Double]
//        } else {
//            print("no value set")
//        }
        
        recentSearchTableView.reloadData()
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
        if let target = targetPostion {
            let myLocation = googleMap.myLocation
            let target = CLLocation(latitude: target.latitude , longitude: target.longitude)
            let distance: CLLocationDistance = (myLocation?.distanceFromLocation(target))!
            print(distance)
            if distance < 50 && !notificationCreated {
                AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                player.play()
                createAlert()
                alarmSounding = true
            } else if distance > 50 {
                alarmSounding = false
            }
        }
    }
    
    func createAlert() {
        notificationCreated = true
        
        let alert = UIAlertController(title: "Destination Reached", message: "You are now arriving your location!", preferredStyle: .ActionSheet)
        
        let dismissAction = UIAlertAction(title: "Dismiss", style: .Destructive) { (UIAlertAction) in
            self.notificationCreated = false
            self.alarmSounding = false
            
            self.pinSearch = false
            self.googleMap.clear()
            targetPostion = nil
            player.stop()
            UIView.animateWithDuration(0.5, animations: {
//                self.opaqueView.hidden = false
//                self.addButton.hidden = false
//                self.pinButton.hidden = false
//                self.pin.hidden = true
//                self.backButton.hidden = true
//                self.recentButton.hidden = false
                
                self.opaqueView.alpha = 0.7
                self.addButton.alpha = 1
                self.pinButton.alpha = 1
                self.pin.alpha = 0
                self.locationButton.alpha = 0
                self.backButton.alpha = 0
                self.recentButton.alpha = 1
            })
            
            self.recentSearchTableView.reloadData()
            
            self.notificationCreated = false
        }
        
        alert.addAction(dismissAction)
        self.presentViewController(alert, animated: true, completion: nil)
    }
}

extension FirstViewController: GMSMapViewDelegate {
    func mapView(mapView: GMSMapView, idleAtCameraPosition position: GMSCameraPosition) {
        reverseGeocodeCoordinate(position.target)
    }
}
