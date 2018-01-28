//
//  ScheduleGroup.swift
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
import UserNotifications

extension Calendar {
    static var gregorian: Calendar {
        return Calendar(identifier: .gregorian)
    }
}

extension Date {
    
    func adding(_ dateComponents: DateComponents) -> Date {
        let calendar = dateComponents.calendar ?? Calendar.current
        return calendar.date(byAdding: dateComponents, to: self) ?? self
    }
    
    /**
     @returns Date with a time of the last second of the day.
     */
    func endOfDay() -> Date {
        return self.startOfDay().addingNumberOfDays(1).addingTimeInterval(-1)
    }
}

struct ScheduleSection {
    
    let items: [ScheduleItem]
    
    var date: Date {
        return items.first!.date
    }
    
    var isCompleted: Bool {
        return items.reduce(true, { $0 && $1.isCompleted })
    }
    
    static let scheduleGroups = [TaskGroup.clinicDay0,
                                 TaskGroup.clinicDay0alt,
                                 TaskGroup.cardio12MT,
                                 TaskGroup.cardioStairStep,
                                 TaskGroup.heartRateMeasurement,
                                 TaskGroup.clinicDay14,
                                 TaskGroup.clinicDay14alt]
    
    static func buildSchedule(with activities:[SBBScheduledActivity],
                              enrollmentDate:Date,
                              studyDuration:DateComponents) -> (sections:[ScheduleSection], dayOne: Date) {
        
        guard activities.count > 0 else { return ([], enrollmentDate) }
        
        // Look a the schedules and start on the first day that has something finished or today
        let sortedSchedules = activities.filter({ $0.finishedOn != nil }).sorted { $0.finishedOn < $1.finishedOn }
        let dayOne = Calendar.gregorian.startOfDay(for: sortedSchedules.first?.finishedOn ?? Date())
        let endDate = dayOne.adding(studyDuration).endOfDay()
        
        var sections: [ScheduleSection] = []
        
        // For each date, map the section
        var date: Date = dayOne
        while date <= endDate {
            let items = scheduleGroups.mapAndFilter({ (taskGroup) -> ScheduleItem? in
                return ScheduleItem(taskGroup: taskGroup, date:date, activities:activities, dayOne: dayOne, studyDuration: studyDuration)
            })
            if items.count > 0 {
                sections.append(ScheduleSection(items: items))
            }
            date = date.addingNumberOfDays(1)
        }
        
        return (sections, dayOne)
    }

    func contains(taskGroup: TaskGroup) -> Bool {
        return items.first(where: { $0.taskGroup == taskGroup }) != nil
    }
}

extension ScheduleSection: Hashable {
    var hashValue: Int {
        return self.items.reduce(0, { $0 ^ $1.hashValue })
    }
}

func ==(lhs: ScheduleSection, rhs: ScheduleSection) -> Bool {
    return lhs.items == rhs.items
}

struct ScheduleItem {
    
    public static let userInfoKeyTaskGroup = "userInfoKeyTaskGroup"
    
    let date: Date
    let taskGroup: TaskGroup
    let isCompleted: Bool
    let identifier: String
    
    init(date: Date, taskGroup: TaskGroup, isCompleted: Bool) {
        self.date = date
        self.taskGroup = taskGroup
        self.isCompleted = isCompleted
        self.identifier = "\(taskGroup.identifier):\(date)"
    }

    init?(taskGroup: TaskGroup, date:Date, activities:[SBBScheduledActivity], dayOne: Date, studyDuration:DateComponents) {
        
        let tasksFilter = taskGroup.tasksPredicate()
        let finishedOnFilter = SBBScheduledActivity.finishedPredicate(on: date)
        let filter = NSCompoundPredicate(andPredicateWithSubpredicates: [tasksFilter, finishedOnFilter])
        let filteredActivities = activities.filter { filter.evaluate(with: $0) }
        
        // Special-case handling of clinic visit task groups:
        guard let dataGroups = SBAUser.shared.dataGroups else { return nil }
        
        if date.startOfDay() == dayOne.startOfDay() {
            // on day one, only the appropriate first clinic visit task group for their data group is valid
            switch taskGroup.identifier {
            case "clinicDay0":
                if !dataGroups.contains("clinic1") {
                    return nil
                }
            case "clinicDay0alt":
                if !dataGroups.contains("clinic2") {
                    return nil
                }
            default:
                return nil
            }
        }
        else if date.startOfDay() == dayOne.adding(studyDuration).startOfDay() {
            // on the last day, only the appropriate final clinic visit task group for their data group is valid
            switch taskGroup.identifier {
            case "clinicDay14":
                if !dataGroups.contains("clinic1") {
                    return nil
                }
            case "clinicDay14alt":
                if !dataGroups.contains("clinic2") {
                    return nil
                }
            default:
                return nil
            }
        }
        else if taskGroup.identifier.hasPrefix("clinicDay") {
            // on any other day, none of the clinic visit task groups are valid
            return nil
        }
        else if taskGroup.filtered(activities, on: date).count == 0 {
            // On a non-clinic day, only show tasks scheduled on that day
            return nil
        }
        
        let isCompleted = (taskGroup.taskIdentifiers.count == filteredActivities.count)
        
        self.date = date
        self.taskGroup = taskGroup
        self.isCompleted = isCompleted
        self.identifier = "\(taskGroup.identifier):\(date)"
    }
    
    func scheduleReminder() {
        let content = UNMutableNotificationContent()
        let calendar = Calendar(identifier: .gregorian)
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: self.date)
        dateComponents.hour = 10
        content.body = "Don't forget to do your \(taskGroup.title) today!"
        content.sound = UNNotificationSound.default()
        content.badge = UIApplication.shared.applicationIconBadgeNumber + 1 as NSNumber;
        content.categoryIdentifier = "org.sagebase.crfModuleApp.Schedule"
        content.userInfo = [ScheduleItem.userInfoKeyTaskGroup: taskGroup.identifier]
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: self.identifier, content: content, trigger: trigger)
        
        // Schedule the notification.
        UNUserNotificationCenter.current().add(request) { (error) in
            if error != nil {
                print("Failed to add notification for \(self.taskGroup.identifier). \(error!)")
            }
        }
    }
}

extension ScheduleItem: Hashable {
    var hashValue: Int {
        return self.taskGroup.hashValue ^ self.date.hashValue ^ self.isCompleted.hashValue
    }
}

func ==(lhs: ScheduleItem, rhs: ScheduleItem) -> Bool {
    return lhs.taskGroup == rhs.taskGroup && lhs.date == rhs.date && lhs.isCompleted == rhs.isCompleted
}
