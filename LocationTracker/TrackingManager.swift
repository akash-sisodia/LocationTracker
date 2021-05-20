//
//  TrackingManager.swift
//  LocationTracker
//
//  Created by Akash Singh Sisodia on 20/05/2021.
//
import Foundation
import INTULocationManager

class TrackingManager {
    
    static var shared: TrackingManager = {
        let instance = TrackingManager()
        return instance
    }()
    
    private let locationManager = INTULocationManager.sharedInstance()
    private var locationRequestID: INTULocationRequestID = 0
    private var backgroundLocationRequestID: INTULocationRequestID = 0
    private var headingRequestID: INTULocationRequestID = 0
    private var bgTask: UIBackgroundTaskIdentifier = .invalid
    private var bestFitLocation: CLLocation?
    private var lastSentLocation: CLLocation?
    private var currentHeading: CLLocationDirection = 0.0
    private var locationTimer: Timer?
    private var backgroundLocationTimer: Timer?
    private var backgroundAliveInterval: CFAbsoluteTime = 0
    private var significantLocationRequestID: INTULocationRequestID = 0
    
    var currentPosCallback: ((CLLocation, CLLocationDirection)->Void)?
    var updateLocationCallback: ((Bool, Data?, Error?)->Void)?
    var writeLogToFileCallback: ((CLLocation, CLLocationDistance)->Void)?
    var currentPOS =  CLLocationCoordinate2DMake(0.0, 0.0)
    var lastUpdatedTimeInterval =  0.0
    
