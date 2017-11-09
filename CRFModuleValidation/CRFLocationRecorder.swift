//
//  CRFLocationRecorder.swift
//  ResearchSuiteUI
//
//  Copyright © 2017 Sage Bionetworks. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// 1.  Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// 2.  Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation and/or
// other materials provided with the distribution.
//
// 3.  Neither the name of the copyright holder(s) nor the names of any contributors
// may be used to endorse or promote products derived from this software without
// specific prior written permission. No license is granted to the trademarks of
// the copyright holders even if such marks are included in this software.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import Foundation
import CoreLocation
import CoreMotion
import ResearchSuite

public struct CRFLocationRecorderConfiguration : RSDRecorderConfiguration, RSDAsyncActionControllerVendor, Codable {
    public let identifier: String
    public let startStepIdentifier: String?
    public let stopStepIdentifier: String?
    
    /**
     Optional identifier for the step that records distance travelled. If non-nil then the recorder will use this step to record distance travelled while the other steps are assumed to be standing still.
     */
    public let motionStepIdentifier: String?
    
    public init(identifier: String, startStepIdentifier: String?, stopStepIdentifier: String?, motionStepIdentifier: String?) {
        self.identifier = identifier
        self.startStepIdentifier = startStepIdentifier
        self.stopStepIdentifier = stopStepIdentifier
        self.motionStepIdentifier = motionStepIdentifier
    }
    
    public var permissions: [RSDPermissionType] {
        return [RSDStandardPermissionType.location]
    }
    
    public var requiresBackgroundAudio: Bool {
        return true
    }
    
    public func validate() throws {
        try RSDStandardPermissionType.location.validate()
    }
    
    public func instantiateController(with taskPath: RSDTaskPath) -> RSDAsyncActionController? {
        return CRFLocationRecorder(configuration: self, outputDirectory: taskPath.outputDirectory)
    }
}

public struct CRFLocationRecord: RSDSampleRecord {

    public let uptime: TimeInterval
    public let timestamp: TimeInterval
    public let stepPath: String
    public let date: Date?
    
    public let horizontalAccuracy: Double?
    public let relativeDistance: Double?
    public let latitude: Double?
    public let longitude: Double?
    
    public let verticalAccuracy: Double?
    public let altitude: Double?
    
    public let totalDistance: Double?
    public let course: Double?
    public let speed: Double?
  
    public init(uptime: TimeInterval, timestamp: TimeInterval, stepPath: String, location: CLLocation, previousLocation: CLLocation?, totalDistance: Double?, relativeDistanceOnly: Bool) {
        self.uptime = uptime
        self.timestamp = timestamp
        self.stepPath = stepPath
        self.totalDistance = totalDistance
        self.date = location.timestamp
        self.speed = location.speed >= 0 ? location.speed : nil
        self.course = location.course >= 0 ? location.course : nil
        
        // Record the horizontal accuracy and relative distance
        if location.horizontalAccuracy >= 0 {
            self.horizontalAccuracy = location.horizontalAccuracy
            if let previous = previousLocation, previous.horizontalAccuracy >= 0 {
                self.relativeDistance = location.distance(from: previous)
            } else {
                self.relativeDistance = nil
            }
            if relativeDistanceOnly {
                self.latitude = nil
                self.longitude = nil
            } else {
                self.latitude = location.coordinate.latitude
                self.longitude = location.coordinate.longitude
            }
        } else {
            self.horizontalAccuracy = nil
            self.relativeDistance = nil
            self.latitude = nil
            self.longitude = nil
        }
        
        // Record the vertical accuracy
        if location.verticalAccuracy >= 0 {
            self.verticalAccuracy = location.verticalAccuracy
            self.altitude = location.altitude
        } else {
            self.verticalAccuracy = nil
            self.altitude = nil
        }
    }
}

/**
 `CRFLocationRecorder` is intended to be used for recording location where the participant is walking, running, cycling, or other activities where the distance traveled is of interest. It should be setup to run in the background which requires setting the capabilities in your app to include background mode. Additionally, you will need to add the private permission for getting location always to the info.plist file and you will need to link the CoreLocation framework.
 */
public class CRFLocationRecorder : RSDSampleRecorder, CLLocationManagerDelegate {
    
    public enum CRFLocationRecorderError : Error {
        case permissionDenied(CLAuthorizationStatus)
    }
    
