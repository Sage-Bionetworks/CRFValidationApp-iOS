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
    
    public let identifier: String
    public let startStepIdentifier: String?
    public let stopStepIdentifier: String?
    
    public init(identifier: String, startStepIdentifier: String? = nil, stopStepIdentifier: String? = nil) {
        self.identifier = identifier
        self.startStepIdentifier = startStepIdentifier
        self.stopStepIdentifier = stopStepIdentifier
    }
    
    public var permissions: [RSDPermissionType] {
        return [RSDStandardPermissionType.camera]
    }
    
    public var requiresBackgroundAudio: Bool {
        return false
    }
    
    public func validate() throws {
        // TODO: syoung 11/16/2017 Decide if we want validation to include checking the plist for required privacy alerts.
        // The value of these keys change from time to time so they can't be relied upon to be the same but it's confusing
        // for "researchers who write code" to have to manage that stuff when setting up a project.
    }
    
    public func instantiateController(with taskPath: RSDTaskPath) -> RSDAsyncActionController? {
        return CRFHeartRateRecorder(configuration: self, outputDirectory: taskPath.outputDirectory)
    }
}

public struct CRFHeartRateSample : RSDSampleRecord {
    public let uptime: TimeInterval
    public let timestamp: TimeInterval
    public let timestampDate: Date?
    public let stepPath: String
    
    public let hue: Double?
    public let saturation: Double?
    public let brightness: Double?
    public let red: Double?
    public let green: Double?
    public let blue: Double?
    
    public var bpm: Int?
    
    public init(uptime: TimeInterval, timestamp: TimeInterval, stepPath: String, bpm: Int?, hue: Double?, saturation: Double?, brightness: Double?, red: Double?, green: Double?, blue: Double?) {
        self.uptime = uptime
        self.timestamp = timestamp
        self.stepPath = stepPath
        self.bpm = bpm
        self.timestampDate = nil
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
        self.red = red
        self.green = green
        self.blue = blue
    }
}

fileprivate let kHeartRateSampleRate: Double = 1.0
fileprivate let kHeartRateFramesPerSecond: Int = 30
fileprivate let kHeartRateSettleSeconds: Int = 3
fileprivate let kHeartRateWindowSeconds: Int = 10
fileprivate let kHeartRateMinFrameCount: Int = (kHeartRateSettleSeconds + kHeartRateWindowSeconds) * kHeartRateFramesPerSecond

public class CRFHeartRateRecorder : RSDSampleRecorder, CRFHeartRateProcessorDelegate {

    public enum CRFHeartRateRecorderError : Error {
        case noBackCamera
    }

    /**
     Last calculated heartrate.
     */
    @objc dynamic public private(set) var bpm: Int = 0
    
    /**
     Flag that indicates that the user's finger is recognized as covering the flash.
     */
    @objc dynamic public private(set) var isCoveringLens: Bool = false

    override public func startRecorder(_ completion: RSDAsyncActionCompletionHandler?) {
        DispatchQueue.main.async {
            do {
                try self._startSampling()
                super.startRecorder(completion)
            } catch let err {
                debugPrint("Failed to start camera: \(err)")
                completion?(self, nil, err)
            }
        }
    }

    override public func stopRecorder(loggerError: Error?, _ completion: RSDAsyncActionCompletionHandler?) {
        DispatchQueue.main.async {
            
            self._simulationTimer?.invalidate()
            self._simulationTimer = nil
            
            self._session?.stopRunning()
            self._session = nil

            super.stopRecorder(loggerError: loggerError, completion)
        }
    }
    
    private let processingQueue = DispatchQueue(label: "org.sagebase.ResearchSuite.heartrate.processing")

    var _simulationTimer: Timer?
    var _session: AVCaptureSession?
    var _dataPointsHue: [Double] = []
    var _loggingSamples: [CRFHeartRateSample] = []
    
    lazy var sampleProcessor: CRFHeartRateProcessor! = {
        let processor = CRFHeartRateProcessor()
        processor.delegate = self
        return processor
    }()
    
