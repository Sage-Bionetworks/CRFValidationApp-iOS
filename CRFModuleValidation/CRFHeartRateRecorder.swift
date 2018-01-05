//
//  CRFHeartRateRecorder.swift
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
import AVFoundation
import ResearchSuite

public struct CRFHeartRateRecorderConfiguration : RSDRecorderConfiguration, RSDAsyncActionControllerVendor, Codable {
    
    /// A unique string used to identify the recorder.
    public let identifier: String
    
    /// The step used to mark when to start the recorder.
    public var startStepIdentifier: String?
    
    /// The step used to mark when to stop the recorder.
    public var stopStepIdentifier: String?
    
    /// Should the log file include the full pixel matrix or just the averaged value?
    public var shouldSaveBuffer: Bool = false
    
    /// The duration of the capture. Default = `30`
    public var duration: TimeInterval = 30
    
    /// Default initializer.
    /// - parameter identifier: A unique string used to identify the recorder.
    public init(identifier: String) {
        self.identifier = identifier
    }
    
    /// This recorder requires permission to use the camera.
    public var permissions: [RSDPermissionType] {
        return [RSDStandardPermissionType.camera]
    }
    
    /// This recorder does not require background audio
    public var requiresBackgroundAudio: Bool {
        return false
    }
    
    /// No validation required.
    public func validate() throws {
        // TODO: syoung 11/16/2017 Decide if we want validation to include checking the plist for required privacy alerts.
        // The value of these keys change from time to time so they can't be relied upon to be the same but it's confusing
        // for "researchers who write code" to have to manage that stuff when setting up a project.
    }
    
    /// Instantiates a `CRFHeartRateRecorder`.
    /// - parameter taskPath: The current task path.
    /// - returns: A new instance of `CRFHeartRateRecorder` keyed to this configuration.
    public func instantiateController(with taskPath: RSDTaskPath) -> RSDAsyncActionController? {
        return CRFHeartRateRecorder(configuration: self, taskPath: taskPath, outputDirectory: taskPath.outputDirectory)
    }
}

public struct CRFHeartRateSample : RSDSampleRecord {
    public let uptime: TimeInterval
    public let timestamp: TimeInterval?
    public let timestampDate: Date?
    public let stepPath: String
    
    public let hue: Double?
    public let saturation: Double?
    public let brightness: Double?
    public let red: Double?
    public let green: Double?
    public let blue: Double?
    
    public var bpm: Int?
    
    public init(uptime: TimeInterval, timestamp: TimeInterval, stepPath: String, hue: Double?, saturation: Double?, brightness: Double?, red: Double?, green: Double?, blue: Double?) {
        self.uptime = uptime
        self.timestamp = timestamp
        self.stepPath = stepPath
        self.bpm = nil
        self.timestampDate = nil
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
        self.red = red
        self.green = green
        self.blue = blue
    }
}

public class CRFHeartRateRecorder : RSDSampleRecorder, CRFHeartRateProcessorDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {

    public enum CRFHeartRateRecorderError : Error {
        case noBackCamera
        case permissionDenied(AVAuthorizationStatus)
    }
    
    /// An optional view that can be used to show the user's finger while the lens is uncovered.
    public var previewView: UIView?

    /// Last calculated heartrate.
    @objc dynamic public private(set) var bpm: Int = 0
    
    /// Flag that indicates that the user's finger is recognized as covering the flash.
    @objc dynamic public private(set) var isCoveringLens: Bool = false
    
    public var heartRateConfiguration : CRFHeartRateRecorderConfiguration? {
        return self.configuration as? CRFHeartRateRecorderConfiguration
    }
    
    public override func requestPermissions(on viewController: UIViewController, _ completion: @escaping RSDAsyncActionCompletionHandler) {
        
        // TODO: syoung 12/11/2017 Implement UI/UX for alerting the user that they do not have the required permission and must
        // change this from the Settings app.
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .denied || status == .restricted {
            let error = CRFHeartRateRecorderError.permissionDenied(status)
            self.updateStatus(to: .failed, error: error)
            completion(self, nil, error)
            return
        }
        
        guard status == .notDetermined else {
            self.updateStatus(to: .permissionGranted, error: nil)
            completion(self, nil, nil)
            return
        }
        
        AVCaptureDevice.requestAccess(for: .video) { (granted) in
            if granted {
                self.updateStatus(to: .permissionGranted, error: nil)
                completion(self, nil, nil)
            } else {
                let error = CRFHeartRateRecorderError.permissionDenied(.denied)
                self.updateStatus(to: .failed, error: error)
                completion(self, nil, error)
            }
        }
    }
    
    public override func startRecorder(_ completion: @escaping ((RSDAsyncActionStatus, Error?) -> Void)) {
        do {
            try self._startSampling()
            completion(.running, nil)
        } catch let err {
            debugPrint("Failed to start camera: \(err)")
            completion(.failed, err)
        }
    }
    
