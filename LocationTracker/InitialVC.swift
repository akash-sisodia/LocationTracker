//
//  InitialVC.swift
//  LocationTracker
//
//  Created by Akash Singh Sisodia on 20/05/2021.
//

import UIKit

class InitialVC: UIViewController {
    
    @IBOutlet weak var informationTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initialSetup()
    }
    
    private func log(title: String, message: String) {
        
         self.informationTextView.text =  (self.informationTextView.text ?? "") + "\n \(title): " + message
    }
    
    /// viewInitialSetup
    private func initialSetup() {
        
        TrackingManager.checkLocationAuthorization()
        configureForUploadResponse()
        configureForLocalPersistance()
        configureForCurrentPosition()
    }
    
    /// You will get backend upload result here
    private func configureForUploadResponse() {
        
        TrackingManager.shared.updateLocationCallback = { [weak self] (success, data, error) in
            guard let weakSelf = self else {
                return
            }
            
            guard success, error == nil else {
                if let message = error?.localizedDescription {
                    weakSelf.log(title: "Response Error", message: message)
                } else {
                    weakSelf.log(title: "Response Error", message: "Not Determined")
                }
                return
            }
            
            weakSelf.log(title: "Response", message: data?.deserialize()?.description ?? "")
        }
    }
    
    /// You can write location to local persistance
    private func configureForLocalPersistance() {
        
        TrackingManager.shared.writeLogToFileCallback =  { [weak self] (position, heading) in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.log(title: "Local Persistence", message: "position \(position), heading \(heading)")
        }
    }
    
    /// You will get current location here
    private func configureForCurrentPosition() {
        
        TrackingManager.shared.currentPosCallback = { location, direction in
            self.log(title: "Tracked location", message: "Latitude: \(location.coordinate.latitude) Longitude: \(location.coordinate.longitude) Accuracy: \(location.horizontalAccuracy)")
        }
    }
    
    @IBAction func startUpdating(_ sender: Any) {
        self.informationTextView.text =  "Started...."
        TrackingManager.shared.startTrackingUserPosition()
    }
    
    @IBAction func stopUpdating(_ sender: Any) {
        self.informationTextView.text =  (self.informationTextView.text ?? "") + "\n Stopped...."
        TrackingManager.shared.stop()
    }
}
