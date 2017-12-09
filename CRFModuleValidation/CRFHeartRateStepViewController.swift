//
//  CRFHeartRateStepViewController.swift
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

public class CRFHeartRateStepViewController: RSDActiveStepViewController, RSDAsyncActionControllerDelegate {
    
    /// The heart rate recorder.
    public private(set) var bpmRecorder: CRFHeartRateRecorder?
    
    /// This step has multiple results so use a collection result to store them.
    public private(set) var collectionResult: RSDCollectionResult?
    
    /// Add the result to the collection. This will fail to add the result if called before the step is
    /// added to the view controller.
    /// - parameter result: The result to add to the collection.
    public func addResult(_ result: RSDResult) {
        guard step != nil else { return }
        var stepResult = self.collectionResult ?? RSDCollectionResultObject(identifier: self.step.identifier)
        stepResult.appendInputResults(with: result)
        self.collectionResult = stepResult
        self.taskController.taskPath.appendStepHistory(with: stepResult)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.progressLabel?.text = "--"
        self.unitLabel?.text = "BPM"    // TODO: syoung 11/08/2017 Localize
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Use a delay to let the page view controller finish its animation
        // and for the user to put their finger on the lens.
        let delay = DispatchTime.now() + .milliseconds(500)
        DispatchQueue.main.asyncAfter(deadline: delay) { [weak self] in
            self?._startCamera()
        }
    }
    
    private func _startCamera() {
        guard isVisible else { return }
        
        // Create a recorder that runs only during this step
        let taskPath = self.taskController.taskPath!
        var config = CRFHeartRateRecorderConfiguration(identifier: "recorder")
        config.shouldSaveBuffer = true  // TODO: refactor to allow setting up the config using json file.
        config.duration = self.activeStep?.duration ?? config.duration
        bpmRecorder = CRFHeartRateRecorder(configuration: config, outputDirectory: taskPath.outputDirectory)
        bpmRecorder?.delegate = self
        
        // add an observer for changes in the bpm
        _bpmObserver = bpmRecorder!.observe(\.bpm, changeHandler: { [weak self] (recorder, _) in
            self?._updateBPMLabelOnMainQueue(recorder.bpm)
        })
        
        // Setup a listener to start the timer when the lens is covered or in 5 seconds if not detected.
        _isCoveredObserver = bpmRecorder!.observe(\.isCoveringLens, changeHandler: { [weak self] (recorder, _) in
            self?._handleLensCoveredOnMainQueue(recorder.isCoveringLens)
        })
        let delay = DispatchTime.now() + .seconds(5)
        DispatchQueue.main.asyncAfter(deadline: delay) { [weak self] in
            self?._startCountdownIfNeeded()
        }
        
        // start the recorder
        bpmRecorder!.start(at: self.taskController.taskPath, completion: nil)
    }
    
    override public func cancel() {
        bpmRecorder?.stop()
        super.cancel()
    }
    
    override public func goForward() {
        guard let recorder = bpmRecorder else {
            super.goForward()
            return
        }
        
        recorder.stop {[weak self] (_, result, error) in
            DispatchQueue.main.async {
                if result != nil {
                    if let collectionResult = result as? RSDCollectionResult {
                        for childResult in collectionResult.inputResults {
                            self?.addResult(childResult)
                        }
                    } else {
                        self?.addResult(result!)
                    }
                }
                // TODO: syoung 11/08/2017 Add error to result set?
                self?._goNext()
            }
        }
    }
    
    private func _goNext() {
        super.goForward()
    }
    
    override public func stop() {

        _bpmObserver?.invalidate()
        _bpmObserver = nil
        
        _isCoveredObserver?.invalidate()
        _isCoveredObserver = nil
        
        // Add the ending heart rate as a result for display to the user
        var bpmResult = RSDAnswerResultObject(identifier: "\(self.step.identifier)_end", answerType: RSDAnswerResultType(baseType: .decimal))
        bpmResult.value = bpmRecorder?.bpm
        addResult(bpmResult)
        
        super.stop()
    }
    
    public func asyncActionController(_ controller: RSDAsyncActionController, didFailWith error: Error) {
        debugPrint("Camera recorder failed. \(error)")
        // TODO: syoung 11/10/2017 Handle errors
    }
    
    private var _bpmObserver: NSKeyValueObservation?
    private var _isCoveredObserver: NSKeyValueObservation?
    
    private func _startCountdownIfNeeded() {
        if _markTime == nil {
            _markTime = ProcessInfo.processInfo.systemUptime
        }
        guard startUptime == nil else { return }
        self.start()
    }
    
    private func _handleLensCoveredOnMainQueue(_ isCoveringLens: Bool) {
        DispatchQueue.main.async {
            if isCoveringLens {
                self._startCountdownIfNeeded()
            } else {
                // zero out the BPM to indicate to the user that they need to cover the flash
                // and show the initial instruction.
                self.progressLabel?.text = "--"
                self._markTime = nil
                if let instruction = self.activeStep?.spokenInstruction(at: 0) {
                    self.instructionLabel?.text = instruction
                }
            }
        }
    }
    
    private func _updateBPMLabelOnMainQueue(_ bpm: Int) {
        DispatchQueue.main.async {
            self._updateBPMLabel(bpm)
        }
    }
    
    private let numberFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.maximumFractionDigits = 0
        return numberFormatter
    }()
    
    private var _encouragementGiven: Bool = false
    private var _markTime: TimeInterval?
    
    private func _updateBPMLabel(_ bpm: Int) {
        if self.collectionResult?.inputResults.count ?? 0 == 0 {
            // Add the starting heart rate as a result for display to the user
            var bpmResult = RSDAnswerResultObject(identifier: "\(self.step.identifier)_start", answerType: RSDAnswerResultType(baseType: .decimal))
            bpmResult.value = bpmRecorder?.bpm
            addResult(bpmResult)
        } else if !_encouragementGiven, let markTime = _markTime, (ProcessInfo.processInfo.systemUptime - markTime) > 40,
            let continueText = self.uiStep?.detail {
            _encouragementGiven = true
            self.speakInstruction(continueText, at: 40, completion: nil)
        }
        
        self.progressLabel?.text = numberFormatter.string(from: NSNumber(value: bpm))
    }
}
