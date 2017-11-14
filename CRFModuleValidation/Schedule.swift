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

class ScheduleResultSource: NSObject, SBATaskResultSource {
    
    let schedule: Schedule
    
    var identifier: String {
        return schedule.taskGroup.scheduleTaskIdentifier!.rawValue
    }
    
    init(schedule: Schedule) {
        self.schedule = schedule
        super.init()
    }
    
    func stepResult(forStepIdentifier stepIdentifier: String) -> ORKStepResult? {
        return schedule.stepResult(with: stepIdentifier)
    }
}

struct Schedule {
    
    public static let userInfoKeyTaskGroup = "userInfoKeyTaskGroup"
    static let timeOfDayKey = "timeOfDay"
    static let daysOfWeekKey = "daysOfWeek"
    
    static let timeOfDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    let taskGroup: TaskGroup
    let daysOfWeek: Set<Int>
    let timeOfDay: DateComponents?
    let hasData: Bool
    
    var isDaily: Bool {
        return self.daysOfWeek == Set(1...7)
    }
    
    var timeDate: Date? {
        guard self.timeOfDay != nil else { return nil }
        var dateComponents = self.timeOfDay!
        dateComponents.year = 2017
        dateComponents.day = 1
        dateComponents.month = 1
        return Calendar.gregorian.date(from: dateComponents)
    }
    
    var localizedString: String {
        
        let dayOfWeekText: String = {
            guard !self.isDaily else { return Localization.localizedString("JP_SCHEDULE_DAILY") }
            
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.setLocalizedDateFormatFromTemplate("EEEE")
            
            var dateComponents = DateComponents()
            dateComponents.calendar = Calendar.gregorian
            dateComponents.year = 2017
            dateComponents.month = 1
            dateComponents.weekdayOrdinal = 1
            
            let daysText = self.daysOfWeek.map({ (weekday) -> String in
                dateComponents.weekday = weekday
                guard let weekDate = dateComponents.date else { return "" }
                return weekdayFormatter.string(from: weekDate)
            })
            
            return Localization.localizedJoin(textList: daysText)
        }()
        
        guard let timeDate = self.timeDate else { return dayOfWeekText }
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        let timeText = timeFormatter.string(from: timeDate)
        
        return Localization.localizedStringWithFormatKey("JP_SCHEDULE_FORMAT_%@_at_%@", dayOfWeekText, timeText)
    }
    
    init?(taskGroup: TaskGroup, date:Date, activities:[SBBScheduledActivity], dayOne:Date) {
        
        guard let scheduleId = taskGroup.scheduleTaskIdentifier else { return nil }
        
        self.taskGroup = taskGroup
        
        // Look for client data
        let filtered = activities.filter({
            scheduleId.rawValue == $0.activityIdentifier &&
            $0.finishedOn != nil && $0.finishedOn <= date
        }).sorted { $0.finishedOn < $1.finishedOn }
        let json: [String : Any]? = filtered.last?.clientData as? [String : Any]
        
        self.hasData = (filtered.count > 0)
        
        self.timeOfDay = {
            guard let tod = json?[Schedule.timeOfDayKey] as? String else { return nil }
            let components = tod.components(separatedBy: ":")
            guard components.count == 2, let hour = Int(components[0]), let minute = Int(components[1])
            else {
                return nil
            }
            
            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute
            dateComponents.timeZone = NSTimeZone.default
            dateComponents.calendar = Calendar.current
            return dateComponents
        }()
        
        self.daysOfWeek = Schedule.parseDaysOfWeek(scheduleId: scheduleId, daysOfWeek: json?[Schedule.daysOfWeekKey] as? [Int], dayOne: dayOne)
    }
    
