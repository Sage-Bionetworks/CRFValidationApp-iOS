//
//  CRFStairStepViewController.swift
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

public class CRFStairStepViewController: RSDActiveStepViewController {
    
    public var imageView: UIImageView! {
        return (self.navigationHeader as? RSDStepHeaderView)?.imageView
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // TODO: syoung 11/09/2017 Replace the idle timer with sound files for up/down
        UIApplication.shared.isIdleTimerDisabled = true
        
        // stop the stair step animation until the accelerometers are ready
        imageView.stopAnimating()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // TODO: syoung 11/09/2017 Replace the idle timer with sound files for up/down
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    public override func performStartCommands() {
        self.instructionLabel?.text = self.uiStep?.text
        
        let config = CRFCoreMotionRecorderConfiguration(identifier: self.step.identifier)
        self.taskController.startAsyncActions(with: [config]) { [weak self] in
            DispatchQueue.main.async {
                self?._finishStart()
            }
        }
    }
    
    private func _finishStart() {
        guard self.isVisible else { return }
        super.performStartCommands()
        imageView.startAnimating()
    }
    
    public override func stop() {
        super.stop()
        imageView.stopAnimating()
        let controllers = taskController.currentAsyncControllers
        taskController.stopAsyncActions(for: controllers) {
            // do nothing
        }
    }
    
    public override var timerInterval: TimeInterval {
        guard let (timeInterval,_) = self.secondInstruction else {
            return 1
        }
        return timeInterval
    }

    lazy public var firstInstruction: (TimeInterval, String)? = {
        return self.spokenInstructions.first
    }()
    
    lazy public var secondInstruction: (TimeInterval, String)? = {
        return self.spokenInstructions.last
    }()
    
    lazy public var spokenInstructions: [(TimeInterval, String)] = {
        guard let instructions = (self.step as? RSDActiveUIStepObject)?.spokenInstructions else { return [] }
        let sorted = instructions.sorted(by: { $0.key < $1.key })
        return Array(sorted.prefix(2))
    }()
    
    private var _toggle = false
    
    public override func speakInstruction(at duration: TimeInterval) {
        guard let stepDuration = self.activeStep?.duration else { return }
        if duration >= stepDuration {
            super.speakInstruction(at: duration)
        } else if duration == 0 || !_toggle {
            _speakFirstInstruction(at: duration)
        } else {
            _speakSecondInstruction(at: duration)
        }
    }
    
    private func _speakFirstInstruction(at duration: TimeInterval) {
        guard let instruction = self.firstInstruction else { return }
        _toggle = true
        self.vibrateDevice()
        self.speakInstruction(instruction.1, at: duration, completion: nil)
    }

    private func _speakSecondInstruction(at duration: TimeInterval) {
        guard let instruction = self.secondInstruction else { return }
        _toggle = false
        self.vibrateDevice()
        self.speakInstruction(instruction.1, at: duration, completion: nil)
    }
}
