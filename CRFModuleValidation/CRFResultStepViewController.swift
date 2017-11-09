//
//  CRFResultStepViewController.swift
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

open class CRFResultStepViewController: RSDStepViewController {
    
    @IBOutlet var textLabel: UILabel?
    @IBOutlet var resultLabel: UILabel!
    @IBOutlet var unitLabel: UILabel?
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.textLabel?.text = self.uiStep?.text
        self.resultLabel.text = resultText
    }
    
    open var resultText: String? {
        return nil
    }
    
    open var numberFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.maximumFractionDigits = 0
        return numberFormatter
    }()
}

public class CRFHeartRateResultStepViewController: CRFResultStepViewController {
    
    override public var resultText: String? {
        
        let resultStepIdentifier = "heartRate"
        let taskPath = self.taskController.taskPath!
        let sResult = taskPath.result.stepHistory.first { $0.identifier == resultStepIdentifier}
        guard let stepResult = sResult as? RSDCollectionResult
            else {
                return nil
        }
        
        let isAfter = (taskPath.parentPath?.currentStep?.identifier == "heartRate.after")
        let resultIdentifier = isAfter ? "\(resultStepIdentifier)_start" : "\(resultStepIdentifier)_end"
        let aResult = stepResult.inputResults.first { $0.identifier == resultIdentifier }
        guard let result = aResult as? RSDAnswerResult,
            let answer = result.value as? Int
            else {
                return nil
        }
        
        return numberFormatter.string(from: NSNumber(value: answer))
    }
}