    init?(scheduledActivity: SBBScheduledActivity, taskResult:ORKTaskResult, dayOne:Date) {
        guard let scheduleId = scheduledActivity.taskId,
            let taskGroup = ScheduleSection.scheduleGroups.first(where: {$0.scheduleTaskIdentifier == scheduleId })
        else {
            return nil
        }
        
        self.taskGroup = taskGroup
        
        let daysOfWeekResult = taskResult.stepResult(forStepIdentifier: Schedule.daysOfWeekKey)?.results?.first as? ORKChoiceQuestionResult
        self.daysOfWeek = Schedule.parseDaysOfWeek(scheduleId: scheduleId,
                                                   daysOfWeek: daysOfWeekResult?.choiceAnswers as? [Int],
                                                   dayOne: dayOne)
        
        let timeOfDayResult = taskResult.stepResult(forStepIdentifier: Schedule.timeOfDayKey)?.results?.first as? ORKTimeOfDayQuestionResult
        self.timeOfDay = timeOfDayResult?.dateComponentsAnswer
        self.hasData = true
    }
    
    static func parseDaysOfWeek(scheduleId: TaskIdentifier, daysOfWeek: [Int]?, dayOne:Date) -> Set<Int> {
        guard let dow = daysOfWeek else {
//            if scheduleId == .scheduleCheckIn {
                return Set(1...7)
//            }
//            else {
//                let firstDate = /*(scheduleId == .scheduleWeeklyChallenge) ? dayOne.addingNumberOfDays(1) :*/ dayOne
//                let dayOfWeek = Calendar.gregorian.component(.weekday, from: firstDate)
//                return Set([dayOfWeek])
//            }
        }
        return Set(dow)
    }
    
    func clientData() -> SBBJSONValue? {
        guard let timeDate = self.timeDate else { return nil }
        let clientData: NSDictionary = [ Schedule.timeOfDayKey : Schedule.timeOfDayFormatter.string(from: timeDate),
                                         Schedule.daysOfWeekKey : self.daysOfWeek.map({ NSNumber(value: $0) })]
        return clientData
    }
    
    func stepResult(with stepIdentifier: String) -> ORKStepResult? {
        if stepIdentifier == Schedule.timeOfDayKey, let dateComponents = self.timeOfDay {
            let result = ORKTimeOfDayQuestionResult(identifier: stepIdentifier)
            result.dateComponentsAnswer = dateComponents
            return ORKStepResult(stepIdentifier: stepIdentifier, results: [result])
        }
        else if stepIdentifier == Schedule.daysOfWeekKey {
            let result = ORKChoiceQuestionResult(identifier: stepIdentifier)
            result.choiceAnswers = Array(self.daysOfWeek)
            return ORKStepResult(stepIdentifier: stepIdentifier, results: [result])
        }
        return nil
    }
    
    func scheduleReminder() {
        guard let timeComponents = self.timeOfDay
        else {
            return
        }

        if isDaily {
            addNotification(with: timeComponents)
        }
        else {
            for weekday in self.daysOfWeek {
                var dateComponents = timeComponents
                dateComponents.weekday = weekday
                addNotification(with: dateComponents)
            }
        }
    }
    
    fileprivate func addNotification(with dateComponents: DateComponents) {
        
        let content = UNMutableNotificationContent()
        content.body = Localization.localizedStringWithFormatKey("JP_TIME_FOR_%@", taskGroup.title)
        content.sound = UNNotificationSound.default()
        content.badge = UIApplication.shared.applicationIconBadgeNumber + 1 as NSNumber;
        content.categoryIdentifier = "org.sagebase.JourneyPro.Schedule"
        content.userInfo = [Schedule.userInfoKeyTaskGroup: taskGroup.identifier]
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: taskGroup.identifier, content: content, trigger: trigger)
        
        // Schedule the notification.
        UNUserNotificationCenter.current().add(request) { (error) in
            if error != nil {
                print("Failed to add notification for \(self.taskGroup.identifier). \(error!)")
            }
        }
    }
}

extension Schedule: Hashable {
    var hashValue: Int {
        return self.taskGroup.hashValue ^ self.daysOfWeek.reduce(0, { $0 ^ $1.hashValue }) ^ SBAObjectHash(self.timeOfDay)
    }
}

