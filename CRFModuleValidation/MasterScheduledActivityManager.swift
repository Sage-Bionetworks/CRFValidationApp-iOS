//
//  MasterScheduledActivityManager.swift
//  JourneyPRO
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

enum ScheduleLoadState {
    case firstLoad
    case cachedLoad
    case fromServer
}

class MasterScheduledActivityManager: ScheduledActivityManager {
    
    static let shared = MasterScheduledActivityManager(delegate: nil)
    
    // Save a pointer to today's activities in case the paged group does not include them
    var scheduleSections: [ScheduleSection] = []
    var schedules: [Schedule] = []
    
    let scheduleUpdatedNotificationName = Notification.Name("MasterScheduledActivityManager.scheduleUpdated")
    
    let studyDuration: DateComponents = {
        var studyDuration = DateComponents()
        studyDuration.day = 15
        return studyDuration
    }()
    
    var enrollment: Date = {
        return (UIApplication.shared.delegate as! AppDelegate).currentUser.createdOn.startOfDay()
    }()
    
    var startStudy: Date {
        return Calendar.gregorian.startOfDay(for: dayOne ?? enrollment)
    }
    
    var endStudy: Date {
        return self.startStudy.adding(studyDuration).endOfDay()
    }
    
    var scheduleAhead: Date {
        return Date().startOfDay().addingNumberOfDays(self.daysAhead + 1)
    }
    
    var dayOne: Date?
    var today = Date()
    
    // When true, the completion step for all scheduling tasks will be skipped
    var alwaysIgnoreTimingIntroductionStepForScheduling = false

    // When set, the user should be automatically sent to the screen to do these tasks
    // After this var is consumed, it should be set back to nil
    var deepLinkTaskGroup: TaskGroup?
    
    // When this contians an object, it will exist until the specific task it is
    // associated with becomes available, and then its closure will be invoked
    fileprivate var notifyAvailableTasks = [NotifyTaskAvailable]()
    
    // As a work-around to a limitation of always completing the newest daily check-in,
    // set this var before completing the SBATaskViewController to grab the schedule at this date
    var scheduleDateForMostRecentQuickCheckIn: Date?
    
    override init(delegate: SBAScheduledActivityManagerDelegate?) {
        super.init(delegate: delegate)
        
        // Set days behind and days ahead to only cache today's activities
        self.daysBehind = 0
        self.daysAhead = 7
    }
    
