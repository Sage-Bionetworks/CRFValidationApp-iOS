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
    
    @IBOutlet open var commandLabel: UILabel?
    
    public var imageView: UIImageView! {
        return (self.navigationHeader as? RSDStepHeaderView)?.imageView
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // stop the stair step animation until the accelerometers are ready
        imageView.stopAnimating()
    }
    
    public override func performStartCommands() {
        self.instructionLabel?.text = self.uiStep?.text
        
        // Use a delay to show the "Stand still" text for the instruction
        // to give the user a moment to prepare.
        let delay = DispatchTime.now() + .milliseconds(500)
        DispatchQueue.main.asyncAfter(deadline: delay) { [weak self] in
            self?._finishStart()
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
    }
    
    public override var timerInterval: TimeInterval {
        return _metronomeInterval
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
    
    private var _speakCadenceOn: Bool = true
    private let _metronomeInterval: TimeInterval = 60 / 96
    private let _speakCadenceDuration: TimeInterval = (60 / 96) * 4 * 4

    /// Override `speakInstruction`. This method is called every time the timer is fired.
    /// Repeat the "Up, Down" instructions for the first 5 cycles.
    public override func speakInstruction(at duration: TimeInterval) {
        
        let cadence = Int(duration / _metronomeInterval) % 4
        let upStep = cadence == 0 || cadence == 1
        
        // Do nothing if the first and second instruction aren't set.
        guard let instructionText = (upStep ? firstInstruction : secondInstruction)?.1,
            let stepDuration = self.activeStep?.duration
            else {
                return
        }
        
        // Play metronome sound.
        self.playSound(.tock)
        
        if _speakCadenceOn && duration > 0 && (cadence == 0 || cadence == 2) {

            // If this is the start then repeat the up/down spoken cadence for the first
            // few steps. After that, only play the metronome sound and follow the logic set up
            // by the super class.
            if !upStep && duration > _speakCadenceDuration {
                _speakCadenceOn = false
            }
            
            // Speak the up/down cadence.
            self.speakInstruction(instructionText, at: duration, completion: nil)
            self.commandLabel?.text = instructionText
        }
        else {
            super.speakInstruction(at: duration)
            if duration < stepDuration {
                // Only the end step should write to the instruction label.
                // Otherwise, should only show the animating person.
                self.commandLabel?.text = ""
            } else {
                // TODO: syoung 01/03/2018 Localize
                self.commandLabel?.text = "Stand Still"
            }
        }
    }
}
