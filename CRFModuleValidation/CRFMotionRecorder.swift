//
//  CRFMotionRecorder.swift
//  CRFModuleValidation
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
import CoreMotion
import ResearchSuite

public enum CRFMotionRecorderType : String, Codable {
    
    case accelerometer
    case attitude
    case gravity
    case gyro
    case magneticField
    case magnetometer
    case rotationRate
    case userAcceleration
    
    public static func allTypes() -> [CRFMotionRecorderType] {
        return [.accelerometer, .attitude, .gravity, .gyro, .magneticField, .magnetometer, .rotationRate, .userAcceleration]
    }
}

public struct CRFMotionRecorderConfiguration : RSDRecorderConfiguration, RSDAsyncActionControllerVendor, Codable {
    public let identifier: String
    
    public var startStepIdentifier: String?
    public var stopStepIdentifier: String?
    
    public var recorderTypes: [CRFMotionRecorderType] {
        return _recorderTypes ?? CRFMotionRecorderType.allTypes()
    }
    private let _recorderTypes: [CRFMotionRecorderType]?

    public let frequency: Double?
    
    public var requiresBackgroundAudio: Bool {
        return _requiresBackgroundAudio ?? false
    }
    private let _requiresBackgroundAudio: Bool?
    
    private enum CodingKeys : String, CodingKey {
        case identifier, _recorderTypes = "recorderTypes", startStepIdentifier, stopStepIdentifier, frequency, _requiresBackgroundAudio = "requiresBackgroundAudio"
    }
    
    public init(recorderType: CRFMotionRecorderType) {
        self.init(identifier: recorderType.rawValue, recorderTypes: [recorderType])
    }
    
    public init(identifier: String, recorderTypes: [CRFMotionRecorderType] = CRFMotionRecorderType.allTypes(), requiresBackgroundAudio: Bool = true, frequency: Double? = nil) {
        self.identifier = identifier
        self._recorderTypes = recorderTypes
        self._requiresBackgroundAudio = requiresBackgroundAudio
        self.frequency = frequency
    }
    
    public var permissions: [RSDPermissionType] {
        return [RSDStandardPermissionType.motion]
    }

    public func validate() throws {
        // TODO: syoung 11/16/2017 Decide if we want validation to include checking the plist for required privacy alerts
    }
    
    public func instantiateController(with taskPath: RSDTaskPath) -> RSDAsyncActionController? {
        return CRFMotionRecorder(configuration: self, taskPath: taskPath, outputDirectory: taskPath.outputDirectory)
    }
}

public enum CRFRecorderError : Error {
    case permissionDenied
    case notAvailable
}

public class CRFMotionRecorder : RSDSampleRecorder {
    
    public var coreMotionConfiguration: CRFMotionRecorderConfiguration? {
        return self.configuration as? CRFMotionRecorderConfiguration
    }
    
    lazy public var recorderTypes: [CRFMotionRecorderType] = {
        return self.coreMotionConfiguration?.recorderTypes ?? CRFMotionRecorderType.allTypes()
    }()
    
    private var motionManager: CMMotionManager?
    private var pedometer: CMPedometer?
    private let motionQueue = OperationQueue()
    
    override public func requestPermissions(on viewController: UIViewController, _ completion: @escaping RSDAsyncActionCompletionHandler) {
        pedometer = CMPedometer()
        let now = Date()
        pedometer!.queryPedometerData(from: now.addingTimeInterval(-2*60), to: now) { [weak self] (_, error) in
            guard let strongSelf = self else { return }
            if let err = error {
                debugPrint("Failed to query pedometer: \(err)")
            }
            let status: RSDAsyncActionStatus = (error == nil) ? .permissionGranted : .failed
            strongSelf.updateStatus(to: status, error: error)
            completion(strongSelf, nil, error)
            strongSelf.pedometer = nil
        }
    }
    
    override public func startRecorder(_ completion: @escaping ((RSDAsyncActionStatus, Error?) -> Void)) {
        guard self.motionManager == nil else {
            completion(.failed, RSDRecorderError.alreadyRunning)
            return
        }
        
        // Call completion before starting all the sensors
        // then add a block to the main queue to start the sensors
        // on the next run loop.
        completion(.running, nil)
        DispatchQueue.main.async { [weak self] in
            self?._startNextRunLoop()
        }
    }
    