    public enum CRFResultIdentifier : String, CodingKey {
        case stepCount, pedometerDistance, gpsDistance
    }
    
    /**
     Convenience property for getting the location configuration.
     */
    public var locationConfiguration: CRFLocationRecorderConfiguration? {
        return self.configuration as? CRFLocationRecorderConfiguration
    }
    
    /**
     Should relative distance only be saved to the log. Default = `true`.
     */
    public var relativeDistanceOnly: Bool = true
    
    /**
     Whether or not the user is expected to be standing still or moving. This is used to mark when to start calculating distance traveled while moving as a part of a larger overrall data gathering effort that might include how much a person is moving in order to get into position.
     */
    public var isStandingStill: Bool = false {
        didSet {
            if !isStandingStill {
                totalDistance = 0.0
                startTotalDistance = Date()
                endTotalDistance = Date.distantFuture
            } else if endTotalDistance == Date.distantFuture {
                endTotalDistance = Date()
            }
        }
    }
    
    /**
     Total distance (measured in meters) from the start of recording.
     */
    @objc dynamic public private(set) var totalDistance: Double = 0.0
    
    /**
     Most recent location recorded.
     */
    public private(set) var mostRecentLocation: CLLocation?
    
    private var startTotalDistance = Date()
    private var endTotalDistance = Date.distantFuture
    private var locationManager: CLLocationManager?
    private let processingQueue = DispatchQueue(label: "org.sagebase.ResearchSuite.location.processing")
    
    override public func startRecorder(_ completion: RSDAsyncActionCompletionHandler?) {
        DispatchQueue.main.async {
            do {
                try self._startLocationManager()
                super.startRecorder(completion)
            } catch let err {
                completion?(self, nil, err)
            }
        }
    }
    
    private func _startLocationManager() throws {
        guard self.locationManager == nil else { return }
        
        let status = CLLocationManager.authorizationStatus()
        if status == .denied || status == .restricted {
            throw CRFLocationRecorderError.permissionDenied(status)
        }
        
        if let motionStepId = self.locationConfiguration?.motionStepIdentifier {
            self.isStandingStill = (self.currentStepIdentifier != motionStepId)
        }
        
        let manager = CLLocationManager()
        manager.delegate = self
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        self.locationManager = manager
        
        if status == .authorizedAlways {
            manager.startUpdatingLocation()
        } else {
            manager.requestAlwaysAuthorization()
        }
    }
    
    override public func stopRecorder(loggerError: Error?, _ completion: RSDAsyncActionCompletionHandler?) {
        DispatchQueue.main.async {
            self.locationManager?.stopUpdatingLocation()
            self.locationManager?.delegate = nil
            self.locationManager = nil
            
            super.stopRecorder(loggerError: loggerError, completion)
        }
    }
    
    override public func pause() {
        if !self.isPaused && self.isRunning {
            self.locationManager?.stopUpdatingLocation()
        }
        super.pause()
    }
    
    override public func resume() {
        if self.isPaused && self.isRunning {
            self.locationManager?.startUpdatingLocation()
        }
        super.resume()
    }
    
    override public func moveTo(step: RSDStep, taskPath: RSDTaskPath) {
        
        // Call super. This will update the step path and add a step change marker.
        super.moveTo(step: step, taskPath: taskPath)
        
        // Look to see if the configuration has a motion step and update state accordingly.
        if let motionStepId = self.locationConfiguration?.motionStepIdentifier {
            let newState = (step.identifier != motionStepId)
            if newState != isStandingStill {
                isStandingStill = newState
                if isStandingStill {
                    // If changed from moving to standing still then add the pedometer data
                    _addPedometerData()
                }
            }
        }
    }
    
