//
//  CRFCameraStepViewController.swift
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

import UIKit
import ResearchSuiteUI
import ResearchSuite
import AVFoundation

public class CRFCameraStepViewController: RSDStepViewController, AVCapturePhotoCaptureDelegate {
    
    @IBOutlet public var previewView: UIView!

    private var _captureSession: AVCaptureSession?
    private var _videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var _capturePhotoOutput: AVCapturePhotoOutput?
    private let processingQueue = DispatchQueue(label: "org.sagebase.ResearchSuite.camera.processing")
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        let captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        do {
            // create the camera session
            let input = try AVCaptureDeviceInput(device: captureDevice)
            let captureSession = AVCaptureSession()
            _captureSession = captureSession
            captureSession.addInput(input)
            
            // add video view
            if let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession) {
                videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
                videoPreviewLayer.frame = view.layer.bounds
                _videoPreviewLayer = videoPreviewLayer
                previewView.layer.addSublayer(videoPreviewLayer)
            }
            
            // add output for taking a picture
            let output = AVCapturePhotoOutput()
            _capturePhotoOutput = output
            output.isHighResolutionCaptureEnabled = true
            captureSession.addOutput(output)
            
            // start the camera
            captureSession.startRunning()
            
        } catch let error {
            debugPrint("Failed to access the camera: \(error)")
        }
    }
    
    public override func goForward() {
        guard let capturePhotoOutput = _capturePhotoOutput else {
            _goNext()
            return
        }
        
        // User feedback of the photo shutter
        self.playSound(.photoShutter)
        
        processingQueue.async {
            
            // Create photo settings
            let photoSettings = AVCapturePhotoSettings()
            photoSettings.isAutoStillImageStabilizationEnabled = true
            photoSettings.isHighResolutionPhotoEnabled = true
            photoSettings.flashMode = .auto
            
            // Call capturePhoto method by passing our photo settings and a
            // delegate implementing AVCapturePhotoCaptureDelegate
            capturePhotoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
    
    private func _goNext() {
        super.goForward()
    }
    
    public override func stop() {
        if _captureSession?.isRunning ?? false {
            _captureSession?.stopRunning()
        }
        _captureSession = nil
        
        super.stop()
    }
    
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            // TODO: syoung 11/10/2017 Handle failure
            debugPrint("Failed to capture image: \(error!)")
            DispatchQueue.main.async {
                self._goNext()
            }
            return
        }
        
        var url: URL?
        do {
            if let imageData = photo.fileDataRepresentation() {
                url = try RSDFileResultUtility.createFileURL(identifier: self.step.identifier, ext: "jpeg", outputDirectory: self.taskController.taskPath.outputDirectory)
                save(imageData, to: url!)
            }
        } catch let error {
            debugPrint("Failed to save the camera image: \(error)")
        }
        
        DispatchQueue.main.async {
            
            // Create the result and set it as the result for this step
            var result = RSDFileResultObject(identifier: self.step.identifier)
            result.url = url
            self.taskController.taskPath.appendStepHistory(with: result)
            
            // Go to the next step
            self._goNext()
        }
    }
    
    private func save(_ imageData: Data, to url: URL) {
        processingQueue.async {
            do {
                try imageData.write(to: url)
            } catch let error {
                debugPrint("Failed to save the camera image: \(error)")
            }
        }
    }
}