    public override func stopRecorder(_ completion: @escaping ((RSDAsyncActionStatus) -> Void)) {
        
        updateStatus(to: .processingResults, error: nil)
        
        self._videoPreviewLayer?.removeFromSuperlayer()
        self._videoPreviewLayer = nil
        
        self._simulationTimer?.invalidate()
        self._simulationTimer = nil
        
        self._session?.stopRunning()
        self._session = nil

        if let url = self.sampleProcessor?.videoURL {

            // Create and add the result
            var fileResult = RSDFileResultObject(identifier: self.videoIdentifier)
            fileResult.startDate = self.startDate
            fileResult.endDate = Date()
            fileResult.url = url
            fileResult.startUptime = self.startUptime
            fileResult.contentType = "video/mp4"
            self.appendResults(fileResult)

            // Close the video recorder
            updateStatus(to: .stopping, error: nil)
            self.sampleProcessor.stopRecording() {
                completion(.finished)
            }
        } else {
            completion(.finished)
        }
    }
    
    private let processingQueue = DispatchQueue(label: "org.sagebase.ResearchSuite.heartrate.processing")

    private var _simulationTimer: Timer?
    private var _session: AVCaptureSession?
    private var _captureDevice: AVCaptureDevice?
    private var _videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var _loggingSamples: [CRFHeartRateSample] = []
    
    lazy var sampleProcessor: CRFHeartRateProcessor! = {
        let processor = CRFHeartRateProcessor(delegate: self, callbackQueue: processingQueue)
        return processor
    }()
    
    deinit {
        _session?.stopRunning()
        _simulationTimer?.invalidate()
    }
    