    func resetScheduleFilter() {
        let todayStart = Date().startOfDay() as NSDate
        let finishedTodayOrFuture = NSPredicate(format: "finishedOn == nil OR finishedOn >= %@", todayStart)
        let expiresTodayOrFuture = NSPredicate(format: "expiresOn == nil OR expiresOn >= %@", todayStart)
        self.scheduleFilterPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [finishedTodayOrFuture, expiresTodayOrFuture])
    }
    
    func completedCount(for taskGroup: TaskGroup) -> Int {
        return scheduleSections.filter({ $0.items.find({ $0.taskGroup == taskGroup })?.isCompleted ?? false }).count
    }
    
    func isTodayCompleted(for taskGroup: TaskGroup) -> Bool {
        guard let todaySection = self.scheduleSections.first(where: { Calendar.gregorian.isDateInToday($0.date) }),
            let todayItem = todaySection.items.first(where: { $0.taskGroup == taskGroup })
        else {
            return false
        }
        return todayItem.isCompleted
    }
    
    func schedule(for taskGroup: TaskGroup) -> Schedule? {
        return self.schedules.first(where: { $0.taskGroup == taskGroup })
    }
    
    func shouldFireTimingSchedule(for taskGroup:TaskGroup) -> Bool {
        guard let schedule = schedule(for: taskGroup)
        else {
            return false
        }
        return !schedule.hasData && completedCount(for: taskGroup) <= 1
    }
    
    override func resetData() {
        scheduleSections.removeAll()
        schedules.removeAll()
        dayOne = nil
    }
    
    override func reloadData() {
        // Unless today's date has changed, rely upon the previously loaded data
        guard !Calendar.current.isDateInToday(today) || scheduleSections.count == 0 else { return }
        
        forceReload()
    }
    
    func forceReload() {
    
        // Exit early if loading
        guard !self.isReloading else { return }
        
        // Mark the date as today and reset the filter
        resetScheduleFilter()
        today = Date()
        
        // load schedules
        loadScheduledActivities(from: startStudy, to: scheduleAhead)
    }
    
    override func load(scheduledActivities: [SBBScheduledActivity]) {

        // Update the schedules if this is a cache, there are no schedules or this is the full range
        if self.scheduleSections.count == 0 || self.loadingState == .fromServerForFullDateRange {
            let (sections, schedules, startDate) = ScheduleSection.buildSchedule(with: scheduledActivities, enrollmentDate: enrollment, studyDuration: studyDuration)
            self.dayOne = startDate
            updateSchedules(newSchedules: schedules,
                            newSections: sections,
                            shouldResetNotifications: self.loadingState == .fromServerForFullDateRange)
        }
        
        // update reminders and send passive data
//        if self.loadingState == .fromServerForFullDateRange {
//            DispatchQueue.global(qos: .background).async {
//                self.updatePassiveData(scheduledActivities: scheduledActivities)
//            }
//        }
        
        // call super with the full set
        super.load(scheduledActivities: scheduledActivities)
        
        // If we were waiting for a task to become available, see if it is now
        for notifyTask in self.notifyAvailableTasks {
            if self.isNotifyTaskAvailable(taskId: notifyTask.taskId) {
                notifyTask.callback(notifyTask.taskId)
            }
        }
        self.notifyAvailableTasks = self.notifyAvailableTasks.filter({ (notifyTask) -> Bool in
            return self.isNotifyTaskAvailable(taskId: notifyTask.taskId)
        })
    }
    
    func updateSchedules(newSchedules: [Schedule], newSections: [ScheduleSection], shouldResetNotifications: Bool) {
        DispatchQueue.main.async {
            
            let schedulesChanged = (self.schedules != newSchedules)
            
            // Set the new values
            self.scheduleSections = newSections
            self.schedules = newSchedules
            
            // refresh the delegate
            self.delegate?.reloadFinished(self)
            
            // update the reminders if changed
            if schedulesChanged && shouldResetNotifications {
                self.updateReminderNotifications()
            }
        }
    }
    
//    func updateSchedulesWithChanges(to scheduledActivities: [SBBScheduledActivity]) {
//        guard let todaySectionIndex = self.scheduleSections.index(where: { Calendar.gregorian.isDateInToday($0.date) })
//            else {
//                return
//        }
//                
//        // Get the existing schedules and replace with the new ones
//        self.activities.replace(with: scheduledActivities) {
//            $0.activityIdentifier == $1.activityIdentifier &&
//                $0.scheduledOn == $1.scheduledOn
//        }
//        
//        let todaySection = self.scheduleSections[todaySectionIndex]
//        
//        // Look to see what has changed and if it is in any of the ScheduleItems
//        let newItems = todaySection.items.map({ (originalItem) -> ScheduleItem in
//            let itemActivities = originalItem.taskGroup.filtered(self.activities, on: originalItem.date)
//            let completedActivities = itemActivities.filter({ $0.finishedOn != nil })
//            let isCompleted = (itemActivities.count == completedActivities.count)
//            return ScheduleItem(date: originalItem.date, taskGroup: originalItem.taskGroup, isCompleted: isCompleted)
//        })
//        
//        // Replace the today Item with a new today item
//        if (todaySection.items != newItems) {
//            let newTodaySection = ScheduleSection(items: newItems)
//            var newSections = self.scheduleSections
//            newSections.remove(at: todaySectionIndex)
//            newSections.insert(newTodaySection, at: todaySectionIndex)
//            
//            // Update the schedules
//            updateSchedules(newSchedules: self.schedules, newSections: newSections, shouldResetNotifications: false)
//        }
//    }
    
