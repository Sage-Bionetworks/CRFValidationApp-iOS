//
//  ScheduledActivityManager.swift
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
import BridgeAppSDK

class ScheduledActivityManager: SBAScheduledActivityManager {
    
    override init(delegate: SBAScheduledActivityManagerDelegate?) {
        super.init(delegate: delegate)
        self.sections = [.keepGoing]
    }
    
    override func isAvailable(schedule: SBBScheduledActivity) -> Bool {
        return true
    }
    
    override func createFactory(for schedule: SBBScheduledActivity, taskRef: SBATaskReference) -> SBASurveyFactory {
        return SurveyFactory()
    }
    
    override func setupNotifications(for scheduledActivities: [SBBScheduledActivity]) {
        // Do nothing - This isn't used for this module
    }

    override func title(for section: Int) -> String? {
        return nil
    }
    
    override func instantiateActivityIntroductionStepViewController(for schedule: SBBScheduledActivity, step: ORKStep, taskRef: SBATaskReference) -> SBAActivityInstructionStepViewController? {
        // Do not use the activity instruction for the first step
        return nil
    }
    
    override func instantiateCompletionStepViewController(for step: ORKStep, task: ORKTask, result: ORKTaskResult) -> ORKStepViewController? {
        
        if task.identifier == TaskIdentifier.heartRateMeasurement.rawValue,
            let stepResult = result.result(forIdentifier: "heartRate") as? ORKStepResult,
            let heartRateResult = stepResult.result(forIdentifier: "heartRate.after.heartRateMeasurement") as? ORKNumericQuestionResult,
            let heartRate = heartRateResult.numericAnswer?.intValue {
            step.text = "Your heart rate is \(heartRate) bpm."
        }
        else if task.identifier == TaskIdentifier.cardio12MT.rawValue,
            let stepResult = result.result(forIdentifier: "Cardio 12MT.workout") as? ORKStepResult,
            let distanceResult = stepResult.result(forIdentifier: "fitness.walk.distance") as? ORKNumericQuestionResult,
            let distance = distanceResult.numericAnswer {
            step.title = "Great job!"
            step.text = "You just ran \(Int(distance.doubleValue * 3.28084)) feet in 12 minutes."
        }
        
        return super.instantiateCompletionStepViewController(for: step, task: task, result: result)
    }

}