    func _startNextRunLoop() {
        guard self.status <= .running else { return }
        
        // set up the motion manager and the frequency
        let frequency: Double = coreMotionConfiguration?.frequency ?? 100
        let updateInterval: TimeInterval = 1.0 / frequency
        let motionManager = CMMotionManager()
        self.motionManager = motionManager
        
        // start each sensor
        var deviceMotionStarted = false
        for motionType in recorderTypes {
            switch motionType {
            case .accelerometer:
                startAccelerometer(with: motionManager, updateInterval: updateInterval, completion: nil)
            case .gyro:
                startGyro(with: motionManager, updateInterval: updateInterval, completion: nil)
            case .magnetometer:
                startMagnetometer(with: motionManager, updateInterval: updateInterval, completion: nil)
            default:
                if !deviceMotionStarted {
                    deviceMotionStarted = true
                    startDeviceMotion(with: motionManager, updateInterval: updateInterval, completion: nil)
                }
            }
        }
    }
    
    func startAccelerometer(with motionManager: CMMotionManager, updateInterval: TimeInterval, completion: ((Error?) -> Void)?) {
        motionManager.stopAccelerometerUpdates()
        motionManager.accelerometerUpdateInterval = updateInterval
        motionManager.startAccelerometerUpdates(to: motionQueue) { [weak self] (data, error) in
            if data != nil, self?.status == .running {
                self?.recordRawSample(data!)
            } else if error != nil, self?.status != .failed {
                self?.didFail(with: error!)
            }
            completion?(error)
        }
    }
    
    func startGyro(with motionManager: CMMotionManager, updateInterval: TimeInterval, completion: ((Error?) -> Void)?) {
        motionManager.stopGyroUpdates()
        motionManager.gyroUpdateInterval = updateInterval
        motionManager.startGyroUpdates(to: motionQueue) { [weak self] (data, error) in
            if data != nil, self?.status == .running {
                self?.recordRawSample(data!)
            } else if error != nil, self?.status != .failed {
                self?.didFail(with: error!)
            }
            completion?(error)
        }
    }
    
    func startMagnetometer(with motionManager: CMMotionManager, updateInterval: TimeInterval, completion: ((Error?) -> Void)?) {
        motionManager.stopMagnetometerUpdates()
        motionManager.magnetometerUpdateInterval = updateInterval
        motionManager.startMagnetometerUpdates(to: motionQueue) { [weak self] (data, error) in
            if data != nil, self?.status == .running {
                self?.recordRawSample(data!)
            } else if error != nil, self?.status != .failed {
                self?.didFail(with: error!)
            }
            completion?(error)
        }
    }
    
    func recordRawSample(_ data: CMLogItem) {
        let sample = CRFMotionRecord(startUptime: startUptime, stepPath: currentStepPath, data: data)
        self.writeSample(sample)
    }
    
    func startDeviceMotion(with motionManager: CMMotionManager, updateInterval: TimeInterval, completion: ((Error?) -> Void)?) {
        motionManager.stopDeviceMotionUpdates()
        motionManager.deviceMotionUpdateInterval = updateInterval
        let frame: CMAttitudeReferenceFrame = recorderTypes.contains(.magneticField) ? .xMagneticNorthZVertical : .xArbitraryZVertical
        motionManager.startDeviceMotionUpdates(using: frame, to: motionQueue) { [weak self] (data, error) in
            if data != nil, self?.status == .running {
                self?.recordDeviceMotionSample(data!)
            } else if error != nil, self?.status != .failed {
                self?.didFail(with: error!)
            }
            completion?(error)
        }
    }
    
    func recordDeviceMotionSample(_ data: CMDeviceMotion) {
        let frame = motionManager?.attitudeReferenceFrame ?? CMAttitudeReferenceFrame.xArbitraryZVertical
        let samples = recorderTypes.rsd_mapAndFilter {
            CRFMotionRecord(startUptime: startUptime, stepPath: currentStepPath, data: data, referenceFrame: frame, sensorType: $0) }
        self.writeSamples(samples)
    }
    