    private func _getCaptureDevice() -> AVCaptureDevice? {
        // If this is an iPhone Plus then the lens that is closer to the flash is the telephoto lens
        let telephoto = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInTelephotoCamera, for: AVMediaType.video, position: .back)
        return telephoto ?? AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: .back)
    }
    
    private var videoIdentifier: String {
        return "\(self.configuration.identifier)_video"
    }
    
    private func _setupVideoRecorder(formatDescription: CMFormatDescription) {
        guard let saveVideo = self.heartRateConfiguration?.shouldSaveBuffer, saveVideo,
            let url = try? RSDFileResultUtility.createFileURL(identifier: videoIdentifier, ext: "mp4", outputDirectory: outputDirectory)
            else {
                return
        }
        let time = CMTime(seconds: self.startUptime, preferredTimescale: 1000000000)
        sampleProcessor.prepareRecording(to: url, startTime: time, formatDescription: formatDescription)
    }
    
    private func _startSampling() throws {
        guard !isSimulator else {
            _simulationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] (_) in
                self?._fireSimulationTimer()
            })
            return
        }
        guard _session == nil else { return }
        
        // Create the session
        let session = AVCaptureSession()
        _session = session
        session.sessionPreset = AVCaptureSession.Preset.low
        
        // Retrieve the back camera and add as an input
        guard let captureDevice = _getCaptureDevice()
            else {
                throw CRFHeartRateRecorderError.noBackCamera
        }
        _captureDevice = captureDevice
        let input = try AVCaptureDeviceInput(device: captureDevice)
        session.addInput(input)
        
        // Find the max frame rate we can get from the given device
        var currentFormat: AVCaptureDevice.Format!
        for format in captureDevice.formats {
            guard let frameRates = format.videoSupportedFrameRateRanges.first,
                frameRates.maxFrameRate == Double(CRFHeartRateFramesPerSecond)
                else {
                    continue
            }
            
            // If this is the first valid format found then set it and continue
            if (currentFormat == nil) {
                currentFormat = format
                continue
            }
            
            // Find the lowest resolution format at the frame rate we want.
            let currentSize = CMVideoFormatDescriptionGetDimensions(currentFormat.formatDescription)
            let formatSize = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            if formatSize.width < currentSize.width && formatSize.height < currentSize.height {
                currentFormat = format
            }
        }

        // Tell the device to use the max frame rate.
        try captureDevice.lockForConfiguration()
        
        // Turn on the flash
        captureDevice.torchMode = .on
        
        // Set the format
        captureDevice.activeFormat = currentFormat
        
        // Set the frame rate
        captureDevice.activeVideoMinFrameDuration = CMTimeMake(1, CRFHeartRateFramesPerSecond)
        captureDevice.activeVideoMaxFrameDuration = CMTimeMake(1, CRFHeartRateFramesPerSecond)
        
        // Belt & suspenders. For currently supported devices, HDR is not supported for the lowest
        // resolution format (which is what this recorder uses), but in case a device comes out that
        // does support HDR, then be sure to turn it off.
        if currentFormat.isVideoHDRSupported {
            captureDevice.isVideoHDREnabled = false
            captureDevice.automaticallyAdjustsVideoHDREnabled = false
        }

        // Restrict the camera to focus in the "near" (or macro) range.
        if captureDevice.isLockingFocusWithCustomLensPositionSupported {
            captureDevice.setFocusModeLocked(lensPosition: 0.0, completionHandler: nil)
        } else if captureDevice.isAutoFocusRangeRestrictionSupported {
            captureDevice.autoFocusRangeRestriction = .near
            if captureDevice.isFocusPointOfInterestSupported {
                captureDevice.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            }
        }

        captureDevice.unlockForConfiguration()
        
        // Set the output
        let videoOutput = AVCaptureVideoDataOutput()
        
        // create a queue to run the capture on
        let captureQueue = DispatchQueue(label: "org.sagebase.ResearchSuite.heartrate.capture.\(configuration.identifier)")
        videoOutput.setSampleBufferDelegate(self, queue: captureQueue)
        
        // set up the video output
        videoOutput.videoSettings = [ kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = false
        
        // start the video recorder (if there is one)
        _setupVideoRecorder(formatDescription: currentFormat.formatDescription)
        
        // Check to see if there is a preview window
        if let view = self.previewView {
            let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
            videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
            videoPreviewLayer.frame = view.layer.bounds
            _videoPreviewLayer = videoPreviewLayer
            view.layer.addSublayer(videoPreviewLayer)
        }

        // Add the output and start running
        session.addOutput(videoOutput)
        session.startRunning()
    }
    
    private func _fireSimulationTimer() {
        let uptime = ProcessInfo.processInfo.systemUptime
        guard uptime - startUptime > 2 else { return }
        guard uptime - startUptime > Double(CRFHeartRateSettleSeconds + CRFHeartRateWindowSeconds) else {
            if !isCoveringLens {
                isCoveringLens = true
            }
            return
        }
        // TODO: syoung 11/08/2017 set up simulator to change the heart rate
        self.bpm = 65
        var sample = CRFHeartRateSample(uptime: uptime, timestamp: uptime - startUptime, stepPath: currentStepPath, hue: nil, saturation: nil, brightness: nil, red: nil, green: nil, blue: nil)
        sample.bpm = 65
        self.writeSample(sample)
    }
    
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        sampleProcessor.appendVideoSampleBuffer(sampleBuffer)
    }

    // MARK: CRFHeartRateProcessorDelegate
    
    public func processor(_ processor: CRFHeartRateProcessor, didCapture sample: CRFPixelSample) {
        _recordColor(sample)
    }
    
    private func _recordColor(_ sample: CRFPixelSample) {
        
        // mark a change in whether or not the lens is covered
        let coveringLens = sample.isCoveringLens
        if coveringLens != self.isCoveringLens {
            DispatchQueue.main.async {
                self.isCoveringLens = coveringLens
                if let previewLayer = self._videoPreviewLayer {
                    if coveringLens {
                        previewLayer.removeFromSuperlayer()
                    } else {
                        self.previewView?.layer.addSublayer(previewLayer)
                    }
                }
            }
        }
        
        // If not covering the lens then check that everything is still on
        if !coveringLens, let device = _captureDevice, device.torchMode != .on {
            do {
                try device.lockForConfiguration()
                device.torchMode = .on
                device.unlockForConfiguration()
            } catch let err {
                self.didFail(with: err)
            }
        }
        
        var sample = CRFHeartRateSample(uptime: sample.uptime,
                                        timestamp: sample.uptime - startUptime,
                                        stepPath: currentStepPath,
                                        hue: sample.hue,
                                        saturation: sample.saturation,
                                        brightness: sample.brightness,
                                        red: sample.red,
                                        green: sample.green,
                                        blue: sample.blue)

        // Only send UI updates once a second and only after min window of time
        guard _loggingSamples.count >= CRFHeartRateFramesPerSecond else {
            // just save the samples in batch and send when the heart rate is updated
            _loggingSamples.append(sample)
            return
        }
        
        // get the new bpm
        if let bpm = calculateBPM() {
            // update the logging samples
            sample.bpm = bpm
        
            // update the stored bpm
            DispatchQueue.main.async {
                self.bpm = bpm
            }
        }
        
        // write the samples
        _loggingSamples.append(sample)
        let samples = _loggingSamples.sorted(by: { $0.uptime < $1.uptime })
        _loggingSamples.removeAll()
        self.writeSamples(samples)
    }

    func calculateBPM() -> Int? {
        // If the heart rate calculated is too low, then it isn't valid
        let bpm = sampleProcessor.calculateBPM()
        return bpm >= 40 ? bpm : nil
    }
}
