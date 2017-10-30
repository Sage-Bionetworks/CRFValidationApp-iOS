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
import ResearchSuite
import ResearchSuiteUI

class ScheduledActivityManager: SBAScheduledActivityManager, RSDTaskViewControllerDelegate {

    
    
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
        
        if task.identifier == TaskIdentifier.cardio12MT.rawValue,
            let stepResult = result.result(forIdentifier: "Cardio 12MT.workout") as? ORKStepResult,
            let distanceResult = stepResult.result(forIdentifier: "fitness.walk.distance") as? ORKNumericQuestionResult,
            let distance = distanceResult.numericAnswer {
            step.title = "Great job!"
            step.text = "You just ran \(Int(distance.doubleValue * 3.28084)) feet in 12 minutes."
        }
        
        return super.instantiateCompletionStepViewController(for: step, task: task, result: result)
    }

    // MARK: ResearchSuite Implementation
    
    override func didSelectRow(at indexPath: IndexPath) {
        // TODO: Get replacement
        
        
        
    }
    
    func taskViewController(_ taskViewController: (UIViewController & RSDTaskController), didFinishWith reason: RSDTaskFinishReason, error: Error?) {
        // dismiss the view controller
        taskViewController.dismiss(animated: true, completion: nil)
    }
    
    func taskViewController(_ taskViewController: (UIViewController & RSDTaskController), readyToSave taskPath: RSDTaskPath) {
        // Check if the results of this survey should be uploaded
        guard let schedule = scheduledActivity(with: taskPath.scheduleIdentifier)
            else {
                assertionFailure("Failed to find a schedule for this task. Cannot save.")
                return
        }
        
        // TODO: syoung 10/30/2017 Handle subresults that point at a different schedule and schema
        let didExitEarly = taskPath.didExitEarly
        let taskResult = taskPath.result as! SBAScheduledActivityResult
        schedule.startedOn = taskResult.startDate
        schedule.finishedOn = taskResult.endDate
        
        self.offMainQueue.async {
            
            // Archive the result
            if let archive = SBAActivityArchive(result: taskResult, schedule: schedule) {
                SBBDataArchive.encryptAndUploadArchives([archive])
            }
            
            // Send updates if not early exit
            if !didExitEarly {
                self.sendUpdated(scheduledActivities: [schedule])
            }
        }
    }
    
    func taskViewController(_ taskViewController: (UIViewController & RSDTaskController), viewControllerFor step: RSDStep) -> (UIViewController & RSDStepController)? {
        return nil  // TODO: build replacement view controllers
    }
}

extension RSDTaskResultObject : SBAScheduledActivityResult {
    
    public var schemaIdentifier: String {
        return self.schemaInfo?.schemaIdentifier ?? self.identifier
    }
    
    public var schemaRevision: NSNumber {
        return NSNumber(value: self.schemaInfo?.schemaRevision ?? 1)
    }
    
    public func archivableResults() -> [(String, SBAArchivableResult)]? {
        
        var archivableResults: [(String, SBAArchivableResult)] = []
        var answerMap: [String : Any] = [:]
        
        var recursiveAddFunc: ((String, [RSDResult]) -> Void)!
        
        recursiveAddFunc = { (stepIdentifier: String, results: [RSDResult]) in
            for result in results {
                
                if let answerResult = result as? RSDAnswerResult,
                    let answer = (answerResult.value as? RSDJSONValue)?.jsonObject() {
                    answerMap[answerResult.identifier] = answer
                    if let unit = answerResult.answerType.unit {
                        answerMap["\(answerResult.identifier)Unit"] = unit
                    }
                }
                
                if let archivableResult = result as? SBAArchivableResult {
                    archivableResults.append((stepIdentifier, archivableResult))
                }
                else if let stepCollection = result as? RSDStepCollectionResult {
                    recursiveAddFunc(stepCollection.identifier, stepCollection.inputResults)
                }
                else if let taskResult = result as? RSDTaskResult {
                    recursiveAddFunc(taskResult.identifier, taskResult.stepHistory)
                    if let asyncResults = taskResult.asyncResults {
                        recursiveAddFunc(taskResult.identifier, asyncResults)
                    }
                }
            }
        }
        
        recursiveAddFunc(identifier, stepHistory)
        if let asyncResults = self.asyncResults {
            recursiveAddFunc(identifier, asyncResults)
        }
        if answerMap.count > 0 {
            let archiveAnswers = RSDAnswerMap(identifier: identifier, startDate: startDate, endDate: endDate, answerMap: answerMap)
            archivableResults.append((identifier, archiveAnswers))
        }

        return archivableResults.count > 0 ? archivableResults : nil
    }
    
}