    deinit {
        _session?.stopRunning()
        _simulationTimer?.invalidate()
    }
    
    public override var isRunning: Bool {
        if isSimulator {
            return _simulationTimer != nil
        } else {
            return _session?.isRunning ?? false
        }
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
        session.sessionPreset = AVCaptureSessionPresetLow
        
        // Retrieve the back camera and add as an input
        guard let captureDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .back)
            else {
                throw CRFHeartRateRecorderError.noBackCamera
        }
        let input = try AVCaptureDeviceInput(device: captureDevice)
        session.addInput(input)
        
        // Find the max frame rate we can get from the given device
        var currentFormat: AVCaptureDeviceFormat!
        for obj in captureDevice.formats {
            guard let format = obj as? AVCaptureDeviceFormat,
                let frameRates = format.videoSupportedFrameRateRanges?.first as? AVFrameRateRange
                else {
                    continue
            }
            // Find the lowest resolution format at the frame rate we want.
            if frameRates.maxFrameRate == Double(kHeartRateFramesPerSecond) {
                if (currentFormat == nil) || (CMVideoFormatDescriptionGetDimensions(format.formatDescription).width < CMVideoFormatDescriptionGetDimensions(currentFormat.formatDescription).width && CMVideoFormatDescriptionGetDimensions(format.formatDescription).height < CMVideoFormatDescriptionGetDimensions(currentFormat.formatDescription).height) {
                    currentFormat = format
                }
            }
        }

        // Tell the device to use the max frame rate.
        try captureDevice.lockForConfiguration()
        captureDevice.torchMode = .on
        captureDevice.activeFormat = currentFormat
        captureDevice.activeVideoMinFrameDuration = CMTimeMake(1, Int32(kHeartRateFramesPerSecond))
        captureDevice.activeVideoMaxFrameDuration = CMTimeMake(1, Int32(kHeartRateFramesPerSecond))
        captureDevice.unlockForConfiguration()
        
        // Set the output
        let videoOutput = AVCaptureVideoDataOutput()
        
        // create a queue to run the capture on
        let captureQueue = DispatchQueue(label: "org.sagebase.ResearchSuite.heartrate.capture.\(configuration.identifier)")
        videoOutput.setSampleBufferDelegate(sampleProcessor, queue: captureQueue)
        
        // configure the pixel format
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey : kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = false
        
