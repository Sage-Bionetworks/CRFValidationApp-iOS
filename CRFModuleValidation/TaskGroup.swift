//
//  TaskGroup.swift
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
import BridgeSDK
import BridgeAppSDK
import ResearchUXFactory


extension SBBScheduledActivity {
    
    var taskId: TaskIdentifier? {
        guard let identifier = (self.taskIdentifier ?? self.surveyIdentifier) else { return nil }
        return TaskIdentifier(rawValue: identifier)
    }
    
    var taskGroup: TaskGroup? {
        guard let taskId = self.taskId else { return nil }
        return ScheduleSection.scheduleGroups.first(where: {
            $0.contains(taskId.rawValue)
        })
    }
}


struct TaskGroup {
    
    let identifier: String
    let title: String
    let journeyTitle: String
    let groupDescription: String?
    let iconImage: UIImage?
    let scheduleTaskIdentifier: TaskIdentifier?
    let taskIdentifiers: [TaskIdentifier]
    
    // task identifiers to exclude from list of all tasks
    let excludedTaskIdentifiers: [TaskIdentifier] = []
    
    /**
     The "Clinic Visit 1" activities.
     */
    static let clinicDay0 = TaskGroup(identifier: "clinicDay0",
                                   title: Localization.localizedString("Clinic fitness test"),
                                   journeyTitle: Localization.localizedString("Clinic fitness test"),
                                   groupDescription: Localization.localizedString("Clinic tests will provide data that scientists  use to assess the accuracy of digital versions. This may help future generations in receiving better tools."),
                                   iconImage: #imageLiteral(resourceName: "clinicDetailIcon"),
                                   scheduleTaskIdentifier: nil,
                                   taskIdentifiers: [.backgroundSurvey,
                                                     .cardioStressTest])
    
    static let clinicDay0alt = TaskGroup(identifier: "clinicDay0alt",
                                   title: Localization.localizedString("Clinic fitness test"),
                                   journeyTitle: Localization.localizedString("Clinic fitness test"),
                                   groupDescription: Localization.localizedString("Clinic tests will provide data that scientists  use to assess the accuracy of digital versions. This may help future generations in receiving better tools."),
                                   iconImage: #imageLiteral(resourceName: "clinicDetailIcon"),
                                   scheduleTaskIdentifier: nil,
                                   taskIdentifiers: [.backgroundSurvey,
                                                     .cardioStairStep,
                                                     .cardio12MT])
    /**
     The "Clinic Visit 2" Activities
     */
    static let clinicDay14 = TaskGroup(identifier: "clinicDay14",
                                   title: Localization.localizedString("Clinic fitness test"),
                                   journeyTitle: Localization.localizedString("Clinic fitness test"),
                                   groupDescription: Localization.localizedString("Clinic tests will provide data that scientists  use to assess the accuracy of digital versions. This may help future generations in receiving better tools."),
                                   iconImage: #imageLiteral(resourceName: "clinicDetailIcon"),
                                   scheduleTaskIdentifier: nil,
                                   taskIdentifiers: [.usabilitySurvey,
                                                     .burdenSurvey,
                                                     .cardioStairStep,
                                                     .cardio12MT])
    
    static let clinicDay14alt = TaskGroup(identifier: "clinicDay14alt",
                                   title: Localization.localizedString("Clinic fitness test"),
                                   journeyTitle: Localization.localizedString("Clinic fitness test"),
                                   groupDescription: Localization.localizedString("Clinic tests will provide data that scientists  use to assess the accuracy of digital versions. This may help future generations in receiving better tools."),
                                   iconImage: #imageLiteral(resourceName: "clinicDetailIcon"),
                                   scheduleTaskIdentifier: nil,
                                   taskIdentifiers: [.usabilitySurvey,
                                                     .burdenSurvey,
                                                     .cardioStressTest])
    
    /**
     The Heartrate Measurement
     */
    static let heartRateMeasurement = TaskGroup(identifier: "HeartRate Measurement",
                                                title: Localization.localizedString("JP_TASK_GROUP_DEMOGRAPHICS"),
                                                journeyTitle: Localization.localizedString("JP_TASK_GROUP_JOURNEY_DEMOGRAPHICS"),
                                                groupDescription: nil,
                                                iconImage: #imageLiteral(resourceName: "heartRateIconCapturing"),
                                                scheduleTaskIdentifier: nil,
                                                taskIdentifiers: [.heartRateMeasurement])
    