func bridgifyFilename(_ filename: String) -> String {
    return filename.replacingOccurrences(of: ".", with: "_").replacingOccurrences(of: " ", with: "_")
}

private let kStartDateKey = "startDate"
private let kEndDateKey = "endDate"
private let kIdentifierKey = "identifier"
private let kItemKey = "item"
private let QuestionResultQuestionTextKey = "questionText"
private let QuestionResultQuestionTypeKey = "questionType"
private let QuestionResultQuestionTypeNameKey = "questionTypeName"
private let QuestionResultSurveyAnswerKey = "answer"

private let NumericResultUnitKey = "unit"
private let DateAndTimeResultTimeZoneKey = "timeZone"

extension RSDAnswerResultObject : SBAArchivableResult {
    public func bridgeData(_ stepIdentifier: String) -> ArchiveableResult? {
        
        var json: [String : Any] = [:]

        json[kIdentifierKey] = self.identifier
        json[kStartDateKey]  = self.startDate
        json[kEndDateKey]    = self.endDate
        json[kItemKey] = self.identifier
        if let answer = (self.value as? RSDJSONValue)?.jsonObject() {
            json[self.answerType.bridgeAnswerKey] = answer
            json[QuestionResultSurveyAnswerKey] = answer
            json[QuestionResultQuestionTypeNameKey] = self.answerType.bridgeAnswerType
            if let unit = self.answerType.unit {
                json[NumericResultUnitKey] = unit
            }
        }
        
        let filename = bridgifyFilename(self.identifier) + ".json"
        return ArchiveableResult(result: json as NSDictionary, filename: filename)
    }
}

extension RSDAnswerResultType {
    
    var bridgeAnswerType: String {
        guard self.sequenceType == nil else {
            return "MultipleChoice"
        }
        
        switch self.baseType {
        case .boolean:
            return "Boolean"
        case .string, .data:
            return "Text"
        case .integer:
            return "Integer"
        case .decimal, .timeInterval:
            return "Decimal"
        case .date:
            if self.dateFormat == "HH:mm:ss" || self.dateFormat == "HH:mm" {
                return "TimeOfDay"
            } else {
                return "Date"
            }
        }
    }
    
    var bridgeAnswerKey: String {
        guard self.sequenceType == nil else {
            return "choiceAnswers"
        }
        
        switch self.baseType {
        case .boolean:
            return "booleanAnswer"
        case .string, .data:
            return "textAnswer"
        case .integer, .decimal, .timeInterval:
            return "numericAnswer"
        case .date:
            if self.dateFormat == "HH:mm:ss" || self.dateFormat == "HH:mm" {
                return "dateComponentsAnswer"
            } else {
                return "dateAnswer"
            }
        }

    }
}

extension RSDFileResultObject : SBAArchivableResult {
    public func bridgeData(_ stepIdentifier: String) -> ArchiveableResult? {
        guard let url = self.url else {
            return nil
        }
        var ext = url.pathExtension
        if ext == "" {
            ext = "json"
        }
        let filename = bridgifyFilename(self.identifier + "_" + stepIdentifier) + "." + ext
        return ArchiveableResult(result: url as AnyObject, filename: filename)
    }
}

public struct RSDAnswerMap : SBAArchivableResult {
    public let identifier: String
    public let startDate: Date
    public let endDate: Date
    public let answerMap: [String : Any]
    
    public func bridgeData(_ stepIdentifier: String) -> ArchiveableResult? {
        return ArchiveableResult(result: answerMap as NSDictionary, filename: "answerMap")
    }
}