        // Add the output and start running
        session.addOutput(videoOutput)
        session.startRunning()
    }
    
    private func _fireSimulationTimer() {
        let uptime = ProcessInfo.processInfo.systemUptime
        guard uptime - startUptime > 2 else { return }
        guard uptime - startUptime > Double(kHeartRateSettleSeconds + kHeartRateWindowSeconds) else {
            if !isCoveringLens {
                isCoveringLens = true
            }
            return
        }
        // TODO: syoung 11/08/2017 set up simulator to change the heart rate
        self.bpm = 65
        let sample = CRFHeartRateSample(uptime: uptime, timestamp: uptime - startUptime, stepPath: currentStepPath, bpm: bpm, hue: nil, saturation: nil, brightness: nil, red: nil, green: nil, blue: nil)
        self.writeSample(sample)
    }

    // MARK: CRFHeartRateProcessorDelegate
    
    public func processor(_ processor: CRFHeartRateProcessor, didCapture sample: CRFPixelSample) {
        self.processingQueue.async { [weak self] in
            self?._recordColor(sample)
        }
    }
    
    private func _recordColor(_ sample: CRFPixelSample) {

        let color = CRFColor(red: sample.red, green: sample.green, blue: sample.blue)
        let hsv = color.getHSV()
        
        // mark a change in whether or not the lens is covered
        let coveringLens = (hsv != nil)
        if coveringLens != self.isCoveringLens {
            DispatchQueue.main.async {
                self.isCoveringLens = coveringLens
            }
        }
        
        // Add the sample to the processor queue
        self.sampleProcessor.addDataPoint(hsv?.hue ?? -1)
        
        var sample = CRFHeartRateSample(uptime: sample.uptime,
                                        timestamp: sample.uptime - startUptime,
                                        stepPath: currentStepPath,
                                        bpm: nil,
                                        hue: hsv?.hue,
                                        saturation: hsv?.saturation,
                                        brightness: hsv?.brightness,
                                        red: color.red,
                                        green: color.green,
                                        blue: color.blue)

        // Only send UI updates once a second and only after min window of time
        guard _loggingSamples.count >= kHeartRateFramesPerSecond else {
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

// MARK: Data processing

// Algorithms adapted from: https://github.com/lehn0058/ATHeartRate (March 19, 2015)
// with additional modifications by: https://github.com/Litekey/heartbeat-cordova-plugin (July 30, 2015)
// and modifications by Shannon Young (February, 2017)

struct CRFColor {
    let red: Double
    let green: Double
    let blue: Double
    
    func getHSV() -> (hue: Double, saturation: Double, brightness: Double)? {
        let minValue = min(red, min(green, blue))
        let maxValue = max(red, max(green, blue))
        let delta = maxValue - minValue
        guard round(delta * 1000) > 0 else { return nil }
        
        // Calculate the hue
        var hue: Double
        if (red == maxValue) {
            hue = (green - blue) / delta
        } else if (green == maxValue) {
            hue = 2 + (blue - red) / delta
        } else {
            hue = 4 + (red - green) / delta
        }
        hue *= 60
        if (hue < 0) {
            hue += 360
        }
        
        return (hue, delta / maxValue, maxValue)
    }
}

/**
 
 // TODO: syoung 11/09/2017 Debug porting the algorithm to Swift
 
struct CRFHeartRateProcessor {
 
    func pixelColor(from sampleBuffer: CMSampleBuffer!) {
 
 //        guard let cvimgRef = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
 //
 //        // Lock the image buffer
 //        CVPixelBufferLockBaseAddress(cvimgRef, [])
 //
 //        var success: Bool = false
 //        var r: Double = 0
 //        var g: Double = 0
 //        var b: Double = 0
 //
 //        // access the data
 //        if let baseAddress = CVPixelBufferGetBaseAddress(cvimgRef) {
 //            success = true
 //            var buf = baseAddress.assumingMemoryBound(to: UInt8.self)
 //
 //            let width = CVPixelBufferGetWidth(cvimgRef)
 //            let height = CVPixelBufferGetHeight(cvimgRef)
 //            let bprow = CVPixelBufferGetBytesPerRow(cvimgRef)
 //
 //            // TODO: syoung 11/08/2017 Not sure what the scale factor is for? I think it is used to
 //            // downsample the buffer and *not* every single pixel value because that would take too
 //            // long to procress, but this is code adapted from elsewhere so I'm not sure.
 //            let widthScaleFactor = width / 192
 //            let heightScaleFactor = height / 144
 //
 //            // Get the average rgb values for the entire image.
 //            for _ in stride(from: 0, to: height, by: heightScaleFactor) {
 //                for x in stride(from: 0, through: 4 * width, by: 4 * widthScaleFactor) {
 //                    r += Double(buf[x + 2])
 //                    g += Double(buf[x + 1])
 //                    b += Double(buf[x])
 //                }
 //                buf += bprow
 //            }
 //
 //            r /= 255 * Double(width * height) / Double(widthScaleFactor * heightScaleFactor)
 //            g /= 255 * Double(width * height) / Double(widthScaleFactor * heightScaleFactor)
 //            b /= 255 * Double(width * height) / Double(widthScaleFactor * heightScaleFactor)
 //        }
 //
 //        // Unlock the image buffer
 //        CVPixelBufferUnlockBaseAddress(cvimgRef, [])
 //
 //        // If not successful then return and do not record the sample
 //        guard success else { return }

 }
 
    func calculateBPM(with dataPoints:[Double]) -> Int {
        let bandpassFilteredItems = butterworthBandpassFilter(dataPoints)
        let smoothedBandpassItems = medianSmoothing(bandpassFilteredItems)
        guard let peak = medianPeak(smoothedBandpassItems), peak > 0
            else {
                return -1
        }
        return 60 * kHeartRateFramesPerSecond / peak
    }
    
    func medianPeak(_ inputData: [Double]) -> Int? {
        var peaks: [Int] = []
        var count: Int = 4
        var ii: Int = 3
        while ii < (inputData.count - 3) {
            if  inputData[ii] > 0 &&
                inputData[ii] > inputData[ii-1] &&
                inputData[ii] > inputData[ii-2] &&
                inputData[ii] > inputData[ii-3] &&
                inputData[ii] >= inputData[ii+1] &&
                inputData[ii] >= inputData[ii+2] &&
                inputData[ii] >= inputData[ii+3]
            {
                peaks.append(count)
                ii += 4
                count += 4
            } else {
                ii += 1
                count += 1
            }
        }
        
        // Return nil if no peaks found
        guard peaks.count > 0 else { return nil }
        
        // TODO: syoung 11/08/2017 Figure out why the value returned is not *actually* the value in the middle.
        peaks[0] += count + 3
        peaks.sort()
        let medianIndex = peaks.count * 2 / 3
        let medianPeak = peaks[medianIndex]
        return medianPeak != 0 ? medianPeak : nil
    }
    
    // http://www-users.cs.york.ac.uk/~fisher/cgi-bin/mkfscript
    // Butterworth Bandpass filter
    // 4th order
    // sample rate - varies between possible camera frequencies. Either 30, 60, 120, or 240 FPS
    // corner1 freq. = 0.667 Hz (assuming a minimum heart rate of 40 bpm, 40 beats/60 seconds = 0.667 Hz)
    // corner2 freq. = 4.167 Hz (assuming a maximum heart rate of 250 bpm, 250 beats/60 secods = 4.167 Hz)
    // Bandpass filter was chosen because it removes frequency noise outside of our target range (both higher and lower)
    func butterworthBandpassFilter(_ inputData: [Double]) -> [Double] {
        
        let dGain = 1.232232910e+02
        let NZEROS = 8
        let NPOLES = 8
        var xv: [Double] = Array(repeatElement(0.0, count: NZEROS+1))
        var yv: [Double] = Array(repeatElement(0.0, count: NPOLES+1))
        
        var outputData: [Double] = []
        for input in inputData {

            xv[0] = xv[1]; xv[1] = xv[2]; xv[2] = xv[3]; xv[3] = xv[4]; xv[4] = xv[5]; xv[5] = xv[6]; xv[6] = xv[7]; xv[7] = xv[8];
            xv[8] = input / dGain;
            yv[0] = yv[1]; yv[1] = yv[2]; yv[2] = yv[3]; yv[3] = yv[4]; yv[4] = yv[5]; yv[5] = yv[6]; yv[6] = yv[7]; yv[7] = yv[8];
            yv[8] = (xv[0] + xv[8]) - 4 * (xv[2] + xv[6]) + 6 * xv[4]
                    + ( -0.1397436053 * yv[0]) + (  1.2948188815 * yv[1])
                    + ( -5.4070037946 * yv[2]) + ( 13.2683981280 * yv[3])
                    + (-20.9442560520 * yv[4]) + ( 21.7932169160 * yv[5])
                    + (-14.5817197500 * yv[6]) + (  5.7161939252 * yv[7]);
            
            outputData.append(yv[8])
        }

        return outputData;
    }

    // Smoothed data helps remove outliers that may be caused by interference, finger movement or pressure changes.
    // This will only help with small interference changes.
    // This also helps keep the data more consistent.
    func medianSmoothing(_ inputData: [Double]) -> [Double] {
    
        var outputData: [Double] = []
        outputData.append(contentsOf: inputData.prefix(3))
        for ii in 3..<(inputData.count - 3) {
            let items = inputData[ii-2 ... ii+2].sorted()
            outputData.append(items[2])
        }
        outputData.append(contentsOf: inputData.suffix(3))
        
        return outputData;
    }
}
*/