//    override open func scheduledActivity(for taskViewController: ORKTaskViewController) -> SBBScheduledActivity? {
//        
//        guard let superSchedule = super.scheduledActivity(for: taskViewController) else { return nil }
//        
//        // The schedule date can be used as secondary information to find the correct schedule
//        // But this only applies to the check in, where you can do today's or yesterday's
//        if superSchedule.surveyIdentifier == TaskIdentifier.checkIn.rawValue {
//            if let date = self.scheduleDateForMostRecentQuickCheckIn,
//                let activity = activities.find({
//                    $0.scheduleIdentifier == superSchedule.scheduleIdentifier &&
//                    $0.scheduledOn.startOfDay() == date.startOfDay()
//                }) {
//                return activity
//            }
//        }
//            
//        return superSchedule
//    }
    
    override open func taskViewController(_ taskViewController: ORKTaskViewController, didFinishWith reason: ORKTaskViewControllerFinishReason, error: Error?) {
        super.taskViewController(taskViewController, didFinishWith: reason, error: error)
        // At this point we can assume any use of scheduleDateForMostRecentQuickCheckIn is complete
        // And that we are safe to reset it back to nil so it doesn't get misused
        self.scheduleDateForMostRecentQuickCheckIn = nil
    }
    
//    func replaceScheduleIfNeeded(_ newSchedule: Schedule) {
//
//        // Only replace the current schedule if it has changed
//        guard let index = self.schedules.index(where: { $0.taskGroup == newSchedule.taskGroup }),
//            self.schedules[index] != newSchedule
//            else {
//                return
//        }
//
//        var newSchedules = self.schedules
//        var newSections = self.scheduleSections
//
//        newSchedules.remove(at: index)
//        newSchedules.append(newSchedule)
//
//        // Look to see what the future schedules should be
//        let futureSchedules = ScheduleSection.buildFutureSchedules(with: newSchedules, endDate: self.endStudy)
//        if let first = futureSchedules.first,
//            let firstIndex = newSections.index(where: { $0.date == first.date }) {
//
//            var replaceSchedules = futureSchedules
//            var fromIndex = firstIndex
//
//            // Look at today and add the new schedule if it isn't already added for today
//            let todayWeekday = Calendar.gregorian.component(.weekday, from: self.today)
//            if newSchedule.daysOfWeek.contains(todayWeekday),
//                let todaySection = newSections.first(where: { $0.date.isToday }),
//                !todaySection.contains(taskGroup: newSchedule.taskGroup) {
//                let newItem = ScheduleItem(date: self.today, taskGroup: newSchedule.taskGroup, isCompleted: false)
//                let newTodaySection = ScheduleSection(items: todaySection.items.appending(newItem))
//                replaceSchedules.insert(newTodaySection, at: 0)
//                fromIndex = fromIndex - 1
//            }
//
//            // replace future and today sections as appropriate
//            newSections.replaceSubrange(fromIndex..<newSections.endIndex, with: replaceSchedules)
//        }
//
//        // Update the schedules and sections and reset the notifications
//        updateSchedules(newSchedules: newSchedules, newSections: newSections, shouldResetNotifications: true)
//    }
    
    func updateReminderNotifications() {
        
        // use dispatch async to allow the method to return and put updating reminders on the next run loop
        DispatchQueue.main.async {
            
            // Remove previous reminders
            let identifiers = self.schedules.map({ $0.taskGroup.identifier })
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
            
            // Check that there are any reminders to set and otherwise, do not even check for permission
            guard self.schedules.filter({ $0.timeOfDay != nil }).count > 0 else { return }

            // Check for permission and if granted, then schedule the reminders
            if let settings = UIApplication.shared.currentUserNotificationSettings, settings.types != [] {
                self.addLocalNotifications()
            }
            else {
                UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .alert, .sound]) { (granted, _) in
                    if granted {
                        self.addLocalNotifications()
                    }
                }
            }
        }
    }
    
    fileprivate func addLocalNotifications() {
        DispatchQueue.main.async {
            for schedule in self.schedules {
                schedule.scheduleReminder()
            }
        }
    }

    func createTaskViewController(for taskIdentifier: TaskIdentifier) -> SBATaskViewController? {
        
        let scheduleFilter = SBBScheduledActivity.availableTodayPredicate()
        guard let schedule = self.activities.reversed().find({
            $0.activityIdentifier == taskIdentifier.rawValue &&
                scheduleFilter.evaluate(with: $0)
        }) else { return nil }
        
        return self.createTaskViewController(for: schedule)
    }
    
    func createYesterdaysTaskViewController(for taskIdentifier: TaskIdentifier) -> SBATaskViewController? {
        
        let expiredYesterdayPredicate = NSPredicate(day: Date().addingNumberOfDays(-1), dateKey: #keyPath(SBBScheduledActivity.scheduledOn))
        let unfinishedPredicate = SBBScheduledActivity.unfinishedPredicate()
        let scheduleFilter = NSCompoundPredicate(andPredicateWithSubpredicates: [expiredYesterdayPredicate, unfinishedPredicate])
        guard let schedule = self.activities.reversed().find({
            $0.activityIdentifier == taskIdentifier.rawValue &&
                scheduleFilter.evaluate(with: $0)
        }) else { return nil }
        
        return self.createTaskViewController(for: schedule)
    }
    
//    override func shouldIncludeTimingIntroduction(for timingSchedule: SBBScheduledActivity) -> Bool {
//        if self.alwaysIgnoreTimingIntroductionStepForScheduling {
//            return false
//        }
//        guard let taskGroup = timingSchedule.taskGroup else { return false }
//        return shouldFireTimingSchedule(for: taskGroup)
//    }
    
    override func createTask(for schedule: SBBScheduledActivity) -> (task: ORKTask?, taskRef: SBATaskReference?) {
        let (task, taskRef) = super.createTask(for: schedule)
        guard task != nil, taskRef != nil, let taskId = schedule.taskId, let taskGroup = schedule.taskGroup
        else {
            return (task, taskRef)
        }
        
//        if taskId == .checkIn {
//            var steps: [SBASubtaskStep] = []
//            
//            // If this is the start of the study then get the timing schedule for the daily task
//            // and append to the steps
//            if shouldFireTimingSchedule(for: taskGroup),
//                let timingActivity = schedule.taskGroup?.timingSchedule(from: self.activities) {
//                let (timingTask, _) = super.createTask(for: timingActivity)
//                if let subtask = timingTask as? (NSCopying & NSSecureCoding & ORKTask) {
//                    let timingSubtaskStep = SBASubtaskStep(subtask: subtask)
//                    timingSubtaskStep.taskIdentifier = subtask.identifier
//                    timingSubtaskStep.schemaIdentifier = subtask.identifier
//                    steps.append(timingSubtaskStep)
//                }
//            }
//                        
//            if steps.count > 0 {
//                // Add the initial survey as a subtask step
//                let initialSurveyStep = SBASubtaskStep(subtask: task! as! NSCopying & NSSecureCoding & ORKTask)
//                initialSurveyStep.taskIdentifier = task!.identifier
//                initialSurveyStep.schemaIdentifier = task!.identifier
//                steps.insert(initialSurveyStep, at: 0)
//                
//                // return a new task
//                return (SBANavigableOrderedTask(identifier: initialSurveyStep.identifier, steps: steps), taskRef)
//            }
//        }
        
        return (task, taskRef)
    }
    
    // MARK: Passive Data collection
    
//    func updatePassiveData(scheduledActivities: [SBBScheduledActivity]) {
//
//        // Look for the schedule to attach new data to
//        let identifier = TaskIdentifier.passiveData.rawValue
//        let availableTodayPredicate = SBBScheduledActivity.availableTodayPredicate()
//        guard let schedule = scheduledActivities.first(where: {
//            $0.activityIdentifier == identifier && availableTodayPredicate.evaluate(with: $0)
//        }), schedule.finishedOn == nil
//        else {
//            return
//        }
//
//        // Look for most recent upload to get the start date
//        let filtered = scheduledActivities.filter({
//                $0.activityIdentifier == identifier &&
//                $0.finishedOn != nil
//        }).sorted { $0.finishedOn < $1.finishedOn }
//        let startDate = Calendar.current.startOfDay(for: filtered.last?.finishedOn ?? self.enrollment)
//
//        // We only want to get data for days where the user has a full day history
//        // otherwise, we would end up with only partial information for steps and heart rate.
//        guard !Calendar.current.isDateInToday(startDate) else { return }
//
//        // The end date is the end of yesterday
//        let endDate = Date().addingNumberOfDays(-1).endOfDay()
//
//        // Request data
//        self.requestPassiveData(from: startDate, to: endDate, for: schedule)
//    }
    
//    func requestPassiveData(from startDate: Date, to endDate: Date, for schedule: SBBScheduledActivity) {
//        guard let identifier = schedule.activityIdentifier else { return }
//
//        let dispatchGroup = DispatchGroup()
//
//        let archiveResult = SBAActivityResult(taskIdentifier: identifier, taskRun: UUID(), outputDirectory: nil)
//        archiveResult.schedule = schedule
//        archiveResult.schemaRevision = self.bridgeInfo.schemaReferenceWithIdentifier(identifier)?.schemaRevision ?? 1
//
//        let heartRateResult = HKSamplesDataResult(identifier: "heartRate")
//        let pedometerResult = PedometerDataResult(identifier: "pedometer")
//
//        // Get heart rate samples
//        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
//        let healthStore = HKHealthStore()
//        dispatchGroup.enter()
//        let heartRateQuery = HKAnchoredObjectQuery(type: HKSampleType.quantityType(forIdentifier: .heartRate)!,
//                                           predicate: datePredicate,
//                                           anchor: nil,
//                                           limit: HKObjectQueryNoLimit) { (_, samples, _, _, error) in
//                                            heartRateResult.samples = samples as? [HKQuantitySample]
//                                            heartRateResult.permissionDenied = (error != nil)
//                                            dispatchGroup.leave()
//        }
//        healthStore.execute(heartRateQuery)
//
//        // Get pedometer per day
//        if SBAPermissionsManager.shared.isPermissionGranted(for: SBAPermissionObjectType(permissionType: .coremotion)) &&
//           CMPedometer.isStepCountingAvailable() {
//            let collector = PedometerDataCollector()
//            dispatchGroup.enter()
//            collector.queryPedometer(from: startDate, to: endDate, withHandler: { (pedometerData) in
//                pedometerResult.pedometerData = pedometerData
//                dispatchGroup.leave()
//            })
//        }
//        else {
//            pedometerResult.permissionDenied = true
//        }
//
//        dispatchGroup.notify(queue: DispatchQueue.global(qos: .background)) {
//            let stepResult = ORKStepResult(stepIdentifier: identifier, results: [heartRateResult, pedometerResult])
//            archiveResult.results = [stepResult]
//            if let archive = self.archive(for: archiveResult) {
//
//                // Update the schedule
//                // Note: the client data is set during the sendUpdated() call
//                schedule.startedOn = Date()
//                schedule.finishedOn = Date()
//                self.sendUpdated(scheduledActivities: [schedule])
//
//                // upload the archive
//                SBBDataArchive.encryptAndUploadArchives([archive])
//            }
//        }
//    }
    
    override func update(schedule: SBBScheduledActivity, task: ORKTask, result: ORKTaskResult, finishedOn: Date?) {
        super.update(schedule: schedule, task: task, result: result, finishedOn: finishedOn)
        
        // Since this is a singleton, it's better to post a notification for events
        // rather than play king of the hill with the delegate
        // This notification will let view controllers know they should update the UI
        // because a scheduled task has been updated
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: self.scheduleUpdatedNotificationName, object: nil)
        }
    }
    
    /**
     If the task is available right away, the callback will be invoked
     Otherwise, we will save the callback to be executed later when today's task is available
     */
    public func notifyWhenTaskIsAvailable(taskId: String, callback: @escaping (String) -> Void) {
        if self.isNotifyTaskAvailable(taskId: taskId) {
            callback(taskId)
        } else {
            let notifyLater = NotifyTaskAvailable(taskId: taskId, callback: callback)
            self.notifyAvailableTasks.append(notifyLater)
        }
    }
    
    fileprivate func isNotifyTaskAvailable(taskId: String) -> Bool {
        let taskAvailablePredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [SBBScheduledActivity.includeTasksPredicate(with: [taskId]),
                                                                                         SBBScheduledActivity.availableTodayPredicate()])
        return self.activities.contains { (schedule) -> Bool in
            return taskAvailablePredicate.evaluate(with: schedule)
        }
    }
    
    fileprivate class NotifyTaskAvailable {
        var taskId: String
        var callback: ((String) -> Void)
        
        init(taskId: String, callback: @escaping ((String) -> Void)) {
            self.taskId = taskId
            self.callback = callback
        }
    }
}
