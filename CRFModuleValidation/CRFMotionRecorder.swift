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
    case deviceMotion
    
    public static func allTypes() -> [CRFMotionRecorderType] {
        return [.accelerometer, .deviceMotion]
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

        let frequency: Double = coreMotionConfiguration?.frequency ?? 100
        let updateInterval: TimeInterval = 1.0 / frequency
        let motionManager = CMMotionManager()
        self.motionManager = motionManager
        
        // Only use the callback on *one* of the motion types that is being started
        for motionType in recorderTypes {
            switch motionType {
            case .accelerometer:
                startAccelerometer(with: motionManager, updateInterval: updateInterval, completion: nil)
            case .deviceMotion:
                startDeviceMotion(with: motionManager, updateInterval: updateInterval, completion: nil)
            }
        }
        
        completion(.running, nil)
    }
    
    func startAccelerometer(with motionManager: CMMotionManager, updateInterval: TimeInterval, completion: ((Error?) -> Void)?) {
        motionManager.stopAccelerometerUpdates()
        motionManager.accelerometerUpdateInterval = updateInterval
        motionManager.startAccelerometerUpdates(to: OperationQueue()) { [weak self] (data, error) in
            if data != nil, self?.status == .running {
                self?.recordAccelerometerSample(data!)
            } else if error != nil, self?.status != .failed {
                self?.didFail(with: error!)
            }
            completion?(error)
        }
    }
    
    func recordAccelerometerSample(_ data: CMAccelerometerData) {
        let sample = CRFAccelerometerRecord(startUptime: startUptime, stepPath: currentStepPath, data: data)
        self.writeSample(sample)
    }
    
    func startDeviceMotion(with motionManager: CMMotionManager, updateInterval: TimeInterval, completion: ((Error?) -> Void)?) {
        motionManager.stopDeviceMotionUpdates()
        motionManager.deviceMotionUpdateInterval = updateInterval
        motionManager.startDeviceMotionUpdates(to: OperationQueue()) { [weak self] (data, error) in
            if data != nil, self?.status == .running {
                self?.recordDeviceMotionSample(data!)
            } else if error != nil, self?.status != .failed {
                self?.didFail(with: error!)
            }
            completion?(error)
        }
    }
    
    func recordDeviceMotionSample(_ data: CMDeviceMotion) {
        let sample = CRFDeviceMotionRecord(startUptime: startUptime, stepPath: currentStepPath, data: data)
        self.writeSample(sample)
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
                    case .deviceMotion:
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

/// `CRFAccelerometerRecord` is intended to be used for recording raw accelerometer data.
public struct CRFAccelerometerRecord: RSDSampleRecord {
    
    public let uptime: TimeInterval
    public let timestamp: TimeInterval?
    public let stepPath: String
    public let timestampDate: Date?
    public let sensorType: CRFMotionRecorderType
    
    public let x: Double?
    public let y: Double?
    public let z: Double?
    
    public init(startUptime: TimeInterval, stepPath: String, data: CMAccelerometerData) {
        self.uptime = data.timestamp
        self.timestamp = data.timestamp - startUptime
        self.stepPath = stepPath
        self.timestampDate = nil
        self.sensorType = CRFMotionRecorderType.accelerometer
        self.x = data.acceleration.x
        self.y = data.acceleration.y
        self.z = data.acceleration.z
    }
}

/// `CRFDeviceMotionRecord` is intended to be used for recording processed device motion data.
public struct CRFDeviceMotionRecord: RSDSampleRecord {
    
    public let uptime: TimeInterval
    public let timestamp: TimeInterval?
    public let stepPath: String
    public let timestampDate: Date?
    public let sensorType: CRFMotionRecorderType
    
    public let attitude_x: Double?
    public let attitude_y: Double?
    public let attitude_z: Double?
    public let attitude_w: Double?
    public let rotationRate_x: Double?
    public let rotationRate_y: Double?
    public let rotationRate_z: Double?
    public let gravity_x: Double?
    public let gravity_y: Double?
    public let gravity_z: Double?
    public let userAcceleration_x: Double?
    public let userAcceleration_y: Double?
    public let userAcceleration_z: Double?
    public let magneticField_x: Double?
    public let magneticField_y: Double?
    public let magneticField_z: Double?
    public let magneticField_accuracy: Int?
    public let heading: Double?
    
    public init(startUptime: TimeInterval, stepPath: String, data: CMDeviceMotion) {
        self.uptime = data.timestamp
        self.timestamp = data.timestamp - startUptime
        self.stepPath = stepPath
        self.timestampDate = nil
        self.sensorType = CRFMotionRecorderType.deviceMotion

        self.attitude_x = data.attitude.quaternion.x
        self.attitude_y = data.attitude.quaternion.y
        self.attitude_z = data.attitude.quaternion.z
        self.attitude_w = data.attitude.quaternion.w
        self.rotationRate_x = data.rotationRate.x
        self.rotationRate_y = data.rotationRate.y
        self.rotationRate_z = data.rotationRate.z
        self.gravity_x = data.gravity.x
        self.gravity_y = data.gravity.y
        self.gravity_z = data.gravity.z
        self.userAcceleration_x = data.userAcceleration.x
        self.userAcceleration_y = data.userAcceleration.y
        self.userAcceleration_z = data.userAcceleration.z
        self.magneticField_x = data.magneticField.field.x
        self.magneticField_y = data.magneticField.field.y
        self.magneticField_z = data.magneticField.field.z
        self.magneticField_accuracy = Int(data.magneticField.accuracy.rawValue)
        self.heading = data.heading
    }
}