    /**
     The Cardio 12 Minute Run Test
     */
    static let cardio12MT = TaskGroup(identifier: "Cardio 12MT",
                                      title: Localization.localizedString("12 min run/walk"),
                                      journeyTitle: Localization.localizedString("12 min run/walk"),
                                      groupDescription: nil,
                                      iconImage: #imageLiteral(resourceName: "active12MinuteRun"),
                                      scheduleTaskIdentifier: nil,
                                      taskIdentifiers: [.cardio12MT])
    
    /**
     The Cardio Stair Step Test
     */
    static let cardioStairStep = TaskGroup(identifier: "Cardio Stair Step",
                                      title: Localization.localizedString("Stair step"),
                                      journeyTitle: Localization.localizedString("Stair step"),
                                      groupDescription: nil,
                                      iconImage: #imageLiteral(resourceName: "stairStepClinicIcon"),
                                      scheduleTaskIdentifier: nil,
                                      taskIdentifiers: [.cardioStairStep])
    
    /**
     List of all activities
     */
    static let addActivities = TaskGroup(identifier: "Add",
                                         title: Localization.localizedString("JP_ACTIVITIES_TITLE"),
                                         journeyTitle: Localization.localizedString("JP_ACTIVITIES_TITLE"),
                                         groupDescription: nil,
                                         iconImage: #imageLiteral(resourceName: "healthRiskIcon"),
                                         scheduleTaskIdentifier: nil,
                                         taskIdentifiers: [.backgroundSurvey,
                                                           .cardioStressTest,
                                                           .usabilitySurvey,
                                                           .burdenSurvey,
                                                           .heartRateMeasurement,
                                                           .cardio12MT,
                                                           .cardioStairStep])
    
    /**
     List of all activities
     */
    static let allActivities = TaskGroup(identifier: "All",
                                         title: Localization.localizedString("JP_ACTIVITIES_TITLE"),
                                         journeyTitle: Localization.localizedString("JP_ACTIVITIES_TITLE"),
                                         groupDescription: nil,
                                         iconImage: #imageLiteral(resourceName: "healthRiskIcon"),
                                         scheduleTaskIdentifier: nil,
                                         taskIdentifiers: [.backgroundSurvey,
                                                           .cardioStressTest,
                                                           .usabilitySurvey,
                                                           .burdenSurvey,
                                                           .heartRateMeasurement,
                                                           .cardio12MT,
                                                           .cardioStairStep])
    
    static func allTaskGroups() -> [TaskGroup] {
        if SBAUser.shared.containsDataGroup("clinic1") {
            return [clinicDay0, heartRateMeasurement, cardio12MT, cardioStairStep, clinicDay14, allActivities]
        } else {
            return [clinicDay0alt, heartRateMeasurement, cardio12MT, cardioStairStep, clinicDay14alt, allActivities]
        }
    }
    
    func contains(_ taskIdentifier: String) -> Bool {
        guard let taskId = TaskIdentifier(rawValue: taskIdentifier) else { return false }
        return taskIdentifiers.contains(taskId)
    }
    
    func scheduledPredicate(on date:Date) -> NSPredicate {
        // unless date is in the past, we can use the standard scheduledPredicate
        let startOfDay = date.startOfDay()
        guard startOfDay.compare(Date().startOfDay()) == .orderedAscending else {
            return SBBScheduledActivity.scheduledPredicate(on: date)
        }
        
        // if it's in the past, we want to show an activity on the day completed or the day originally scheduled,
        // not the day it expired
        let startOfNextDay = startOfDay.addingNumberOfDays(1)
        
        // Scheduled for this date or prior
        let scheduledKey = #keyPath(SBBScheduledActivity.scheduledOn)
        let scheduledOnThisDay = NSPredicate(format: "%K <> nil AND %K >= %@ AND %K < %@", scheduledKey, scheduledKey, startOfDay as CVarArg, scheduledKey, startOfNextDay as CVarArg)
        let unfinished = SBBScheduledActivity.unfinishedPredicate()
        let finishedOnThisDay = SBBScheduledActivity.finishedPredicate(on: date)
        
        // build a filter for a day in the past that includes scheduled on that day OR completed on that day
        let scheduledThisDayAndNotFinished = NSCompoundPredicate(andPredicateWithSubpredicates: [unfinished, scheduledOnThisDay])
        return NSCompoundPredicate(orPredicateWithSubpredicates: [finishedOnThisDay, scheduledThisDayAndNotFinished])
    }
    
