//
//  GroupedScheduledActivityManager.swift
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

class GroupedScheduledActivityManager : ScheduledActivityManager {
    
    // Set a default to the all activities
    var taskGroup: TaskGroup! = TaskGroup.addActivities
    var timingActivity: SBBScheduledActivity?
    var timingActivityFired: Bool = false
    
    // Set the date for activities to show. default == today.
    var date: Date = Date()
    
    var allActivitiesCompleted: Bool {
        return self.activities.reduce(true, { $0 && $1.finishedOn != nil })
    }
    
    var shouldFireTimingSchedule: Bool {
        return false
//        return !timingActivityFired &&
//            (timingActivity != nil) &&
//            allActivitiesCompleted &&
//            MasterScheduledActivityManager.shared.shouldFireTimingSchedule(for: self.taskGroup)
    }
    
    func createTimingTaskViewController() -> ORKTaskViewController? {
        guard let schedule = timingActivity else { return nil }
        let taskVC = self.createTaskViewController(for: schedule)
        timingActivityFired = true
        return taskVC
    }
    
    override var activities:[SBBScheduledActivity] {
        get { return super.activities }
        set {
            super.activities = taskGroup.filteredAndSorted(newValue, on: date)
//            self.timingActivity = taskGroup.timingSchedule(from: newValue)
        }
    }
    
//    override func shouldIncludeTimingIntroduction(for timingSchedule: SBBScheduledActivity) -> Bool {
//        guard let lhs = timingSchedule.taskId, let rhs = self.timingActivity?.taskId else { return false }
//        return lhs == rhs && allActivitiesCompleted
//    }
    
    override func reloadData() {
        // If the activities are already loaded, then there is no need to load them again
        guard activities.count == 0 else {
            DispatchQueue.main.async {
                self.delegate?.reloadFinished(self)
            }
            return
        }
        super.reloadData()
    }
    
    override func scheduledActivity(for taskViewController: ORKTaskViewController) -> SBBScheduledActivity? {
        if let schedule = super.scheduledActivity(for: taskViewController) {
            return schedule
        }
        else if timingActivity != nil, taskViewController.task!.identifier == timingActivity!.activityIdentifier! {
            return timingActivity
        }
        return nil
    }
    
    override func scheduledActivity(for taskIdentifier: String) -> SBBScheduledActivity? {
        return super.scheduledActivity(for: taskIdentifier) ?? {
            guard let timingIdentifer = self.timingActivity?.activityIdentifier,
                timingIdentifer == taskIdentifier
            else {
                return nil
            }
            return self.timingActivity
        }()
    }
    
//    func numberOfSections() -> Int {
//        return 1
//    }
//    
//    @objc(numberOfRowsInSection:)
//    func numberOfRows(for section: Int) -> Int {
//        return self.activities.count
//    }
//    
//    @objc(scheduledActivityAtIndexPath:)
//    func scheduledActivity(at indexPath: IndexPath) -> SBBScheduledActivity? {
//        return self.activities[indexPath.row]
//    }
//    
//    @objc(shouldShowTaskForIndexPath:)
//    func shouldShowTask(for indexPath: IndexPath) -> Bool {
//        return true
//    }
    
    @objc(didSelectRowAtIndexPath:)
    override func didSelectRow(at indexPath: IndexPath) {
        // Only if the task was created should something be done.
        guard let schedule = scheduledActivity(at: indexPath)
            else {
                assertionFailure("Could not find schedule")
                return
        }
        
        guard let taskViewController = createRSDTaskViewController(for: schedule)
            else {
                assertionFailure("Failed to create task view controller for \(schedule)")
                return
        }
        
        self.delegate?.presentViewController(taskViewController, animated: true, completion: nil)
    }
}
