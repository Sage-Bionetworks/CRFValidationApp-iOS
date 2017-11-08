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
    
    var taskGroup: TaskGroup? {
        guard let taskId = self.taskId else { return nil }
        return ScheduleSection.scheduleGroups.first(where: {
            $0.scheduleTaskIdentifier == taskId || $0.contains(taskId.rawValue)
        })
    }
    
    var isTimingSchedule: Bool {
        guard let scheduleTaskIdentifier = self.taskGroup?.scheduleTaskIdentifier
        else {
            return false
        }
        return scheduleTaskIdentifier == self.taskId!
    }
}


struct TaskGroup {
    
    let identifier: String
    let title: String
    let journeyTitle: String
    let iconImage: UIImage?
    let scheduleTaskIdentifier: TaskIdentifier?
    let taskIdentifiers: [TaskIdentifier]
    
    // task identifiers to exclude from list of all tasks
    let excludedTaskIdentifiers: [TaskIdentifier] = [.scheduleCheckIn,
                                                     .scheduleWeeklyChallenge,
                                                     .scheduleTreatmentDetails,
                                                     .passiveData,
                                                     ]
    
    /**
     The "Weekly Challenge" activities.
     */
    static let weeklyChallenge = TaskGroup(identifier: "Weekly Challenge",
                                           title: Localization.localizedString("JP_TASK_GROUP_WEEKLY_CHALLENGE"),
                                           journeyTitle: Localization.localizedString("JP_TASK_GROUP_JOURNEY_WEEKLY_CHALLENGE"),
                                           iconImage: #imageLiteral(resourceName: "activeChallengeIcon"),
                                           scheduleTaskIdentifier: .scheduleWeeklyChallenge,
                                           taskIdentifiers: [.healthSurveyWeekly,
                                                             .visualMemory,
                                                             .reactionTime,
                                                             .attention,
                                                             .cardioChallenge])
    /**
     The "Daily Check-in" Activities
     */
    static let dailyCheckIn = TaskGroup(identifier: "Quick Check-In",
                                        title: Localization.localizedString("JP_TASK_GROUP_DAILY_CHECK_IN"),
                                        journeyTitle: Localization.localizedString("JP_TASK_GROUP_JOURNEY_DAILY_CHECK_IN"),
                                        iconImage: #imageLiteral(resourceName: "checkInIcon"),
                                        scheduleTaskIdentifier: .scheduleCheckIn,
                                        taskIdentifiers: [.checkIn])
    
    /**
     The "Treatment Details" Activities
     */
    static let treatmentDetails = TaskGroup(identifier: "Treatment Check-In",
                                        title: Localization.localizedString("JP_TASK_GROUP_TREATMENT_DETAILS"),
                                        journeyTitle: Localization.localizedString("JP_TASK_GROUP_JOURNEY_TREATMENT_DETAILS"),
                                        iconImage: #imageLiteral(resourceName: "anemiaLabMedTransfusionIcon"),
                                        scheduleTaskIdentifier: .scheduleTreatmentDetails,
                                        taskIdentifiers: [.labDetails,
                                                          .transfusionDetails,
                                                          .anemiaPrescription])
    
    /**
     The Demographics survey
     */
    static let demographic = TaskGroup(identifier: "Demographics",
                                       title: Localization.localizedString("JP_TASK_GROUP_DEMOGRAPHICS"),
                                       journeyTitle: Localization.localizedString("JP_TASK_GROUP_JOURNEY_DEMOGRAPHICS"),
                                       iconImage: #imageLiteral(resourceName: "demographicIcon"),
                                       scheduleTaskIdentifier: nil,
                                       taskIdentifiers: [.demographics])
    
    /**
     The Monthly Health Survey
     */
    static let monthlyHealth = TaskGroup(identifier: "Monthly Surveys",
                                       title: Localization.localizedString("JP_TASK_GROUP_MONTHLY_SURVEY"),
                                       journeyTitle: Localization.localizedString("JP_TASK_GROUP_JOURNEY_MONTHLY_SURVEY"),
                                       iconImage: #imageLiteral(resourceName: "healthSurveyIcon"),
                                       scheduleTaskIdentifier: nil,
                                       taskIdentifiers: [.healthSurveyMonthly])
    
    /**
     List of all activities
     */
    static let addActivities = TaskGroup(identifier: "Add",
                                         title: Localization.localizedString("JP_ACTIVITIES_TITLE"),
                                         journeyTitle: Localization.localizedString("JP_ACTIVITIES_TITLE"),
                                         iconImage: #imageLiteral(resourceName: "activeChallengeIcon"),
                                         scheduleTaskIdentifier: nil,
                                         taskIdentifiers: [.labDetails,
                                                           .transfusionDetails,
                                                           .anemiaPrescription,
                                                           .visualMemory,
                                                           .reactionTime,
                                                           .attention,
                                                           .cardioChallenge])
    
    /**
     List of all activities
     */
    static let allActivities = TaskGroup(identifier: "All",
                                         title: Localization.localizedString("JP_ACTIVITIES_TITLE"),
                                         journeyTitle: Localization.localizedString("JP_ACTIVITIES_TITLE"),
                                         iconImage: #imageLiteral(resourceName: "activeChallengeIcon"),
                                         scheduleTaskIdentifier: nil,
                                         taskIdentifiers: [])
    
    static func allTaskGroups() -> [TaskGroup] {
        return [weeklyChallenge, dailyCheckIn, treatmentDetails, demographic, monthlyHealth, addActivities, allActivities]
    }
    
    func contains(_ taskIdentifier: String) -> Bool {
        guard let taskId = TaskIdentifier(rawValue: taskIdentifier) else { return false }
        return taskIdentifiers.contains(taskId)
    }
    
    func scheduleFilterPredicate(for date: Date) -> NSPredicate {
        let dateFilter = SBBScheduledActivity.scheduledPredicate(on: date)
        let taskFilter = tasksPredicate()
        return NSCompoundPredicate(andPredicateWithSubpredicates: [taskFilter, dateFilter])
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
            guard predicate.evaluate(with: schedule),
                let identifier = schedule.activityIdentifier
            else {
                continue
            }
            
            // Only add one schedule - give preference to the schedule that is finished
            if let previousIndex = foundActivities.index(where: { $0.activityIdentifier == identifier }) {
                if schedule.finishedOn != nil && foundActivities[previousIndex].finishedOn == nil {
                    foundActivities.remove(at: previousIndex)
                    foundActivities.append(schedule)
                }
            }
            else {
                foundActivities.append(schedule)
            }
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
    
    func timingSchedule(from activities:[SBBScheduledActivity]) -> SBBScheduledActivity? {
        guard let scheduleId = self.scheduleTaskIdentifier else { return nil }
        let filteredList = activities.reversed().filter({ $0.taskId == scheduleId })
        return filteredList.first(where: { $0.finishedOn == nil }) ?? filteredList.last
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

