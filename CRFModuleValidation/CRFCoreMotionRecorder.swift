//
//  CRFCoreMotionRecorder.swift
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

public enum CRFCoreMotionRecorderType : String, Codable {
    case accelerometer
    case deviceMotion
}

public struct CRFCoreMotionRecorderConfiguration : RSDRecorderConfiguration, RSDAsyncActionControllerVendor, Codable {
    public let identifier: String
    public let recorderType: CRFCoreMotionRecorderType
    public let startStepIdentifier: String?
    public let stopStepIdentifier: String?
    public let requiresBackgroundAudio: Bool
    public let frequency: Double?
    
    public init(recorderType: CRFCoreMotionRecorderType) {
        self.init(identifier: recorderType.rawValue, recorderType: recorderType)
    }
    
    public init(identifier: String, recorderType: CRFCoreMotionRecorderType, startStepIdentifier: String? = nil, stopStepIdentifier: String? = nil, requiresBackgroundAudio: Bool = true, frequency: Double? = nil) {
        self.identifier = identifier
        self.recorderType = recorderType
        self.startStepIdentifier = startStepIdentifier
        self.stopStepIdentifier = stopStepIdentifier
        self.requiresBackgroundAudio = requiresBackgroundAudio
        self.frequency = frequency
    }
    
    public var permissions: [RSDPermissionType] {
        return [RSDStandardPermissionType.coremotion]
    }

    public func validate() throws {
        try RSDStandardPermissionType.coremotion.validate()
    }
    
    public func instantiateController(with taskPath: RSDTaskPath) -> RSDAsyncActionController? {
        switch recorderType {
        case .accelerometer:
            return CRFAccelerometerRecorder(configuration: self, outputDirectory: taskPath.outputDirectory)
        case .deviceMotion:
            return CRFDeviceMotionRecorder(configuration: self, outputDirectory: taskPath.outputDirectory)
        }
    }
}

public enum CRFRecorderError : Error {
    case permissionDenied
    case notAvailable
}

/**
 `CRFAccelerometerRecord` is intended to be used for recording raw accelerometer data.
 */
public struct CRFAccelerometerRecord: RSDSampleRecord {
    
    public let uptime: TimeInterval
    public let timestamp: TimeInterval
    public let stepPath: String
    public let date: Date?
    
    public let x: Double?
    public let y: Double?
    public let z: Double?
    
    public init(startUptime: TimeInterval, stepPath: String, data: CMAccelerometerData) {
        self.uptime = data.timestamp
        self.timestamp = data.timestamp - startUptime
        self.stepPath = stepPath
        self.date = nil
        self.x = data.acceleration.x
        self.y = data.acceleration.y
        self.z = data.acceleration.z
    }
}

public class CRFAccelerometerRecorder : RSDSampleRecorder {
    
    public var coreMotionConfiguration: CRFCoreMotionRecorderConfiguration? {
        return self.configuration as? CRFCoreMotionRecorderConfiguration
    }
    
    private let processingQueue = DispatchQueue(label: "org.sagebase.ResearchSuite.accelerometer.processing")
    private let motionManager = CMMotionManager()
    
    override public var isRunning: Bool {
        return super.isRunning && motionManager.isAccelerometerActive
    }
    
    override public func startRecorder(_ completion: RSDAsyncActionCompletionHandler?) {
        DispatchQueue.main.async {
            do {
                try self._startMotionManager()
                super.startRecorder(completion)
            } catch let err {
                completion?(self, nil, err)
            }
        }
    }
    
    private func _startMotionManager() throws {
        guard motionManager.isAccelerometerAvailable else {
            throw CRFRecorderError.notAvailable
        }
        
        self.motionManager.stopAccelerometerUpdates()
        
        let frequency: Double = coreMotionConfiguration?.frequency ?? 100
        self.motionManager.accelerometerUpdateInterval = 1.0 / frequency
        
        self.motionManager.startAccelerometerUpdates(to: OperationQueue()) { [weak self] (data, error) in
            if data != nil {
                self?.recordSample(data!)
            } else if error != nil {
                self?.didFail(with: error!)
            }
        }
    }
    
    func recordSample(_ data: CMAccelerometerData) {
        let sample = CRFAccelerometerRecord(startUptime: startUptime, stepPath: currentStepPath, data: data)
        self.writeSample(sample)
    }
    
    override public func stopRecorder(loggerError: Error?, _ completion: RSDAsyncActionCompletionHandler?) {
        DispatchQueue.main.async {
            self.motionManager.stopAccelerometerUpdates()
            super.stopRecorder(loggerError: loggerError, completion)
        }
    }
}

/**
 `CRFDeviceMotionRecord` is intended to be used for recording processed device motion data.
 */
public struct CRFDeviceMotionRecord: RSDSampleRecord {
    
    public let uptime: TimeInterval
    public let timestamp: TimeInterval
    public let stepPath: String
    public let date: Date?
    
    public let attitude_pitch: Double?
    public let attitude_roll: Double?
    public let attitude_yaw: Double?
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
        self.date = nil
        self.attitude_pitch = data.attitude.pitch
        self.attitude_roll = data.attitude.roll
        self.attitude_yaw = data.attitude.yaw
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

public class CRFDeviceMotionRecorder : RSDSampleRecorder {
    
    public var coreMotionConfiguration: CRFCoreMotionRecorderConfiguration? {
        return self.configuration as? CRFCoreMotionRecorderConfiguration
    }
    
    private let processingQueue = DispatchQueue(label: "org.sagebase.ResearchSuite.deviceMotion.processing")
    private let motionManager = CMMotionManager()
    
    override public var isRunning: Bool {
        return super.isRunning && motionManager.isDeviceMotionActive
    }
    
    override public func startRecorder(_ completion: RSDAsyncActionCompletionHandler?) {
        DispatchQueue.main.async {
            do {
                try self._startMotionManager()
                super.startRecorder(completion)
            } catch let err {
                completion?(self, nil, err)
            }
        }
    }
    
    private func _startMotionManager() throws {
        guard motionManager.isDeviceMotionAvailable else {
            throw CRFRecorderError.notAvailable
        }
        
        self.motionManager.stopDeviceMotionUpdates()
        
        let frequency: Double = coreMotionConfiguration?.frequency ?? 100
        self.motionManager.deviceMotionUpdateInterval = 1.0 / frequency
        
        self.motionManager.startDeviceMotionUpdates(to: OperationQueue()) { [weak self] (data, error) in
            if data != nil {
                self?.recordSample(data!)
            } else if error != nil {
                self?.didFail(with: error!)
            }
        }
    }
    
    func recordSample(_ data: CMDeviceMotion) {
        let sample = CRFDeviceMotionRecord(startUptime: startUptime, stepPath: currentStepPath, data: data)
        self.writeSample(sample)
    }
    
    override public func stopRecorder(loggerError: Error?, _ completion: RSDAsyncActionCompletionHandler?) {
        DispatchQueue.main.async {
            self.motionManager.stopDeviceMotionUpdates()
            super.stopRecorder(loggerError: loggerError, completion)
        }
    }
}