func ==(lhs: Schedule, rhs: Schedule) -> Bool {
    return lhs.taskGroup == rhs.taskGroup && lhs.daysOfWeek == rhs.daysOfWeek && SBAObjectEquality(lhs.timeOfDay, rhs.timeOfDay)
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
                              studyDuration:DateComponents) -> (sections:[ScheduleSection], today:[Schedule], dayOne: Date) {
        
        guard activities.count > 0 else { return ([], [], enrollmentDate) }
        
        // Look a the schedules and start on the first day that has something finished or today
        let sortedSchedules = activities.filter({ $0.finishedOn != nil }).sorted { $0.finishedOn < $1.finishedOn }
        let dayOne = Calendar.gregorian.startOfDay(for: sortedSchedules.first?.finishedOn ?? Date())
        let endDate = dayOne.adding(studyDuration).endOfDay()
        
        var sections: [ScheduleSection] = []
        
        // For each date, map the section
        var date: Date = dayOne
        while date <= endDate {
            var items = scheduleGroups.mapAndFilter({ (taskGroup) -> ScheduleItem? in
                return ScheduleItem(taskGroup: taskGroup, date:date, activities:activities, dayOne: dayOne, studyDuration: studyDuration)
            })
//            if items.count == 0 {
//                items = [ScheduleItem(date: date, taskGroup: TaskGroup.dailyCheckIn, isCompleted: false)]
//            }
            if items.count > 0 {
                sections.append(ScheduleSection(items: items))
            }
            date = date.addingNumberOfDays(1)
        }
        
        // Get the schedules that are active today
        let today = scheduleGroups.mapAndFilter({
            Schedule(taskGroup: $0, date: Date(), activities: activities, dayOne: dayOne)
        })
        
        return (sections, today, dayOne)
    }
    
    static func buildFutureSchedules(with schedules:[Schedule], endDate: Date) -> [ScheduleSection] {
        
        var sections: [ScheduleSection] = []
        
        // For each date, map the section
        var date: Date = Date().startOfDay().addingNumberOfDays(1)
        while date < endDate {
            let items = schedules.mapAndFilter({ (schedule) -> ScheduleItem? in
                let thisDayOfWeek = Calendar.gregorian.component(.weekday, from: date)
                guard schedule.daysOfWeek.contains(thisDayOfWeek) else { return nil }
                return ScheduleItem(date: date, taskGroup: schedule.taskGroup, isCompleted: false)
            })
            sections.append(ScheduleSection(items: items))
            date = date.addingNumberOfDays(1)
        }
        
        return sections
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
    
    let date: Date
    let taskGroup: TaskGroup
    let isCompleted: Bool
    
    init(date: Date, taskGroup: TaskGroup, isCompleted: Bool) {
        self.date = date
        self.taskGroup = taskGroup
        self.isCompleted = isCompleted
    }

    init?(taskGroup: TaskGroup, date:Date, activities:[SBBScheduledActivity], dayOne: Date, studyDuration:DateComponents) {
        
        let tasksFilter = taskGroup.tasksPredicate()
        let finishedOnFilter = SBBScheduledActivity.finishedPredicate(on: date)
        let filter = NSCompoundPredicate(andPredicateWithSubpredicates: [tasksFilter, finishedOnFilter])
        var filteredActivities = activities.filter { filter.evaluate(with: $0) }
        
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
        else {
            // On a non-clinic day, only show tasks scheduled on that day
            
        }
        
        var isCompleted = (taskGroup.taskIdentifiers.count == filteredActivities.count)
        
        if let schedule = Schedule(taskGroup: taskGroup, date: date, activities: activities, dayOne: dayOne) {
            // If there is a schedule, then look to see if the schedule is set for this day, otherwise, return nil
            let thisDayOfWeek = Calendar.gregorian.component(.weekday, from: date)
            if (!schedule.daysOfWeek.contains(thisDayOfWeek)) {
//                if (Calendar.gregorian.isDateInToday(date) && (taskGroup == TaskGroup.weeklyChallenge || taskGroup == TaskGroup.treatmentDetails)) {
//                    // The logic for determining whether to show a weekly challenge or a weekly treatment is less than ideal,
//                    // which is driven by the fact that the schedule for these are actually daily items. The old approach of
//                    // "show the daily activity if its the right day of the week, otherwise don't" doesn't meet the requirements
//                    // of IA-347 which is to keep showing it later in the week after its scheduled if they didn't complete it.
//                    //
//                    // The approach taken is check every day back to the appropriate date of the week to see if it has
//                    // been completed since it was scheduled. If it was, hide it. If not, go ahead and show it today during
//                    // the journey even though it normally would not be shown. There is also an edge case check to make sure
//                    // we don't show it until the first time that we are supposed to show it based on the day of the week
//                    // settings.
//
//                    if (isCompleted || (dayOne >= date)) {
//                        // If we've already completed it, or this is the first day and the scheduled
//                        // date for the taskGroup is later in the week, don't show the taskGroup
//                        return nil
//                    } else {
//                        // Iterate back to the appropriate day of the week to see if it has been completed
//                        // since it was scheduled
//                        var dateToCheck = date
//                        var dayOfWeekToCheck = Calendar.gregorian.component(.weekday, from: dateToCheck)
//                        var totalChecks = 0 // guard against infinite loop if there is no day of the week for some reason
//
//                        while (!isCompleted && (dateToCheck > dayOne) && (totalChecks <= Calendar.gregorian.weekdaySymbols.count)
//                            && !schedule.daysOfWeek.contains(dayOfWeekToCheck)) {
//                            totalChecks += 1
//                            // go backwards 1 day
//                            dateToCheck = NSCalendar.current.date(byAdding: .day, value: -1, to: dateToCheck)!
//                            dayOfWeekToCheck = Calendar.gregorian.component(.weekday, from: dateToCheck)
//
//                            // Now see if it was completed on this date
//                            let dateToCheckFinishedOnFilter = SBBScheduledActivity.finishedPredicate(on: dateToCheck)
//                            let dateToCheckFilter = NSCompoundPredicate(andPredicateWithSubpredicates: [tasksFilter, dateToCheckFinishedOnFilter])
//                            let dateToCheckFilteredActivities = activities.filter { dateToCheckFilter.evaluate(with: $0) }
//                            isCompleted = (taskGroup.taskIdentifiers.count == dateToCheckFilteredActivities.count)
//
//                            if (!isCompleted && dateToCheck <= dayOne && !schedule.daysOfWeek.contains(dayOfWeekToCheck)) {
//                                // Edge case - if we are rewinding and hit the start of the journey but haven't yet
//                                // made it back to the appropriate day of the week, then we don't want to show the
//                                // taskGroup since the first instance it should appear is still in the future
//                                isCompleted = true
//                            }
//                        }
//
//                        // Now return nil if it was completed
//                        if (isCompleted) {
//                            return nil
//                        }
//                    }
//                } else {
                    // If it isn't the proper day of the week, then don't show the task group
                    return nil
//                }
            }
        }
        else if taskGroup.filtered(activities, on: date).count == 0 {
            // If there is no schedule, then return nil. This is not included in the task groups shown
            // in the history or future schedule
            return nil
        }
        
//        if (taskGroup == TaskGroup.demographic || taskGroup == TaskGroup.monthlyHealth) && !(isCompleted || Calendar.gregorian.isDateInToday(date)) {
//            // If the schedule is for the demographics or monthly surveys, then only include it on either the day it was
//            // marked finished or today (if still unfinished)
//            return nil
//        }
        
        self.date = date
        self.taskGroup = taskGroup
        self.isCompleted = isCompleted
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