    override public func stopRecorder(_ completion: @escaping ((RSDAsyncActionStatus) -> Void)) {
        
        // Call completion immediately with a "stopping" status.
        completion(.stopping)
        
        DispatchQueue.main.async {
            
            // Stop the updates synchronously
            if let motionManager = self.motionManager {
                for motionType in self.recorderTypes {
                    switch motionType {
                    case .accelerometer:
                        motionManager.stopAccelerometerUpdates()
                    default:
                        motionManager.stopDeviceMotionUpdates()
                    }
                }
            }
            self.motionManager = nil
            
            // and then call finished.
            self.updateStatus(to: .finished, error: nil)
        }
    }
}

public enum CRFAttitudeReferenceFrame : String, Codable {
    
    case xArbitraryZVertical = "Z-Up"
    case xMagneticNorthZVertical = "North-West-Up"
    
    init(frame : CMAttitudeReferenceFrame) {
        switch frame {
        case .xMagneticNorthZVertical:
            self = .xMagneticNorthZVertical
        default:
            self = .xArbitraryZVertical
        }
    }
}

public struct CRFMotionRecord : RSDSampleRecord {
    
    public let uptime: TimeInterval
    public let timestamp: TimeInterval?
    public let stepPath: String
    public let timestampDate: Date?
    
    public let sensorType: CRFMotionRecorderType?
    public let eventAccuracy: Int?
    public let referenceCoordinate: CRFAttitudeReferenceFrame?
    public let heading: Double?
    
    public let x: Double?
    public let y: Double?
    public let z: Double?
    public let w: Double?
    
    public init?(startUptime: TimeInterval, stepPath: String, data: CMDeviceMotion, referenceFrame: CMAttitudeReferenceFrame, sensorType: CRFMotionRecorderType) {

        var eventAccuracy: Int?
        var referenceCoordinate: CRFAttitudeReferenceFrame?
        var w: Double?
        
        switch sensorType {
        case .attitude:
            self.x = data.attitude.quaternion.x
            self.y = data.attitude.quaternion.y
            self.z = data.attitude.quaternion.z
            w = data.attitude.quaternion.w
            referenceCoordinate = CRFAttitudeReferenceFrame(frame: referenceFrame)
            
        case .gravity:
            self.x = data.gravity.x
            self.y = data.gravity.y
            self.z = data.gravity.z
            
        case .magneticField:
            self.x = data.magneticField.field.x
            self.y = data.magneticField.field.y
            self.z = data.magneticField.field.z
            eventAccuracy = Int(data.magneticField.accuracy.rawValue)
            
        case .rotationRate:
            self.x = data.rotationRate.x
            self.y = data.rotationRate.y
            self.z = data.rotationRate.z
            
        case .userAcceleration:
            self.x = data.userAcceleration.x
            self.y = data.userAcceleration.y
            self.z = data.userAcceleration.z
            
        default:
            return nil
        }

        self.uptime = data.timestamp
        self.timestamp = data.timestamp - startUptime
        self.stepPath = stepPath
        self.timestampDate = nil
        self.sensorType = sensorType
        self.heading = (data.heading >= 0) ? data.heading : nil
        self.w = w
        self.eventAccuracy = eventAccuracy
        self.referenceCoordinate = referenceCoordinate
    }
    
    public init(startUptime: TimeInterval, stepPath: String, data: CMLogItem) {
        
        if let accel = data as? CMAccelerometerData {
            self.sensorType = .accelerometer
            self.x = accel.acceleration.x
            self.y = accel.acceleration.y
            self.z = accel.acceleration.z
        }
        else if let gyro = data as? CMGyroData {
            self.sensorType = .gyro
            self.x = gyro.rotationRate.x
            self.y = gyro.rotationRate.y
            self.z = gyro.rotationRate.z
        }
        else if let mag = data as? CMMagnetometerData {
            self.sensorType = .magnetometer
            self.x = mag.magneticField.x
            self.y = mag.magneticField.y
            self.z = mag.magneticField.z
        }
        else {
            self.sensorType = nil
            self.x = nil
            self.y = nil
            self.z = nil
        }
        
        self.uptime = data.timestamp
        self.timestamp = data.timestamp - startUptime
        self.stepPath = stepPath
        self.timestampDate = nil
        self.heading = nil
        self.w = nil
        self.eventAccuracy = nil
        self.referenceCoordinate = nil
    }
}
