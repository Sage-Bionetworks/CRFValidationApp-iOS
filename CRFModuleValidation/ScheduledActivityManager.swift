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

class ScheduledActivityManager: SBABaseScheduledActivityManager, SBAScheduledActivityDataSource, RSDTaskViewControllerDelegate {

    private let heartRateMeasurementGuid = "fa1058e7-8df2-41b9-aaf4-376049ab66a7"
    private let heartRateTaskIdentifier = "HeartRate Measurement"
    
    override func filteredSchedules(scheduledActivities: [SBBScheduledActivity]) -> [SBBScheduledActivity] {
        
        var schedules = super.filteredSchedules(scheduledActivities: scheduledActivities)
        
        // IA-591 If this is the test user then force the display of the heart rate measurement task
        // syoung 10/30/2017 This is a work-around for the tasks disappearing until we have time to
        // try and repro.
        if self.user.isTestUser, !schedules.contains(where: { $0.scheduleIdentifier == heartRateMeasurementGuid }) {
            let schedule = SBBScheduledActivity()
            schedule.guid = heartRateMeasurementGuid
            schedule.persistentValue = true
            schedule.scheduledOn = Date().startOfDay()
            let activity = SBBActivity()
            schedule.activity = activity
            activity.guid = UUID().uuidString
            let taskReference = SBBTaskReference()
            taskReference.identifier = heartRateTaskIdentifier
            activity.task = taskReference
            schedules.append(schedule)
        }
        
        return schedules
    }
    
    override func isAvailable(schedule: SBBScheduledActivity) -> Bool {
        return true
    }

    override func setupNotifications(for scheduledActivities: [SBBScheduledActivity]) {
        // Do nothing - This isn't used for this module
    }
    
    // MARK: ORKTask management
    