    // MARK: CLLocationManagerDelegate
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.didFail(with: error)
    }
    
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways {
            self.locationManager = manager
            manager.startUpdatingLocation()
        } else {
            self.didFail(with: CRFLocationRecorderError.permissionDenied(status))
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard locations.count > 0 else { return }
        
        self.processingQueue.async {
            
            let samples = locations.map { (location) ->CRFLocationRecord in
            
                // Calculate time interval since start time
                let timeInterval = location.timestamp.timeIntervalSince(self.startDate)
                let uptime = self.startUptime + timeInterval

                // Update the total distance
                let distance = self._updateTotalDistance(location)
                
                // Create the sample
                let sample = CRFLocationRecord(uptime: uptime, timestamp: timeInterval, stepPath: self.currentStepPath, location: location, previousLocation: self.mostRecentLocation, totalDistance: distance, relativeDistanceOnly: self.relativeDistanceOnly)
                
                // If this is a valid location then store as the previous location
                self._updateMostRecent(location, timeInterval: timeInterval)
                
                return sample
            }
            
            self.writeSamples(samples)
        }
    }
    
    // MARK: Data management
    
    private var _stepStartLocation : CLLocation?
    private var _lastAccurateLocation : CLLocation?
    private var _recentLocations : [CLLocation] = []
    private let kLocationRequiredAccuracy : CLLocationAccuracy = 20.0
    
    public func isOutdoors() -> Bool {
        var isOutdoors = false
        self.processingQueue.sync {
            if _recentLocations.count > 0 {
                let sorted = _recentLocations.sorted(by: { $0.horizontalAccuracy < $1.horizontalAccuracy })
                let median = sorted[Int(sorted.count / 2)]
                isOutdoors = median.horizontalAccuracy <= kLocationRequiredAccuracy
            }
        }
        return isOutdoors
    }
    
    private func _addPedometerData() {
        // Get the results of the pedometer for the time when in motion.
        let pedometer = CMPedometer()
        pedometer.queryPedometerData(from: startTotalDistance, to: endTotalDistance) { [weak self] (data, _) in
            guard let pedometerData = data else { return }
            self?._recordPedometerData(pedometerData)
        }
    }
    
    private func _recordPedometerData(_ data: CMPedometerData) {
        
        var stepCountResult = RSDAnswerResultObject(identifier: CRFResultIdentifier.stepCount.stringValue, answerType: RSDAnswerResultType(baseType: .decimal))
        stepCountResult.value = data.numberOfSteps
        self.appendResults(stepCountResult)
        
        var pedometerDistanceResult = RSDAnswerResultObject(identifier: CRFResultIdentifier.pedometerDistance.stringValue, answerType: RSDAnswerResultType(baseType: .decimal))
        pedometerDistanceResult.value = data.distance
        self.appendResults(pedometerDistanceResult)
        
        var gpsDistanceResult = RSDAnswerResultObject(identifier: CRFResultIdentifier.gpsDistance.stringValue, answerType: RSDAnswerResultType(baseType: .decimal))
        gpsDistanceResult.value = totalDistance
        self.appendResults(gpsDistanceResult)
    }
    
    private func _updateTotalDistance(_ location: CLLocation) -> Double? {

        let timestamp = location.timestamp
        guard timestamp >= self.startDate.addingTimeInterval(-60)
            else {
                return nil
        }

        // Determine if this location is accurat enough to use in calculations
        let isOutdoors = location.horizontalAccuracy > 0 && location.horizontalAccuracy <= kLocationRequiredAccuracy
        var distance: Double?
        
        if let lastLocation = _lastAccurateLocation, timestamp >= self.startTotalDistance, timestamp <= self.endTotalDistance {
            if isSimulator {
                // If running in the simulator then have the simulator run a 12 minute mile.
                totalDistance += timestamp.timeIntervalSince(lastLocation.timestamp) * 2.2352
            } else if isOutdoors {
                // If the time is after the start time, then add the distance traveled to the total distance.
                // This is a rough measurement and does not (at this time) include any spline drawing to measure the
                // actual curve of the distance traveled. It also does not check for bearing to see if the user
                // is actually standing still.
                totalDistance += lastLocation.distance(from: location)
            } else {
                // If the user is indoors then don't calculate a change in distance, but still
                // update any KVO observers.
                totalDistance += 0
            }
            distance = totalDistance
        } 
        
        // Save the previous location as the last accurate location
        if isOutdoors || isSimulator {
            _lastAccurateLocation = location
            if _stepStartLocation == nil {
                _stepStartLocation = _lastAccurateLocation
            }
        }
        
        return distance
    }

    private func _updateMostRecent(_ location: CLLocation, timeInterval: TimeInterval) {
        // If this is a valid location then store as the previous location
        guard location.horizontalAccuracy >= 0 else { return }
        mostRecentLocation = location
        if (timeInterval > 0) {
            _recentLocations.append(location)
            if _recentLocations.count > 5 {
                _recentLocations.remove(at: 0)
            }
        }
    }
}