    func startTrackingUserPosition() {
        
        // Cancel previously running location request
        if locationRequestID > 0 {
            locationManager.cancelLocationRequest(locationRequestID)
        }
        
        locationRequestID = locationManager.subscribeToLocationUpdates(withDesiredAccuracy: .house, block: { [unowned self] (currentLocation, achievedAccuracy, status) in
            if (status == .success) {
                if let location = currentLocation, location.isValid() {
                    self.bestFitLocation = location
                    print("Tracked location: Latitude: \(location.coordinate.latitude) Longitude: \(location.coordinate.longitude) Accuracy: \(location.horizontalAccuracy)")
                    self.currentPOS = location.coordinate
                    
                    if let callback = self.currentPosCallback {
                        callback(location, self.currentHeading)
                    }
                }
            } else if (status == .servicesDenied || status == .servicesDisabled) {
                print("Location permission denied")
                self.startTimer(false)
            }
        })
        
        NotificationCenter.default.addObserver(self, selector: #selector(initializeBackgroundTracking), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(dismissBackgroundTracking), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        startTimer(true)
        subscribeContinousHeadingUpdates()
    }
    
    func currentPosition() -> CLLocation? {
        if let bestFit = bestFitLocation {
            return bestFit
        } else if let lastSent = lastSentLocation {
            return lastSent
        }
        
        return nil
    }
    
    func resendLocationToRemote() {
        lastSentLocation = nil
        sendLocationToRemote()
    }
    
    func stop() {
        NotificationCenter.default.removeObserver(self)
        locationManager.cancelLocationRequest(locationRequestID)
        locationManager.cancelHeadingRequest(headingRequestID)
        startTimer(false)
        stopBackgroundTracking()
        flushCurrentBackgroundTask()
        flushBackgroundTimer()
        bestFitLocation = nil
        lastSentLocation = nil
        currentHeading = 0
        backgroundAliveInterval = 0
        locationRequestID = 0
        backgroundLocationRequestID = 0
        headingRequestID = 0
        stopSignificantLocationTracking()
        significantLocationRequestID = 0
    }
    
    //  MARK:- Private methods
    private func subscribeContinousHeadingUpdates() {
        // Check If heading updates already running
        guard headingRequestID == 0 else {
            return
        }
        
        headingRequestID = locationManager.subscribeToHeadingUpdates({ [unowned self] (heading, status) in
            if status == .success, let newHeading = heading, newHeading.headingAccuracy > 0 {
                self.currentHeading = newHeading.trueHeading > 0 ? newHeading.trueHeading : newHeading.magneticHeading
            } else {
                print("Error occured while updating heading")
            }
        })
    }
    
    private func startTimer(_ start: Bool) {
        if locationTimer != nil {
            locationTimer!.invalidate()
            locationTimer = nil
        }
        
        if start {
            locationTimer = Timer.scheduledTimer(timeInterval: TimeInterval(kLocationUpdateInterval), target: self, selector: #selector(sendLocationToRemoteViaTime), userInfo: nil, repeats: true)
        }
    }
    
    /// will check if 2 minutes have passed since last update 
    @objc private func sendLocationToRemoteViaTime() {
        
        if Date().timeIntervalSince1970 - lastUpdatedTimeInterval > 120.0  {
            resendLocationToRemote()
        }
    }
    
    @objc private func sendLocationToRemote() {
        guard let bestFit = bestFitLocation else {
            return
        }
        if let lastSent = lastSentLocation {
            let distanceInMeter = bestFit.distance(from: lastSent)
            if distanceInMeter < kDistanceFilter {
                return
            }
        }
        
        if let lastSent = lastSentLocation {
            print("updated location at distance: ", bestFit.distance(from: lastSent))
            writeLogToFileCallback?(bestFit, bestFit.distance(from: lastSent))
        }
        
        
        //Update Parameters as required
        let parameters: HTTPParameters = ["lat": bestFit.coordinate.latitude, "lng": bestFit.coordinate.longitude]
        
        NSSession.shared.requestWith(path: "location", method: .post, parameters: parameters, retryCount: 2) { (success, data, error) in
            
            self.lastSentLocation = bestFit
            self.updateLocationCallback?(success, data, error)
            self.lastUpdatedTimeInterval = Date().timeIntervalSince1970
        }
    }
    
    
    
    @objc private func initializeBackgroundTracking() {
        guard CLLocationManager.authorizationStatus() == .authorizedAlways else {
            return
        }
        
        startTimer(false)
        if locationRequestID > 0 {
            locationManager.cancelLocationRequest(locationRequestID)
        }
        
        backgroundAliveInterval = CFAbsoluteTimeGetCurrent()
        flushBackgroundTimer()
        startBackgroundTracking()
        startSignificantLocationTracking()
        
        
    }
    
    @objc private func dismissBackgroundTracking() {
        stopBackgroundTracking()
        backgroundAliveInterval = 0
        NotificationCenter.default.removeObserver(self)
        
        flushBackgroundTimer()
        flushCurrentBackgroundTask()
        
        stopSignificantLocationTracking()
        startTrackingUserPosition()
        
        TrackingManager.checkLocationAuthorization()
        
    }
    
    @objc private func startBackgroundTracking() {
        stopBackgroundTracking()
        var locationSent = false
        
        backgroundLocationRequestID = locationManager.subscribeToLocationUpdates(withDesiredAccuracy: .house, block: { [unowned self] (currentLocation, achievedAccuracy, status) in
            if (status == .success) {
                if let location = currentLocation, location.isValid() {
                    self.bestFitLocation = location
                    print("Background location: Latitude: \(location.coordinate.latitude) Longitude: \(location.coordinate.longitude) Accuracy: \(location.horizontalAccuracy)")
                    self.currentPOS = location.coordinate
                    
                    if let callback = self.currentPosCallback {
                        callback(location, self.currentHeading)
                    }
                    
                    if !locationSent {
                        locationSent = true
                        self.beginNewBackgroundTask()
                        self.sendLocationToRemote()
                    }
                }
            } else if (status == .servicesDenied || status == .servicesDisabled) {
                print("Location permission denied")
                self.stopBackgroundTracking()
                self.beginNewBackgroundTask()
            }
        })
    }
    
    private func stopBackgroundTracking() {
        if backgroundLocationRequestID > 0 {
            locationManager.cancelLocationRequest(backgroundLocationRequestID)
        }
    }
    
    private func flushCurrentBackgroundTask() {
        if bgTask != .invalid {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }
    }
    
    private func flushBackgroundTimer() {
        if backgroundLocationTimer != nil {
            backgroundLocationTimer!.invalidate()
            backgroundLocationTimer = nil
        }
    }
    
    private func beginNewBackgroundTask() -> Void {
        let state = UIApplication.shared.applicationState
        
        if (state == .background || state == .inactive) {
            var previousTask = bgTask
            
            bgTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
                print("Current task killed by system")
            })
            
            if previousTask != .invalid {
                UIApplication.shared.endBackgroundTask(previousTask)
                previousTask = .invalid
                print("Killing previous task")
            }
            
            flushBackgroundTimer()
            
            let elapsed = CFAbsoluteTimeGetCurrent() - backgroundAliveInterval
            let threshold = kBackgroundAliveInterval
            print("elapsed time in background (sec) - \(elapsed)")
            
            if threshold > 0, elapsed > threshold {
                print("forcefully killing background operations")
                flushCurrentBackgroundTask()
                stopBackgroundTracking()
                return
            }
            
            backgroundLocationTimer = Timer.scheduledTimer(timeInterval: TimeInterval(kLocationUpdateInterval), target: self, selector: #selector(startBackgroundTracking), userInfo: nil, repeats: false)
        }
    }
    
    class func checkLocationAuthorization() {
        let state = INTULocationManager.locationServicesState()
        if (state == .denied || state == .disabled || state == .restricted) {
            CLLocationManager.locationServicesDeniedAlert(message: "Turn on location services and let the app find your current location.")
        }
    }
    
    @objc func startSignificantLocationTracking() {
        stopSignificantLocationTracking()
        
        significantLocationRequestID = locationManager.subscribeToSignificantLocationChanges { [unowned self] (currentLocation, achievedAccuracy, status) in
            if (status == .success) {
                if let location = currentLocation, location.isValid() {
                    self.bestFitLocation = location
                    print("Tracked significant location: Latitude: \(location.coordinate.latitude) Longitude: \(location.coordinate.longitude) Accuracy: \(location.horizontalAccuracy)")
                    self.currentPOS = location.coordinate
                    
                    if let callback = self.currentPosCallback {
                        callback(location, self.currentHeading)
                    }
                }
            } else if (status == .servicesDenied || status == .servicesDisabled) {
                print("Location permission denied")
                self.stopSignificantLocationTracking()
            }
        }
    }
    
    private func stopSignificantLocationTracking() {
        if significantLocationRequestID > 0 {
            locationManager.cancelLocationRequest(significantLocationRequestID)
        }
    }
}

extension CLLocationManager {
    
    class func locationServicesDeniedAlert(message: String) {
        
        
        AlertView.show(message: message, isDismissOnly: false, dismissTitle: nil, cancelTitle: "Later", okTitle: "Turn On"){ (index) in
            guard index == 2 else { return }
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
        }
    }
}

extension CLLocation {
    
    func isValid() -> Bool {
        let locationAge = -timestamp.timeIntervalSinceNow
        return (horizontalAccuracy > 0 && locationAge < 5)
    }
}

extension UIViewController {
    func showAlertWith(message: String, cancelButtonCallback: (() -> Void)? = nil) {
        AlertView.show(message: message, isDismissOnly: true, dismissTitle: "OK", cancelTitle: nil, okTitle: nil){ (index) in
            guard index == 0 else { return }
            cancelButtonCallback?()
        }
    }
}