    override func createFactory(for schedule: SBBScheduledActivity, taskRef: SBATaskReference) -> SBASurveyFactory {
        return SurveyFactory()
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

    // MARK: Data source
    
    func numberOfSections() -> Int {
        return 1
    }
    
    func numberOfRows(for section: Int) -> Int {
        return self.activities.count
    }
    
    func scheduledActivity(at indexPath: IndexPath) -> SBBScheduledActivity? {
        return self.activities[indexPath.row]
    }
    
    func shouldShowTask(for indexPath: IndexPath) -> Bool {
        return true
    }
    
    func title(for section: Int) -> String? {
        return nil
    }
    
    func didSelectRow(at indexPath: IndexPath) {
       
        // Only if the task was created should something be done.
        guard let schedule = scheduledActivity(at: indexPath),
            let taskRef = bridgeInfo.taskReferenceForSchedule(schedule),
            let identifier = schedule.activityIdentifier
            else {
                assertionFailure("Could not find schedule or task reference")
                return
        }
        
        // For the HeartRate Measurement, use the ORKTask so that the schema stays consistent.
        if identifier == heartRateTaskIdentifier {
            
            // If this is a valid schedule then create the task view controller
            guard let taskViewController = createTaskViewController(for: schedule)
                else {
                    assertionFailure("Failed to create task view controller for \(schedule)")
                    return
            }
            
            self.delegate?.presentViewController(taskViewController, animated: true, completion: nil)
        }
        else {
            
            RSDFactory.shared = CRFTaskFactory()
            
            // Otherwise, This is a task that should run using ResearchSuite
            let taskInfo: RSDTaskInfoStep = (taskRef as? RSDTaskInfoStep) ?? {
                guard let dictionary = taskRef as? NSDictionary,
                    let resourceName = dictionary["resourceName"] as? String else {
                    fatalError("Cannot create task info")
                }
                
                var taskInfo = RSDTaskInfoStepObject(with: identifier)
                
                taskInfo.estimatedMinutes = taskRef.activityMinutes
                taskInfo.taskTransformer = RSDResourceTransformerObject(resourceName: resourceName)
                taskInfo.title = dictionary["title"] as? String
                taskInfo.subtitle = dictionary["subtitle"] as? String
                
                return taskInfo
            }()
            
            let taskViewController = RSDTaskViewController(taskInfo: taskInfo)
            taskViewController.taskPath.scheduleIdentifier = schedule.scheduleIdentifier
            taskViewController.delegate = self
            
            self.delegate?.presentViewController(taskViewController, animated: true, completion: nil)
        }
    }
    
    // MARK: RSDTaskViewControllerDelegate
    
    open func deleteOutputDirectory(_ outputDirectory: URL?) {
        guard let outputDirectory = outputDirectory else { return }
        do {
            try FileManager.default.removeItem(at: outputDirectory)
        } catch let error {
            print("Error removing ResearchKit output directory: \(error.localizedDescription)")
            debugPrint("\tat: \(outputDirectory)")
        }
    }
    
    func taskViewController(_ taskViewController: (UIViewController & RSDTaskController), didFinishWith reason: RSDTaskFinishReason, error: Error?) {
        
        // dismiss the view controller
        let outputDirectory = taskViewController.taskPath.outputDirectory
        taskViewController.dismiss(animated: true) {
            self.offMainQueue.async {
                self.deleteOutputDirectory(outputDirectory)
            }
        }
        
        if let err = error {
            debugPrint(err)
        }
    }
    
    func taskViewController(_ taskViewController: (UIViewController & RSDTaskController), readyToSave taskPath: RSDTaskPath) {
        // Check if the results of this survey should be uploaded
        guard let schedule = scheduledActivity(with: taskPath.scheduleIdentifier)
            else {
                assertionFailure("Failed to find a schedule for this task. Cannot save.")
                return
        }
        
        // TODO: syoung 10/30/2017 Handle subresults that point at a different schedule and schema
        // NOTE: Should not be required for this app.
        let didExitEarly = taskPath.didExitEarly
        let taskResult = taskPath.result as! SBAScheduledActivityResult
        schedule.startedOn = taskResult.startDate
        schedule.finishedOn = taskResult.endDate
        
        self.offMainQueue.async {
            
            // Archive the result
            if let archive = SBAActivityArchive(result: taskResult, schedule: schedule) {
                SBBDataArchive.encryptAndUploadArchives([archive])
            }
            
            DispatchQueue.main.async {
                // Send updates if not early exit
                if !didExitEarly {
                    self.sendUpdated(scheduledActivities: [schedule])
                }
            }
        }
    }
    
    func taskViewController(_ taskViewController: (UIViewController & RSDTaskController), viewControllerFor step: RSDStep) -> (UIViewController & RSDStepController)? {
        return nil
    }
    
    func taskViewControllerShouldAutomaticallyForward(_ taskViewController: (UIViewController & RSDTaskController)) -> Bool {
        return true
    }
    
    func taskViewController(_ taskViewController: (UIViewController & RSDTaskController), asyncActionControllerFor configuration: RSDAsyncActionConfiguration) -> RSDAsyncActionController? {
        return nil
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
        
        var recursiveAddFunc: ((String?, String, [RSDResult]) -> Void)!
        
        recursiveAddFunc = { (sectionIdentifier: String?, stepIdentifier: String, results: [RSDResult]) in
            for result in results {

                if let archivableResult = result as? SBAArchivableResult {
                    archivableResults.append((stepIdentifier, archivableResult))
                }
                else if let collection = result as? RSDCollectionResult {
                    recursiveAddFunc(sectionIdentifier, collection.identifier, collection.inputResults)
                }
                else if let taskResult = result as? RSDTaskResult {
                    recursiveAddFunc(taskResult.identifier, taskResult.identifier, taskResult.stepHistory)
                    if let asyncResults = taskResult.asyncResults {
                        recursiveAddFunc(taskResult.identifier, taskResult.identifier, asyncResults)
                    }
                }
                else if let answerResult = result as? RSDAnswerResult {
                    
                    let archivableResult = RSDAnswerResultWrapper(sectionIdentifier: sectionIdentifier, result: answerResult)
                    archivableResults.append((stepIdentifier, archivableResult))
                    
                    if let answer = (answerResult.value as? RSDJSONValue)?.jsonObject() {
                        answerMap[archivableResult.identifier] = answer
                        if let unit = answerResult.answerType.unit {
                            answerMap["\(archivableResult.identifier)Unit"] = unit
                        }
                    }
                }
                else if let fileResult = result as? RSDFileResult {
                    let archivableResult = RSDFileResultWrapper(sectionIdentifier: sectionIdentifier, result: fileResult)
                    archivableResults.append((stepIdentifier, archivableResult))
                }
            }
        }
        
        recursiveAddFunc(nil, identifier, stepHistory)
        if let asyncResults = self.asyncResults {
            recursiveAddFunc(nil, identifier, asyncResults)
        }
        
        if answerMap.count > 0 {
            let archiveAnswers = RSDConsolidatedResult(identifier: identifier, startDate: startDate, endDate: endDate, filename: "answerMap", json: answerMap)
            archivableResults.append((identifier, archiveAnswers))
        }
        
        if stepHistory.count > 0 {
            let archiveStepHistory = RSDJSONEncodedResult(taskResult: self, filename: "taskResult")
            archivableResults.append((identifier, archiveStepHistory))
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

public struct RSDAnswerResultWrapper : SBAArchivableResult {
    public let sectionIdentifier : String?
    public let result : RSDAnswerResult
    
    public var identifier: String {
        if let section = sectionIdentifier {
            return "\(section).\(result.identifier)"
        } else {
            return result.identifier
        }
    }
    
    public var startDate: Date {
        return result.startDate
    }
    
    public var endDate: Date {
        return result.endDate
    }

    public func bridgeData(_ stepIdentifier: String) -> ArchiveableResult? {
        
        var json: [String : Any] = [:]

        json[kIdentifierKey] = result.identifier
        json[kStartDateKey]  = result.startDate
        json[kEndDateKey]    = result.endDate
        json[kItemKey] = result.identifier
        if let answer = (result.value as? RSDJSONValue)?.jsonObject() {
            json[result.answerType.bridgeAnswerKey] = answer
            json[QuestionResultSurveyAnswerKey] = answer
            json[QuestionResultQuestionTypeNameKey] = result.answerType.bridgeAnswerType
            if let unit = result.answerType.unit {
                json[NumericResultUnitKey] = unit
            }
        }
        
        let filename = bridgifyFilename(self.identifier) + ".json"
        return ArchiveableResult(result: (json as NSDictionary).jsonObject(), filename: filename)
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

public struct RSDFileResultWrapper : SBAArchivableResult {
    public let sectionIdentifier : String?
    public let result : RSDFileResult
    
    public var identifier: String {
        return "\(sectionIdentifier ?? "").\(result.identifier)"
    }
    
    public var startDate: Date {
        return result.startDate
    }
    
    public var endDate: Date {
        return result.endDate
    }
    
    public func bridgeData(_ stepIdentifier: String) -> ArchiveableResult? {
        guard let url = result.url else {
            return nil
        }
        var ext = url.pathExtension
        if ext == "" {
            ext = "json"
        }
        let filename = bridgifyFilename(self.identifier) + "." + ext
        return ArchiveableResult(result: url as AnyObject, filename: filename)
    }
}

public struct RSDJSONEncodedResult : SBAArchivableResult, Encodable {
    public let taskResult: RSDTaskResult
    public let filename: String
    
    public var identifier: String {
        return taskResult.identifier
    }
    
    public var startDate: Date {
        return taskResult.startDate
    }
    
    public var endDate: Date {
        return taskResult.endDate
    }
    
    public func bridgeData(_ stepIdentifier: String) -> ArchiveableResult? {
        do {
            let encoder = RSDFactory.shared.createJSONEncoder()
            let data = try encoder.encode(self)
            return ArchiveableResult(result: data as NSData, filename: filename)
        } catch let err {
            debugPrint("Error encoding resule: \(err)")
            return nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        try taskResult.encode(to: encoder)
    }
}

public struct RSDConsolidatedResult : SBAArchivableResult {
    public let identifier: String
    public let startDate: Date
    public let endDate: Date
    public let filename: String
    public let json: [String : Any]
    
    public func bridgeData(_ stepIdentifier: String) -> ArchiveableResult? {
        return ArchiveableResult(result: (json as NSDictionary).jsonObject(), filename: filename)
    }
}
