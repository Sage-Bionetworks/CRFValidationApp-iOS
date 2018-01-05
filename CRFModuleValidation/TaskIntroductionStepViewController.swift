//
//  TaskIntroductionStepViewController.swift
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
import ResearchSuiteUI
import ResearchSuite
import UserNotifications

open class TaskIntroductionStepViewController: RSDStepViewController {
    
    open var reminderIdentifier: String {
        return self.step.identifier
    }

    open override func skipForward() {
        updateReminderNotification()
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Remove any previous reminder.
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
    }
    
    open func handleNotificationAuthorizationDenied() {
        // TODO: syoung 12/27/2017 Localize
        self.presentAlertWithOk(title: "Cannot add reminder", message: "This app does not have authorization to send you a reminder notification. Go to the 'Settings' app to change your permissions.") { (_) in
        }
    }
    
    open func remindMeLater() {
        // TODO: syoung 12/27/2017 Localize
        
        let actionNone = UIAlertAction(title: "Do not remind me", style: .cancel) { (_) in
            // Do nothing.
        }
        let action15min = UIAlertAction(title: "Remind me in 15 minutes", style: .default) { (_) in
            self.addReminder(timeInterval: 15 * 60)
        }
        let action1hr = UIAlertAction(title: "Remind me in 1 hour", style: .default) { (_) in
            self.addReminder(timeInterval: 60 * 60)
        }
        let action2hr = UIAlertAction(title: "Remind me in 2 hour", style: .default) { (_) in
            self.addReminder(timeInterval: 2 * 60 * 60)
        }
        
        self.presentAlertWithActions(title: nil, message: "When do you want a reminder?", preferredStyle: .actionSheet, actions: [action2hr, action1hr, action15min, actionNone])
    }
    
    open func addReminder(timeInterval: TimeInterval) {
        // TODO: syoung 12/27/2017 Localize
        
        let content = UNMutableNotificationContent()
        if let title = (self.step as? RSDTaskInfoStep)?.title ?? self.uiStep?.title {
            content.body = "Time to do the \(title)."
        } else {
            content.body = "Time to perform your next task."
        }
        content.sound = UNNotificationSound.default()
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            content.categoryIdentifier = "\(bundleIdentifier).RemindMeLater"
        }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: reminderIdentifier, content: content, trigger: trigger)
        
        // Schedule the notification.
        UNUserNotificationCenter.current().add(request) { (error) in
            if error != nil {
                print("Failed to add notification for \(self.reminderIdentifier). \(error!)")
            }
            self.cancel()
        }
    }
    
    public final func updateReminderNotification() {
        
        // Check if this is the main thread and if not, then call it on the main thread.
        // The expectation is that if calling method is a button push, the response should be inline
        // and *not* at the bottom of the queue.
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.updateReminderNotification()
            }
            return
        }

        UNUserNotificationCenter.current().getNotificationSettings { [weak self] (settings) in
            switch settings.authorizationStatus {
            case .notDetermined:
                self?._requestAuthorization()
            case .denied:
                self?.handleNotificationAuthorizationDenied()
            case .authorized:
                self?.remindMeLater()
            }
        }
    }

    fileprivate func _requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .alert, .sound]) { [weak self] (granted, _) in
            DispatchQueue.main.async {
                if granted {
                    self?.remindMeLater()
                }
            }
        }
    }
}