    func scheduleFilterPredicate(for date: Date) -> NSPredicate {
        let dateFilter = scheduledPredicate(on: date)
        let taskFilter = tasksPredicate()
        if identifier.hasPrefix("clinicDay") {
            return NSCompoundPredicate(andPredicateWithSubpredicates: [taskFilter, dateFilter])
        }
        else {
            let scheduledKey = "scheduledOn"
            let onDateOnlyFilter = NSPredicate(format: "%K <> nil AND %K >= %@ AND %K < %@", scheduledKey, scheduledKey, date.startOfDay() as CVarArg, scheduledKey, date.addingNumberOfDays(1).startOfDay() as CVarArg)
            return NSCompoundPredicate(andPredicateWithSubpredicates: [taskFilter, onDateOnlyFilter])
        }
    }
    
    func tasksPredicate() -> NSPredicate {
        if taskIdentifiers.count > 0 {
            let includeTasks = taskIdentifiers.map({ $0.rawValue })
            return SBBScheduledActivity.includeTasksPredicate(with: includeTasks)
        }
        else {
            let excludeTasks = excludedTaskIdentifiers.map({ $0.rawValue })
            return NSCompoundPredicate(notPredicateWithSubpredicate: SBBScheduledActivity.includeTasksPredicate(with: excludeTasks))
        }
    }
    
    func filtered(_ activities:[SBBScheduledActivity], on date: Date) -> [SBBScheduledActivity] {
        let predicate = scheduleFilterPredicate(for: date)
        var foundActivities: [SBBScheduledActivity] = []
        for schedule in activities {
            
            // Only add the schedule if it passes the predicate
            guard predicate.evaluate(with: schedule) else { continue }
            
            foundActivities.append(schedule)
        }
        return foundActivities
    }
    
    func sorted(_ activities:[SBBScheduledActivity]) -> [SBBScheduledActivity] {
        let orderedIdentifiers = taskIdentifiers.map({ $0.rawValue })
        return activities.sorted(by: { (scheduleA, scheduleB) -> Bool in
            guard let identifierA = scheduleA.activityIdentifier, let indexA = orderedIdentifiers.index(of: identifierA),
                let identifierB = scheduleB.activityIdentifier, let indexB = orderedIdentifiers.index(of: identifierB)
                else {
                    return false
            }
            return indexA < indexB
        })
    }
    
    func filteredAndSorted(_ activities:[SBBScheduledActivity], on date: Date) -> [SBBScheduledActivity] {
        let filteredActivities = filtered(activities, on: date)
        let sortedActivities = sorted(filteredActivities)
        return sortedActivities
    }
    
    func activityMinutesLabel() -> String? {
        guard let bridgeInfo = (UIApplication.shared.delegate as? AppDelegate)?.bridgeInfo else { return nil }
        
        let minutesTotal = self.taskIdentifiers.reduce(0) { (minutes, taskId) -> Int in
            let taskRef = bridgeInfo.taskReferenceWithIdentifier(taskId.rawValue)
            let add = taskRef?.activityMinutes ?? 0
            return minutes + add
        }

        let minutesFormatter = DateComponentsFormatter()
        minutesFormatter.unitsStyle = .full
        minutesFormatter.allowedUnits = [.minute]
        
        return minutesFormatter.string(from: TimeInterval(minutesTotal * 60))!.lowercased()
    }
}

extension TaskGroup: Hashable {
    var hashValue: Int {
        return self.identifier.hash
    }
}

func ==(lhs: TaskGroup, rhs: TaskGroup) -> Bool {
    return lhs.taskIdentifiers == rhs.taskIdentifiers
}

