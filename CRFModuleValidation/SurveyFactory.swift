//
//  SurveyFactory.swift
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
import ResearchUXFactory
import ResearchKit
import ResearchSuite

enum TaskIdentifier: String {
    case heartRateMeasurement = "HeartRate Measurement"
    case cardio12MT = "Cardio 12MT"
    case cardioStairStep = "Cardio Stair Step"
}

enum CustomSurveyItemSubtype: String {
    case heartRate
    case review
}

extension SBASurveyItemType {
    func customSubtype() -> CustomSurveyItemSubtype? {
        if case .custom(let subtype) = self, subtype != nil {
            return CustomSurveyItemSubtype(rawValue: subtype!)
        }
        return nil
    }
}


class SurveyFactory: SBASurveyFactory {
    
    override func createSurveyStepWithCustomType(_ inputItem: SBASurveyItem) -> ORKStep? {
        guard let subtype = inputItem.surveyItemType.customSubtype() else {
            return super.createSurveyStepWithCustomType(inputItem)
        }
        switch (subtype) {
        case .heartRate:
            
            // Setup for camera
            let cameraInstruction = ORKInstructionStep(identifier: "cameraInstruction")
            cameraInstruction.title = "Using camera"
            cameraInstruction.text = "Use your camera to capture your heart rate by placing your finger over the lens and flash."
            
            let camera = ORKHeartRateCaptureStep(identifier: "camera")
            camera.stepDuration = 40
            camera.minimumDuration = 40
            
            // Setup for accelerometer
            let motionSensorInstruction = ORKInstructionStep(identifier: "motionSensorInstruction")
            motionSensorInstruction.title = "Using motion sensors"
            motionSensorInstruction.text = "Use your motion sensors to capture your heart rate by holding your phone against your heart."
            
            let motionSensor = ORKActiveStep(identifier: "motionSensor")
            motionSensor.recorderConfigurations = [
                ORKAccelerometerRecorderConfiguration(identifier: "accelerometer", frequency: 100),
                ORKDeviceMotionRecorderConfiguration(identifier: "deviceMotion", frequency: 100)]
            motionSensor.shouldContinueOnFinish = true
            motionSensor.shouldSpeakCountDown = true
            motionSensor.shouldStartTimerAutomatically = true
            motionSensor.stepDuration = 20
            motionSensor.text = "Hold your phone against your heart for 20 seconds."
            motionSensor.finishedSpokenInstruction = "Motion sensor measurement is complete."
            motionSensor.shouldPlaySoundOnFinish = true
            motionSensor.shouldVibrateOnFinish = true
            
            // Setup question for cross reference step
            let bpmCrossRefStep = ORKQuestionStep(identifier: "oximeter", title: "What is your heart rate using the oximeter?", answer: ORKNumericAnswerFormat(style: .integer, unit: "bpm"))
            
            return ORKPageStep(identifier: inputItem.identifier, steps:[cameraInstruction, camera, motionSensorInstruction, motionSensor, bpmCrossRefStep])
            
        case .review:
            return ORKReviewStep(identifier: inputItem.identifier)
        }
    }

    override func createTaskWithActiveTask(_ activeTask: SBAActiveTask, taskOptions: ORKPredefinedTaskOption) ->
        (ORKTask & NSCopying & NSSecureCoding)? {
            // If not a cardio task then call super
            guard activeTask.taskType == .activeTask(.cardio)
                else {
                    return super.createTaskWithActiveTask(activeTask, taskOptions: taskOptions)
            }
            // If the task fails to return an ordered task, then return nil
            guard let task = activeTask.createDefaultORKActiveTask(taskOptions)
            else {
                return nil
            }
            
            // Remove some of the steps before and after
            // syoung 09/19/2017 There's some weirdness going on here where the camera permission is added twice
            // so remove that as well.
            let rkIdentifiers: [BridgeCardioChallengeStepIdentifier] = [.instruction,
                                                                        .breathingBefore,
                                                                        .tiredBefore,
                                                                        .breathingAfter,
                                                                        .tiredAfter]
            var removeStepIdentifers = rkIdentifiers.map({ $0.rawValue })
            removeStepIdentifers.append("SBAPermissionsStep")
            
            var steps: [ORKStep] = task.steps
            for stepIdentifier in removeStepIdentifers {
                if let idx = steps.index(where: { $0.identifier == stepIdentifier }) {
                    steps.remove(at: idx)
                }
            }
            steps = steps.map {
                if let workoutStep = $0 as? ORKWorkoutStep {
                    var workoutSteps = workoutStep.steps
                    if let idx = workoutSteps.index(where: { $0.identifier == BridgeCardioChallengeStepIdentifier.walkInstruction.rawValue }) {
                        workoutSteps.remove(at: idx)
                    }
                    if let runStep = workoutStep.step(withIdentifier: "fitness.walk") as? ORKFitnessStep {
                        runStep.title = "Run as fast as you can for 12 minutes."
                        runStep.spokenInstruction = runStep.title
                    }
                    let workoutTask = ORKOrderedTask(identifier: "workout", steps: workoutSteps)
                    return ORKWorkoutStep(identifier: workoutTask.identifier,
                                                     pageTask: workoutTask,
                                                     relativeDistanceOnly: !SBAInfoManager.shared.currentParticipant.isTestUser,
                                                     options: [])
                }
                else {
                    return activeTask.replaceCardioStepIfNeeded($0)
                }
            }
            
            return task.copy(with: steps)
    }
}
