//
//  Constants.swift
//  LocationTracker
//
//  Created by Akash Singh Sisodia on 21/05/2021.
//

import Foundation

/// Configure your base url for application
let BaseURL = "https://api.locus.sh/v1//client/test/user/candidate/"

/// username for basic auth
let username = "test/candidate"

/// password for basic auth
let password = "c00e-4764"

/// background termination interuption
/// to keep app alive in bacground mode.
let kBackgroundAliveInterval = 120.0

/// nedd to update location to server passed 2 mins.
let kLocationUpdateInterval = 120.0

/// nedd to update location to server passed 100 meters.
let kDistanceFilter = 100.0



